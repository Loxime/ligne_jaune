<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\SourceRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class SourceShowController
{
    public function __construct(
        private readonly SourceRepository $sources
    ) {
    }

    public function __invoke(string $id): JsonResponse
    {
        if (preg_match(
            '/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/iD',
            $id
        ) !== 1) {
            return $this->error('INVALID_SOURCE_ID', 400);
        }

        try {
            $source = $this->sources->findById(
                strtolower($id)
            );
        } catch (Throwable $exception) {
            error_log(
                '[Ligne Jaune] Source lookup failed: '
                . $exception::class
            );

            return $this->error('STORAGE_UNAVAILABLE', 503);
        }

        if ($source === null) {
            return $this->error('SOURCE_NOT_FOUND', 404);
        }

        return new JsonResponse(
            ['data' => $source],
            Response::HTTP_OK,
            ['Cache-Control' => 'no-store']
        );
    }

    private function error(
        string $code,
        int $status
    ): JsonResponse {
        return new JsonResponse(
            ['error' => ['code' => $code]],
            $status,
            [
                'Cache-Control' => 'no-store',
                'X-Content-Type-Options' => 'nosniff',
            ]
        );
    }
}
