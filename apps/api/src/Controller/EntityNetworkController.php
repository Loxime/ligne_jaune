<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\EntityNetworkRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class EntityNetworkController
{
    private const STATUSES = [
        'draft', 'reviewed', 'disputed', 'retracted',
    ];

    public function __construct(
        private readonly EntityNetworkRepository $network
    ) {}

    public function __invoke(
        Request $request,
        string $id
    ): JsonResponse {
        if (preg_match(
            '/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/iD',
            $id
        ) !== 1) {
            return $this->error('INVALID_ENTITY_ID', 400);
        }

        $query = $request->query->all();

        if (array_diff(
            array_keys($query),
            ['direction', 'status', 'limit', 'offset']
        )) {
            return $this->error('INVALID_QUERY', 400);
        }

        $direction = $query['direction'] ?? 'both';
        $status = $query['status'] ?? null;

        if (
            !is_string($direction)
            || !in_array(
                $direction,
                ['both', 'incoming', 'outgoing'],
                true
            )
        ) {
            return $this->error('INVALID_DIRECTION', 400);
        }

        if (
            $status !== null
            && (
                !is_string($status)
                || !in_array($status, self::STATUSES, true)
            )
        ) {
            return $this->error('INVALID_STATUS', 400);
        }

        $limit = $this->integer(
            $query['limit'] ?? '20', 1, 100
        );

        $offset = $this->integer(
            $query['offset'] ?? '0', 0, 10000
        );

        if ($limit === null || $offset === null) {
            return $this->error('INVALID_PAGINATION', 400);
        }

        try {
            if (!$this->network->entityExists($id)) {
                return $this->error('ENTITY_NOT_FOUND', 404);
            }

            $result = $this->network->findAll(
                $id,
                $direction,
                $status,
                $limit,
                $offset
            );

            return $this->response([
                'data' => $result['items'],
                'pagination' => [
                    'limit' => $limit,
                    'offset' => $offset,
                    'returned' => count($result['items']),
                    'has_more' => $result['has_more'],
                ],
            ], 200);
        } catch (Throwable $exception) {
            error_log(
                '[Ligne Jaune] Entity network: '
                . $exception::class
            );

            return $this->error('STORAGE_UNAVAILABLE', 503);
        }
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
        return $this->response(
            ['error' => ['code' => $code]], $status
        );
    }

    private function response(
        array $payload,
        int $status
    ): JsonResponse {
        return new JsonResponse($payload, $status, [
            'Cache-Control' => 'no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
