<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;

final class SourceRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {
    }

    public function findAll(
        ?string $kind,
        int $limit,
        int $offset
    ): array {
        $pdo = $this->connections->connect();

        $sql = <<<'SQL'
            SELECT
                id, kind, title, author, publisher,
                published_on, url, isbn, doi,
                license_note, created_at
            FROM public.sources
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

    public function findById(string $id): ?array
    {
        $statement = $this->connections
            ->connect()
            ->prepare(<<<'SQL'
                SELECT
                    id, kind, title, author, publisher,
                    published_on, url, isbn, doi,
                    license_note, created_at
                FROM public.sources
                WHERE id = CAST(:id AS uuid)
                SQL
            );

        $statement->bindValue(':id', $id, PDO::PARAM_STR);
        $statement->execute();

        $source = $statement->fetch(PDO::FETCH_ASSOC);

        return $source === false ? null : $source;
    }
}
