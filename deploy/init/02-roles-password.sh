#!/bin/sh
# Applique le mot de passe du rôle authenticator depuis la variable d'environnement
# AUTHENTICATOR_PASSWORD (définie dans .env). Exécuté au premier démarrage du
# conteneur Postgres, juste après 01-roles.sql.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  ALTER ROLE authenticator WITH PASSWORD '$AUTHENTICATOR_PASSWORD';
EOSQL
