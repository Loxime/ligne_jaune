-- Ligne Jaune : audit des identifiants et relations.
-- Exécution transactionnelle par db-migrate.sh.

CREATE TABLE public.research_audit_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    target_table TEXT NOT NULL CHECK (
        target_table IN (
            'entity_identifiers',
            'relationships',
            'relationship_evidence'
        )
    ),

    target_id UUID NOT NULL,

    operation TEXT NOT NULL CHECK (
        operation IN ('INSERT', 'UPDATE', 'DELETE')
    ),

    actor_role TEXT NOT NULL,

    occurred_at TIMESTAMPTZ NOT NULL
        DEFAULT clock_timestamp(),

    before_state JSONB,
    after_state JSONB,

    CONSTRAINT valid_research_audit_states CHECK (
        (
            operation = 'INSERT'
            AND before_state IS NULL
            AND after_state IS NOT NULL
        )
        OR (
            operation = 'UPDATE'
            AND before_state IS NOT NULL
            AND after_state IS NOT NULL
        )
        OR (
            operation = 'DELETE'
            AND before_state IS NOT NULL
            AND after_state IS NULL
        )
    )
);

CREATE INDEX idx_research_audit_target
    ON public.research_audit_events (
        target_table, target_id, id DESC
    );

REVOKE ALL ON public.research_audit_events
    FROM PUBLIC, ligne_jaune_app;

CREATE FUNCTION public.log_research_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN

        INSERT INTO public.research_audit_events (
            target_table,
            target_id,
            operation,
            actor_role,
            after_state
        )
        VALUES (
            TG_TABLE_NAME,
            NEW.id,
            'INSERT',
            session_user,
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        IF OLD IS NOT DISTINCT FROM NEW THEN
            RETURN NEW;
        END IF;

        INSERT INTO public.research_audit_events (
            target_table,
            target_id,
            operation,
            actor_role,
            before_state,
            after_state
        )
        VALUES (
            TG_TABLE_NAME,
            NEW.id,
            'UPDATE',
            session_user,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO public.research_audit_events (
            target_table,
            target_id,
            operation,
            actor_role,
            before_state
        )
        VALUES (
            TG_TABLE_NAME,
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

REVOKE ALL ON FUNCTION public.log_research_change()
    FROM PUBLIC, ligne_jaune_app;

CREATE TRIGGER trg_identifiers_research_audit
AFTER INSERT OR UPDATE OR DELETE
ON public.entity_identifiers
FOR EACH ROW
EXECUTE FUNCTION public.log_research_change();

CREATE TRIGGER trg_relationships_research_audit
AFTER INSERT OR UPDATE OR DELETE
ON public.relationships
FOR EACH ROW
EXECUTE FUNCTION public.log_research_change();

CREATE TRIGGER trg_evidence_research_audit
AFTER INSERT OR UPDATE OR DELETE
ON public.relationship_evidence
FOR EACH ROW
EXECUTE FUNCTION public.log_research_change();
