<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\EntityRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class EntityIndexController
{
    private const ENTITY_KINDS = [
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
        private readonly EntityRepository $entities
    ) {
    }

    public function __invoke(Request $request): JsonResponse
    {
        $query = $request->query->all();

        // Refuser les paramètres inconnus.
        foreach (array_keys($query) as $parameter) {
            if (!in_array(
                $parameter,
                ['kind', 'limit', 'offset'],
                true
            )) {
                return $this->invalidQuery();
            }
        }

        $kind = $query['kind'] ?? null;

        if (
            $kind !== null
            && (
                !is_string($kind)
                || !in_array($kind, self::ENTITY_KINDS, true)
            )
        ) {
            return $this->invalidQuery();
        }

        $limit = $this->parseInteger(
            $query['limit'] ?? '20',
            1,
            100
        );

        $offset = $this->parseInteger(
            $query['offset'] ?? '0',
            0,
            10000
        );

        if ($limit === null || $offset === null) {
            return $this->invalidQuery();
        }

        try {
            $result = $this->entities->findAll(
                $kind,
                $limit,
                $offset
            );

            return new JsonResponse(
                [
                    'data' => $result['items'],
                    'pagination' => [
                        'limit' => $limit,
                        'offset' => $offset,
                        'returned' => count($result['items']),
                        'has_more' => $result['has_more'],
                    ],
                ],
                Response::HTTP_OK,
                self::HEADERS
            );
        } catch (Throwable $exception) {
            // Aucun détail de connexion SQL
            // n'est transmis au client.
            error_log(sprintf(
                '[Ligne Jaune] Entity read failed: %s',
                $exception::class
            ));

            return new JsonResponse(
                [
                    'error' => [
                        'code' => 'ENTITY_STORAGE_UNAVAILABLE',
                    ],
                ],
                Response::HTTP_SERVICE_UNAVAILABLE,
                self::HEADERS
            );
        }
    }

    private function parseInteger(
        mixed $value,
        int $minimum,
        int $maximum
    ): ?int {
        if (
            !is_string($value)
            || preg_match(
                '/\A(?:0|[1-9][0-9]*)\z/',
                $value
            ) !== 1
            || strlen($value) > 6
        ) {
            return null;
        }

        $number = (int) $value;

        if ($number < $minimum || $number > $maximum) {
            return null;
        }

        return $number;
    }

    private function invalidQuery(): JsonResponse
    {
        return new JsonResponse(
            [
                'error' => [
                    'code' => 'INVALID_QUERY_PARAMETERS',
                    'message' => 'Invalid entity filters or pagination.',
                ],
            ],
            Response::HTTP_BAD_REQUEST,
            self::HEADERS
        );
    }
}
