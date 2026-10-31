<?php

declare(strict_types=1);

namespace App\Repository;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;
use RuntimeException;

final class SourceWriteRepository
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {
    }

    public function create(array $data): array
    {
        $statement = $this->connections
            ->connect()
            ->prepare(<<<'SQL'
                INSERT INTO public.sources (
                    kind,
                    title,
                    author,
                    publisher,
                    published_on,
                    url,
                    isbn,
                    doi,
                    license_note
                )
                VALUES (
                    :kind,
                    :title,
                    :author,
                    :publisher,
                    :published_on,
                    :url,
                    :isbn,
                    :doi,
                    :license_note
                )
                RETURNING
                    id,
                    kind,
                    title,
                    author,
                    publisher,
                    published_on,
                    url,
                    isbn,
                    doi,
                    license_note,
                    created_at
                SQL
            );

        foreach ($data as $key => $value) {
            $statement->bindValue(
                ':' . $key,
                $value,
                $value === null
                    ? PDO::PARAM_NULL
                    : PDO::PARAM_STR
            );
        }

        $statement->execute();

        $source = $statement->fetch(PDO::FETCH_ASSOC);

        if (!is_array($source)) {
            throw new RuntimeException(
                'Source insert returned no row.'
            );
        }

        return $source;
    }
}
