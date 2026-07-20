# CLAUDE.md — ExNihilo

Instructions pour toute session Claude Code sur ce dépôt. À lire en premier.

## Le projet
ExNihilo est un POC de **suivi du financement d'opérations immobilières** pour AXENTIA (SA d'HLM, groupe Habitat en Région / BPCE). Public : chargés de financement (côté opérateur/emprunteur). Langue de l'interface et des commentaires : **français**.

## Architecture (à respecter absolument)
- **Application mono-fichier en JavaScript vanilla** : toute la logique est dans `app.js` (~13 000 lignes). Pas de framework, pas d'étape de build, pas de bundler.
- Trois fichiers servis en statique : `index.html` (coquille + CDN), `app.js` (logique), `styles.css` (styles).
- **Backend Supabase (Postgres)** appelé en **`fetch()` brut vers l'API PostgREST** — surtout **PAS** la librairie `supabase-js`. La constante `SUPABASE_URL` est en tête de `app.js`.
- Hébergement : **GitHub Pages**, fichiers à la racine du repo, servis sur `https://bmtestaxentia.github.io/exnihilo/`.

## Workflow de modification (obligatoire à chaque changement)
1. **Lire la zone concernée** de `app.js` avant d'éditer (le fichier est énorme : édition chirurgicale, pas de réécriture globale).
2. Valider la syntaxe : `node --check app.js`.
3. Lancer l'outillage de pré-déploiement : `node predeploy.mjs index.html`.
   - Il **incrémente le cache-buster** `?v=N` sur `app.js` et `styles.css` dans `index.html` (indispensable, sinon les navigateurs servent l'ancienne version).
   - Il exécute `smoke_test.mjs` (vérifie que les fonctions critiques existent toujours).
4. **Ne jamais pousser si `predeploy` échoue.**
5. Après `git push`, GitHub Pages redéploie automatiquement (~1 min).

## Sécurité / rollback
- **Travailler sur une branche**, pas directement sur `main`. On ne fusionne dans `main` que ce qui est testé et validé visuellement par l'utilisateur.
- Des snapshots de rollback existent sous la forme `*_avant_refonte_totale.*` (app.js / styles.css / index.html). Ne pas les supprimer.
- Avant une refonte lourde d'un écran, créer un snapshot équivalent.

## Modèle de données (tables Supabase)
`operations`, `tranches`, `prets`, `garanties`, `subventions`, `prefinancements`, `reservataires`, `comites`, `avenants`, `aap`, `referentiels`, `tags`, `audit_log`, `comptes`, `phase_snapshots`.

Conventions de dates : `prefinancements.date_debut` / `date_fin` sont de vraies colonnes `DATE` ; les autres dates d'opération sont stockées en **TEXTE au format `JJ/MM/AAAA`**. Utiliser les helpers `parseDateStr` / `fmtDateStr` / `fmtDateFR`.

Persistance : `saveOpToSupabase` (avec garde anti auto-refresh via `_pendingWrites`), `syncEntitiesToSupabase` (prêts/garanties/tranches en PATCH/INSERT via `buildPretPayload` / `buildTranchePayload` ; subventions/réservataires/préfis/avenants/comités en delete-all + reinsert). Journalisation via `logModification` + `flushAuditBatch`.

## État connu / pièges
- **Bug prioritaire** : des champs de tranche saisissables dans l'UI ne sont **pas** inclus dans `buildTranchePayload`, donc **non persistés** (ex. `famille_agrement`, `uls_rhvs`, `date_butoir_depot`, `date_depot_agr`, `plai_adapte`, `n_leon`, `date_ref`). À corriger en priorité.
- La fonctionnalité « workflow de validation de documents » a été **entièrement retirée** ; les comités (avec PV joint) sont conservés.
- L'espace Opérations est organisé en **onglets** (Synthèse / Dossier / Bilan / Tranches / Financements / Comités & suivi) : en-tête permanent + vues focalisées, grilles CSS calibrées pour ~1920×950.
- Référence métier : voir `MATCH_ExNihilo_vs_Excel_SFO.md` pour la correspondance entre le modèle POC et le fichier Excel SFO de référence (champs à ajouter, écart de nomenclature de phases CEP/CA/CPR/CL/OS/Clôture, etc.).

## Style attendu
- Réponses et commits **concis**, techniques, en français.
- Édition ciblée, pas de reformatage massif de fichiers.
- Toujours tester (`node --check` + `predeploy`) avant de proposer un commit.
