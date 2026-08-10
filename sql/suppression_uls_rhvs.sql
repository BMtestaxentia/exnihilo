-- Suppression du champ "ULS / RHVS" (tranches.uls_rhvs).
-- Champ jamais utilise : vide sur la totalite des tranches au moment de la
-- suppression. L'information RHVS reste suivie par logts_rhvs / date_arrete_rhvs.
--
-- A n'executer QU'APRES le deploiement de l'application qui ne l'envoie plus
-- (v117) : tant qu'un PATCH contient uls_rhvs, retirer la colonne ferait
-- echouer la sauvegarde entiere en PGRST204.
--
-- Idempotent : rejouable sans effet de bord.

-- Garde-fou : on refuse de supprimer une colonne qui contiendrait des donnees.
DO $$
DECLARE n bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_name = 'tranches' AND column_name = 'uls_rhvs') THEN
    EXECUTE 'SELECT count(*) FROM tranches WHERE nullif(uls_rhvs, '''') IS NOT NULL' INTO n;
    IF n > 0 THEN
      RAISE EXCEPTION 'Abandon : % tranche(s) ont une valeur ULS / RHVS, suppression annulee', n;
    END IF;
  END IF;
END $$;

ALTER TABLE tranches DROP COLUMN IF EXISTS uls_rhvs;

DELETE FROM referentiels WHERE ref_key = 'uls_rhvs';

-- PostgREST met son schema en cache : sans rechargement il continuerait
-- d'annoncer une colonne qui n'existe plus.
NOTIFY pgrst, 'reload schema';
