#!/usr/bin/env bash
# Restauration de la base SFO depuis une sauvegarde.
#
#   sudo /opt/sfo/sfo-restore.sh /var/backups/exnihilo_2026-08-10.sql.gz
#
# ECRASE LA BASE DE PRODUCTION. Une confirmation explicite est demandee, et une
# sauvegarde de securite de l'etat courant est prise avant toute destruction :
# meme une restauration decidee par erreur reste reversible.
set -euo pipefail

CONF=/opt/sfo/backup.env
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

DB=${SFO_DB:-exnihilo}
CT=${SFO_CONTAINER:-sfo-db}
DEST=${SFO_BACKUP_DIR:-/var/backups}
SAUV=${1:-}

[ -n "$SAUV" ] || { echo "Usage : $0 <fichier.sql.gz>"; echo; echo "Sauvegardes disponibles :";
  find "$DEST" -maxdepth 1 -name 'exnihilo_*.sql.gz' | sort | tail -10; exit 2; }
[ -r "$SAUV" ] || { echo "Fichier introuvable : $SAUV"; exit 2; }

echo "Verification de l'archive..."
gzip -t "$SAUV" || { echo "ECHEC : archive gzip corrompue, restauration annulee."; exit 1; }
if [ -r "$SAUV.sha256" ]; then
  [ "$(cat "$SAUV.sha256")" = "$(sha256sum "$SAUV" | awk '{print $1}')" ] \
    || { echo "ECHEC : empreinte sha256 differente, archive alteree."; exit 1; }
  echo "  empreinte sha256 conforme"
fi
# grep -c et non -q : avec pipefail, un grep -q ferait echouer le pipeline par
# SIGPIPE sur zcat alors meme que le motif est trouve.
[ "$(zcat "$SAUV" | grep -cE '^(COPY|CREATE TABLE) public\.operations' || true)" -gt 0 ] \
  || { echo "ECHEC : ce fichier ne contient pas la table operations."; exit 1; }
echo "  archive valide"

echo
echo "ATTENTION : la base '$DB' va etre supprimee puis recreee depuis"
echo "  $SAUV  ($(date -r "$SAUV" '+%d/%m/%Y %H:%M'))"
echo "Toute donnee saisie depuis cette sauvegarde sera perdue."
if [ "${SFO_CONFIRME:-}" != "oui" ]; then
  read -r -p "Taper RESTAURER pour confirmer : " REP
  [ "$REP" = "RESTAURER" ] || { echo "Annule."; exit 3; }
fi

# 1. Filet de securite : etat courant sauvegarde avant destruction.
FILET="$DEST/avant_restauration_$(date +%Y-%m-%d_%H%M%S).sql.gz"
echo "Sauvegarde de securite de l'etat courant -> $FILET"
docker exec "$CT" pg_dump -U postgres "$DB" | gzip > "$FILET" \
  || { echo "ECHEC de la sauvegarde de securite, restauration annulee."; rm -f "$FILET"; exit 1; }

# 2. Couper les clients : ils gardent des connexions ouvertes qui empechent le DROP.
echo "Arret de l'API et de l'authentification..."
docker stop sfo-rest sfo-auth >/dev/null 2>&1 || true

# 3. Recreation.
docker exec -i "$CT" psql -U postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DB' AND pid<>pg_backend_pid();" >/dev/null
docker exec -i "$CT" psql -U postgres -c "DROP DATABASE IF EXISTS $DB;" >/dev/null
docker exec -i "$CT" psql -U postgres -c "CREATE DATABASE $DB;" >/dev/null

echo "Restauration en cours..."
gunzip -c "$SAUV" | docker exec -i "$CT" psql -q -U postgres -d "$DB" >/dev/null

# 4. Droits applicatifs : sans eux l'API ne voit aucune table.
docker exec -i "$CT" psql -U postgres -d "$DB" -c \
  "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
   GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;" >/dev/null

# 5. Redemarrage (PostgREST relit le schema au demarrage).
echo "Redemarrage de l'API et de l'authentification..."
docker start sfo-auth sfo-rest >/dev/null
sleep 3

# 6. Controle final.
LIRE() { docker exec -i "$CT" psql -U postgres -d "$DB" -t -A -c "$1" 2>/dev/null | tr -d '[:space:]'; }
echo
echo "Restauration terminee :"
echo "  operations  : $(LIRE 'SELECT count(*) FROM operations;')"
echo "  tranches    : $(LIRE 'SELECT count(*) FROM tranches;')"
echo "  prets       : $(LIRE 'SELECT count(*) FROM prets;')"
echo "  comptes SSO : $(LIRE 'SELECT count(*) FROM auth.users;')"
echo "  API         : HTTP $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/ || echo '???')"
echo
echo "Etat precedent conserve dans : $FILET"
echo "Penser a verifier l'application dans le navigateur (Ctrl+Shift+R)."
