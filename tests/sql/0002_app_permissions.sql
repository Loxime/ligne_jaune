-- Ligne Jaune : vérification des privilèges

DO $$
DECLARE
    app_role RECORD;
    table_name TEXT;
    permission TEXT;
BEGIN
    SELECT *
    INTO app_role
    FROM pg_roles
    WHERE rolname = 'ligne_jaune_app';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rôle applicatif absent';
    END IF;

    -- Aucun privilège administratif
    IF app_role.rolsuper
       OR app_role.rolcreatedb
       OR app_role.rolcreaterole
       OR app_role.rolreplication
       OR app_role.rolbypassrls
    THEN
        RAISE EXCEPTION
            'Privilèges administratifs détectés';
    END IF;

    -- Connexion autorisée
    IF NOT has_database_privilege(
        'ligne_jaune_app',
        current_database(),
        'CONNECT'
    ) THEN
        RAISE EXCEPTION 'Connexion interdite';
    END IF;

    -- Création interdite
    IF has_database_privilege(
        'ligne_jaune_app',
        current_database(),
        'CREATE'
    ) OR has_schema_privilege(
        'ligne_jaune_app',
        'public',
        'CREATE'
    ) THEN
        RAISE EXCEPTION
            'Création de schéma ou objet autorisée';
    END IF;

    -- Droit d'utilisation du schéma
    IF NOT has_schema_privilege(
        'ligne_jaune_app',
        'public',
        'USAGE'
    ) THEN
        RAISE EXCEPTION
            'Accès au schéma interdit';
    END IF;

    -- Permissions sur les tables métier
    FOREACH table_name IN ARRAY ARRAY[
        'entities',
        'entity_identifiers',
        'sources',
        'relationships',
        'relationship_evidence'
    ]
    LOOP
        FOREACH permission IN ARRAY ARRAY[
            'SELECT',
            'INSERT',
            'UPDATE',
            'DELETE'
        ]
        LOOP
            IF NOT has_table_privilege(
                'ligne_jaune_app',
                'public.' || table_name,
                permission
            ) THEN
                RAISE EXCEPTION
                    'Permission % manquante sur %',
                    permission,
                    table_name;
            END IF;
        END LOOP;

        -- Privilèges supplémentaires interdits
        FOREACH permission IN ARRAY ARRAY[
            'TRUNCATE',
            'REFERENCES',
            'TRIGGER'
        ]
        LOOP
            IF has_table_privilege(
                'ligne_jaune_app',
                'public.' || table_name,
                permission
            ) THEN
                RAISE EXCEPTION
                    'Permission excessive : % sur %',
                    permission,
                    table_name;
            END IF;
        END LOOP;
    END LOOP;

    -- Le registre des migrations reste réservé
    -- à l'administrateur.
    FOREACH permission IN ARRAY ARRAY[
        'SELECT',
        'INSERT',
        'UPDATE',
        'DELETE'
    ]
    LOOP
        IF has_table_privilege(
            'ligne_jaune_app',
            'public.schema_migrations',
            permission
        ) THEN
            RAISE EXCEPTION
                'Accès interdit au registre : %',
                permission;
        END IF;
    END LOOP;

    -- L'application ne doit pas pouvoir
    -- devenir administrateur.
    IF pg_has_role(
        'ligne_jaune_app',
        'ligne_jaune_admin',
        'MEMBER'
    ) THEN
        RAISE EXCEPTION
            'Héritage du rôle administrateur détecté';
    END IF;

    RAISE NOTICE
        'OK : séparation des privilèges SQL';
END
$$;
