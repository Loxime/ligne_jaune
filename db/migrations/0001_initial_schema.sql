-- Ligne Jaune
-- Migration 0001 : modèle relationnel initial
-- PostgreSQL 16

CREATE TABLE schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1. Entités
CREATE TABLE entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    kind TEXT NOT NULL CHECK (
        kind IN (
            'person',
            'company',
            'association',
            'institution',
            'other'
        )
    ),

    name TEXT NOT NULL CHECK (btrim(name) <> ''),

    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_entities_name
    ON entities (LOWER(name));

CREATE INDEX idx_entities_kind
    ON entities (kind);


-- 2. Identifiants externes
CREATE TABLE entity_identifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    entity_id UUID NOT NULL
        REFERENCES entities(id) ON DELETE RESTRICT,

    scheme TEXT NOT NULL CHECK (btrim(scheme) <> ''),
    value TEXT NOT NULL CHECK (btrim(value) <> ''),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (scheme, value)
);

CREATE INDEX idx_entity_identifiers_entity
    ON entity_identifiers (entity_id);


-- 3. Sources documentaires
CREATE TABLE sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    kind TEXT NOT NULL CHECK (
        kind IN (
            'official',
            'book',
            'article',
            'report',
            'archive',
            'personal_note',
            'other'
        )
    ),

    title TEXT NOT NULL CHECK (btrim(title) <> ''),

    author TEXT,
    publisher TEXT,

    published_on DATE,

    url TEXT,
    isbn TEXT,
    doi TEXT,

    license_note TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sources_kind
    ON sources (kind);


-- 4. Relations entre entités
CREATE TABLE relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    subject_entity_id UUID NOT NULL
        REFERENCES entities(id) ON DELETE RESTRICT,

    object_entity_id UUID NOT NULL
        REFERENCES entities(id) ON DELETE RESTRICT,

    relation_type TEXT NOT NULL
        CHECK (btrim(relation_type) <> ''),

    valid_from DATE,
    valid_until DATE,

    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'reviewed',
                'disputed',
                'retracted'
            )
        ),

    -- Source principale obligatoire
    source_id UUID NOT NULL
        REFERENCES sources(id) ON DELETE RESTRICT,

    -- Page, article, paragraphe, section...
    source_locator TEXT NOT NULL
        CHECK (btrim(source_locator) <> ''),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_relationship_period
        CHECK (
            valid_from IS NULL
            OR valid_until IS NULL
            OR valid_until >= valid_from
        )
);

CREATE INDEX idx_relationships_subject
    ON relationships (subject_entity_id);

CREATE INDEX idx_relationships_object
    ON relationships (object_entity_id);

CREATE INDEX idx_relationships_type
    ON relationships (relation_type);

CREATE INDEX idx_relationships_source
    ON relationships (source_id);


-- 5. Preuves complémentaires
CREATE TABLE relationship_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    relationship_id UUID NOT NULL
        REFERENCES relationships(id) ON DELETE RESTRICT,

    source_id UUID NOT NULL
        REFERENCES sources(id) ON DELETE RESTRICT,

    locator TEXT NOT NULL CHECK (btrim(locator) <> ''),

    role TEXT NOT NULL CHECK (
        role IN (
            'supports',
            'contradicts',
            'context'
        )
    ),

    note TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (relationship_id, source_id, locator, role)
);

CREATE INDEX idx_relationship_evidence_relation
    ON relationship_evidence (relationship_id);

CREATE INDEX idx_relationship_evidence_source
    ON relationship_evidence (source_id);


-- Enregistrement de la migration
INSERT INTO schema_migrations (version)
VALUES ('0001_initial_schema');
