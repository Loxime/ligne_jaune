<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\EntityWriteRepository;
use JsonException;
use PDOException;
use stdClass;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;

#[AsController]
final class EntityCreateController
{
    private const KINDS = [
        'person',
        'company',
        'association',
        'institution',
        'other',
    ];

    private const HEADERS = [
        'Cache-Control' => 'no-store',
        'X-Content-Type-Options' => 'nosniff',
    ];

    public function __construct(
        private readonly EntityWriteRepository $entities
    ) {
    }

    public function __invoke(Request $request): JsonResponse
    {
        if ($request->getContentTypeFormat() !== 'json') {
            return $this->error('UNSUPPORTED_MEDIA_TYPE', 415);
        }

        $declaredSize = $request->headers->get('Content-Length');

        if (
            $declaredSize !== null
            && ctype_digit($declaredSize)
            && (int) $declaredSize > 4096
        ) {
            return $this->error('PAYLOAD_TOO_LARGE', 413);
        }

        $body = $request->getContent();

        if (strlen($body) > 4096) {
            return $this->error('PAYLOAD_TOO_LARGE', 413);
        }

        try {
            $payload = json_decode(
                $body,
                false,
                16,
                JSON_THROW_ON_ERROR
            );
        } catch (JsonException) {
            return $this->error('INVALID_JSON', 400);
        }

        if (!$payload instanceof stdClass) {
            return $this->error('INVALID_PAYLOAD', 400);
        }

        $fields = get_object_vars($payload);

        foreach (array_keys($fields) as $key) {
            if (!in_array(
                $key,
                ['kind', 'name', 'description'],
                true
            )) {
                return $this->error('UNKNOWN_FIELD', 400);
            }
        }

        $kind = $fields['kind'] ?? null;
        $name = $fields['name'] ?? null;
        $description = $fields['description'] ?? null;

        if (
            !is_string($kind)
            || !in_array($kind, self::KINDS, true)
        ) {
            return $this->error('INVALID_KIND', 400);
        }

        if (!is_string($name)) {
            return $this->error('INVALID_NAME', 400);
        }

        $name = trim($name);

        if (
            $name === ''
            || strlen($name) > 240
            || preg_match('/[\x00-\x1F\x7F]/', $name) === 1
            || preg_match('/\A[\s\p{Z}]*\z/u', $name) === 1
        ) {
            return $this->error('INVALID_NAME', 400);
        }

        if ($description !== null) {
            if (!is_string($description)) {
                return $this->error('INVALID_DESCRIPTION', 400);
            }

            $description = trim($description);

            if (
                strlen($description) > 4000
                || str_contains($description, "\0")
            ) {
                return $this->error('INVALID_DESCRIPTION', 400);
            }

            if ($description === '') {
                $description = null;
            }
        }

        try {
            $created = $this->entities->create(
                $kind,
                $name,
                $description
            );
        } catch (PDOException $exception) {
            error_log(
                '[Ligne Jaune] Entity creation failed: '
                . $exception::class
            );

            return $this->error(
                'ENTITY_STORAGE_UNAVAILABLE',
                503
            );
        }

        return new JsonResponse(
            ['data' => $created],
            Response::HTTP_CREATED,
            self::HEADERS
        );
    }

    private function error(
        string $code,
        int $status
    ): JsonResponse {
        return new JsonResponse(
            ['error' => ['code' => $code]],
            $status,
            self::HEADERS
        );
    }
}
