# Ligne Jaune

Plateforme privée de recherche, d'analyse documentaire
et de cartographie des relations économiques et
institutionnelles.

## Objectifs

- Identifier des personnes et des organisations.
- Cartographier leurs relations documentées.
- Conserver les sources et les preuves associées.
- Intégrer les recherches bibliographiques personnelles.
- Historiser les informations et leurs modifications.
- Exploiter des données publiques officielles.
- Étendre progressivement la couverture internationale.

## Principes

1. Toute relation doit être sourcée.
2. Une hypothèse n'est pas un fait établi.
3. Les sources originales doivent être traçables.
4. La collecte respecte les droits et licences applicables.
5. Les informations personnelles sont minimisées.
6. Aucun service métier n'est directement exposé à Internet.
7. Le stockage documentaire distant est chiffré.

## Architecture prévue

- Frontend : Nuxt
- Backend : Symfony
- Base principale : PostgreSQL
- Ingestion documentaire : Python
- Stockage documentaire : Google Drive via rclone crypt
- Déploiement : Docker Compose

## Environnements

- Développement : VM Ubuntu locale
- Production : VPS Ubuntu existant

La configuration de production sera isolée de celle du
développement.

## État

Projet en cours d'initialisation.
