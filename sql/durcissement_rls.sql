-- Durcissement des accès anonymes (audit du 31/07/2026).
-- Contexte : l'application est exposée sur internet ; le rôle `anon` (clé
-- publique embarquée dans le front) ne doit avoir AUCUN accès aux données.
-- L'app n'interroge jamais l'API avec la clé anon : toutes les requêtes portent
-- le jeton de session de l'utilisateur (rôle `authenticated`).
--
-- Anomalies corrigées :
--   1. Policies héritées de Supabase avec `TO public` (= anon inclus) sur aap,
--      avenants, prefinancements -> lecture ET écriture anonymes possibles.
--   2. RLS absente sur referentiel_notaires -> table entièrement ouverte.
--   3. Vue comptes_auth (e-mails des utilisateurs) lisible en anonyme.
--   4. GRANT larges donnés à anon lors de la migration.
-- Idempotent : rejouable sans risque.

-- 1. Policies « public » (anon inclus) : supprimées, les policies
--    `exn_auth_all` (TO authenticated) couvrent déjà l'application.
DROP POLICY IF EXISTS aap_all ON aap;
DROP POLICY IF EXISTS avenants_all ON avenants;
DROP POLICY IF EXISTS prefinancements_all ON prefinancements;

-- 2. Table sans RLS : activation + policy réservée aux utilisateurs connectés
ALTER TABLE referentiel_notaires ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS exn_auth_all ON referentiel_notaires;
CREATE POLICY exn_auth_all ON referentiel_notaires FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 3. Retrait de tous les droits du rôle anon (tables, vues, séquences, fonctions)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE USAGE ON SCHEMA public FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;

-- 4. Les futures tables restent ouvertes aux seuls rôles applicatifs légitimes
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO authenticated, service_role;
