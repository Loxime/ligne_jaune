-- Test transactionnel du modèle Ligne Jaune.
-- Toutes les données sont fictives.
-- Aucune donnée n'est conservée.

BEGIN;

DO $$
DECLARE
    person_id UUID;
    company_id UUID;
    official_source_id UUID;
    book_source_id UUID;
    relation_id UUID;
BEGIN
    -- Personne fictive
    INSERT INTO entities (kind, name)
    VALUES ('person', 'Personne Exemple')
    RETURNING id INTO person_id;

    -- Entreprise fictive
    INSERT INTO entities (kind, name)
    VALUES ('company', 'Entreprise Exemple')
    RETURNING id INTO company_id;

    -- Source officielle fictive
    INSERT INTO sources (kind, title)
    VALUES (
        'official',
        'Registre officiel fictif'
    )
    RETURNING id INTO official_source_id;

    -- Identifiant fictif avec provenance obligatoire
    INSERT INTO entity_identifiers (
        entity_id,
        scheme,
        value,
        source_id,
        source_locator
    )
    VALUES (
        company_id,
        'TEST_IDENTIFIER',
        'TEST-0001',
        official_source_id,
        'Section Identification'
    );

    IF NOT EXISTS (
        SELECT 1
        FROM entity_identifiers i
        JOIN sources s ON s.id = i.source_id
        WHERE i.entity_id = company_id
          AND i.scheme = 'TEST_IDENTIFIER'
          AND i.value = 'TEST-0001'
          AND i.source_locator = 'Section Identification'
          AND s.kind = 'official'
    ) THEN
        RAISE EXCEPTION 'Provenance identifiant absente';
    END IF;


    -- Livre fictif
    INSERT INTO sources (kind, title)
    VALUES (
        'book',
        'Ouvrage de test'
    )
    RETURNING id INTO book_source_id;

    -- Relation documentée
    INSERT INTO relationships (
        subject_entity_id,
        object_entity_id,
        relation_type,
        source_id,
        source_locator,
        valid_from,
        valid_until
    )
    VALUES (
        person_id,
        company_id,
        'directs',
        official_source_id,
        'Fiche fictive numéro 1',
        DATE '2020-01-01',
        DATE '2023-12-31'
    )
    RETURNING id INTO relation_id;

    -- Source complémentaire
    INSERT INTO relationship_evidence (
        relationship_id,
        source_id,
        locator,
        role
    )
    VALUES (
        relation_id,
        book_source_id,
        'Page 42',
        'supports'
    );

    -- Vérification du graphe relationnel
    IF NOT EXISTS (
        SELECT 1
        FROM relationships r
        JOIN entities e1
            ON e1.id = r.subject_entity_id
        JOIN entities e2
            ON e2.id = r.object_entity_id
        JOIN sources s
            ON s.id = r.source_id
        JOIN relationship_evidence ev
            ON ev.relationship_id = r.id
        WHERE r.id = relation_id
          AND e1.name = 'Personne Exemple'
          AND e2.name = 'Entreprise Exemple'
          AND s.kind = 'official'
          AND ev.role = 'supports'
    ) THEN
        RAISE EXCEPTION
            'Erreur : relation ou provenance invalide';
    END IF;

    -- Vérifier qu'une relation sans source est refusée
    BEGIN
        INSERT INTO relationships (
            subject_entity_id,
            object_entity_id,
            relation_type,
            source_locator
        )
        VALUES (
            person_id,
            company_id,
            'directs',
            'Page 42'
        );

        RAISE EXCEPTION
            'Erreur : relation sans source acceptée';

    EXCEPTION WHEN not_null_violation THEN
        NULL;
    END;

    -- Vérifier qu'une période inversée est refusée
    BEGIN
        INSERT INTO relationships (
            subject_entity_id,
            object_entity_id,
            relation_type,
            source_id,
            source_locator,
            valid_from,
            valid_until
        )
        VALUES (
            person_id,
            company_id,
            'directs',
            official_source_id,
            'Test',
            DATE '2025-01-01',
            DATE '2024-01-01'
        );

        RAISE EXCEPTION
            'Erreur : période invalide acceptée';

    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    RAISE NOTICE
        'OK : modèle, relations, preuves et contraintes';
END;
$$;

-- Annulation volontaire des données de test
ROLLBACK;
