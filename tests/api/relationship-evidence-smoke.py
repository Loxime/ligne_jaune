import uuid

from support import Client


client = Client()

try:
    source = client.create(
        "/api/sources",
        {"kind": "official", "title": "LJ_TEST_PRIMARY_SOURCE"},
        "sources",
    )

    article = client.create(
        "/api/sources",
        {"kind": "article", "title": "LJ_TEST_SECONDARY_SOURCE"},
        "sources",
    )

    person = client.create(
        "/api/entities",
        {"kind": "person", "name": "LJ_TEST_PERSON_EVIDENCE"},
        "entities",
    )

    company = client.create(
        "/api/entities",
        {"kind": "company", "name": "LJ_TEST_COMPANY_EVIDENCE"},
        "entities",
    )

    relationship = client.create(
        "/api/relationships",
        {
            "subject_entity_id": person["id"],
            "object_entity_id": company["id"],
            "relation_type": "directs",
            "source_id": source["id"],
            "source_locator": "Section 1",
        },
        "relationships",
    )

    path = f"/api/relationships/{relationship['id']}/evidence"

    status, _ = client.request("GET", path, auth=False)
    assert status == 401
    print("OK : authentification obligatoire")

    invalid = {
        "source_id": article["id"],
        "locator": "Page 12",
        "role": "invalid",
    }

    status, _ = client.request("POST", path, invalid)
    assert status == 400
    print("OK : rôle invalide refusé")

    invalid["role"] = "supports"
    invalid["source_id"] = str(uuid.uuid4())

    status, _ = client.request("POST", path, invalid)
    assert status == 422
    print("OK : source inexistante refusée")

    supporting = {
        "source_id": article["id"],
        "locator": "Page 12",
        "role": "supports",
        "note": "Confirmation documentaire fictive.",
    }

    status, body = client.request("POST", path, supporting)
    assert status == 201, (status, body)
    print("OK : preuve corroborante créée")

    status, _ = client.request("POST", path, supporting)
    assert status == 409
    print("OK : doublon refusé")

    contradicting = {
        "source_id": article["id"],
        "locator": "Page 18",
        "role": "contradicts",
        "note": "Période contestée.",
    }

    status, _ = client.request("POST", path, contradicting)
    assert status == 201
    print("OK : preuve contradictoire créée")

    status, body = client.request("GET", path)
    assert status == 200
    assert len(body["data"]) == 2

    assert {e["role"] for e in body["data"]} == {
        "supports", "contradicts"
    }

    assert all(
        e["source_title"] == article["title"]
        for e in body["data"]
    )

    print("OK : preuves et sources retrouvées")

    status, body = client.request(
        "GET", path + "?limit=1&offset=0"
    )
    assert status == 200
    assert len(body["data"]) == 1
    assert body["pagination"]["has_more"] is True

    status, body = client.request(
        "GET", path + "?limit=1&offset=1"
    )
    assert status == 200
    assert len(body["data"]) == 1
    assert body["pagination"]["has_more"] is False

    print("OK : pagination")

    status, _ = client.request(
        "GET", "/api/relationships/invalid/evidence"
    )
    assert status == 400

    status, _ = client.request(
        "GET", f"/api/relationships/{uuid.uuid4()}/evidence"
    )
    assert status == 404

    status, _ = client.request("GET", path + "?limit=0")
    assert status == 400

    status, body = client.request(
        "GET", f"/api/relationships/{relationship['id']}"
    )
    assert status == 200
    assert body["data"]["status"] == "draft"

    print("OK : erreurs et statut brouillon")
    print("=== EVIDENCE TESTS PASSED ===")

finally:
    client.cleanup()
