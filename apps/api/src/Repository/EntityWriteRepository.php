<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;
use RuntimeException;

final class EntityWriteRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {
    }

    /** @return array<string, mixed> */
    public function create(
        string $kind,
        string $name,
        ?string $description
    ): array {
        $statement = $this->connections->connect()->prepare(<<<'SQL'
            INSERT INTO public.entities (
                kind,
                name,
                description
            )
            VALUES (
                :kind,
                :name,
                :description
            )
            RETURNING
                id,
                kind,
                name,
                description,
                created_at
            SQL
        );

        $statement->bindValue(':kind', $kind, PDO::PARAM_STR);
        $statement->bindValue(':name', $name, PDO::PARAM_STR);
        $statement->bindValue(
            ':description',
            $description,
            $description === null
                ? PDO::PARAM_NULL
                : PDO::PARAM_STR
        );

        $statement->execute();

        $entity = $statement->fetch(PDO::FETCH_ASSOC);

        if (!is_array($entity)) {
            throw new RuntimeException(
                'Entity insert did not return a row.'
            );
        }

        return $entity;
    }
}
