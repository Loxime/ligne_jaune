#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="http://127.0.0.1:3071"

echo "=== TEST 1 : consultation des entités ==="

response="$(
    curl --fail --silent --show-error \
        --max-time 5 \
        "$BASE_URL/api/entities?kind=company&limit=10&offset=0"
)"

python3 -c '
import json
import sys

response = json.load(sys.stdin)

assert isinstance(response["data"], list)
assert response["pagination"]["limit"] == 10
assert response["pagination"]["offset"] == 0
assert isinstance(response["pagination"]["has_more"], bool)

print("OK : réponse JSON et pagination")
' <<< "$response"

echo "=== TEST 2 : type invalide ==="

status="$(
    curl --silent --show-error \
        --max-time 5 \
        --output /dev/null \
        --write-out '%{http_code}' \
        "$BASE_URL/api/entities?kind=invalid"
)"

test "$status" = "400"
echo "OK : type invalide refusé"

echo "=== TEST 3 : pagination invalide ==="

status="$(
    curl --silent --show-error \
        --max-time 5 \
        --output /dev/null \
        --write-out '%{http_code}' \
        "$BASE_URL/api/entities?limit=0"
)"

test "$status" = "400"
echo "OK : pagination invalide refusée"

echo "=== TEST 4 : paramètre tableau ==="

status="$(
    curl --silent --show-error \
        --max-time 5 \
        --output /dev/null \
        --write-out '%{http_code}' \
        "$BASE_URL/api/entities?limit%5B%5D=10"
)"

test "$status" = "400"
echo "OK : paramètres complexes refusés"

echo "=== TEST 5 : écriture interdite ==="

status="$(
    curl --silent --show-error \
        --max-time 5 \
        --output /dev/null \
        --write-out '%{http_code}' \
        --request POST \
        "$BASE_URL/api/entities"
)"

test "$status" = "405"
echo "OK : POST interdit"

echo "=== TOUS LES TESTS ONT REUSSI ==="
