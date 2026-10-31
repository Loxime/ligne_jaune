import uuid

from support import Client


client = Client()

try:
    source = client.create(
        "/api/sources",
        {
            "kind": "official",
            "title": "LJ_TEST_SOURCE_RELATION",
            "url": "https://example.org/registre-fictif",
        },
        "sources",
    )

    person = client.create(
        "/api/entities",
        {
            "kind": "person",
            "name": "LJ_TEST_PERSONNE",
        },
        "entities",
    )

    company = client.create(
        "/api/entities",
        {
            "kind": "company",
            "name": "LJ_TEST_ENTREPRISE",
        },
        "entities",
    )

    payload = {
        "subject_entity_id": person["id"],
        "object_entity_id": company["id"],
        "relation_type": "directs",
        "source_id": source["id"],
        "source_locator": "Section Dirigeants",
        "valid_from": "2020-01-01",
        "valid_until": "2024-12-31",
    }

    status, _ = client.request(
        "POST", "/api/relationships", payload, auth=False
    )
    assert status == 401
    print("OK : création anonyme refusée")

    invalid = dict(payload)
    invalid["source_id"] = str(uuid.uuid4())

    status, body = client.request(
        "POST", "/api/relationships", invalid
    )
    assert status == 422, (status, body)
    print("OK : source inexistante refusée")

    invalid = dict(payload)
    invalid["valid_until"] = "2019-01-01"

    status, _ = client.request(
        "POST", "/api/relationships", invalid
    )
    assert status == 400
    print("OK : période incorrecte refusée")

    invalid = dict(payload)
    invalid["object_entity_id"] = person["id"]

    status, _ = client.request(
        "POST", "/api/relationships", invalid
    )
    assert status == 400
    print("OK : relation réflexive refusée")

    relationship = client.create(
        "/api/relationships",
        payload,
        "relationships",
    )

    assert relationship["status"] == "draft"
    assert relationship["source_id"] == source["id"]
    assert relationship["source_locator"] == "Section Dirigeants"

    print("OK : relation créée en brouillon")

    status, body = client.request(
        "GET",
        f"/api/relationships/{relationship['id']}",
    )

    assert status == 200, (status, body)

    result = body["data"]

    assert result["subject_entity_id"] == person["id"]
    assert result["object_entity_id"] == company["id"]
    assert result["subject_name"] == person["name"]
    assert result["object_name"] == company["name"]
    assert result["source_title"] == source["title"]
    assert result["source_kind"] == "official"
    assert result["source_url"] == source["url"]
    assert result["relation_type"] == "directs"
    assert result["valid_from"] == "2020-01-01"
    assert result["valid_until"] == "2024-12-31"

    print("OK : relation et provenance retrouvées")

    status, _ = client.request(
        "GET", "/api/relationships/invalid-uuid"
    )
    assert status == 400

    status, _ = client.request(
        "GET",
        f"/api/relationships/{uuid.uuid4()}",
    )
    assert status == 404

    print("OK : UUID incorrects et absents traités")
    print("=== RELATIONSHIPS TESTS PASSED ===")

finally:
    client.cleanup()
