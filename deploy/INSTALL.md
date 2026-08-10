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

## 6. Charger les données

### 6.A Reconstruction depuis une sauvegarde (cas normal)

C'est le chemin à suivre pour toute remise en service : reconstruction de la VM, retour arrière après incident, ou migration vers une nouvelle machine.

```bash
# Déposer l'archive récupérée (copie hors VM) dans /var/backups, puis :
sudo /opt/sfo/sfo-restore.sh /var/backups/exnihilo_AAAA-MM-JJ.sql.gz
```

Le script vérifie l'archive, prend une sauvegarde de sécurité de l'état courant, recrée la base, réapplique les droits applicatifs, redémarre l'API et affiche un contrôle final. Détail en section « Restauration » plus bas.

La sauvegarde contient **aussi les comptes SSO** (schéma `auth`) : les utilisateurs n'ont pas à se recréer un compte après restauration.

### 6.B Migration initiale depuis Supabase cloud (historique)

Conservé pour mémoire. **Ne concerne plus l'exploitation courante** : le projet Supabase cloud n'est plus la source de vérité depuis la mise en service de la VM.

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

## 7. Comptes utilisateurs (SSO uniquement)

L'application est en **SSO Microsoft Entra ID exclusif** : aucun mot de passe n'est géré
(le provider e-mail de GoTrue est coupé, cf. `GOTRUE_EXTERNAL_EMAIL_ENABLED=false`).

