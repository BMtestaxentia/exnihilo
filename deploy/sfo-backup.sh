#!/usr/bin/env bash
# Sauvegarde quotidienne de la base SFO.
#
# Corrige le defaut de la commande d'origine ("pg_dump | gzip > fichier") :
# la redirection creait le fichier meme quand pg_dump echouait, et le "&&"
# ne testait que gzip. Une archive vide pouvait donc passer pour une sauvegarde.
#
# Ici : ecriture dans un fichier temporaire, verification de l'archive, et
# publication seulement si elle est valide. Tout echec est signale et le script
# sort en erreur.
#
# Installation : voir deploy/INSTALL.md, section Exploitation.
set -euo pipefail

CONF=/opt/sfo/backup.env
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

DB=${SFO_DB:-exnihilo}
CT=${SFO_CONTAINER:-sfo-db}
DEST=${SFO_BACKUP_DIR:-/var/backups}
ARCHIVE=${SFO_ARCHIVE_DIR:-/var/backups/mensuelles}
KEEP_DAYS=${SFO_KEEP_DAYS:-30}
KEEP_MONTHS=${SFO_KEEP_MONTHS:-12}
MIN_SIZE=${SFO_MIN_SIZE:-10240}          # octets ; en dessous, l'archive est suspecte
STATUS=${SFO_STATUS_FILE:-/var/lib/sfo/backup.status}
LOG=${SFO_LOG:-/var/log/sfo-backup.log}
ALERT_URL=${SFO_ALERT_URL:-}             # webhook Teams optionnel
OFFSITE_CMD=${SFO_OFFSITE_CMD:-}         # copie hors VM optionnelle ; "$1" = chemin de l'archive

JOUR=$(date -I)
CIBLE="$DEST/exnihilo_$JOUR.sql.gz"
TMP="$DEST/.exnihilo_$JOUR.partiel.gz"

mkdir -p "$DEST" "$ARCHIVE" "$(dirname "$STATUS")" "$(dirname "$LOG")"

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

fin_erreur() {
  local msg="$1"
  log "ERREUR : $msg"
  printf 'ERREUR %s %s\n' "$(date -Is)" "$msg" > "$STATUS"
  logger -p daemon.err -t sfo-backup "$msg" 2>/dev/null || true
  if [ -n "$ALERT_URL" ]; then
    curl -s -m 10 -H 'Content-Type: application/json' \
      -d "{\"text\":\"[SFO] Sauvegarde en echec sur $(hostname) : $msg\"}" \
      "$ALERT_URL" >/dev/null 2>&1 || true
  fi
  rm -f "$TMP"
  exit 1
}
trap 'fin_erreur "interruption inattendue ligne $LINENO"' ERR

log "--- debut de sauvegarde ($DB) ---"

# 1. Le conteneur doit tourner, sinon on sait immediatement pourquoi ca echoue.
[ "$(docker inspect -f '{{.State.Running}}' "$CT" 2>/dev/null)" = "true" ] \
  || fin_erreur "le conteneur $CT ne tourne pas"

# 2. Dump. pipefail fait remonter un echec de pg_dump malgre le pipe vers gzip.
docker exec "$CT" pg_dump -U postgres "$DB" 2>>"$LOG" | gzip > "$TMP" \
  || fin_erreur "pg_dump a echoue"

# 3. Verifications avant publication.
TAILLE=$(stat -c %s "$TMP" 2>/dev/null || echo 0)
[ "$TAILLE" -ge "$MIN_SIZE" ] || fin_erreur "archive trop petite ($TAILLE octets, seuil $MIN_SIZE)"
gzip -t "$TMP" 2>/dev/null || fin_erreur "archive gzip corrompue"
# grep -c (et non -q) : -q sort des la premiere correspondance, zcat prend un
# SIGPIPE et, avec pipefail, le pipeline echouerait alors que le motif est present.
[ "$(zcat "$TMP" | grep -cE '^(COPY|CREATE TABLE) public\.operations' || true)" -gt 0 ] \
  || fin_erreur "la table operations est absente du dump"

# 4. Publication atomique + empreinte, pour pouvoir prouver l'integrite plus tard.
mv -f "$TMP" "$CIBLE"
sha256sum "$CIBLE" | awk '{print $1}' > "$CIBLE.sha256"

# 5. Archive mensuelle : on garde le 1er du mois plus longtemps que 30 jours.
if [ "$(date +%d)" = "01" ]; then
  cp -f "$CIBLE" "$ARCHIVE/" && cp -f "$CIBLE.sha256" "$ARCHIVE/"
  log "archive mensuelle conservee"
fi

# 6. Copie hors VM. Sans elle, une perte de VM emporte la base ET ses sauvegardes.
if [ -n "$OFFSITE_CMD" ]; then
  if ( set -- "$CIBLE"; eval "$OFFSITE_CMD" ) >>"$LOG" 2>&1; then
    log "copie hors VM effectuee"
  else
    fin_erreur "la copie hors VM a echoue (l'archive locale, elle, est valide)"
  fi
else
  log "ATTENTION : aucune copie hors VM configuree (SFO_OFFSITE_CMD vide)"
fi

# 7. Retention.
find "$DEST" -maxdepth 1 -name 'exnihilo_*.sql.gz*' -mtime "+$KEEP_DAYS" -delete
find "$ARCHIVE" -maxdepth 1 -name 'exnihilo_*.sql.gz*' -mtime "+$((KEEP_MONTHS * 31))" -delete

NB=$(find "$DEST" -maxdepth 1 -name 'exnihilo_*.sql.gz' | wc -l)
log "OK $CIBLE ($(numfmt --to=iec "$TAILLE" 2>/dev/null || echo "$TAILLE o")) ; $NB archives quotidiennes"
printf 'OK %s %s %s\n' "$(date -Is)" "$CIBLE" "$TAILLE" > "$STATUS"
trap - ERR
exit 0
