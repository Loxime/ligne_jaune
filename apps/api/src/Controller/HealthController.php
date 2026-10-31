<?php

declare(strict_types=1);

namespace App\Controller;

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

final class HealthController
{
    public function __invoke(): JsonResponse
    {
        return new JsonResponse(
            [
                'status' => 'ok',
                'service' => 'ligne-jaune-api',
            ],
            Response::HTTP_OK,
            [
                'Cache-Control' => 'no-store',
                'X-Content-Type-Options' => 'nosniff',
            ]
        );
    }
}
