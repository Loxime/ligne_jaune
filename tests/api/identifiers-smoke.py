import uuid

from support import Client


client = Client()

try:
    source = client.create(
        "/api/sources",
        {
            "kind": "official",
            "title": "LJ_TEST_REGISTRE_FICTIF",
        },
        "sources",
    )

    entity = client.create(
        "/api/entities",
        {
            "kind": "company",
            "name": "LJ_TEST_SOCIETE_FICTIVE",
        },
        "entities",
    )

    path = f"/api/entities/{entity['id']}/identifiers"

    status, _ = client.request("GET", path, auth=False)
    assert status == 401
    print("OK : accès anonyme refusé")

    status, _ = client.request(
        "POST",
        path,
        {
            "scheme": "SIREN",
            "value": "123",
            "source_id": source["id"],
            "source_locator": "Section 1",
        },
    )
    assert status == 400
    print("OK : format incorrect refusé")

    payload = {
        "scheme": "SIREN",
        "value": "123456789",
        "source_id": source["id"],
        "source_locator": "Section Identification",
    }

    status, body = client.request("POST", path, payload)
    assert status == 201, (status, body)

    identifier_id = body["data"]["id"]
    uuid.UUID(identifier_id)

    print("OK : identifiant fictif créé")

    status, _ = client.request("POST", path, payload)
    assert status == 409
    print("OK : doublon refusé")

    status, body = client.request("GET", path)
    assert status == 200
    assert len(body["data"]) == 1

    item = body["data"][0]

    assert item["id"] == identifier_id
    assert item["scheme"] == "SIREN"
    assert item["value"] == "123456789"
    assert item["source_id"] == source["id"]
    assert item["source_title"] == source["title"]

    print("OK : identifiant et provenance retrouvés")

    print("=== IDENTIFIERS TESTS PASSED ===")

finally:
    client.cleanup()
