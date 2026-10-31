#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

LJ_COMPOSE_FILE="${LJ_COMPOSE_FILE:-compose.test.yaml}"
BASE_URL="${LJ_BASE_URL:-http://127.0.0.1:3072}/api/sources"

TOKEN_FILE=".secrets/api_access_token"
TEST_TITLE="LJ_SOURCE_TEST_$(date +%s)_$$"

TMP_DIR="$(mktemp -d)"

cleanup() {
    # Nettoyage limité à une référence fictive
    # générée exclusivement par ce test.
    printf \
      "DELETE FROM public.sources WHERE title = '%s';\n" \
      "$TEST_TITLE" |
      docker compose -f "$LJ_COMPOSE_FILE" exec -T db \
        psql -X -q -v ON_ERROR_STOP=1 \
          -U ligne_jaune_admin \
          -d ligne_jaune -f - >/dev/null ||
      echo "ATTENTION : nettoyage à vérifier." >&2

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

expect_status() {
    local actual
    actual="$(
        auth_curl \
          -o /dev/null \
          -w '%{http_code}' \
          "$2" \
          -X POST \
          -H 'Content-Type: application/json' \
          -d "$3"
    )"

    if [[ "$actual" != "$1" ]]; then
        echo "HTTP $actual, attendu $1" >&2
        exit 1
    fi
}

echo "=== TEST 1 : accès anonyme ==="

status="$(
    curl -q -sS -o /dev/null -w '%{http_code}' \
      -X POST -H 'Content-Type: application/json' \
      -d '{}' "$BASE_URL"
)"

[[ "$status" == "401" ]]
echo "OK : accès anonyme refusé"

echo "=== TEST 2 : type invalide ==="
expect_status 400 "$BASE_URL" \
  '{"kind":"invalid","title":"Test"}'
echo "OK"

echo "=== TEST 3 : date invalide ==="
expect_status 400 "$BASE_URL" \
  '{"kind":"book","title":"Test","published_on":"2024-02-30"}'
echo "OK"

echo "=== TEST 4 : URL non HTTPS ==="
expect_status 400 "$BASE_URL" \
  '{"kind":"article","title":"Test","url":"http://example.com"}'
echo "OK"

echo "=== TEST 5 : champ inconnu ==="
expect_status 400 "$BASE_URL" \
  '{"kind":"book","title":"Test","internal_admin":true}'
echo "OK"

echo "=== TEST 6 : création d'une source fictive ==="

payload="$(
    printf \
      '{"kind":"book","title":"%s","author":"Auteur fictif","published_on":"2024-05-10","isbn":"9780000000002"}' \
      "$TEST_TITLE"
)"

status="$(
    auth_curl \
      -X POST \
      -H 'Content-Type: application/json' \
      --data-binary "$payload" \
      -o "$TMP_DIR/created.json" \
      -w '%{http_code}' \
      "$BASE_URL"
)"

if [[ "$status" != "201" ]]; then
    echo "ECHEC : HTTP $status" >&2
    cat "$TMP_DIR/created.json" >&2
    exit 1
fi

SOURCE_ID="$(
    python3 - "$TMP_DIR/created.json" "$TEST_TITLE" <<'PY'
import json
import sys
import uuid

with open(sys.argv[1], encoding="utf-8") as file:
    data = json.load(file)["data"]

assert data["kind"] == "book"
assert data["title"] == sys.argv[2]
assert data["author"] == "Auteur fictif"
assert data["published_on"] == "2024-05-10"

print(uuid.UUID(data["id"]))
PY
)"

echo "OK : source créée"

echo "=== TEST 7 : consultation par UUID ==="

auth_curl --fail \
  -o "$TMP_DIR/show.json" \
  "$BASE_URL/$SOURCE_ID"

python3 - "$TMP_DIR/show.json" "$SOURCE_ID" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    data = json.load(file)["data"]

assert data["id"] == sys.argv[2]
assert data["kind"] == "book"
assert data["isbn"] == "9780000000002"

print("OK : source retrouvée")
PY

echo "=== TESTS SOURCES CREATE REUSSIS ==="
