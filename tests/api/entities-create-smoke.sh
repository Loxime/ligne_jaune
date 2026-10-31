#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

url="${LJ_BASE_URL:-http://127.0.0.1:3071}/api/entities"
token_file='.secrets/api_access_token'

[[ -r "$token_file" ]] || {
    echo 'Secret de test introuvable.' >&2
    exit 1
}

test_name="LJ_TEST_$(date +%s)_$$"
tmp_dir="$(mktemp -d)"
insert_attempted=0

cleanup() {
    if [[ "$insert_attempted" == 1 ]]; then
        printf \
          "DELETE FROM public.entities WHERE name = '%s';\n" \
          "$test_name" |
            docker compose -f compose.dev.yaml exec -T db \
              psql -X -q -v ON_ERROR_STOP=1 \
              -U ligne_jaune_admin \
              -d ligne_jaune -f - >/dev/null ||
              echo 'ATTENTION : nettoyage DB à vérifier.' >&2
    fi

    rm -rf -- "$tmp_dir"
}

trap cleanup EXIT

auth_curl() {
    local token
    IFS= read -r token < "$token_file"

    [[ "$token" =~ ^[a-f0-9]{64}$ ]] || return 1

    printf 'Authorization: Bearer %s\n' "$token" |
        curl -q --header @- \
          --silent --show-error --max-time 10 "$@"
}

expect_auth_status() {
    local expected="$1" actual
    shift

    actual="$(
        auth_curl \
          --output /dev/null \
          --write-out '%{http_code}' "$@"
    )"

    [[ "$actual" == "$expected" ]] || {
        echo "ECHEC : HTTP $actual, attendu $expected" >&2
        exit 1
    }
}

echo '=== TEST 1 : POST sans authentification ==='

status="$(
    curl -q -sS -o /dev/null -w '%{http_code}' \
      -X POST \
      -H 'Content-Type: application/json' \
      -d '{}' "$url"
)"

[[ "$status" == 401 ]] || exit 1
echo 'OK : accès anonyme refusé'

echo '=== TEST 2 : format non JSON ==='

expect_auth_status 415 -X POST -d '{}' "$url"
echo 'OK : format refusé'

echo '=== TEST 3 : JSON invalide ==='

expect_auth_status 400 -X POST \
  -H 'Content-Type: application/json' \
  -d '{' "$url"

echo 'OK : JSON invalide refusé'

echo '=== TEST 4 : validation des champs ==='

expect_auth_status 400 -X POST \
  -H 'Content-Type: application/json' \
  -d '{"kind":"unknown","name":"Test"}' "$url"

expect_auth_status 400 -X POST \
  -H 'Content-Type: application/json' \
  -d '{"kind":"company","name":"Test","is_admin":true}' "$url"

echo 'OK : champs invalides refusés'

echo '=== TEST 5 : limite de taille ==='

large_json="$(python3 -c 'print("{" + "x" * 5000)')"

expect_auth_status 413 -X POST \
  -H 'Content-Type: application/json' \
  --data-binary "$large_json" "$url"

echo 'OK : taille excessive refusée'

echo '=== TEST 6 : création fictive ==='

json="$(
    printf \
      '{"kind":"company","name":"%s","description":"Entité fictive de test"}' \
      "$test_name"
)"

insert_attempted=1

status="$(
    auth_curl \
      -X POST \
      -H 'Content-Type: application/json' \
      --data-binary "$json" \
      --output "$tmp_dir/created.json" \
      --write-out '%{http_code}' \
      "$url"
)"

if [[ "$status" != 201 ]]; then
    echo "ECHEC : création HTTP $status" >&2
    cat "$tmp_dir/created.json" >&2
    exit 1
fi

entity_id="$(
    python3 - "$tmp_dir/created.json" "$test_name" <<'PY'
import json
import sys
import uuid

with open(sys.argv[1], encoding="utf-8") as file:
    data = json.load(file)["data"]

assert data["kind"] == "company"
assert data["name"] == sys.argv[2]
assert data["description"] == "Entité fictive de test"

print(uuid.UUID(data["id"]))
PY
)"

count="$(
    docker compose -f compose.dev.yaml exec -T db \
      psql -X -At -v ON_ERROR_STOP=1 \
      -U ligne_jaune_admin \
      -d ligne_jaune \
      -c "SELECT COUNT(*)
          FROM public.entities
          WHERE id = '$entity_id'::uuid
          AND name = '$test_name';"
)"

[[ "$count" == 1 ]] || {
    echo 'ECHEC : entité absente de PostgreSQL' >&2
    exit 1
}

echo 'OK : création HTTP 201 et persistance PostgreSQL'
echo '=== TOUS LES TESTS ONT REUSSI ==='
