#!/usr/bin/env bash
# Test de restauration automatique (hebdomadaire).
#
# Restaure la derniere sauvegarde dans une base jetable, controle qu'elle
# contient bien des donnees coherentes, puis supprime la base de test.
# Ne touche jamais a la base de production.
#
# Objectif : pouvoir affirmer que la restauration fonctionne a une date donnee,
# preuve a l'appui, au lieu de le supposer.
set -euo pipefail

CONF=/opt/sfo/backup.env
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

CT=${SFO_CONTAINER:-sfo-db}
DEST=${SFO_BACKUP_DIR:-/var/backups}
LOG=${SFO_LOG:-/var/log/sfo-backup.log}
STATUS=${SFO_RESTORE_STATUS_FILE:-/var/lib/sfo/restore-test.status}
ALERT_URL=${SFO_ALERT_URL:-}
TESTDB=exnihilo_test_restauration
MIN_OPS=${SFO_MIN_OPERATIONS:-50}        # seuil de vraisemblance metier

mkdir -p "$(dirname "$STATUS")" "$(dirname "$LOG")"
log() { printf '%s  [test-restauration] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

nettoyer() { docker exec -i "$CT" psql -U postgres -c "DROP DATABASE IF EXISTS $TESTDB;" >/dev/null 2>&1 || true; }

fin_erreur() {
  local msg="$1"
  log "ERREUR : $msg"
  printf 'ERREUR %s %s\n' "$(date -Is)" "$msg" > "$STATUS"
  logger -p daemon.err -t sfo-restore-test "$msg" 2>/dev/null || true
  [ -n "$ALERT_URL" ] && curl -s -m 10 -H 'Content-Type: application/json' \
    -d "{\"text\":\"[SFO] Test de restauration en echec sur $(hostname) : $msg\"}" \
    "$ALERT_URL" >/dev/null 2>&1 || true
  nettoyer
  exit 1
}
trap 'fin_erreur "interruption inattendue ligne $LINENO"' ERR

SAUV=$(find "$DEST" -maxdepth 1 -name 'exnihilo_*.sql.gz' -printf '%T@ %p\n' 2>/dev/null \
       | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$SAUV" ] || fin_erreur "aucune sauvegarde trouvee dans $DEST"
log "--- test sur $SAUV ---"

# Empreinte : detecte une archive alteree depuis son ecriture.
if [ -r "$SAUV.sha256" ]; then
  ATTENDU=$(cat "$SAUV.sha256"); OBTENU=$(sha256sum "$SAUV" | awk '{print $1}')
  [ "$ATTENDU" = "$OBTENU" ] || fin_erreur "empreinte sha256 differente : archive alteree"
fi

nettoyer
docker exec -i "$CT" psql -U postgres -c "CREATE DATABASE $TESTDB;" >/dev/null 2>&1 \
  || fin_erreur "impossible de creer la base de test"

gunzip -c "$SAUV" | docker exec -i "$CT" psql -q -U postgres -d "$TESTDB" >/dev/null 2>>"$LOG" \
  || fin_erreur "la restauration a echoue"

LIRE() { docker exec -i "$CT" psql -U postgres -d "$TESTDB" -t -A -c "$1" 2>/dev/null | tr -d '[:space:]'; }
OPS=$(LIRE 'SELECT count(*) FROM operations;')
TR=$(LIRE 'SELECT count(*) FROM tranches;')
PR=$(LIRE 'SELECT count(*) FROM prets;')

[ "${OPS:-0}" -ge "$MIN_OPS" ] || fin_erreur "seulement ${OPS:-0} operations restaurees (seuil $MIN_OPS)"

nettoyer
log "OK : $OPS operations, $TR tranches, $PR prets restaures depuis $(basename "$SAUV")"
printf 'OK %s %s operations=%s tranches=%s prets=%s\n' \
  "$(date -Is)" "$(basename "$SAUV")" "$OPS" "$TR" "$PR" > "$STATUS"
trap - ERR
exit 0
