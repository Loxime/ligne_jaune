<?php

declare(strict_types=1);

namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

final class ApiTokenSubscriber implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::REQUEST => [
                'onKernelRequest',
                256,
            ],
        ];
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        $request = $event->getRequest();
        $path = $request->getPathInfo();

        if ($path !== '/api' && !str_starts_with($path, '/api/')) {
            return;
        }

        // Seul le healthcheck de base est public.
        if (
            $path === '/api/health'
            && $request->isMethod(Request::METHOD_GET)
        ) {
            return;
        }

        $secretPath = $_SERVER['API_ACCESS_TOKEN_FILE']
            ?? $_ENV['API_ACCESS_TOKEN_FILE']
            ?? getenv('API_ACCESS_TOKEN_FILE')
            ?: '/run/secrets/api_access_token';

        if (
            !is_string($secretPath)
            || !is_readable($secretPath)
        ) {
            $event->setResponse(
                $this->error('AUTH_UNAVAILABLE', 503)
            );
            return;
        }

        $secret = file_get_contents($secretPath);

        if ($secret === false) {
            $event->setResponse(
                $this->error('AUTH_UNAVAILABLE', 503)
            );
            return;
        }

        $expected = trim($secret);

        if (
            preg_match('/\A[a-f0-9]{64}\z/D', $expected) !== 1
        ) {
            $event->setResponse(
                $this->error('AUTH_UNAVAILABLE', 503)
            );
            return;
        }

        $authorization = $request->headers->get(
            'Authorization',
            ''
        );

        if (
            preg_match(
                '/\ABearer ([a-f0-9]{64})\z/D',
                $authorization,
                $matches
            ) !== 1
            || !hash_equals($expected, $matches[1])
        ) {
            $event->setResponse(
                $this->error('UNAUTHORIZED', 401)
            );
        }
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
                'WWW-Authenticate' => 'Bearer realm="Ligne Jaune"',
            ]
        );
    }
}
