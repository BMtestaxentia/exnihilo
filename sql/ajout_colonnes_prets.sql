-- Nouvelles colonnes de prêt (alignement sur le référentiel SFO)
-- A exécuter dans le SQL Editor de Supabase AVANT de tester la sauvegarde des prêts :
-- sans ces colonnes, le PATCH d'un prêt échoue (PGRST204) et rien ne s'enregistre.
-- Idempotent : rejouable sans risque grâce à IF NOT EXISTS.

ALTER TABLE prets ADD COLUMN IF NOT EXISTS montant_valide_ca bigint;   -- Montant validé CA
ALTER TABLE prets ADD COLUMN IF NOT EXISTS profil_amort text;          -- Profil amort Caisse d'épargne
ALTER TABLE prets ADD COLUMN IF NOT EXISTS avenant_duree_prefi text;   -- Avenant durée préfi
