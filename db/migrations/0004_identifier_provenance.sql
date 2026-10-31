-- Ligne Jaune - Provenance des identifiants externes.
--
-- Les colonnes NOT NULL supposent qu'aucun identifiant
-- historique dépourvu de source n'est présent.
-- En cas d'échec, effectuer une migration de reprise
-- des données, sans supprimer les enregistrements.

ALTER TABLE public.entity_identifiers
    ADD COLUMN source_id UUID NOT NULL
        REFERENCES public.sources(id) ON DELETE RESTRICT,
    ADD COLUMN source_locator TEXT NOT NULL
        CHECK (
            length(btrim(source_locator)) BETWEEN 1 AND 500
        );

CREATE INDEX idx_identifiers_source
    ON public.entity_identifiers (source_id);
