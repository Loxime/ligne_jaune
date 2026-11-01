#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

export LJ_COMPOSE_FILE="compose.test.yaml"
export LJ_BASE_URL="http://127.0.0.1:3072"

export LOCAL_UID="$(id -u)"
export LOCAL_GID="$(id -g)"

compose() {
    docker compose -f "$LJ_COMPOSE_FILE" "$@"
}

echo "=== VALIDATION CONFIGURATION ==="
compose config --quiet

echo "=== DEMARRAGE ENVIRONNEMENT DE TEST ==="
compose up -d --build --wait

echo "=== VERIFICATION SCHEMA INITIAL ==="

initial_exists="$(
    compose exec -T db \
      psql -X -At -v ON_ERROR_STOP=1 \
        -U ligne_jaune_admin \
        -d ligne_jaune \
        -c "SELECT to_regclass(
          'public.schema_migrations'
        ) IS NOT NULL;"
)"

# La première migration doit être installée avant
# le provisionnement du rôle applicatif.
# La migration 0002 dépend de ce rôle.
if [[ "$initial_exists" == "f" ]]; then
    echo "Initialisation du schema..."

    compose exec -T db \
      psql -X -v ON_ERROR_STOP=1 \
        --single-transaction \
        -U ligne_jaune_admin \
        -d ligne_jaune \
        -f - \
      < db/migrations/0001_initial_schema.sql
fi

echo "=== ROLE APPLICATIF ==="
./scripts/db-provision-app.sh

echo "=== MIGRATIONS ==="
./scripts/db-migrate.sh

echo "=== TEST SQL : MODELE ==="
compose exec -T db \
  psql -X -v ON_ERROR_STOP=1 \
    -U ligne_jaune_admin \
    -d ligne_jaune \
    -f - \
  < tests/sql/0001_initial_schema.sql

echo "=== TEST SQL : PERMISSIONS ==="
compose exec -T db \
  psql -X -v ON_ERROR_STOP=1 \
    -U ligne_jaune_admin \
    -d ligne_jaune \
    -f - \
  < tests/sql/0002_app_permissions.sql

echo "=== TEST SQL : AUDIT ==="
compose exec -T db \
  psql -X -v ON_ERROR_STOP=1 \
    -U ligne_jaune_admin \
    -d ligne_jaune \
    -f - \
  < tests/sql/0003_entity_audit.sql

echo "=== TEST SQL : SOURCES AUDIT ==="
compose exec -T db \
  psql -X -v ON_ERROR_STOP=1 \
    -U ligne_jaune_admin -d ligne_jaune -f - \
  < tests/sql/0004_source_audit.sql

echo "=== TEST SQL : RESEARCH AUDIT ==="
compose exec -T db \
  psql -X -v ON_ERROR_STOP=1 \
    -U ligne_jaune_admin -d ligne_jaune -f - \
  < tests/sql/0005_research_audit.sql

echo "=== TESTS HTTP ==="
./tests/api/entities-smoke.sh
./tests/api/entities-create-smoke.sh
./tests/api/entities-show-smoke.sh
./tests/api/sources-read-smoke.sh
./tests/api/sources-create-smoke.sh

python3 tests/api/identifiers-smoke.py

python3 tests/api/relationships-smoke.py

python3 tests/api/relationship-evidence-smoke.py

python3 tests/api/research-audit-smoke.py

echo "=== INTEGRATION VALIDEE ==="
