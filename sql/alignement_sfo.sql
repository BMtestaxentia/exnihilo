-- Alignement du modèle sur l'outil Excel SFO (feuille TEMPLATE)
-- A exécuter dans le SQL Editor de Supabase AVANT de sauvegarder une opération :
-- sans ces colonnes, les PATCH échouent (PGRST204). Idempotent (IF NOT EXISTS).

-- OPÉRATIONS : localisation + calendrier
ALTER TABLE operations ADD COLUMN IF NOT EXISTS qpv text;                -- QPV (Oui/Non) - saisi dans l'UI mais jamais persisté jusqu'ici
ALTER TABLE operations ADD COLUMN IF NOT EXISTS action_coeur_ville text; -- Action cœur de ville (Oui/Non)
ALTER TABLE operations ADD COLUMN IF NOT EXISTS pvd text;                -- PVD - Petites villes de demain (Oui/Non)
ALTER TABLE operations ADD COLUMN IF NOT EXISTS date_revue_op text;      -- Date dernière revue d'opération (JJ/MM/AAAA)

-- TRANCHES : identification SFO
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS nom_interne text;          -- Nom interne tranche
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS gestionnaire_statut text;  -- Gestionnaire statut (SAS, Association…)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS capacite_has text;         -- Capacité HAS sur capacité totale

-- TRANCHES : section « Hors agrément »
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS logts_lli bigint;          -- Logements LLI (nombre)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS date_decl_lli text;        -- Date déclaration LLI
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS logts_rhvs bigint;         -- Logements RHVS (nombre)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS date_arrete_rhvs text;     -- Date arrêté préfectoral agrément RHVS
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS logts_libre bigint;        -- Logements LIBRE (nombre)
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS locaux_libre bigint;       -- Locaux LIBRE (nombre)

-- GARANTIES : lien convention
ALTER TABLE garanties ADD COLUMN IF NOT EXISTS lien_sp_conv text;        -- Lien SharePoint convention

-- SUBVENTIONS : montant validé CA
ALTER TABLE subventions ADD COLUMN IF NOT EXISTS montant_valide_ca bigint;
