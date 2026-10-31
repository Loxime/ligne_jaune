<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\RelationshipRepository;
use DateTimeImmutable;
use JsonException;
use PDOException;
use stdClass;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class RelationshipController
{
    private const UUID_PATTERN =
        '/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/iD';

    private const TYPES = [
        'directs',
        'member_of',
        'holds_office_at',
        'employed_by',
        'sits_on_board_of',
        'owns_stake_in',
        'subsidiary_of',
    ];

    private const REQUIRED_FIELDS = [
        'subject_entity_id',
        'object_entity_id',
        'relation_type',
        'source_id',
        'source_locator',
    ];

    public function __construct(
        private readonly RelationshipRepository $relationships
    ) {
    }

    public function create(Request $request): JsonResponse
    {
        if ($request->getContentTypeFormat() !== 'json') {
            return $this->error('UNSUPPORTED_MEDIA_TYPE', 415);
        }

        $body = $request->getContent();

        if (strlen($body) > 8192) {
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

        $allowed = [
            ...self::REQUIRED_FIELDS,
            'valid_from',
            'valid_until',
        ];

        foreach (array_keys($input) as $key) {
            if (!in_array($key, $allowed, true)) {
                return $this->error('UNKNOWN_FIELD', 400);
            }
        }

        foreach (self::REQUIRED_FIELDS as $field) {
            if (
                !array_key_exists($field, $input)
                || !is_string($input[$field])
            ) {
                return $this->error('MISSING_REQUIRED_FIELD', 400);
            }
        }

        foreach ([
            'subject_entity_id',
            'object_entity_id',
            'source_id',
        ] as $field) {
            if (!$this->uuid($input[$field])) {
                return $this->error('INVALID_REFERENCE_ID', 400);
            }
        }

        if (
            strtolower($input['subject_entity_id'])
            === strtolower($input['object_entity_id'])
        ) {
            return $this->error('SELF_RELATION_NOT_ALLOWED', 400);
        }

        if (!in_array(
            $input['relation_type'],
            self::TYPES,
            true
        )) {
            return $this->error('INVALID_RELATION_TYPE', 400);
        }

        $locator = trim($input['source_locator']);

        if (
            $locator === ''
            || strlen($locator) > 500
            || preg_match('/[\x00-\x1F\x7F]/', $locator)
        ) {
            return $this->error('INVALID_SOURCE_LOCATOR', 400);
        }

        $from = $this->parseDate(
            $input['valid_from'] ?? null
        );

        $until = $this->parseDate(
            $input['valid_until'] ?? null
        );

        if (
            $from === false
            || $until === false
            || (
                $from !== null
                && $until !== null
                && $until < $from
            )
        ) {
            return $this->error('INVALID_RELATION_PERIOD', 400);
        }

        try {
            $created = $this->relationships->create([
                'subject_entity_id' =>
                    $input['subject_entity_id'],
                'object_entity_id' =>
                    $input['object_entity_id'],
                'relation_type' =>
                    $input['relation_type'],
                'source_id' =>
                    $input['source_id'],
                'source_locator' => $locator,
                'valid_from' => $from,
                'valid_until' => $until,
            ]);

            return $this->response(
                ['data' => $created],
                201
            );

        } catch (PDOException $exception) {
            if ($exception->getCode() === '23503') {
                return $this->error(
                    'REFERENCED_ENTITY_OR_SOURCE_NOT_FOUND',
                    422
                );
            }

            return $this->storageError($exception);

        } catch (Throwable $exception) {
            return $this->storageError($exception);
        }
    }

    public function show(string $id): JsonResponse
    {
        if (!$this->uuid($id)) {
            return $this->error('INVALID_RELATIONSHIP_ID', 400);
        }

        try {
            $relation = $this->relationships->findById($id);
        } catch (Throwable $exception) {
            return $this->storageError($exception);
        }

        if ($relation === null) {
            return $this->error('RELATIONSHIP_NOT_FOUND', 404);
        }

        return $this->response(['data' => $relation], 200);
    }

    private function uuid(string $value): bool
    {
        return preg_match(
            self::UUID_PATTERN, $value
        ) === 1;
    }

    private function parseDate(mixed $value): string|false|null
    {
        if ($value === null) {
            return null;
        }

        if (
            !is_string($value)
            || preg_match(
                '/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/D',
                $value
            ) !== 1
        ) {
            return false;
        }

        $date = DateTimeImmutable::createFromFormat(
            '!Y-m-d',
            $value
        );

        if (
            $date === false
            || $date->format('Y-m-d') !== $value
        ) {
            return false;
        }

        return $value;
    }

    private function storageError(Throwable $exception): JsonResponse
    {
        error_log(
            '[Ligne Jaune] Relationship storage: '
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
        array $data,
        int $status
    ): JsonResponse {
        return new JsonResponse(
            $data,
            $status,
            [
                'Cache-Control' => 'no-store',
                'X-Content-Type-Options' => 'nosniff',
            ]
        );
    }
}
