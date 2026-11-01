import subprocess

from support import Client, COMPOSE, ROOT


client = Client()

try:
    source = client.create(
        "/api/sources",
        {"kind": "official", "title": "LJ_TEST_AUDIT_SOURCE"},
        "sources",
    )

    person = client.create(
        "/api/entities",
        {"kind": "person", "name": "LJ_TEST_AUDIT_PERSON"},
        "entities",
    )

    company = client.create(
        "/api/entities",
        {"kind": "company", "name": "LJ_TEST_AUDIT_COMPANY"},
        "entities",
    )

    identifier_path = (
        f"/api/entities/{company['id']}/identifiers"
    )

    status, identifier = client.request(
        "POST",
        identifier_path,
        {
            "scheme": "SIREN",
            "value": "123456789",
            "source_id": source["id"],
            "source_locator": "Section Identification",
        },
    )

    assert status == 201, (status, identifier)

    relationship = client.create(
        "/api/relationships",
        {
            "subject_entity_id": person["id"],
            "object_entity_id": company["id"],
            "relation_type": "directs",
            "source_id": source["id"],
            "source_locator": "Section Mandats",
        },
        "relationships",
    )

    evidence_path = (
        f"/api/relationships/{relationship['id']}/evidence"
    )

    status, evidence = client.request(
        "POST",
        evidence_path,
        {
            "source_id": source["id"],
            "locator": "Page 12",
            "role": "supports",
        },
    )

    assert status == 201, (status, evidence)

    expected = {
        "entity_identifiers": identifier["data"]["id"],
        "relationships": relationship["id"],
        "relationship_evidence": evidence["data"]["id"],
    }

    for table, identifier_id in expected.items():
        sql = (
            "SELECT COUNT(*) FROM public.research_audit_events "
            f"WHERE target_table = '{table}' "
            f"AND target_id = '{identifier_id}'::uuid "
            "AND operation = 'INSERT' "
            "AND actor_role = 'ligne_jaune_app';"
        )

        result = subprocess.run(
            [
                "docker", "compose", "-f", COMPOSE,
                "exec", "-T", "db",
                "psql", "-X", "-At",
                "-v", "ON_ERROR_STOP=1",
                "-U", "ligne_jaune_admin",
                "-d", "ligne_jaune",
                "-c", sql,
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )

        assert result.stdout.strip() == "1", (
            table, result.stdout, result.stderr
        )

        print(f"OK : {table} journalisé par ligne_jaune_app")

    print("=== RESEARCH AUDIT HTTP TESTS PASSED ===")

finally:
    client.cleanup()
