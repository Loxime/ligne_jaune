BEGIN;

DO $$
DECLARE
    v_person UUID;
    v_company UUID;
    v_source UUID;
    v_identifier UUID;
    v_relationship UUID;
    v_evidence UUID;
    v_permission TEXT;
    v_count INTEGER;
BEGIN
    FOREACH v_permission IN ARRAY ARRAY[
        'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'
    ]
    LOOP
        IF has_table_privilege(
            'ligne_jaune_app',
            'public.research_audit_events',
            v_permission
        ) THEN
            RAISE EXCEPTION
                'Excessive audit privilege: %', v_permission;
        END IF;
    END LOOP;

    IF has_function_privilege(
        'ligne_jaune_app',
        'public.log_research_change()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'Application can execute audit function';
    END IF;

    RAISE NOTICE 'OK : droits audit restreints';

    INSERT INTO public.entities (kind, name)
    VALUES ('person', 'LJ_AUDIT_PERSON')
    RETURNING id INTO v_person;

    INSERT INTO public.entities (kind, name)
    VALUES ('company', 'LJ_AUDIT_COMPANY')
    RETURNING id INTO v_company;

    INSERT INTO public.sources (kind, title)
    VALUES ('official', 'LJ_AUDIT_SOURCE')
    RETURNING id INTO v_source;

    INSERT INTO public.entity_identifiers (
        entity_id, scheme, value,
        source_id, source_locator
    )
    VALUES (
        v_company, 'TEST', 'AUDIT-0001',
        v_source, 'Section 1'
    )
    RETURNING id INTO v_identifier;

    INSERT INTO public.relationships (
        subject_entity_id, object_entity_id,
        relation_type, source_id, source_locator
    )
    VALUES (
        v_person, v_company, 'directs',
        v_source, 'Section 2'
    )
    RETURNING id INTO v_relationship;

    INSERT INTO public.relationship_evidence (
        relationship_id, source_id, locator, role
    )
    VALUES (
        v_relationship, v_source, 'Page 12', 'supports'
    )
    RETURNING id INTO v_evidence;

    SELECT COUNT(*) INTO v_count
    FROM public.research_audit_events
    WHERE (target_table, target_id) IN (
        ('entity_identifiers', v_identifier),
        ('relationships', v_relationship),
        ('relationship_evidence', v_evidence)
    )
      AND operation = 'INSERT'
      AND before_state IS NULL
      AND after_state IS NOT NULL
      AND actor_role = session_user;

    IF v_count <> 3 THEN
        RAISE EXCEPTION 'Missing INSERT audits: %', v_count;
    END IF;

    RAISE NOTICE 'OK : trois créations journalisées';

    UPDATE public.relationships
    SET status = 'disputed'
    WHERE id = v_relationship;

    IF NOT EXISTS (
        SELECT 1
        FROM public.research_audit_events
        WHERE target_table = 'relationships'
          AND target_id = v_relationship
          AND operation = 'UPDATE'
          AND before_state->>'status' = 'draft'
          AND after_state->>'status' = 'disputed'
    ) THEN
        RAISE EXCEPTION 'UPDATE audit invalid';
    END IF;

    UPDATE public.relationships
    SET status = status
    WHERE id = v_relationship;

    SELECT COUNT(*) INTO v_count
    FROM public.research_audit_events
    WHERE target_table = 'relationships'
      AND target_id = v_relationship
      AND operation = 'UPDATE';

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'No-op UPDATE incorrectly logged';
    END IF;

    RAISE NOTICE 'OK : modification et no-op vérifiés';

    DELETE FROM public.relationship_evidence
    WHERE id = v_evidence;

    DELETE FROM public.relationships
    WHERE id = v_relationship;

    DELETE FROM public.entity_identifiers
    WHERE id = v_identifier;

    SELECT COUNT(*) INTO v_count
    FROM public.research_audit_events
    WHERE operation = 'DELETE'
      AND (target_table, target_id) IN (
        ('relationship_evidence', v_evidence),
        ('relationships', v_relationship),
        ('entity_identifiers', v_identifier)
      )
      AND before_state IS NOT NULL
      AND after_state IS NULL;

    IF v_count <> 3 THEN
        RAISE EXCEPTION 'Missing DELETE audits: %', v_count;
    END IF;

    RAISE NOTICE 'OK : suppressions journalisées';
    RAISE NOTICE 'OK : audit de recherche complet';
END;
$$;

ROLLBACK;
