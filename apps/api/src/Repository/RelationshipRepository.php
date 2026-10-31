<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;
use RuntimeException;

final class RelationshipRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {
    }

    public function create(array $data): array
    {
        $statement = $this->connections->connect()->prepare(<<<'SQL'
            INSERT INTO public.relationships (
                subject_entity_id,
                object_entity_id,
                relation_type,
                source_id,
                source_locator,
                valid_from,
                valid_until
            )
            VALUES (
                CAST(:subject_entity_id AS uuid),
                CAST(:object_entity_id AS uuid),
                :relation_type,
                CAST(:source_id AS uuid),
                :source_locator,
                :valid_from,
                :valid_until
            )
            RETURNING
                id,
                subject_entity_id,
                object_entity_id,
                relation_type,
                source_id,
                source_locator,
                valid_from,
                valid_until,
                status,
                created_at
            SQL
        );

        $statement->execute($data);

        $row = $statement->fetch(PDO::FETCH_ASSOC);

        if (!is_array($row)) {
            throw new RuntimeException(
                'Relationship insert returned no row.'
            );
        }

        return $row;
    }

    public function findById(string $id): ?array
    {
        $statement = $this->connections->connect()->prepare(<<<'SQL'
            SELECT
                r.id,
                r.subject_entity_id,
                subject.name AS subject_name,
                subject.kind AS subject_kind,

                r.object_entity_id,
                object.name AS object_name,
                object.kind AS object_kind,

                r.relation_type,
                r.valid_from,
                r.valid_until,
                r.status,

                r.source_id,
                r.source_locator,

                source.title AS source_title,
                source.kind AS source_kind,
                source.url AS source_url,
                source.author AS source_author,

                r.created_at
            FROM public.relationships r

            JOIN public.entities subject
                ON subject.id = r.subject_entity_id

            JOIN public.entities object
                ON object.id = r.object_entity_id

            JOIN public.sources source
                ON source.id = r.source_id

            WHERE r.id = CAST(:id AS uuid)
            SQL
        );

        $statement->execute(['id' => $id]);

        $row = $statement->fetch(PDO::FETCH_ASSOC);

        return $row === false ? null : $row;
    }
}
