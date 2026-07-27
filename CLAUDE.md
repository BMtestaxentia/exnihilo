# CLAUDE.md - ExNihilo

Instructions pour toute session Claude Code sur ce dépôt. À lire en premier.

## Le projet
ExNihilo est un POC de **suivi du financement d'opérations immobilières** pour AXENTIA (SA d'HLM, groupe Habitat en Région / BPCE). Public : chargés de financement (côté opérateur/emprunteur). Langue de l'interface, des commentaires et des réponses : **français**. Ne jamais utiliser de tiret cadratin ; utiliser des tirets simples.

## Architecture (à respecter absolument)
- **Application mono-fichier en JavaScript vanilla** : toute la logique est dans `app.js` (~14 000 lignes). Pas de framework, pas d'étape de build, pas de bundler.
- Trois fichiers servis en statique : `index.html` (coquille + CDN), `app.js` (logique), `styles.css` (styles).
- **Backend Supabase (Postgres)** appelé en **`fetch()` brut vers l'API PostgREST** - surtout **PAS** la librairie `supabase-js`. `SUPABASE_URL` en tête de `app.js`.
- Hébergement : **GitHub Pages**, fichiers à la racine, servis sur `https://bmtestaxentia.github.io/exnihilo/`.

## Environnement de travail (important)
- **Ni Node ni Python sur la machine.** `node --check`, `predeploy.mjs`, `smoke_test.mjs` n'existent pas / ne sont pas utilisables.
- Validation de syntaxe : vérification d'équilibre via awk. Baseline connue de `app.js` : `{}=0 ()=-8 []=0`, backticks pairs. Tout écart après édition = erreur à trouver avant commit.
- **Cache-buster manuel obligatoire** : à chaque modif de `app.js` ou `styles.css`, incrémenter `?v=N` sur les DEUX liens dans `index.html`, sinon les navigateurs servent l'ancienne version. Après déploiement, conseiller un hard reload (Ctrl+Shift+R).
- Workflow git : **commits directs sur `main` autorisés** (validé par l'utilisateur), messages concis en français, push déclenche le redéploiement GitHub Pages (~1 min).
- PowerShell disponible pour les manipulations lourdes (remplacements en masse, lecture xlsx via zip/XML) ; vérifier BOM/accents/équilibre après toute réécriture PowerShell d'un fichier.

## Structure de l'UI (état actuel)
- Topnav : Accueil / Opérations / Synthèse (`dashboard`) / Suivi / Comités / Gantt, via `switchToTab`. Boutons globaux dans `.topnav-user` : scope « mes opérations », toggle k€/€ (`MONEY_FMT`, persisté), dark mode, refresh manuel (l'auto-refresh 30 s est désactivé volontairement).
- **Vue opération = vues EN PLACE** (le système tiroir/drawer a été retiré) : bandeau unique `opsUnifiedBarHtml` (nav Vue d'ensemble / Informations / Bilan / Financements / Suivi + pastilles de tranches + Détail/Financements), strip KPI permanent, dashboard à briques (`renderOpHomeDashboard`), vue financements générée (`renderOpFinancementsDrawer`, couleurs par tranche). Routage : `switchOpsTab` + `OPS_TAB` ('home','syn','dos','bilan','suivi','tr','fin','finop') ; `openOpsDomain` est un simple routeur ; Échap revient à 'home'.
- **Édition** : onglets legacy (`opsTabsHtml`) + bandeau d'édition ; lignes de financement compactes (`fin-emain` + détail repliable).
- Moteur de tâches `computeTasks` (catégories `SUIVI_CATS`, dont 'Pilotage') partagé par l'onglet Suivi (cockpit) et l'Accueil.
- Synthèse : onglets `SYNTH_TABS`, filtres avec chips actives, vues sauvegardées (snapshot complet de l'état).

## Modèle de données (tables Supabase)
`operations`, `tranches`, `prets`, `garanties`, `subventions`, `prefinancements`, `reservataires`, `comites`, `avenants`, `aap`, `referentiels`, `tags`, `audit_log`, `comptes`, `phase_snapshots`.

- Dates : `prefinancements.date_debut/date_fin` sont des `DATE` ; toutes les autres dates sont du **TEXTE `JJ/MM/AAAA`**. Helpers : `parseDateStr` / `fmtDateStr` / `fmtDateFR`.
- Persistance : `saveOpToSupabase(op, beforeSnap)` avec diff par snapshot ; `syncEntitiesToSupabase` (tranches/prêts/garanties en PATCH/INSERT ciblés, entités simples via `syncSimpleEntity`). Toute réponse non-ok doit être contrôlée (pattern `checkRes`/`chk` : toast + throw).
- **Règle d'or anti-bug** : un champ éditable doit exister à TROIS endroits - `buildXPayload` (écriture), `mapXFromSupabase` (relecture), colonne SQL (sinon PGRST204 et tout le PATCH échoue). À chaque nouveau champ : vérifier les trois + créer un fichier `sql/*.sql` idempotent (`ADD COLUMN IF NOT EXISTS`) à faire exécuter par l'utilisateur dans Supabase.
- Journalisation : `logModification` + `flushAuditBatch`.

## Alignement SFO (référence métier)
Le modèle est aligné sur le fichier Excel SFO du groupe (analysé en session) : liste de prêts 23 colonnes, volumétrie stricte (agréé PLAI/PLUS/PLS + hors agrément LLI/RHVS/libre + surfaces SU), champs supplémentaires conservés. Fichiers SQL déjà exécutés par l'utilisateur : `sql/ajout_colonnes_tranches.sql`, `sql/ajout_colonnes_prets.sql`, `sql/alignement_sfo.sql`, `sql/ajout_colonnes_tranches_2.sql`.

Phases : nomenclature SFO **CEP > CA > CPR > CL > OS > Clôture** (`PHASES`), migration auto des anciennes valeurs via `migratePhase` (Montage->CEP, Validation CA->CA, Travaux->OS, Livraison/GPA->Clôture) + `sql/migration_phases_sfo.sql`.

Bilan : lignes de prix de revient pilotées par la table `referentiels` (ref_keys `bilan_*`), catalogue aligné SFO/LEON via `sql/referentiel_bilan_sfo.sql` ; les postes hors catalogue restent affichés (garde-fou dans `renderBilanSection` / `renderBilanOpSection`).

## Sécurité / rollback
- Snapshots de rollback `*_avant_refonte_totale.*` (app.js / styles.css / index.html) : **ne pas les supprimer**.
- Avant une refonte lourde d'un écran, créer un snapshot équivalent.
- Toute refonte UI significative : proposer une maquette (Artifact) et attendre validation avant d'implémenter.

## Style attendu
- Réponses et commits **concis**, techniques, en français, sans tiret cadratin.
- Édition chirurgicale de `app.js` (lire la zone avant d'éditer), pas de reformatage massif.
- Toujours vérifier (équilibre awk + bump `?v=`) avant de committer.
