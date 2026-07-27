-- Catalogue des postes de bilan aligne sur l'outil SFO (structure LEON).
-- A exécuter dans le SQL Editor de Supabase. Idempotent :
--   1) insère les postes manquants ; 2) réactive et réordonne les postes du catalogue.
-- Les postes ajoutés localement (hors catalogue) ne sont PAS touchés.

WITH catalogue (ref_key, ref_label, item_value, item_order) AS (
  VALUES
    -- I. Charge foncière
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Terrain', 1),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'VRD', 2),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Droits et taxes', 3),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Frais d''acquisition', 4),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Taxe d''aménagement', 5),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Autres charge foncière', 6),
    -- II. Bâtiment
    ('bilan_batiment', 'Lignes Bâtiment', 'Travaux de construction', 1),
    ('bilan_batiment', 'Lignes Bâtiment', 'Aléas', 2),
    ('bilan_batiment', 'Lignes Bâtiment', 'Autres bâtiment', 3),
    -- III. Honoraires
    ('bilan_honoraires', 'Lignes Honoraires', 'AMO', 1),
    ('bilan_honoraires', 'Lignes Honoraires', 'Architecte', 2),
    ('bilan_honoraires', 'Lignes Honoraires', 'Assurances', 3),
    ('bilan_honoraires', 'Lignes Honoraires', 'Géomètre', 4),
    ('bilan_honoraires', 'Lignes Honoraires', 'OPC / SPS / CT', 5),
    ('bilan_honoraires', 'Lignes Honoraires', 'Bureau d''étude', 6),
    ('bilan_honoraires', 'Lignes Honoraires', 'Études & qualité', 7),
    ('bilan_honoraires', 'Lignes Honoraires', 'Conduite d''opération', 8),
    -- IV. Frais divers
    ('bilan_frais_divers', 'Lignes Frais Divers', 'Actualisation / Révision', 1),
    ('bilan_frais_divers', 'Lignes Frais Divers', 'Autres frais divers', 2),
    -- V. Frais financiers
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'Frais financiers', 1),
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'Intérêts de préfinancement', 2),
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'Commissions', 3)
)
INSERT INTO referentiels (ref_key, ref_label, item_value, item_order, is_active)
SELECT c.ref_key, c.ref_label, c.item_value, c.item_order, true
FROM catalogue c
WHERE NOT EXISTS (
  SELECT 1 FROM referentiels r
  WHERE r.ref_key = c.ref_key AND r.item_value = c.item_value
);

-- Réactive et remet dans l'ordre SFO les postes du catalogue déjà présents
WITH catalogue (ref_key, ref_label, item_value, item_order) AS (
  VALUES
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Terrain', 1),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'VRD', 2),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Droits et taxes', 3),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Frais d''acquisition', 4),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Taxe d''aménagement', 5),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'Autres charge foncière', 6),
    ('bilan_batiment', 'Lignes Bâtiment', 'Travaux de construction', 1),
    ('bilan_batiment', 'Lignes Bâtiment', 'Aléas', 2),
    ('bilan_batiment', 'Lignes Bâtiment', 'Autres bâtiment', 3),
    ('bilan_honoraires', 'Lignes Honoraires', 'AMO', 1),
    ('bilan_honoraires', 'Lignes Honoraires', 'Architecte', 2),
    ('bilan_honoraires', 'Lignes Honoraires', 'Assurances', 3),
    ('bilan_honoraires', 'Lignes Honoraires', 'Géomètre', 4),
    ('bilan_honoraires', 'Lignes Honoraires', 'OPC / SPS / CT', 5),
    ('bilan_honoraires', 'Lignes Honoraires', 'Bureau d''étude', 6),
    ('bilan_honoraires', 'Lignes Honoraires', 'Études & qualité', 7),
    ('bilan_honoraires', 'Lignes Honoraires', 'Conduite d''opération', 8),
    ('bilan_frais_divers', 'Lignes Frais Divers', 'Actualisation / Révision', 1),
    ('bilan_frais_divers', 'Lignes Frais Divers', 'Autres frais divers', 2),
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'Frais financiers', 1),
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'Intérêts de préfinancement', 2),
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'Commissions', 3)
)
UPDATE referentiels r
SET item_order = c.item_order, is_active = true
FROM catalogue c
WHERE r.ref_key = c.ref_key AND r.item_value = c.item_value;
