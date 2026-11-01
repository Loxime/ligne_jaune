<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;

final class EntityNetworkRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {}

    public function entityExists(string $id): bool
    {
        $stmt = $this->connections->connect()->prepare(
            'SELECT 1 FROM public.entities WHERE id = CAST(:id AS uuid)'
        );

        $stmt->execute(['id' => $id]);

        return $stmt->fetchColumn() !== false;
    }

    public function findAll(
        string $entityId,
        string $direction,
        ?string $status,
        int $limit,
        int $offset
    ): array {
        $condition = match ($direction) {
            'incoming' =>
                'r.object_entity_id = CAST(:object_id AS uuid)',
            'outgoing' =>
                'r.subject_entity_id = CAST(:subject_id AS uuid)',
            default =>
                '(r.subject_entity_id = CAST(:subject_id AS uuid)
                  OR r.object_entity_id = CAST(:object_id AS uuid))',
        };

        $sql = <<<'SQL'
            SELECT
                r.id,
                r.subject_entity_id,
                subject.name AS subject_name,
                subject.kind AS subject_kind,
                r.object_entity_id,
                object.name AS object_name,
                object.kind AS object_kind,
                r.relation_type,
                r.status,
                r.valid_from,
                r.valid_until,
                r.source_id,
                r.source_locator,
                s.title AS source_title,
                s.kind AS source_kind,
                r.created_at,

                (
                    SELECT COUNT(*)
                    FROM public.relationship_evidence e
                    WHERE e.relationship_id = r.id
                      AND e.role = 'supports'
                ) AS supporting_evidence_count,

                (
                    SELECT COUNT(*)
                    FROM public.relationship_evidence e
                    WHERE e.relationship_id = r.id
                      AND e.role = 'contradicts'
                ) AS contradictory_evidence_count

            FROM public.relationships r

            JOIN public.entities subject
                ON subject.id = r.subject_entity_id

            JOIN public.entities object
                ON object.id = r.object_entity_id

            JOIN public.sources s
                ON s.id = r.source_id
            SQL;

        $sql .= "\nWHERE $condition";

        if ($status !== null) {
            $sql .= "\nAND r.status = :status";
        }

        $sql .= <<<'SQL'

            ORDER BY r.created_at DESC, r.id DESC
            LIMIT :limit OFFSET :offset
            SQL;

        $stmt = $this->connections->connect()->prepare($sql);

        if ($direction !== 'incoming') {
            $stmt->bindValue(':subject_id', $entityId);
        }

        if ($direction !== 'outgoing') {
            $stmt->bindValue(':object_id', $entityId);
        }

        if ($status !== null) {
            $stmt->bindValue(':status', $status);
        }

        $stmt->bindValue(':limit', $limit + 1, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $hasMore = count($items) > $limit;

        if ($hasMore) {
            array_pop($items);
        }

        foreach ($items as &$item) {
            $item['supporting_evidence_count'] = (int)
                $item['supporting_evidence_count'];

            $item['contradictory_evidence_count'] = (int)
                $item['contradictory_evidence_count'];
        }

        unset($item);

        return [
            'items' => $items,
            'has_more' => $hasMore,
        ];
    }
}
