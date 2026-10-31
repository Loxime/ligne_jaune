<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\SourceWriteRepository;
use DateTimeImmutable;
use InvalidArgumentException;
use JsonException;
use stdClass;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\AsController;
use Throwable;

#[AsController]
final class SourceCreateController
{
    private const KINDS = [
        'official',
        'book',
        'article',
        'report',
        'archive',
        'personal_note',
        'other',
    ];

    private const OPTIONAL_FIELDS = [
        'author' => 250,
        'publisher' => 250,
        'url' => 2048,
        'isbn' => 32,
        'doi' => 255,
        'license_note' => 2000,
    ];

    public function __construct(
        private readonly SourceWriteRepository $sources
    ) {
    }

    public function __invoke(Request $request): JsonResponse
    {
        if ($request->getContentTypeFormat() !== 'json') {
            return $this->error('UNSUPPORTED_MEDIA_TYPE', 415);
        }

        $body = $request->getContent();

        if (strlen($body) > 8192) {
            return $this->error('PAYLOAD_TOO_LARGE', 413);
        }

        try {
            $payload = json_decode(
                $body,
                false,
                16,
                JSON_THROW_ON_ERROR
            );
        } catch (JsonException) {
            return $this->error('INVALID_JSON', 400);
        }

        if (!$payload instanceof stdClass) {
            return $this->error('INVALID_PAYLOAD', 400);
        }

        $input = get_object_vars($payload);

        $allowed = [
            'kind',
            'title',
            'published_on',
            ...array_keys(self::OPTIONAL_FIELDS),
        ];

        foreach (array_keys($input) as $key) {
            if (!in_array($key, $allowed, true)) {
                return $this->error('UNKNOWN_FIELD', 400);
            }
        }

        $kind = $input['kind'] ?? null;

        if (
            !is_string($kind)
            || !in_array($kind, self::KINDS, true)
        ) {
            return $this->error('INVALID_KIND', 400);
        }

        try {
            $data = [
                'kind' => $kind,
                'title' => $this->text(
                    $input['title'] ?? null,
                    500,
                    true
                ),
            ];

            foreach (self::OPTIONAL_FIELDS as $field => $max) {
                $data[$field] = $this->text(
                    $input[$field] ?? null,
                    $max,
                    false
                );
            }

            $data['published_on'] = $this->date(
                $input['published_on'] ?? null
            );

            // Enregistrer uniquement des URL HTTPS.
            // Aucun téléchargement n'est effectué ici.
            if (
                $data['url'] !== null
                && (
                    filter_var(
                        $data['url'],
                        FILTER_VALIDATE_URL
                    ) === false
                    || parse_url(
                        $data['url'],
                        PHP_URL_SCHEME
                    ) !== 'https'
                )
            ) {
                throw new InvalidArgumentException(
                    'Invalid source URL.'
                );
            }
        } catch (InvalidArgumentException) {
            return $this->error('INVALID_SOURCE_FIELDS', 400);
        }

        try {
            $created = $this->sources->create($data);
        } catch (Throwable $exception) {
            error_log(
                '[Ligne Jaune] Source insert failed: '
                . $exception::class
            );

            return $this->error('STORAGE_UNAVAILABLE', 503);
        }

        return new JsonResponse(
            ['data' => $created],
            Response::HTTP_CREATED,
            [
                'Cache-Control' => 'no-store',
                'Location' => '/api/sources/' . $created['id'],
                'X-Content-Type-Options' => 'nosniff',
            ]
        );
    }

    private function text(
        mixed $value,
        int $max,
        bool $required
    ): ?string {
        if ($value === null && !$required) {
            return null;
        }

        if (!is_string($value)) {
            throw new InvalidArgumentException();
        }

        $value = trim($value);

        if (
            strlen($value) > $max
            || preg_match(
                '/[\x00-\x1F\x7F]/',
                $value
            ) === 1
            || !preg_match('//u', $value)
            || ($required && $value === '')
        ) {
            throw new InvalidArgumentException();
        }

        return $value === '' ? null : $value;
    }

    private function date(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (
            !is_string($value)
            || preg_match(
                '/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/D',
                $value
            ) !== 1
        ) {
            throw new InvalidArgumentException();
        }

        $date = DateTimeImmutable::createFromFormat(
            '!Y-m-d',
            $value
        );

        if (
            $date === false
            || $date->format('Y-m-d') !== $value
        ) {
            throw new InvalidArgumentException();
        }

        return $value;
    }

    private function error(
        string $code,
        int $status
    ): JsonResponse {
        return new JsonResponse(
            ['error' => ['code' => $code]],
            $status,
            [
                'Cache-Control' => 'no-store',
                'X-Content-Type-Options' => 'nosniff',
            ]
        );
    }
}
