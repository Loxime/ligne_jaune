<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;

final class EntityRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {
    }

    /**
     * @return array{
     *     items: array<int, array<string, mixed>>,
     *     has_more: bool
     * }
     */
    public function findAll(
        ?string $kind,
        int $limit,
        int $offset
    ): array {
        $pdo = $this->connections->connect();

        $sql = <<<'SQL'
            SELECT
                id,
                kind,
                name,
                description,
                created_at
            FROM public.entities
            SQL;

        if ($kind !== null) {
            $sql .= ' WHERE kind = :kind';
        }

        $sql .= <<<'SQL'

            ORDER BY created_at ASC, id ASC
            LIMIT :limit OFFSET :offset
            SQL;

        $statement = $pdo->prepare($sql);

        if ($kind !== null) {
            $statement->bindValue(
                ':kind',
                $kind,
                PDO::PARAM_STR
            );
        }

        // Une ligne supplémentaire permet de
        // déterminer s'il reste des résultats.
        $statement->bindValue(
            ':limit',
            $limit + 1,
            PDO::PARAM_INT
        );

        $statement->bindValue(
            ':offset',
            $offset,
            PDO::PARAM_INT
        );

        $statement->execute();

        $items = $statement->fetchAll(PDO::FETCH_ASSOC);

        $hasMore = count($items) > $limit;

        if ($hasMore) {
            array_pop($items);
        }

        return [
            'items' => $items,
            'has_more' => $hasMore,
        ];
    }
}
