-- Migration de la nomenclature de phases vers le referentiel SFO :
-- CEP > CA > CPR > CL > OS > Clôture
-- Correspondance depuis l'ancienne nomenclature :
--   Montage -> CEP | Validation CA -> CA | Travaux -> OS | Livraison -> Clôture | GPA -> Clôture
-- A exécuter dans le SQL Editor de Supabase. Idempotent (ne touche que les anciennes valeurs).
-- Note : l'app migre aussi ces valeurs à la volée au chargement, ce script aligne la base une fois pour toutes.

UPDATE operations SET phase_actuelle = CASE phase_actuelle
    WHEN 'Montage'       THEN 'CEP'
    WHEN 'Validation CA' THEN 'CA'
    WHEN 'Travaux'       THEN 'OS'
    WHEN 'Livraison'     THEN 'Clôture'
    WHEN 'GPA'           THEN 'Clôture'
  END
WHERE phase_actuelle IN ('Montage', 'Validation CA', 'Travaux', 'Livraison', 'GPA');

UPDATE phase_snapshots SET phase = CASE phase
    WHEN 'Montage'       THEN 'CEP'
    WHEN 'Validation CA' THEN 'CA'
    WHEN 'Travaux'       THEN 'OS'
    WHEN 'Livraison'     THEN 'Clôture'
    WHEN 'GPA'           THEN 'Clôture'
  END
WHERE phase IN ('Montage', 'Validation CA', 'Travaux', 'Livraison', 'GPA');
