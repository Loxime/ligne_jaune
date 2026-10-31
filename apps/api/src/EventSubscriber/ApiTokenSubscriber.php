<?php

declare(strict_types=1);

namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

final class ApiTokenSubscriber implements EventSubscriberInterface
{
    private const PUBLIC_PATH = '/api/health';

    private const HEADERS = [
        'Cache-Control' => 'no-store',
        'X-Content-Type-Options' => 'nosniff',
    ];

    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::REQUEST => ['onKernelRequest', 64],
        ];
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();
        $path = $request->getPathInfo();

        if ($path === self::PUBLIC_PATH) {
            return;
        }

        // Toutes les routes API sont privées par défaut.
        if ($path !== '/api' && !str_starts_with($path, '/api/')) {
            return;
        }

        $secretFile = getenv('API_ACCESS_TOKEN_FILE');

        if (!is_string($secretFile) || $secretFile === '') {
            $event->setResponse($this->unavailable());
            return;
        }

        if (!is_file($secretFile) || !is_readable($secretFile)) {
            $event->setResponse($this->unavailable());
            return;
        }

        $expected = file_get_contents($secretFile);

        if ($expected === false) {
            $event->setResponse($this->unavailable());
            return;
        }

        $expected = rtrim($expected, "\r\n");

        // Un secret mal configuré n'autorise aucune requête.
        if (preg_match('/\A[a-f0-9]{64}\z/D', $expected) !== 1) {
            $event->setResponse($this->unavailable());
            return;
        }

        $authorization = $request->headers->all('authorization');

        if (count($authorization) !== 1) {
            $event->setResponse($this->unauthorized());
            return;
        }

        $header = $authorization[0];

        if (
            !is_string($header)
            || preg_match(
                '/\ABearer ([a-f0-9]{64})\z/iD',
                $header,
                $matches
            ) !== 1
        ) {
            $event->setResponse($this->unauthorized());
            return;
        }

        // Comparaison résistante aux attaques temporelles.
        if (!hash_equals($expected, $matches[1])) {
            $event->setResponse($this->unauthorized());
            return;
        }
    }

    private function unauthorized(): JsonResponse
    {
        return new JsonResponse(
            [
                'error' => [
                    'code' => 'AUTHENTICATION_REQUIRED',
                ],
            ],
            Response::HTTP_UNAUTHORIZED,
            [
                ...self::HEADERS,
                'WWW-Authenticate' => 'Bearer realm="ligne-jaune-api"',
            ]
        );
    }

    private function unavailable(): JsonResponse
    {
        return new JsonResponse(
            [
                'error' => [
                    'code' => 'AUTHENTICATION_UNAVAILABLE',
                ],
            ],
            Response::HTTP_SERVICE_UNAVAILABLE,
            self::HEADERS
        );
    }
}
