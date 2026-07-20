-- Ajout des colonnes de tranche manquantes (persistées via buildTranchePayload)
-- Dates stockées en TEXTE au format JJ/MM/AAAA (cf. CLAUDE.md), plai_adapte en entier.
-- Idempotent : rejouable sans risque grâce à IF NOT EXISTS.

ALTER TABLE tranches ADD COLUMN IF NOT EXISTS famille_agrement text;
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS uls_rhvs text;
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS n_leon text;
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS date_butoir_depot text;
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS date_depot_agr text;
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS date_ref text;
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS plai_adapte bigint;
