-- Hors agrément : arrêté d'autorisation ARS (places médico-sociales).
-- Les 8 lignes "HORS AGRÉMENT" de l'Excel SFO sont désormais toutes suivies :
--   places ARS + date arrêté ARS      <- ce fichier
--   places RHVS + date arrêté RHVS    <- logts_rhvs / date_arrete_rhvs (déjà en place)
--   logements LLI + date décl. LLI    <- logts_lli / date_decl_lli    (déjà en place)
--   logements LIBRE / locaux LIBRE    <- logts_libre / locaux_libre   (déjà en place)
--
-- Idempotent : rejouable sans effet de bord.

ALTER TABLE tranches ADD COLUMN IF NOT EXISTS places_ars      bigint;
ALTER TABLE tranches ADD COLUMN IF NOT EXISTS date_arrete_ars text;   -- JJ/MM/AAAA

COMMENT ON COLUMN tranches.places_ars IS
  'Nombre de places de l''arrêté d''autorisation ARS. Hors agrément : non compté dans le total logements (les places sont déjà couvertes par l''agrément PLS).';
COMMENT ON COLUMN tranches.date_arrete_ars IS
  'Date de l''arrêté d''autorisation ARS, texte JJ/MM/AAAA.';

-- Reprise des valeurs stockées faute de colonne dans les notes de tranche,
-- sous la forme exacte "Places ARS : 40 (arrete du 11/08/2020)".
-- La note n'est vidée que si elle ne contient QUE cette information.
UPDATE tranches
   SET places_ars      = NULLIF(substring(notes from 'Places ARS : ([0-9]+)'), '')::bigint,
       date_arrete_ars = substring(notes from 'arrete du ([0-9]{2}/[0-9]{2}/[0-9]{4})'),
       notes           = ''
 WHERE notes ~ '^Places ARS : [0-9]+( \(arrete du [0-9]{2}/[0-9]{2}/[0-9]{4}\))?$';

-- PostgREST met son schéma en cache : sans ce rechargement, tout PATCH portant
-- les nouvelles colonnes échouerait en PGRST204 et ferait échouer la sauvegarde entière.
NOTIFY pgrst, 'reload schema';