- Le compte GoTrue d'un utilisateur **se crée automatiquement à sa première connexion**
  via « Se connecter avec Microsoft » (l'accès est contrôlé en amont par Entra ID :
  application mono-tenant, restriction possible par affectation d'utilisateurs/groupes).
- Le rattachement du compte à sa « personne des opérations » se fait ensuite dans
  l'administration des comptes de l'application (un clic sur le compte nouvellement créé).
- Prérequis Entra : inscription d'application mono-tenant, URI de redirection
  `https://DOMAINE/auth/v1/callback`, et les 3 valeurs reportées dans `.env`
  (`AZURE_TENANT_URL` **sans** `/v2.0` final, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`,
  puis `AZURE_SSO_ENABLED=true` et recréation du conteneur auth).

## 8. Brancher l'application

Dans `app.js` (deux constantes en tête de fichier) :
- `SUPABASE_URL` -> `https://sfo.axentia.fr` (le domaine, sans slash final)
- `SUPABASE_KEY` -> la valeur de `ANON_KEY`

Redéployer `app.js` dans `/var/www/exnihilo` (et penser au cache-buster `?v=N` dans `index.html`). Les chemins `/rest/v1/` et `/auth/v1/` étant identiques à Supabase, **aucun autre changement de code n'est nécessaire**.

Test final : ouvrir `https://sfo.axentia.fr`, se connecter avec un compte créé en étape 7.

---

## Exploitation

### Sauvegardes

Installation (une seule fois) :

```bash
sudo cp /opt/sfo/backup.env.example /opt/sfo/backup.env
sudo nano /opt/sfo/backup.env          # choisir la copie hors VM + l'alerte
sudo chmod 600 /opt/sfo/backup.env     # peut contenir un webhook
sudo chmod +x /opt/sfo/sfo-backup.sh /opt/sfo/sfo-restore.sh /opt/sfo/sfo-restore-test.sh
sudo cp /opt/sfo/cron-sfo-backup /etc/cron.d/sfo-backup
sudo /opt/sfo/sfo-backup.sh            # premier passage, doit finir par "OK"
```

| Quoi | Quand | Où |
|---|---|---|
| Sauvegarde quotidienne | 02:00 | `/var/backups/exnihilo_AAAA-MM-JJ.sql.gz` (+ `.sha256`) |
| Archive mensuelle | le 1er | `/var/backups/mensuelles/`, conservée 12 mois |
| Rattrapage | au démarrage | si la VM était éteinte à 02:00 |
| Test de restauration | dimanche 03:00 | base jetable, jamais la production |

Rétention : 30 jours en quotidien, 12 mois en mensuel.

**Contrôler que tout va bien** :
```bash
cat /var/lib/sfo/backup.status         # OK <date> <fichier> <taille>
cat /var/lib/sfo/restore-test.status   # OK <date> operations=81 tranches=88 ...
tail -20 /var/log/sfo-backup.log
journalctl -t sfo-backup -t sfo-restore-test --since '7 days ago'
```

En cas d'échec : ligne `ERREUR` dans le fichier de statut, message en `daemon.err` dans le journal système, code de sortie non nul, et notification Teams si `SFO_ALERT_URL` est renseigné.

⚠️ **La copie hors VM n'est pas optionnelle.** Tant que `SFO_OFFSITE_CMD` est vide, les sauvegardes vivent sur le même disque que la base : une perte de VM emporte les deux. Voir les options A/B/C dans `backup.env.example`.

### Mise à jour

**Application** : `ssh sfo "bash ~/exnihilo/deploy/deploy-app.sh"` (récupère le dépôt, publie les 3 fichiers, substitue les constantes de connexion, contrôle la version servie). Aucun redémarrage nécessaire.
**Stack** : `cd /opt/sfo && docker-compose pull && docker-compose up -d`.
**Logs** : `docker-compose logs -f rest` (API) / `auth` (connexions) / `db`.

---

## Restauration

### Vérifier une sauvegarde sans rien casser

```bash
sudo /opt/sfo/sfo-restore-test.sh      # restaure dans une base jetable, puis la supprime
cat /var/lib/sfo/restore-test.status
```

C'est ce que fait le cron chaque dimanche. À lancer aussi avant toute opération risquée.

### Restaurer réellement la base

```bash
sudo /opt/sfo/sfo-restore.sh                                        # liste les sauvegardes
sudo /opt/sfo/sfo-restore.sh /var/backups/exnihilo_2026-08-10.sql.gz
```

Le script demande de taper `RESTAURER` en toutes lettres, puis enchaîne :

1. vérification de l'archive (gzip, empreinte sha256, présence de la table `operations`) ;
2. **sauvegarde de sécurité de l'état courant** dans `/var/backups/avant_restauration_*.sql.gz` ;
3. arrêt de `sfo-rest` et `sfo-auth` (ils gardent des connexions ouvertes qui bloqueraient la suppression) ;
4. suppression et recréation de la base, puis import ;
5. réapplication des `GRANT` applicatifs, sans lesquels l'API ne verrait aucune table ;
6. redémarrage des conteneurs et contrôle final (nombres d'opérations, tranches, prêts, comptes SSO, code HTTP de l'API).

Durée constatée : moins d'une minute pour la base actuelle (environ 50 Ko compressés).

> Une restauration décidée par erreur reste réversible : l'état précédent est dans `avant_restauration_*.sql.gz`.

### Restaurer une seule table

Il n'y a pas d'outil dédié : restaurer l'archive dans une base jetable, puis recopier ce qui manque.

```bash
docker exec -i sfo-db psql -U postgres -c 'CREATE DATABASE reprise;'
gunzip -c /var/backups/exnihilo_2026-08-10.sql.gz | docker exec -i sfo-db psql -q -U postgres -d reprise
# examiner, extraire, réinjecter ce qui est nécessaire, puis :
docker exec -i sfo-db psql -U postgres -c 'DROP DATABASE reprise;'
```

---

## PRA : reconstruire entièrement la VM

Procédure complète, depuis une machine nue jusqu'au service rétabli.

**Prérequis à réunir avant de commencer** (hors VM, sinon la reconstruction est impossible) :

| Élément | Où il se trouve |
|---|---|
| Sauvegarde de la base | copie hors VM (`backup.env`, option A/B/C) |
| Dépôt `deploy/` + les 3 fichiers de l'app | dépôt GitHub `BMtestaxentia/exnihilo` |
| Secrets (`JWT_SECRET`, mots de passe, `ANON_KEY`, `SERVICE_KEY`) | fichier `.env`, **à conserver hors VM** |
| Identifiants Entra (`AZURE_TENANT_URL`, `CLIENT_ID`, `CLIENT_SECRET`) | inscription d'application Entra, côté DSI |
| Certificat HTTPS | Let's Encrypt (regénérable) ou certificat Axentia |
| Enregistrement DNS `sfo.axentia.fr` | DSI |

⚠️ Si le `.env` est perdu, les secrets sont regénérables avec `./gen-keys.sh`, mais **il faut alors reporter le nouvel `ANON_KEY` dans `app.js`** et redéployer, sinon l'application prendra un 401 sur chaque appel.

**Enchaînement** :

| # | Étape | Section | Durée |
|---|---|---|---|
| 1 | Provisionner la VM (Ubuntu), ouvrir 22/80/443, pointer le DNS | DSI | variable |
| 2 | Paquets système et Docker | § 1 | 10 min |
| 3 | Déposer `deploy/` dans `/opt/sfo` et l'app dans `/var/www/exnihilo` | § 2 | 5 min |
| 4 | Restaurer le `.env` (ou le regénérer) | § 3 | 5 min |
| 5 | Démarrer la stack, vérifier les 3 conteneurs | § 4 | 5 min |
| 6 | nginx + HTTPS | § 5 | 15 min |
| 7 | **Restaurer les données depuis la sauvegarde** | § 6.A | 5 min |
| 8 | Vérifier le SSO Entra (URI de redirection = nouveau domaine si changé) | § 7 | 10 min |
| 9 | Vérifier `SUPABASE_URL` / `SUPABASE_KEY` dans `app.js`, redéployer | § 8 | 5 min |
| 10 | Réinstaller sauvegardes et cron | § Exploitation | 5 min |
| 11 | Contrôle de bon fonctionnement (ci-dessous) | | 5 min |

Objectif réaliste : **1 h 30 à 2 h**, VM provisionnée et prérequis en main.

**Contrôle de bon fonctionnement, à passer intégralement** :

```bash
docker ps --format '{{.Names}}\t{{.Status}}'          # 3 conteneurs Up
curl -s -o /dev/null -w '%{http_code}\n' https://sfo.axentia.fr/    # 200
docker exec -i sfo-db psql -U postgres -d exnihilo -t -A -c \
  "SELECT 'operations='||count(*) FROM operations;"   # cohérent avec la sauvegarde
docker exec -i sfo-db psql -U postgres -d exnihilo -t -A -c \
  "SELECT count(*) FROM auth.users;"                  # les comptes SSO sont revenus
sudo /opt/sfo/sfo-restore-test.sh                     # la chaîne de sauvegarde refonctionne
```

Puis, dans le navigateur : connexion SSO, ouverture d'une opération, **et une modification enregistrée** (le seul test qui prouve que l'écriture fonctionne de bout en bout).

**Limites connues, à assumer devant la DSI** :

- Aucune réplication ni bascule automatique : la reconstruction est manuelle, la perte de données maximale est d'une journée (dernière sauvegarde à 02:00).
- Aucune supervision active : un service arrêté n'est constaté que par un utilisateur, ou par l'échec de la sauvegarde suivante.
- La procédure ci-dessus n'a **pas encore été rejouée de bout en bout** sur une VM vierge. Tant que ce n'est pas fait, elle reste théorique sur les étapes 1 à 6.

---

## Dépannage rapide

| Symptôme | Piste |
|---|---|
| L'app affiche « Erreur Supabase : 401 » | `ANON_KEY` d'app.js ≠ `JWT_SECRET` du `.env` (régénérer via `./gen-keys.sh $JWT_SECRET`) |
| Login refusé pour tous | GoTrue ne signe pas avec le même `JWT_SECRET` que PostgREST (vérifier `.env`, `docker-compose up -d`) |
| PGRST204 « column not found » | Rejouer les fichiers `sql/` du dépôt puis `docker restart sfo-rest` |
| Tables invisibles dans l'API | GRANT manquants (relancer le bloc GRANT de l'étape 6.B) puis `docker restart sfo-rest` |
| Aucune sauvegarde depuis plusieurs jours | VM éteinte aux heures du cron : `last -x reboot` pour confirmer. Le `@reboot` du cron rattrape au démarrage suivant |
| `backup.status` en ERREUR | Lire `/var/log/sfo-backup.log` : conteneur arrêté, disque plein (`df -h /var`), ou copie hors VM injoignable |
| Test de restauration en échec | L'archive est illisible ou incomplète : vérifier les précédentes avec `gzip -t`, et ne pas compter sur la sauvegarde du jour tant que ce n'est pas résolu |
| Après restauration, l'app renvoie 401 | `ANON_KEY` d'`app.js` ≠ `JWT_SECRET` du `.env` restauré (cas typique d'un `.env` regénéré) |
