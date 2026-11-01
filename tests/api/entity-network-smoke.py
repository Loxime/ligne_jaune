import uuid

from support import Client


client = Client()

try:
    source = client.create(
        "/api/sources",
        {"kind": "official", "title": "LJ_TEST_NETWORK_SOURCE"},
        "sources",
    )

    person = client.create(
        "/api/entities",
        {"kind": "person", "name": "LJ_NETWORK_PERSON"},
        "entities",
    )

    company = client.create(
        "/api/entities",
        {"kind": "company", "name": "LJ_NETWORK_COMPANY"},
        "entities",
    )

    institution = client.create(
        "/api/entities",
        {"kind": "institution", "name": "LJ_NETWORK_INSTITUTION"},
        "entities",
    )

    incoming = client.create(
        "/api/relationships",
        {
            "subject_entity_id": person["id"],
            "object_entity_id": company["id"],
            "relation_type": "directs",
            "source_id": source["id"],
            "source_locator": "Section A",
        },
        "relationships",
    )

    outgoing = client.create(
        "/api/relationships",
        {
            "subject_entity_id": company["id"],
            "object_entity_id": institution["id"],
            "relation_type": "member_of",
            "source_id": source["id"],
            "source_locator": "Section B",
        },
        "relationships",
    )

    evidence_path = (
        f"/api/relationships/{outgoing['id']}/evidence"
    )

    status, _ = client.request(
        "POST",
        evidence_path,
        {
            "source_id": source["id"],
            "locator": "Page 4",
            "role": "contradicts",
        },
    )
    assert status == 201

    path = f"/api/entities/{company['id']}/relationships"

    status, body = client.request("GET", path, auth=False)
    assert status == 401

    status, body = client.request("GET", path)
    assert status == 200, (status, body)
    assert len(body["data"]) == 2
    assert {r["id"] for r in body["data"]} == {
        incoming["id"], outgoing["id"]
    }

    print("OK : réseau entrant et sortant")

    status, body = client.request(
        "GET", path + "?direction=incoming"
    )
    assert status == 200
    assert len(body["data"]) == 1
    assert body["data"][0]["id"] == incoming["id"]

    status, body = client.request(
        "GET", path + "?direction=outgoing"
    )
    assert status == 200
    assert len(body["data"]) == 1
    assert body["data"][0]["id"] == outgoing["id"]
    assert body["data"][0]["contradictory_evidence_count"] == 1

    print("OK : filtres directionnels et contradictions")

    status, body = client.request(
        "GET", path + "?status=draft"
    )
    assert status == 200
    assert len(body["data"]) == 2

    status, body = client.request(
        "GET", path + "?limit=1&offset=0"
    )
    assert status == 200
    assert len(body["data"]) == 1
    assert body["pagination"]["has_more"] is True

    print("OK : statut et pagination")

    status, _ = client.request(
        "GET", path + "?direction=invalid"
    )
    assert status == 400

    status, _ = client.request(
        "GET", path + "?limit[]=1"
    )
    assert status == 400

    status, _ = client.request(
        "GET", f"/api/entities/{uuid.uuid4()}/relationships"
    )
    assert status == 404

    print("OK : validations et erreurs")
    print("=== ENTITY NETWORK TESTS PASSED ===")

finally:
    client.cleanup()
