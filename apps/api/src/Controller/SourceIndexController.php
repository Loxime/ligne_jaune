<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\SourceRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class SourceIndexController
{
    private const KINDS = [
        'official',
        'book',
        'article',
        'report',
        'archive',
        'personal_note',
        'other',
    ];

    public function __construct(
        private readonly SourceRepository $sources
    ) {
    }

    public function __invoke(Request $request): JsonResponse
    {
        $query = $request->query->all();

        foreach (array_keys($query) as $key) {
            if (!in_array(
                $key,
                ['kind', 'limit', 'offset'],
                true
            )) {
                return $this->error('INVALID_QUERY', 400);
            }
        }

        $kind = $query['kind'] ?? null;

        if (
            $kind !== null &&
            (
                !is_string($kind) ||
                !in_array($kind, self::KINDS, true)
            )
        ) {
            return $this->error('INVALID_KIND', 400);
        }

        $limit = $this->integer(
            $query['limit'] ?? '20',
            1,
            100
        );

        $offset = $this->integer(
            $query['offset'] ?? '0',
            0,
            10000
        );

        if ($limit === null || $offset === null) {
            return $this->error('INVALID_PAGINATION', 400);
        }

        try {
            $result = $this->sources->findAll(
                $kind,
                $limit,
                $offset
            );
        } catch (Throwable $exception) {
            error_log(
                '[Ligne Jaune] Source listing failed: '
                . $exception::class
            );

            return $this->error('STORAGE_UNAVAILABLE', 503);
        }

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
            ['Cache-Control' => 'no-store']
        );
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
