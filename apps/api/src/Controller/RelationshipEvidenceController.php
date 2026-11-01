<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\RelationshipEvidenceRepository;
use JsonException;
use PDOException;
use stdClass;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class RelationshipEvidenceController
{
    private const UUID =
        '/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/iD';

    private const ROLES = [
        'supports', 'contradicts', 'context',
    ];

    public function __construct(
        private readonly RelationshipEvidenceRepository $repository
    ) {}

    public function index(
        Request $request,
        string $id
    ): JsonResponse {
        if (!$this->validUuid($id)) {
            return $this->error('INVALID_RELATIONSHIP_ID', 400);
        }

        $query = $request->query->all();

        if (array_diff(array_keys($query), ['limit', 'offset'])) {
            return $this->error('INVALID_QUERY', 400);
        }

        $limit = $this->integer($query['limit'] ?? '20', 1, 100);
        $offset = $this->integer(
            $query['offset'] ?? '0', 0, 10000
        );

        if ($limit === null || $offset === null) {
            return $this->error('INVALID_PAGINATION', 400);
        }

        try {
            if (!$this->repository->relationshipExists($id)) {
                return $this->error('RELATIONSHIP_NOT_FOUND', 404);
            }

            $result = $this->repository->findAll(
                $id, $limit, $offset
            );

            return $this->response([
                'data' => $result['items'],
                'pagination' => [
                    'limit' => $limit,
                    'offset' => $offset,
                    'returned' => count($result['items']),
                    'has_more' => $result['has_more'],
                ],
            ], 200);
        } catch (Throwable $exception) {
            return $this->storageError($exception);
        }
    }

    public function create(
        Request $request,
        string $id
    ): JsonResponse {
        if (!$this->validUuid($id)) {
            return $this->error('INVALID_RELATIONSHIP_ID', 400);
        }

        if ($request->getContentTypeFormat() !== 'json') {
            return $this->error('UNSUPPORTED_MEDIA_TYPE', 415);
        }

        $body = $request->getContent();

        if (strlen($body) > 4096) {
            return $this->error('PAYLOAD_TOO_LARGE', 413);
        }

        try {
            $payload = json_decode(
                $body, false, 16, JSON_THROW_ON_ERROR
            );
        } catch (JsonException) {
            return $this->error('INVALID_JSON', 400);
        }

        if (!$payload instanceof stdClass) {
            return $this->error('INVALID_PAYLOAD', 400);
        }

        $input = get_object_vars($payload);
        $required = ['source_id', 'locator', 'role'];

        if (
            array_diff($required, array_keys($input))
            || array_diff(
                array_keys($input),
                [...$required, 'note']
            )
        ) {
            return $this->error('INVALID_FIELDS', 400);
        }

        foreach ($required as $field) {
            if (!is_string($input[$field])) {
                return $this->error('INVALID_FIELDS', 400);
            }
        }

        $sourceId = $input['source_id'];
        $locator = trim($input['locator']);
        $role = $input['role'];
        $note = $input['note'] ?? null;

        if (!$this->validUuid($sourceId)) {
            return $this->error('INVALID_SOURCE_ID', 400);
        }

        if (
            !$this->validText($locator, 500)
            || $locator === ''
        ) {
            return $this->error('INVALID_LOCATOR', 400);
        }

        if (!in_array($role, self::ROLES, true)) {
            return $this->error('INVALID_ROLE', 400);
        }

        if ($note !== null) {
            if (!is_string($note)) {
                return $this->error('INVALID_NOTE', 400);
            }

            $note = trim($note);

            if (!$this->validText($note, 2000)) {
                return $this->error('INVALID_NOTE', 400);
            }

            $note = $note === '' ? null : $note;
        }

        try {
            if (!$this->repository->relationshipExists($id)) {
                return $this->error('RELATIONSHIP_NOT_FOUND', 404);
            }

            $created = $this->repository->create(
                $id, $sourceId, $locator, $role, $note
            );

            return $this->response(['data' => $created], 201);
        } catch (PDOException $exception) {
            return match ($exception->getCode()) {
                '23505' => $this->error('EVIDENCE_EXISTS', 409),
                '23503' => $this->error('SOURCE_NOT_FOUND', 422),
                default => $this->storageError($exception),
            };
        } catch (Throwable $exception) {
            return $this->storageError($exception);
        }
    }

    private function validUuid(string $id): bool
    {
        return preg_match(self::UUID, $id) === 1;
    }

    private function validText(string $value, int $max): bool
    {
        return strlen($value) <= $max
            && preg_match('//u', $value) === 1
            && preg_match('/[\x00-\x1F\x7F]/', $value) !== 1;
    }

    private function integer(
        mixed $value,
        int $min,
        int $max
    ): ?int {
        if (
            !is_string($value)
            || preg_match(
                '/\A(?:0|[1-9][0-9]*)\z/D',
                $value
            ) !== 1
            || strlen($value) > 6
        ) {
            return null;
        }

        $number = (int) $value;

        return $number >= $min && $number <= $max
            ? $number
            : null;
    }

    private function storageError(Throwable $exception): JsonResponse
    {
        error_log(
            '[Ligne Jaune] Evidence: ' . $exception::class
        );

        return $this->error('STORAGE_UNAVAILABLE', 503);
    }

    private function error(
        string $code,
        int $status
    ): JsonResponse {
        return $this->response(
            ['error' => ['code' => $code]], $status
        );
    }

    private function response(
        array $payload,
        int $status
    ): JsonResponse {
        return new JsonResponse($payload, $status, [
            'Cache-Control' => 'no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
