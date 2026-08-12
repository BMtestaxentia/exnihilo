-- Nomenclature du prix de revient, alignee sur la maquette LEON REWORK
-- (onglet PDR) : 5 chapitres, 46 postes.
--
-- A executer dans le SQL Editor de Supabase. Idempotent : rejouable sans effet
-- de bord.
--
-- Deux regles heritees de la maquette, a ne pas « corriger » :
--   1) la numerotation comporte des trous (17 a 19 et 28 sont absents) : elle
--      est reservee par chapitre, ce n'est pas une sequence, et la conserver
--      telle quelle garde la saisie comparable a LEON et au PMT ;
--   2) `item_code` est STABLE et independant du numero comme du rang
--      d'affichage. C'est lui la cle de stockage du montant dans les colonnes
--      JSONB des tranches, jamais le libelle - renommer un poste ne doit
--      jamais deplacer d'argent.
--
-- L'application n'a PAS besoin de ce script pour fonctionner : tant qu'aucun
-- poste ne porte de code, elle utilise la nomenclature embarquee dans app.js
-- (constante NOMENCLATURE_PDR), identique a celle-ci. Ce script fait passer la
-- reference du code a la donnee, et rend la nomenclature modifiable sans
-- deploiement.

-- 1) Les deux colonnes qui portent l'identite d'un poste
ALTER TABLE referentiels ADD COLUMN IF NOT EXISTS item_code text;
ALTER TABLE referentiels ADD COLUMN IF NOT EXISTS item_numero integer;

-- Un code est unique DANS son referentiel (rien n'interdit le meme suffixe
-- ailleurs), et l'index ignore les lignes sans code.
CREATE UNIQUE INDEX IF NOT EXISTS referentiels_refkey_itemcode_uidx
  ON referentiels (ref_key, item_code)
  WHERE item_code IS NOT NULL;

-- 2) Le catalogue LEON
WITH catalogue (ref_key, ref_label, item_code, item_numero, item_value, item_order) AS (
  VALUES
    -- I. Charge fonciere
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_acquisition',          1,  'Acquisition / Terrain',      1),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_sondages',             2,  'Sondages / Études de sols',  2),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_demolition',           3,  'Démolition',                 3),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_vrd',                  4,  'Travaux VRD',                4),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_vrd_actualisation',    5,  'Actualisation VRD',          5),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_vrd_revision',         6,  'Révision VRD',               6),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_branchements',         7,  'Branchements',               7),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_taxe_assainissement',  8,  'Taxe assainissement',        8),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_notaire',              9,  'Frais de notaire',           9),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_commission_achat',     10, 'Commission achat',           10),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_taxes_amenagement',    11, 'Taxes aménagement & VSD',    11),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_fondations_speciales', 12, 'Fondations spéciales',       12),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_desamiantage',         13, 'Désamiantage',               13),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_divers_1',             14, 'Divers foncier 1',           14),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_divers_2',             15, 'Divers foncier 2',           15),
    ('bilan_charge_fonciere', 'Lignes Charge Foncière', 'cf_divers_3',             16, 'Divers foncier 3',           16),
    -- II. Batiment (la numerotation reprend a 20 : 17 a 19 sont reserves)
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_travaux',       20, 'Travaux de construction', 1),
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_actualisation', 21, 'Actual. bâtiment',        2),
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_revision',      22, 'Révision bâtiment',       3),
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_aleas',         23, 'Aléas',                   4),
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_divers_1',      24, 'Divers bât. 1',           5),
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_divers_2',      25, 'Divers bât. 2',           6),
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_divers_3',      26, 'Divers bât. 3',           7),
    ('bilan_batiment', 'Lignes Bâtiment', 'bat_divers_4',      27, 'Divers bât. 4',           8),
    -- III. Honoraires (reprise a 29 : 28 est reserve)
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_vrd',                     29, 'Honoraires VRD',          1),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_architecte',              30, 'Architecte',              2),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_bureau_etudes',           31, 'Bureau d''études',        3),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_amo',                     32, 'AMO',                     4),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_geometre',                33, 'Géomètre',                5),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_opc',                     34, 'OPC / Pilotage',          6),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_controleur',              35, 'Contrôleur technique',    7),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_assurances',              36, 'Assurances (DO/TRC)',     8),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_sps',                     37, 'SPS / Coord. sécurité',   9),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_labellisation',           38, 'Labellisation / Certif.', 10),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_conduite_operation',      39, 'Conduite d''opération',   11),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_dir_investissement',      40, 'Dir. d''investissement',  12),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_etudes',                  41, 'Études',                  13),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_faisabilite',             42, 'Étude de faisabilité',    14),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_interets_immobilisables', 43, 'Intérêts immobilisables', 15),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_divers_1',                44, 'Divers hon. 1',           16),
    ('bilan_honoraires', 'Lignes Honoraires', 'hon_divers_2',                45, 'Divers hon. 2',           17),
    -- IV. Frais divers
    ('bilan_frais_divers', 'Lignes Frais Divers', 'fd_actualisation_hon', 46, 'Actual./Rév. hon.', 1),
    ('bilan_frais_divers', 'Lignes Frais Divers', 'fd_divers_1',          47, 'Divers frais 1',    2),
    ('bilan_frais_divers', 'Lignes Frais Divers', 'fd_divers_2',          48, 'Divers frais 2',    3),
    -- V. Frais financiers
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'ff_interets_prefi', 49, 'Intérêts préfin.',  1),
    ('bilan_frais_financiers', 'Lignes Frais Financiers', 'ff_divers',         50, 'Frais fin. divers', 2)
),
-- 2a) Les postes absents sont crees
inserts AS (
  INSERT INTO referentiels (ref_key, ref_label, item_code, item_numero, item_value, item_order, is_active)
  SELECT c.ref_key, c.ref_label, c.item_code, c.item_numero, c.item_value, c.item_order, true
  FROM catalogue c
  WHERE NOT EXISTS (
    SELECT 1 FROM referentiels r WHERE r.ref_key = c.ref_key AND r.item_code = c.item_code
  )
  RETURNING 1
)
-- 2b) Les postes deja presents sont remis a jour et reactives.
-- Le libelle est reecrit : c'est le CODE qui fait l'identite, le libelle n'est
-- que son affichage.
UPDATE referentiels r
SET item_numero = c.item_numero,
    item_value  = c.item_value,
    item_order  = c.item_order,
    ref_label   = c.ref_label,
    is_active   = true
FROM catalogue c
WHERE r.ref_key = c.ref_key AND r.item_code = c.item_code;

-- 3) Les anciens postes (catalogue SFO reduit, indexe par libelle) sont
-- DESACTIVES, pas supprimes : ils gardent une trace de ce qui existait, et un
-- simple is_active = true les ramenerait. Aucun montant n'y est attache - les
-- cinq colonnes JSONB des tranches etaient vides au moment de la bascule.
UPDATE referentiels
SET is_active = false
WHERE ref_key LIKE 'bilan\_%' AND item_code IS NULL;

-- 4) Controle : 46 postes actifs, repartis 16 / 8 / 17 / 3 / 2
SELECT ref_key, count(*) AS postes_actifs
FROM referentiels
WHERE ref_key LIKE 'bilan\_%' AND is_active AND item_code IS NOT NULL
GROUP BY ref_key
ORDER BY ref_key;
