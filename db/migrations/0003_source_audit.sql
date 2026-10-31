-- Ligne Jaune - Audit des sources documentaires
-- Migration transactionnelle : sans BEGIN ni COMMIT.

CREATE TABLE public.source_audit_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id UUID NOT NULL,

    operation TEXT NOT NULL
        CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),

    actor_role TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),

    before_state JSONB,
    after_state JSONB,

    CHECK (
        (operation = 'INSERT'
            AND before_state IS NULL
            AND after_state IS NOT NULL)
        OR
        (operation = 'UPDATE'
            AND before_state IS NOT NULL
            AND after_state IS NOT NULL)
        OR
        (operation = 'DELETE'
            AND before_state IS NOT NULL
            AND after_state IS NULL)
    )
);

CREATE INDEX idx_source_audit_source
    ON public.source_audit_events (source_id, id DESC);

REVOKE ALL ON public.source_audit_events
    FROM PUBLIC, ligne_jaune_app;

CREATE FUNCTION public.log_source_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN

        INSERT INTO public.source_audit_events (
            source_id, operation, actor_role, after_state
        )
        VALUES (
            NEW.id, 'INSERT', session_user, to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        IF OLD IS NOT DISTINCT FROM NEW THEN
            RETURN NEW;
        END IF;

        INSERT INTO public.source_audit_events (
            source_id, operation, actor_role,
            before_state, after_state
        )
        VALUES (
            NEW.id, 'UPDATE', session_user,
            to_jsonb(OLD), to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO public.source_audit_events (
            source_id, operation, actor_role, before_state
        )
        VALUES (
            OLD.id, 'DELETE', session_user, to_jsonb(OLD)
        );

        RETURN OLD;
    END IF;

    RAISE EXCEPTION 'Unsupported operation: %', TG_OP;
END;
$$;

REVOKE ALL ON FUNCTION public.log_source_change()
    FROM PUBLIC, ligne_jaune_app;

CREATE TRIGGER trg_sources_audit
AFTER INSERT OR UPDATE OR DELETE
ON public.sources
FOR EACH ROW
EXECUTE FUNCTION public.log_source_change();
