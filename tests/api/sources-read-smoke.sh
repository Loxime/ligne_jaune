#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

BASE_URL="${LJ_BASE_URL:-http://127.0.0.1:3072}/api/sources"
TOKEN_FILE=".secrets/api_access_token"

auth_curl() {
    local token
    IFS= read -r token < "$TOKEN_FILE"

    [[ "$token" =~ ^[a-f0-9]{64}$ ]] || return 1

    printf 'Authorization: Bearer %s\n' "$token" |
        curl -q --header @- \
          --silent --show-error --max-time 10 "$@"
}

status() {
    local actual
    actual="$(
        auth_curl \
          -o /dev/null \
          -w '%{http_code}' \
          "$2"
    )"

    [[ "$actual" == "$1" ]] || {
        echo "HTTP $actual, attendu $1 : $2" >&2
        exit 1
    }
}

echo "=== LECTURE DES SOURCES ==="

response="$(
    auth_curl --fail \
      "$BASE_URL?kind=book&limit=5&offset=0"
)"

python3 -c '
import json
import sys

payload = json.load(sys.stdin)

assert isinstance(payload["data"], list)
assert payload["pagination"]["limit"] == 5
assert isinstance(payload["pagination"]["has_more"], bool)

print("OK : listing et pagination")
' <<< "$response"

status 400 "$BASE_URL?kind=invalid"
status 400 "$BASE_URL?limit=0"
status 400 "$BASE_URL?limit%5B%5D=5"
echo "OK : filtres invalides refusés"

status 400 "$BASE_URL/not-an-uuid"
status 404 "$BASE_URL/00000000-0000-4000-8000-000000000000"
echo "OK : UUID invalides et inexistants"

anonymous="$(
    curl -q -sS -o /dev/null -w '%{http_code}' \
      "$BASE_URL"
)"

[[ "$anonymous" == "401" ]]
echo "OK : accès anonyme refusé"

echo "=== TESTS SOURCES READ REUSSIS ==="
