# Installation ExNihilo / SFO sur la VM

Guide pas à pas - stack : **Postgres + PostgREST (API) + GoTrue (auth)** en conteneurs Docker, **nginx sur l'hôte** (fichiers statiques + reverse proxy + HTTPS).

Prérequis côté Bastien : ce dossier `deploy/` + les 3 fichiers de l'application (`index.html`, `app.js`, `styles.css`).
Prérequis côté DSI : le **nom de domaine** (ex. `sfo.axentia.fr`) pointant vers la VM, et le choix du **certificat** (Let's Encrypt ou certificat Axentia).

---

## 1. Préparer le système (une seule fois)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io && sudo systemctl enable docker && sudo systemctl start docker
sudo apt install -y docker-compose
sudo usermod -aG docker $USER        # puis se déconnecter / reconnecter
sudo apt install -y nginx
sudo apt install -y certbot python3-certbot-nginx   # seulement si option Let's Encrypt
```

## 2. Déposer les fichiers

```bash
sudo mkdir -p /opt/sfo /var/www/exnihilo
# le dossier deploy/ du dépôt -> /opt/sfo
# les 3 fichiers de l'app (index.html, app.js, styles.css) -> /var/www/exnihilo
```

## 3. Générer les secrets et remplir `.env`

```bash
cd /opt/sfo
chmod +x gen-keys.sh init/02-roles-password.sh
./gen-keys.sh          # affiche JWT_SECRET, mots de passe, ANON_KEY, SERVICE_KEY
cp .env.example .env
nano .env              # reporter les valeurs générées + SITE_URL (le domaine)
```

⚠️ `SERVICE_KEY` est la clé d'administration : la garder dans `.env` sur la VM, jamais ailleurs.

## 4. Démarrer la stack

```bash
cd /opt/sfo
docker-compose up -d
docker-compose ps                      # les 3 services doivent être "Up (healthy)"
curl -s http://127.0.0.1:3000/ | head  # PostgREST répond (liste des tables, vide au début)
curl -s http://127.0.0.1:9999/health   # GoTrue répond {"name":"GoTrue",...}
```

Au premier démarrage, Postgres exécute `init/01-roles.sql` (rôles anon / authenticated / service_role / authenticator + schéma auth) et GoTrue crée ses tables tout seul.

## 5. nginx + HTTPS

```bash
sudo cp /opt/sfo/nginx/exnihilo.conf /etc/nginx/sites-available/exnihilo
sudo nano /etc/nginx/sites-available/exnihilo   # remplacer sfo.axentia.fr si besoin
sudo ln -s /etc/nginx/sites-available/exnihilo /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

**Option A - Let's Encrypt** (le domaine doit déjà pointer vers la VM) :
```bash
sudo certbot --nginx -d sfo.axentia.fr
```
**Option B - certificat Axentia** : déposer le `.crt` et la `.key` dans `/etc/ssl/axentia/`, décommenter le bloc « OPTION B » de la conf nginx, `sudo nginx -t && sudo systemctl reload nginx`.

## 6. Migrer les données depuis Supabase cloud

Depuis la VM (la chaîne de connexion source est dans le dashboard Supabase, Settings > Database) :

```bash
# Export du schéma + données du projet cloud (schéma public uniquement)
docker run --rm postgres:15-alpine pg_dump \
  "postgresql://postgres:MOT_DE_PASSE@db.odcquhorfhlasnqahgls.supabase.co:5432/postgres" \
  --schema=public --no-owner --no-privileges > /tmp/exnihilo_dump.sql

# Import dans la base locale
docker exec -i sfo-db psql -U postgres -d exnihilo < /tmp/exnihilo_dump.sql

# Redonner les droits aux rôles applicatifs
docker exec -i sfo-db psql -U postgres -d exnihilo -c \
  "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
   GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;"

# PostgREST doit recharger le schéma
docker restart sfo-rest
```

## 7. Créer les comptes utilisateurs

L'auto-inscription est désactivée : les comptes se créent avec la clé admin (`SERVICE_KEY` du `.env`).

```bash
source /opt/sfo/.env
curl -s -X POST http://127.0.0.1:9999/admin/users \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"prenom.nom@axentia.fr","password":"MotDePasseInitial!","email_confirm":true}'
```

(Répéter par utilisateur. Le rattachement compte -> personne se fait ensuite dans la table `comptes` de l'application, comme aujourd'hui.)

## 8. Brancher l'application

Dans `app.js` (deux constantes en tête de fichier) :
- `SUPABASE_URL` -> `https://sfo.axentia.fr` (le domaine, sans slash final)
- `SUPABASE_KEY` -> la valeur de `ANON_KEY`

Redéployer `app.js` dans `/var/www/exnihilo` (et penser au cache-buster `?v=N` dans `index.html`). Les chemins `/rest/v1/` et `/auth/v1/` étant identiques à Supabase, **aucun autre changement de code n'est nécessaire**.

Test final : ouvrir `https://sfo.axentia.fr`, se connecter avec un compte créé en étape 7.

---

## Exploitation

**Sauvegarde quotidienne** (à mettre en cron, ex. `0 2 * * *`) :
```bash
docker exec sfo-db pg_dump -U postgres exnihilo | gzip > /var/backups/exnihilo_$(date +%F).sql.gz
find /var/backups -name 'exnihilo_*.sql.gz' -mtime +30 -delete
```

**Mise à jour de l'application** : remplacer les 3 fichiers dans `/var/www/exnihilo` (aucun redémarrage nécessaire).
**Mise à jour de la stack** : `cd /opt/sfo && docker-compose pull && docker-compose up -d`.
**Logs** : `docker-compose logs -f rest` (API) / `auth` (connexions) / `db`.

## Dépannage rapide

| Symptôme | Piste |
|---|---|
| L'app affiche « Erreur Supabase : 401 » | `ANON_KEY` d'app.js ≠ `JWT_SECRET` du `.env` (régénérer via `./gen-keys.sh $JWT_SECRET`) |
| Login refusé pour tous | GoTrue ne signe pas avec le même `JWT_SECRET` que PostgREST (vérifier `.env`, `docker-compose up -d`) |
| PGRST204 « column not found » | Rejouer les fichiers `sql/` du dépôt puis `docker restart sfo-rest` |
| Tables invisibles dans l'API | GRANT manquants (relancer le bloc GRANT de l'étape 6) puis `docker restart sfo-rest` |
