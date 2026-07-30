#!/usr/bin/env bash
# Déploiement de l'application sur la VM, en une commande :
#   ssh sfo "bash ~/exnihilo/deploy/deploy-app.sh"
# Récupère la dernière version du dépôt, la publie dans /var/www/exnihilo et
# bascule les deux constantes de connexion sur le backend de la VM.
set -euo pipefail

REPO="$HOME/exnihilo"
WWW="/var/www/exnihilo"

cd "$REPO"
git pull --quiet
source /opt/sfo/.env

sudo cp index.html styles.css app.js "$WWW/"
sudo sed -i "s|const SUPABASE_URL = 'https://odcquhorfhlasnqahgls.supabase.co';|const SUPABASE_URL = '${SITE_URL}';|" "$WWW/app.js"
sudo sed -i "s|const SUPABASE_KEY = 'ey[^']*';|const SUPABASE_KEY = '${ANON_KEY}';|" "$WWW/app.js"

# Contrôles : constantes bien substituées + version servie
grep -q "const SUPABASE_URL = '${SITE_URL}';" "$WWW/app.js" || { echo "ERREUR : URL non substituée"; exit 1; }
grep -q "const SUPABASE_KEY = '${ANON_KEY}';" "$WWW/app.js" || { echo "ERREUR : clé non substituée"; exit 1; }
VER=$(grep -o 'app.js?v=[0-9]*' "$WWW/index.html" | head -1)
echo "Déployé : $(git log --oneline -1)"
echo "Version servie : $VER"
curl -s -o /dev/null -w "Page d'accueil : HTTP %{http_code}\n" "${SITE_URL}/"
