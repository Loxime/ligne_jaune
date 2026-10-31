#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

BASE_URL="http://127.0.0.1:3071"
TOKEN_FILE=".secrets/api_access_token"

if [[ ! -r "$TOKEN_FILE" ]]; then
    echo "Erreur : jeton de test indisponible." >&2
    exit 1
fi

# Transmettre le jeton par stdin, sans le placer
# dans les arguments de la commande curl.
auth_curl() {
    local token
    IFS= read -r token < "$TOKEN_FILE"

    if [[ ! "$token" =~ ^[a-f0-9]{64}$ ]]; then
        echo "Jeton local invalide." >&2
        return 1
    fi

    printf 'Authorization: Bearer %s\n' "$token" |
        curl -q --header @- "$@"
}

assert_status() {
    local expected="$1"
    shift

    local actual
    actual="$(
        curl -q --silent --show-error \
            --max-time 5 \
            --output /dev/null \
            --write-out '%{http_code}' \
            "$@"
    )"

    if [[ "$actual" != "$expected" ]]; then
        echo "ECHEC : HTTP $actual, attendu $expected" >&2
        exit 1
    fi
}

assert_auth_status() {
    local expected="$1"
    shift

    local actual
    actual="$(
        auth_curl --silent --show-error \
            --max-time 5 \
            --output /dev/null \
            --write-out '%{http_code}' \
            "$@"
    )"

    if [[ "$actual" != "$expected" ]]; then
        echo "ECHEC : HTTP $actual, attendu $expected" >&2
        exit 1
    fi
}

echo "=== TEST 1 : healthcheck public ==="
assert_status 200 "$BASE_URL/api/health"
echo "OK : healthcheck accessible"

echo "=== TEST 2 : entités sans authentification ==="
assert_status 401 "$BASE_URL/api/entities"
echo "OK : accès anonyme refusé"

echo "=== TEST 3 : jeton incorrect ==="
assert_status 401 \
    --header 'Authorization: Bearer invalid' \
    "$BASE_URL/api/entities"
echo "OK : jeton incorrect refusé"

echo "=== TEST 4 : accès authentifié ==="
response="$(
    auth_curl \
        --fail \
        --silent \
        --show-error \
        --max-time 5 \
        "$BASE_URL/api/entities?kind=company&limit=10&offset=0"
)"

python3 -c '
import json
import sys

payload = json.load(sys.stdin)

assert isinstance(payload["data"], list)
assert payload["pagination"]["limit"] == 10
assert payload["pagination"]["offset"] == 0
assert isinstance(payload["pagination"]["has_more"], bool)

print("OK : entités et pagination accessibles")
' <<< "$response"

echo "=== TEST 5 : filtre invalide ==="
assert_auth_status 400 \
    "$BASE_URL/api/entities?kind=invalid"
echo "OK : filtre rejeté"

echo "=== TEST 6 : pagination invalide ==="
assert_auth_status 400 \
    "$BASE_URL/api/entities?limit=0"
echo "OK : pagination rejetée"

echo "=== TEST 7 : paramètre tableau ==="
assert_auth_status 400 \
    "$BASE_URL/api/entities?limit%5B%5D=10"
echo "OK : paramètre tableau rejeté"

echo "=== TEST 8 : écriture interdite ==="
assert_auth_status 405 \
    --request POST \
    "$BASE_URL/api/entities"
echo "OK : POST interdit"

echo "=== TEST 9 : healthcheck DB privé ==="
assert_status 401 "$BASE_URL/api/health/db"
assert_auth_status 200 "$BASE_URL/api/health/db"
echo "OK : contrôle DB protégé"

echo "=== TEST 10 : routes API privées par défaut ==="
assert_status 401 "$BASE_URL/api/private-test"
echo "OK : route API non déclarée protégée"

echo "=== TOUS LES TESTS ONT REUSSI ==="
