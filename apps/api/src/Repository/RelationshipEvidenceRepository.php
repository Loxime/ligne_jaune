<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;
use RuntimeException;

final class RelationshipEvidenceRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {}

    public function relationshipExists(string $id): bool
    {
        $sql = <<<'SQL'
            SELECT 1 FROM public.relationships
            WHERE id = CAST(:id AS uuid)
            SQL;

        $stmt = $this->connections->connect()->prepare($sql);
        $stmt->execute(['id' => $id]);

        return $stmt->fetchColumn() !== false;
    }

    public function findAll(
        string $relationshipId,
        int $limit,
        int $offset
    ): array {
        $sql = <<<'SQL'
            SELECT
                e.id, e.relationship_id, e.source_id,
                e.locator, e.role, e.note, e.created_at,
                s.title AS source_title,
                s.kind AS source_kind,
                s.author AS source_author,
                s.url AS source_url
            FROM public.relationship_evidence e
            JOIN public.sources s ON s.id = e.source_id
            WHERE e.relationship_id = CAST(:id AS uuid)
            ORDER BY e.created_at ASC, e.id ASC
            LIMIT :limit OFFSET :offset
            SQL;

        $stmt = $this->connections->connect()->prepare($sql);
        $stmt->bindValue(':id', $relationshipId);
        $stmt->bindValue(':limit', $limit + 1, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $hasMore = count($rows) > $limit;

        if ($hasMore) {
            array_pop($rows);
        }

        return [
            'items' => $rows,
            'has_more' => $hasMore,
        ];
    }

    public function create(
        string $relationshipId,
        string $sourceId,
        string $locator,
        string $role,
        ?string $note
    ): array {
        $sql = <<<'SQL'
            INSERT INTO public.relationship_evidence (
                relationship_id, source_id, locator,
                role, note
            )
            VALUES (
                CAST(:relationship_id AS uuid),
                CAST(:source_id AS uuid),
                :locator, :role, :note
            )
            RETURNING
                id, relationship_id, source_id,
                locator, role, note, created_at
            SQL;

        $stmt = $this->connections->connect()->prepare($sql);
        $stmt->execute([
            'relationship_id' => $relationshipId,
            'source_id' => $sourceId,
            'locator' => $locator,
            'role' => $role,
            'note' => $note,
        ]);

        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!is_array($row)) {
            throw new RuntimeException('Evidence insert failed.');
        }

        return $row;
    }
}
