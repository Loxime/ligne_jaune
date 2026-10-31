<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\EntityRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class EntityShowController
{
    private const HEADERS = [
        'Cache-Control' => 'no-store',
        'X-Content-Type-Options' => 'nosniff',
    ];

    public function __construct(
        private readonly EntityRepository $entities
    ) {
    }

    public function __invoke(string $id): JsonResponse
    {
        // Validation d'un UUID canonique.
        if (preg_match(
            '/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i',
            $id
        ) !== 1) {
            return $this->error(
                'INVALID_ENTITY_ID',
                Response::HTTP_BAD_REQUEST
            );
        }

        try {
            $entity = $this->entities->findById(
                strtolower($id)
            );
        } catch (Throwable $exception) {
            error_log(sprintf(
                '[Ligne Jaune] Entity lookup failed: %s',
                $exception::class
            ));

            return $this->error(
                'ENTITY_STORAGE_UNAVAILABLE',
                Response::HTTP_SERVICE_UNAVAILABLE
            );
        }

        if ($entity === null) {
            return $this->error(
                'ENTITY_NOT_FOUND',
                Response::HTTP_NOT_FOUND
            );
        }

        return new JsonResponse(
            ['data' => $entity],
            Response::HTTP_OK,
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
