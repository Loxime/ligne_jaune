#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LJ_COMPOSE_FILE="${LJ_COMPOSE_FILE:-compose.dev.yaml}"

# Vérification des dépendances
for command in docker flock; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Erreur : commande absente : $command" >&2
    exit 1
  fi
done

# Empêcher deux migrations locales simultanées
mkdir -p .local
exec 9>.local/db-migrate.lock

if ! flock -n 9; then
  echo "Erreur : une migration locale est déjà en cours." >&2
  exit 1
fi

# Connexion administrateur PostgreSQL
psql_admin() {
  docker compose -f "$LJ_COMPOSE_FILE" exec -T db \
    psql -X -v ON_ERROR_STOP=1 \
      -U ligne_jaune_admin \
      -d ligne_jaune "$@"
}

# Découverte des migrations
mapfile -d '' -t migrations < <(
  find db/migrations \
    -maxdepth 1 \
    -type f \
    -name '*.sql' \
    -print0 | sort -z
)

if ((${#migrations[@]} == 0)); then
  echo "Aucune migration à appliquer."
  exit 0
fi

# Vérifier la présence du registre des migrations
schema_exists="$(
  psql_admin -At -c \
    "SELECT to_regclass('public.schema_migrations') IS NOT NULL;"
)"

for migration in "${migrations[@]}"; do
  version="$(basename "$migration" .sql)"

  # Format strict : 0001_nom_migration
  if [[ ! "$version" =~ ^[0-9]{4}_[a-z0-9_]+$ ]]; then
    echo "Nom de migration invalide : $migration" >&2
    exit 1
  fi

  # Vérifier si la migration est déjà installée
  if [[ "$schema_exists" == "t" ]]; then
    applied="$(
      psql_admin -At -c \
        "SELECT EXISTS(
          SELECT 1 FROM public.schema_migrations
          WHERE version = '$version'
        );"
    )"
  elif [[ "$version" == "0001_initial_schema" ]]; then
    applied="f"
  else
    echo "Erreur : la migration initiale est absente." >&2
    exit 1
  fi

  if [[ "$applied" == "t" ]]; then
    echo "Déjà appliquée : $version"
    continue
  fi

  echo "Application : $version"

  # La migration 0001 enregistre déjà sa version.
  # Les suivantes sont enregistrées automatiquement.
  if [[ "$version" == "0001_initial_schema" ]]; then
    psql_admin --single-transaction -f - < "$migration"
  else
    {
      cat "$migration"
      printf \
        "\nINSERT INTO public.schema_migrations (version) VALUES ('%s');\n" \
        "$version"
    } | psql_admin --single-transaction -f -
  fi

  schema_exists="t"

  # Vérification après exécution
  verified="$(
    psql_admin -At -c \
      "SELECT EXISTS(
        SELECT 1 FROM public.schema_migrations
        WHERE version = '$version'
      );"
  )"

  if [[ "$verified" != "t" ]]; then
    echo "Erreur : migration non enregistrée : $version" >&2
    exit 1
  fi

  echo "Validée : $version"
done

echo "Toutes les migrations sont à jour."
