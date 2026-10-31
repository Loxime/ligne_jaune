#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

umask 077

SECRET_DIR=".secrets"
SECRET_FILE="$SECRET_DIR/app_db_password"

mkdir -p "$SECRET_DIR"
chmod 700 "$SECRET_DIR"

# Génération unique du mot de passe applicatif
if [[ -L "$SECRET_FILE" ]]; then
    echo "Erreur : lien symbolique interdit." >&2
    exit 1
fi

if [[ ! -e "$SECRET_FILE" ]]; then
    openssl rand -hex 32 > "$SECRET_FILE"
fi

chmod 600 "$SECRET_FILE"

password="$(cat "$SECRET_FILE")"

if [[ ! "$password" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Erreur : format du secret invalide." >&2
    exit 1
fi

echo "Configuration du rôle applicatif..."

{
cat <<'SQL'
-- Création du rôle si nécessaire
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'ligne_jaune_app'
    ) THEN
        CREATE ROLE ligne_jaune_app LOGIN;
    END IF;
END
$$;
SQL

# Le secret est transmis par stdin, jamais en argument
# de la commande Docker.
printf \
    "ALTER ROLE ligne_jaune_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '%s';\n" \
    "$password"

cat <<'SQL'
-- Retrait des permissions générales
REVOKE ALL ON DATABASE ligne_jaune FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- Autorisations minimales
GRANT CONNECT ON DATABASE ligne_jaune
    TO ligne_jaune_app;

GRANT USAGE ON SCHEMA public
    TO ligne_jaune_app;

-- Réinitialisation des permissions applicatives
REVOKE ALL ON ALL TABLES IN SCHEMA public
    FROM ligne_jaune_app;

-- Tables métier uniquement
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    public.entities,
    public.entity_identifiers,
    public.sources,
    public.relationships,
    public.relationship_evidence
TO ligne_jaune_app;

-- Recherche de schéma maîtrisée
ALTER ROLE ligne_jaune_app
    IN DATABASE ligne_jaune
    SET search_path TO pg_catalog, public;

-- Limiter les requêtes et transactions bloquées
ALTER ROLE ligne_jaune_app
    SET statement_timeout = '15s';

ALTER ROLE ligne_jaune_app
    SET idle_in_transaction_session_timeout = '30s';
SQL

} | docker compose -f compose.dev.yaml exec -T db \
    psql \
        -X \
        -q \
        -v ON_ERROR_STOP=1 \
        --single-transaction \
        -U ligne_jaune_admin \
        -d ligne_jaune \
        -f -

unset password

echo "Rôle applicatif provisionné."
