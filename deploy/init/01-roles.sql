-- Rôles attendus par PostgREST / GoTrue (équivalents des rôles Supabase).
-- Exécuté automatiquement au PREMIER démarrage du conteneur Postgres
-- (docker-entrypoint-initdb.d). Le mot de passe authenticator est injecté
-- depuis l'environnement par 02-roles-password.sh si présent, sinon le
-- définir manuellement (cf. INSTALL.md).

-- Rôles applicatifs (sans login) : ceux que les policies RLS référencent
CREATE ROLE anon NOLOGIN NOINHERIT;
CREATE ROLE authenticated NOLOGIN NOINHERIT;
CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;

-- Rôle de connexion de PostgREST : il "devient" anon/authenticated selon le JWT
CREATE ROLE authenticator LOGIN NOINHERIT;
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;

-- Schéma auth pour GoTrue (il y crée ses tables tout seul au démarrage)
CREATE SCHEMA IF NOT EXISTS auth;

-- Droits par défaut sur le schéma public (les GRANT précis arrivent avec le dump)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated, service_role;
