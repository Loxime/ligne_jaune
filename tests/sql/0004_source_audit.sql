BEGIN;

DO $$
DECLARE
    test_source UUID;
    event_total INTEGER;
    role_permission TEXT;
BEGIN
    FOREACH role_permission IN ARRAY ARRAY[
        'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'
    ]
    LOOP
        IF has_table_privilege(
            'ligne_jaune_app',
            'public.source_audit_events',
            role_permission
        ) THEN
            RAISE EXCEPTION
                'Permission excessive: %',
                role_permission;
        END IF;
    END LOOP;

    RAISE NOTICE 'OK : journal inaccessible à application';

    INSERT INTO public.sources (kind, title)
    VALUES ('book', 'LJ_TEST_SOURCE_INITIAL')
    RETURNING id INTO test_source;

    IF NOT EXISTS (
        SELECT 1 FROM public.source_audit_events
        WHERE source_id = test_source
          AND operation = 'INSERT'
          AND after_state->>'title' = 'LJ_TEST_SOURCE_INITIAL'
    ) THEN
        RAISE EXCEPTION 'Audit INSERT absent';
    END IF;

    RAISE NOTICE 'OK : création journalisée';

    UPDATE public.sources
    SET title = 'LJ_TEST_SOURCE_MODIFIED'
    WHERE id = test_source;

    IF NOT EXISTS (
        SELECT 1 FROM public.source_audit_events
        WHERE source_id = test_source
          AND operation = 'UPDATE'
          AND before_state->>'title' = 'LJ_TEST_SOURCE_INITIAL'
          AND after_state->>'title' = 'LJ_TEST_SOURCE_MODIFIED'
    ) THEN
        RAISE EXCEPTION 'Audit UPDATE absent';
    END IF;

    RAISE NOTICE 'OK : modification journalisée';

    UPDATE public.sources
    SET title = title
    WHERE id = test_source;

    DELETE FROM public.sources
    WHERE id = test_source;

    IF NOT EXISTS (
        SELECT 1 FROM public.source_audit_events
        WHERE source_id = test_source
          AND operation = 'DELETE'
          AND before_state->>'title' = 'LJ_TEST_SOURCE_MODIFIED'
    ) THEN
        RAISE EXCEPTION 'Audit DELETE absent';
    END IF;

    SELECT COUNT(*)
    INTO event_total
    FROM public.source_audit_events
    WHERE source_id = test_source;

    IF event_total <> 3 THEN
        RAISE EXCEPTION
            'Nombre d événements incorrect: %',
            event_total;
    END IF;

    RAISE NOTICE 'OK : suppression et historique complet';
END;
$$;

ROLLBACK;
