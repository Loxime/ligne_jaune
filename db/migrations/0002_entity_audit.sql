-- Ligne Jaune
-- Migration 0002 : journalisation des entités
-- PostgreSQL 16
--
-- Transaction gérée par db-migrate.sh.
-- Ne pas ajouter BEGIN ou COMMIT ici.

CREATE TABLE public.entity_audit_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    entity_id UUID NOT NULL,

    operation TEXT NOT NULL
        CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),

    actor_role TEXT NOT NULL,

    occurred_at TIMESTAMPTZ NOT NULL
        DEFAULT clock_timestamp(),

    before_state JSONB,
    after_state JSONB,

    CONSTRAINT valid_audit_states CHECK (
        (
            operation = 'INSERT'
            AND before_state IS NULL
            AND after_state IS NOT NULL
        )
        OR
        (
            operation = 'UPDATE'
            AND before_state IS NOT NULL
            AND after_state IS NOT NULL
        )
        OR
        (
            operation = 'DELETE'
            AND before_state IS NOT NULL
            AND after_state IS NULL
        )
    )
);

-- Retrouver rapidement l'historique d'une entité.
CREATE INDEX idx_entity_audit_entity
    ON public.entity_audit_events (entity_id, id DESC);

CREATE INDEX idx_entity_audit_occurred
    ON public.entity_audit_events (occurred_at DESC);

-- Le compte applicatif n'a aucun accès direct
-- au journal, y compris en lecture.
REVOKE ALL ON TABLE public.entity_audit_events
    FROM PUBLIC, ligne_jaune_app;


-- Fonction exécutée automatiquement par PostgreSQL.
CREATE FUNCTION public.log_entity_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN

        INSERT INTO public.entity_audit_events (
            entity_id,
            operation,
            actor_role,
            after_state
        )
        VALUES (
            NEW.id,
            'INSERT',
            session_user,
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        -- Éviter de journaliser une mise à jour
        -- qui ne modifie aucune donnée.
        IF OLD IS NOT DISTINCT FROM NEW THEN
            RETURN NEW;
        END IF;

        INSERT INTO public.entity_audit_events (
            entity_id,
            operation,
            actor_role,
            before_state,
            after_state
        )
        VALUES (
            NEW.id,
            'UPDATE',
            session_user,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO public.entity_audit_events (
            entity_id,
            operation,
            actor_role,
            before_state
        )
        VALUES (
            OLD.id,
            'DELETE',
            session_user,
            to_jsonb(OLD)
        );

        RETURN OLD;
    END IF;

    RAISE EXCEPTION 'Unsupported audit operation: %', TG_OP;
END;
$$;

-- La fonction n'est pas appelable directement
-- par le compte applicatif.
REVOKE ALL ON FUNCTION public.log_entity_change()
    FROM PUBLIC, ligne_jaune_app;

-- Déclenchement automatique sur toute écriture.
CREATE TRIGGER trg_entities_audit
AFTER INSERT OR UPDATE OR DELETE
ON public.entities
FOR EACH ROW
EXECUTE FUNCTION public.log_entity_change();
