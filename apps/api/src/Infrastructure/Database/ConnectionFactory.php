<?php

declare(strict_types=1);

namespace App\Infrastructure\Database;

use PDO;
use RuntimeException;

final class ConnectionFactory
{
    public function connect(): PDO
    {
        $host = $this->environment('DB_HOST');
        $port = $this->environment('DB_PORT');
        $database = $this->environment('DB_NAME');
        $user = $this->environment('DB_USER');

        $secretFile = $this->environment('DB_PASSWORD_FILE');

        if (!is_readable($secretFile)) {
            throw new RuntimeException(
                'Database credentials are unavailable.'
            );
        }

        $secret = file_get_contents($secretFile);

        if ($secret === false) {
            throw new RuntimeException(
                'Unable to read database credentials.'
            );
        }

        $password = rtrim($secret, "\r\n");

        if ($password === '') {
            throw new RuntimeException(
                'Database credentials are empty.'
            );
        }

        $dsn = sprintf(
            'pgsql:host=%s;port=%s;dbname=%s;connect_timeout=3',
            $host,
            $port,
            $database
        );

        return new PDO(
            $dsn,
            $user,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
    }

    private function environment(string $name): string
    {
        $value = getenv($name);

        if ($value === false || $value === '') {
            throw new RuntimeException(
                sprintf('Missing database configuration: %s', $name)
            );
        }

        return $value;
    }
}
