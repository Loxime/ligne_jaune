-- Tests transactionnels de la piste d'audit.
-- Aucune donnée de test conservée.

BEGIN;

DO $$
DECLARE
    test_id UUID;
    event_count INTEGER;
    event_record RECORD;
    permission TEXT;
BEGIN
    -- 1. Vérifier les restrictions d'accès.
    FOREACH permission IN ARRAY ARRAY[
        'SELECT',
        'INSERT',
        'UPDATE',
        'DELETE',
        'TRUNCATE'
    ]
    LOOP
        IF has_table_privilege(
            'ligne_jaune_app',
            'public.entity_audit_events',
            permission
        ) THEN
            RAISE EXCEPTION
                'Permission excessive sur audit : %',
                permission;
        END IF;
    END LOOP;

    RAISE NOTICE 'OK : journal inaccessible à application';

    -- 2. Création fictive.
    INSERT INTO public.entities (kind, name)
    VALUES ('company', 'LJ_AUDIT_TEST_INITIAL')
    RETURNING id INTO test_id;

    SELECT *
    INTO event_record
    FROM public.entity_audit_events
    WHERE entity_id = test_id
      AND operation = 'INSERT';

    IF NOT FOUND
       OR event_record.before_state IS NOT NULL
       OR event_record.after_state->>'name'
          <> 'LJ_AUDIT_TEST_INITIAL'
       OR event_record.actor_role <> session_user
    THEN
        RAISE EXCEPTION 'Audit INSERT incorrect';
    END IF;

    RAISE NOTICE 'OK : INSERT journalisé';

    -- 3. Modification de l'entité.
    UPDATE public.entities
    SET name = 'LJ_AUDIT_TEST_MODIFIED',
        updated_at = NOW()
    WHERE id = test_id;

    SELECT *
    INTO event_record
    FROM public.entity_audit_events
    WHERE entity_id = test_id
      AND operation = 'UPDATE';

    IF NOT FOUND
       OR event_record.before_state->>'name'
          <> 'LJ_AUDIT_TEST_INITIAL'
       OR event_record.after_state->>'name'
          <> 'LJ_AUDIT_TEST_MODIFIED'
    THEN
        RAISE EXCEPTION 'Audit UPDATE incorrect';
    END IF;

    RAISE NOTICE 'OK : UPDATE journalisé';

    -- 4. Modification sans changement.
    UPDATE public.entities
    SET name = name
    WHERE id = test_id;

    SELECT COUNT(*)
    INTO event_count
    FROM public.entity_audit_events
    WHERE entity_id = test_id;

    IF event_count <> 2 THEN
        RAISE EXCEPTION 'Audit sans changement détecté';
    END IF;

    RAISE NOTICE 'OK : UPDATE sans changement ignoré';

    -- 5. Suppression.
    DELETE FROM public.entities
    WHERE id = test_id;

    SELECT *
    INTO event_record
    FROM public.entity_audit_events
    WHERE entity_id = test_id
      AND operation = 'DELETE';

    IF NOT FOUND
       OR event_record.before_state->>'name'
          <> 'LJ_AUDIT_TEST_MODIFIED'
       OR event_record.after_state IS NOT NULL
    THEN
        RAISE EXCEPTION 'Audit DELETE incorrect';
    END IF;

    SELECT COUNT(*)
    INTO event_count
    FROM public.entity_audit_events
    WHERE entity_id = test_id;

    IF event_count <> 3 THEN
        RAISE EXCEPTION
            'Nombre événements incorrect : %',
            event_count;
    END IF;

    RAISE NOTICE 'OK : DELETE journalisé';
    RAISE NOTICE 'OK : historique complet de 3 événements';
END;
$$;

ROLLBACK;
