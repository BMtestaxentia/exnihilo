#!/usr/bin/env bash
# ============================================================================
# Génère les secrets de la stack ExNihilo / SFO :
#   - JWT_SECRET (64 hex) + mots de passe Postgres
#   - ANON_KEY et SERVICE_KEY : JWT HS256 signés avec JWT_SECRET
#     (équivalents des clés "anon" et "service_role" de Supabase)
# Usage :
#   ./gen-keys.sh              -> génère tout (nouveau JWT_SECRET)
#   ./gen-keys.sh <jwt_secret> -> régénère seulement les jetons avec un secret existant
# Reporter les valeurs affichées dans le fichier .env (et ANON_KEY dans app.js).
# ============================================================================
set -euo pipefail

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

JWT_SECRET="${1:-$(openssl rand -hex 32)}"
IAT=$(date +%s)
EXP=$((IAT + 10 * 365 * 24 * 3600))   # 10 ans

make_jwt() {
  local role="$1"
  local header payload sig
  header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '{"role":"%s","iss":"exnihilo","iat":%s,"exp":%s}' "$role" "$IAT" "$EXP" | b64url)
  sig=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | b64url)
  printf '%s.%s.%s' "$header" "$payload" "$sig"
}

echo "# --- à reporter dans .env ---------------------------------------"
echo "JWT_SECRET=$JWT_SECRET"
if [ -z "${1:-}" ]; then
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)"
  echo "AUTHENTICATOR_PASSWORD=$(openssl rand -hex 16)"
fi
echo "ANON_KEY=$(make_jwt anon)"
echo "SERVICE_KEY=$(make_jwt service_role)"
echo "# ----------------------------------------------------------------"
echo "# ANON_KEY est aussi la valeur de SUPABASE_KEY dans app.js."
echo "# SERVICE_KEY ne doit JAMAIS apparaître côté client."
