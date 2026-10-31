<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\EntityIdentifierRepository;
use JsonException;
use PDOException;
use stdClass;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class EntityIdentifierController
{
    private const UUID_PATTERN =
        '/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/iD';

    private const FORMATS = [
        'SIREN' => '/\A[0-9]{9}\z/D',
        'SIRET' => '/\A[0-9]{14}\z/D',
        'LEI' => '/\A[A-Z0-9]{18}[0-9]{2}\z/D',
    ];

    public function __construct(
        private readonly EntityIdentifierRepository $identifiers
    ) {
    }

    public function index(string $id): JsonResponse
    {
        if (!$this->uuid($id)) {
            return $this->error('INVALID_ENTITY_ID', 400);
        }

        try {
            if (!$this->identifiers->entityExists($id)) {
                return $this->error('ENTITY_NOT_FOUND', 404);
            }

            return $this->response(
                ['data' => $this->identifiers->findByEntity($id)],
                200
            );
        } catch (Throwable $exception) {
            error_log(
                '[Ligne Jaune] Identifier read: '
                . $exception::class
            );

            return $this->error('STORAGE_UNAVAILABLE', 503);
        }
    }

    public function create(
        Request $request,
        string $id
    ): JsonResponse {
        if (!$this->uuid($id)) {
            return $this->error('INVALID_ENTITY_ID', 400);
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

        $required = [
            'scheme', 'value', 'source_id', 'source_locator'
        ];

        if (
            count($input) !== count($required)
            || array_diff(array_keys($input), $required)
            || array_diff($required, array_keys($input))
        ) {
            return $this->error('INVALID_FIELDS', 400);
        }

        foreach ($required as $field) {
            if (!is_string($input[$field])) {
                return $this->error('INVALID_FIELDS', 400);
            }
        }

        $scheme = strtoupper(trim($input['scheme']));
        $value = strtoupper(trim($input['value']));
        $sourceId = $input['source_id'];
        $locator = trim($input['source_locator']);

        if (
            !isset(self::FORMATS[$scheme])
            || preg_match(self::FORMATS[$scheme], $value) !== 1
        ) {
            return $this->error('INVALID_IDENTIFIER', 400);
        }

        if (
            !$this->uuid($sourceId)
            || $locator === ''
            || strlen($locator) > 500
            || preg_match('/[\x00-\x1F\x7F]/', $locator)
        ) {
            return $this->error('INVALID_PROVENANCE', 400);
        }

        try {
            if (!$this->identifiers->entityExists($id)) {
                return $this->error('ENTITY_NOT_FOUND', 404);
            }

            $created = $this->identifiers->create(
                $id, $scheme, $value, $sourceId, $locator
            );

            return $this->response(['data' => $created], 201);
        } catch (PDOException $exception) {
            return match ($exception->getCode()) {
                '23505' => $this->error('IDENTIFIER_EXISTS', 409),
                '23503' => $this->error('INVALID_REFERENCE', 422),
                default => $this->storageError($exception),
            };
        } catch (Throwable $exception) {
            return $this->storageError($exception);
        }
    }

    private function uuid(string $value): bool
    {
        return preg_match(
            self::UUID_PATTERN, $value
        ) === 1;
    }

    private function storageError(Throwable $exception): JsonResponse
    {
        error_log(
            '[Ligne Jaune] Identifier storage: '
            . $exception::class
        );

        return $this->error('STORAGE_UNAVAILABLE', 503);
    }

    private function error(
        string $code,
        int $status
    ): JsonResponse {
        return $this->response(
            ['error' => ['code' => $code]],
            $status
        );
    }

    private function response(
        array $payload,
        int $status
    ): JsonResponse {
        return new JsonResponse(
            $payload,
            $status,
            [
                'Cache-Control' => 'no-store',
                'X-Content-Type-Options' => 'nosniff',
            ]
        );
    }
}
