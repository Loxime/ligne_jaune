<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;

final class EntityIdentifierRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {
    }

    public function entityExists(string $id): bool
    {
        $statement = $this->connections->connect()->prepare(
            'SELECT 1 FROM public.entities WHERE id = CAST(:id AS uuid)'
        );

        $statement->execute(['id' => $id]);

        return $statement->fetchColumn() !== false;
    }

    public function findByEntity(string $id): array
    {
        $statement = $this->connections->connect()->prepare(<<<'SQL'
            SELECT
                i.id,
                i.entity_id,
                i.scheme,
                i.value,
                i.source_id,
                i.source_locator,
                i.created_at,
                s.title AS source_title,
                s.kind AS source_kind
            FROM public.entity_identifiers i
            JOIN public.sources s ON s.id = i.source_id
            WHERE i.entity_id = CAST(:id AS uuid)
            ORDER BY i.scheme, i.value
            SQL
        );

        $statement->execute(['id' => $id]);

        return $statement->fetchAll(PDO::FETCH_ASSOC);
    }

    public function create(
        string $entityId,
        string $scheme,
        string $value,
        string $sourceId,
        string $locator
    ): array {
        $statement = $this->connections->connect()->prepare(<<<'SQL'
            INSERT INTO public.entity_identifiers (
                entity_id, scheme, value,
                source_id, source_locator
            )
            VALUES (
                CAST(:entity_id AS uuid),
                :scheme,
                :value,
                CAST(:source_id AS uuid),
                :source_locator
            )
            RETURNING
                id, entity_id, scheme, value,
                source_id, source_locator, created_at
            SQL
        );

        $statement->execute([
            'entity_id' => $entityId,
            'scheme' => $scheme,
            'value' => $value,
            'source_id' => $sourceId,
            'source_locator' => $locator,
        ]);

        return $statement->fetch(PDO::FETCH_ASSOC);
    }
}
