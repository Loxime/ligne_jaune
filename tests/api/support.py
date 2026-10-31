import json
import os
import re
import subprocess
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[2]
COMPOSE = os.environ.get("LJ_COMPOSE_FILE", "compose.test.yaml")
BASE_URL = os.environ.get(
    "LJ_BASE_URL", "http://127.0.0.1:3072"
)

# Empêcher tout nettoyage sur la base de développement.
parsed = urlsplit(BASE_URL)

if (
    COMPOSE != "compose.test.yaml"
    or parsed.scheme != "http"
    or parsed.hostname != "127.0.0.1"
    or parsed.port != 3072
    or parsed.path not in ("", "/")
):
    raise RuntimeError(
        "Les tests d'écriture exigent ligne-jaune-test."
    )

TOKEN = (
    ROOT / ".secrets/api_access_token"
).read_text(encoding="utf-8").strip()

if re.fullmatch(r"[a-f0-9]{64}", TOKEN) is None:
    raise RuntimeError("Jeton de test invalide.")


class Client:
    def __init__(self):
        self.entities = []
        self.sources = []
        self.relationships = []

    def request(self, method, path, payload=None, auth=True):
        headers = {"Accept": "application/json"}

        if auth:
            headers["Authorization"] = f"Bearer {TOKEN}"

        data = None

        if payload is not None:
            data = json.dumps(
                payload, ensure_ascii=False
            ).encode("utf-8")
            headers["Content-Type"] = "application/json"

        request = urllib.request.Request(
            BASE_URL + path,
            data=data,
            headers=headers,
            method=method,
        )

        try:
            response = urllib.request.urlopen(
                request, timeout=10
            )
        except urllib.error.HTTPError as error:
            response = error

        with response:
            raw = response.read()
            body = json.loads(raw) if raw else {}
            return response.status, body

    def create(self, path, payload, collection):
        status, body = self.request("POST", path, payload)

        if status != 201:
            raise AssertionError((status, body))

        identifier = str(uuid.UUID(body["data"]["id"]))
        getattr(self, collection).append(identifier)

        return body["data"]

    def cleanup(self):
        # Tous les IDs sont contrôlés comme UUID avant SQL.
        def identifiers(values):
            return ", ".join(
                f"'{uuid.UUID(value)}'::uuid"
                for value in values
            )

        queries = []

        if self.relationships:
            ids = identifiers(self.relationships)
            queries.extend([
                "DELETE FROM public.relationship_evidence "
                f"WHERE relationship_id IN ({ids});",
                "DELETE FROM public.relationships "
                f"WHERE id IN ({ids});",
            ])

        if self.entities:
            ids = identifiers(self.entities)
            queries.append(
                "DELETE FROM public.entity_identifiers "
                f"WHERE entity_id IN ({ids});"
            )

        if self.sources:
            queries.append(
                "DELETE FROM public.sources WHERE id IN "
                f"({identifiers(self.sources)});"
            )

        if self.entities:
            queries.append(
                "DELETE FROM public.entities WHERE id IN "
                f"({identifiers(self.entities)});"
            )

        if not queries:
            return

        subprocess.run(
            [
                "docker", "compose", "-f", COMPOSE,
                "exec", "-T", "db",
                "psql", "-X", "-q",
                "-v", "ON_ERROR_STOP=1",
                "-U", "ligne_jaune_admin",
                "-d", "ligne_jaune",
                "-f", "-",
            ],
            cwd=ROOT,
            input="\n".join(queries) + "\n",
            text=True,
            check=True,
            capture_output=True,
        )
