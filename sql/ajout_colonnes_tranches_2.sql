-- Correction persistance tranches (2e vague du bug "champ saisi mais jamais sauvegardé")
-- A exécuter dans le SQL Editor de Supabase AVANT de sauvegarder une opération.
-- Idempotent (IF NOT EXISTS) : sans risque si certaines colonnes existent déjà.

-- Convention de location (probablement déjà créées, on sécurise)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS conv_loc_signee boolean;        -- Convention signée (Oui/Non)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS conv_loc_montant_loyer numeric; -- Montant du loyer
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS conv_loc_date_valeur text;      -- Date de valeur (JJ/MM/AAAA)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS conv_loc_grille text;           -- Grille / référence

-- Loyer / redevance gestionnaire
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS type_redevance text;            -- Type de redevance
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS montant_redevance numeric;      -- Montant de la redevance
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS date_accord_redev text;         -- Date accord redevance (JJ/MM/AAAA)

-- Détail logements (notes libres de la section volumétrie)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS detail_logements text;
