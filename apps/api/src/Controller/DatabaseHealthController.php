<?php

declare(strict_types=1);

namespace App\Controller;

use App\Infrastructure\Database\ConnectionFactory;
use PDO;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class DatabaseHealthController
{
    public function __construct(
        private readonly ConnectionFactory $connections
    ) {
    }

    public function __invoke(): JsonResponse
    {
        $headers = [
            'Cache-Control' => 'no-store',
            'X-Content-Type-Options' => 'nosniff',
        ];

        try {
            $connection = $this->connections->connect();

            $statement = $connection->query(<<<'SQL'
                SELECT CASE
                    WHEN current_user = 'ligne_jaune_app'
                     AND NOT (
                         SELECT rolsuper
                         FROM pg_roles
                         WHERE rolname = current_user
                     )
                     AND has_table_privilege(
                         'public.entities',
                         'SELECT'
                     )
                     AND NOT has_table_privilege(
                         'public.schema_migrations',
                         'SELECT'
                     )
                    THEN 1
                    ELSE 0
                END AS security_ok
                SQL
            );

            if (
                $statement === false
                || (int) $statement->fetchColumn() !== 1
            ) {
                throw new \RuntimeException(
                    'Database security verification failed.'
                );
            }

            return new JsonResponse(
                [
                    'status' => 'ok',
                    'database' => 'reachable',
                    'permissions' => 'restricted',
                ],
                Response::HTTP_OK,
                $headers
            );
        } catch (Throwable $exception) {
            // Ne jamais exposer les détails de connexion
            // ou les informations SQL au client.
            error_log(sprintf(
                '[Ligne Jaune] DB health failed: %s',
                $exception::class
            ));

            return new JsonResponse(
                [
                    'status' => 'unavailable',
                    'database' => 'unavailable',
                ],
                Response::HTTP_SERVICE_UNAVAILABLE,
                $headers
            );
        }
    }
}
