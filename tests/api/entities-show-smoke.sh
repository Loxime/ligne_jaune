#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Tests d'écriture : environnement de test exclusivement.
LJ_COMPOSE_FILE="${LJ_COMPOSE_FILE:-compose.test.yaml}"
LJ_BASE_URL="${LJ_BASE_URL:-http://127.0.0.1:3072}"

if [[ "$LJ_COMPOSE_FILE" != "compose.test.yaml" ||
      "$LJ_BASE_URL" != "http://127.0.0.1:3072" ]]; then
    echo "ERREUR : environnement de test obligatoire." >&2
    exit 1
fi

BASE_URL="${LJ_BASE_URL:-http://127.0.0.1:3072}/api/entities"
TOKEN_FILE=".secrets/api_access_token"

[[ -r "$TOKEN_FILE" ]] || {
    echo "Secret API introuvable." >&2
    exit 1
}

TEST_NAME="LJ_TEST_SHOW_$(date +%s)_$$"
TMP_DIR="$(mktemp -d)"
CREATION_ATTEMPTED=0

cleanup() {
    if [[ "$CREATION_ATTEMPTED" == 1 ]]; then
        printf \
            "DELETE FROM public.entities WHERE name = '%s';\n" \
            "$TEST_NAME" |
        docker compose -f "$LJ_COMPOSE_FILE" exec -T db \
            psql -X -q -v ON_ERROR_STOP=1 \
            -U ligne_jaune_admin \
            -d ligne_jaune -f - >/dev/null ||
        echo "ATTENTION : nettoyage SQL à vérifier." >&2
    fi

    rm -rf -- "$TMP_DIR"
}

trap cleanup EXIT

auth_curl() {
    local token
    IFS= read -r token < "$TOKEN_FILE"

    [[ "$token" =~ ^[a-f0-9]{64}$ ]] || return 1

    printf 'Authorization: Bearer %s\n' "$token" |
        curl -q --header @- \
            --silent --show-error --max-time 10 "$@"
}

expect_auth_status() {
    local expected="$1"
    shift

    local actual
    actual="$(
        auth_curl \
            --output /dev/null \
            --write-out '%{http_code}' \
            "$@"
    )"

    if [[ "$actual" != "$expected" ]]; then
        echo "ECHEC : HTTP $actual, attendu $expected" >&2
        exit 1
    fi
}

echo "=== TEST 1 : UUID invalide ==="

expect_auth_status 400 "$BASE_URL/invalid-uuid"
echo "OK : UUID invalide refusé"

echo "=== TEST 2 : UUID inexistant ==="

MISSING_ID="00000000-0000-4000-8000-000000000000"

expect_auth_status 404 "$BASE_URL/$MISSING_ID"
echo "OK : entité inexistante"

echo "=== TEST 3 : accès anonyme ==="

status="$(
    curl -q -sS \
        -o /dev/null \
        -w '%{http_code}' \
        "$BASE_URL/$MISSING_ID"
)"

[[ "$status" == "401" ]] || exit 1
echo "OK : accès anonyme refusé"

echo "=== TEST 4 : création fictive ==="

payload="$(
    printf \
        '{"kind":"company","name":"%s","description":"Fiche de test"}' \
        "$TEST_NAME"
)"

CREATION_ATTEMPTED=1

status="$(
    auth_curl \
        -X POST \
        -H 'Content-Type: application/json' \
        --data-binary "$payload" \
        --output "$TMP_DIR/created.json" \
        --write-out '%{http_code}' \
        "$BASE_URL"
)"

if [[ "$status" != "201" ]]; then
    echo "ECHEC : création HTTP $status" >&2
    cat "$TMP_DIR/created.json" >&2
    exit 1
fi

ENTITY_ID="$(
    python3 - "$TMP_DIR/created.json" "$TEST_NAME" <<'PY'
import json
import sys
import uuid

with open(sys.argv[1], encoding="utf-8") as file:
    entity = json.load(file)["data"]

assert entity["name"] == sys.argv[2]
assert entity["kind"] == "company"

print(uuid.UUID(entity["id"]))
PY
)"

echo "OK : entreprise fictive créée"

echo "=== TEST 5 : consultation individuelle ==="

auth_curl \
    --fail \
    --output "$TMP_DIR/show.json" \
    "$BASE_URL/$ENTITY_ID"

python3 - "$TMP_DIR/show.json" "$ENTITY_ID" "$TEST_NAME" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    entity = json.load(file)["data"]

assert entity["id"] == sys.argv[2]
assert entity["name"] == sys.argv[3]
assert entity["kind"] == "company"
assert entity["description"] == "Fiche de test"
assert "created_at" in entity

print("OK : fiche individuelle cohérente")
PY

echo "=== TEST 6 : méthode POST interdite sur la fiche ==="

expect_auth_status 405 \
    --request POST \
    "$BASE_URL/$ENTITY_ID"

echo "OK : POST sur fiche refusé"

echo "=== TEST 7 : suppression de la donnée fictive ==="

printf \
    "DELETE FROM public.entities WHERE id = '%s'::uuid;\n" \
    "$ENTITY_ID" |
docker compose -f "$LJ_COMPOSE_FILE" exec -T db \
    psql -X -q -v ON_ERROR_STOP=1 \
    -U ligne_jaune_admin \
    -d ligne_jaune -f - >/dev/null

expect_auth_status 404 "$BASE_URL/$ENTITY_ID"

echo "OK : fiche absente après nettoyage"

echo "=== TOUS LES TESTS ONT REUSSI ==="
