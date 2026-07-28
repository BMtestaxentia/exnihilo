-- Abandon du stockage de documents dans les comités (décision du 30/07/2026) :
-- les PV vivent sur SharePoint (champ lien_sharepoint conservé), plus jamais
-- en base64 dans la base. Ce script supprime les colonnes et leur contenu.
-- ⚠ DESTRUCTIF pour les PDF déjà stockés : les récupérer avant si besoin.
-- Idempotent (IF EXISTS) - à exécuter dans le SQL Editor de Supabase.

ALTER TABLE comites DROP COLUMN IF EXISTS doc_name;
ALTER TABLE comites DROP COLUMN IF EXISTS doc_size;
ALTER TABLE comites DROP COLUMN IF EXISTS doc_data_url;
