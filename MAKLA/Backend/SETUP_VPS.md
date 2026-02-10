# 🚀 Guide de déploiement MAKLA sur VPS

> Infrastructure complète pour déployer MAKLA Backend sur VPS (même setup que Vegece)

---

## 📋 Table des matières

1. [Prérequis](#-prérequis)
2. [Installation sur VPS](#-installation-sur-vps)
3. [Configuration OVH Object Storage](#-configuration-ovh-object-storage)
4. [Déploiement Docker](#-déploiement-docker)
5. [Configuration Nginx](#-configuration-nginx)
6. [Maintenance](#-maintenance)

---

## ✅ Prérequis

### **Sur ton VPS**
- Ubuntu 20.04+ ou Debian 11+
- Docker & Docker Compose installés
- Nginx installé
- Accès SSH root ou sudo

### **Sur OVH**
- Compte OVH Cloud
- Bucket Object Storage créé
- Credentials S3 (Access Key + Secret Key)

### **Localement**
- Git configuré
- Accès au repo `ecolealgerienne-ui/Otha`

---

## 🛠️ Installation sur VPS

### **Étape 1 : Connexion SSH**

```bash
# Remplace par ton IP VPS
ssh root@YOUR_VPS_IP

# Ou avec un utilisateur sudo
ssh ubuntu@YOUR_VPS_IP
```

---

### **Étape 2 : Installer Docker & Docker Compose**

```bash
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer les dépendances
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Ajouter la clé GPG officielle de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajouter le repo Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installer Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Vérifier l'installation
docker --version
docker compose version

# Ajouter ton utilisateur au groupe Docker (éviter sudo)
sudo usermod -aG docker $USER
newgrp docker
```

---

### **Étape 3 : Installer PostgreSQL**

#### **Option A : Docker (Recommandé)**

```bash
# PostgreSQL sera dans le docker-compose.yml (voir étape 5)
```

#### **Option B : Installation native**

```bash
sudo apt install -y postgresql postgresql-contrib

# Configurer PostgreSQL
sudo -u postgres psql

# Dans psql :
CREATE DATABASE makla;
CREATE USER makla WITH PASSWORD 'makla_secure_password_123';
GRANT ALL PRIVILEGES ON DATABASE makla TO makla;
\q
```

---

### **Étape 4 : Créer la structure de dossiers**

```bash
# Créer la structure
sudo mkdir -p /srv/infrastructure
sudo mkdir -p /srv/apps/api/makla-api

# Donner les permissions
sudo chown -R $USER:$USER /srv/infrastructure
sudo chown -R $USER:$USER /srv/apps
```

---

### **Étape 5 : Cloner le projet**

```bash
cd /srv/apps/api/makla-api

# Cloner le repo (remplace par ton repo)
git clone https://github.com/ecolealgerienne-ui/Otha.git .

# Aller dans le dossier backend
cd backend

# Vérifier la structure
ls -la
# Tu devrais voir : Dockerfile, package.json, prisma/, src/, etc.
```

---

## ☁️ Configuration OVH Object Storage

### **Étape 1 : Créer un bucket sur OVH**

1. Connecte-toi à l'[interface OVH Cloud](https://www.ovh.com/manager/)
2. Va dans **Public Cloud** > **Object Storage**
3. Clique sur **Créer un conteneur de stockage d'objets**
4. Choisis :
   - **Nom :** `makla-videos` (pour les vidéos)
   - **Région :** RBX (Roubaix) ou GRA (Gravelines)
   - **Type :** Standard Object Storage
5. Crée aussi `makla-images` (pour les avatars/photos)

---

### **Étape 2 : Générer les credentials S3**

1. Va dans **Utilisateurs** > **Créer un utilisateur OpenStack**
2. Télécharge le fichier `openrc.sh`
3. Récupère :
   - **Access Key ID** (ex: `8be211cd79404bebb5fa04fe507b443f`)
   - **Secret Access Key** (ex: `9c939ccc1fdb42c0ad4765b5ebcb520d`)

---

### **Étape 3 : Tester les credentials**

```bash
# Installer AWS CLI
sudo apt install -y awscli

# Configurer
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_DEFAULT_REGION=rbx

# Tester la connexion
aws s3 ls \
  --endpoint-url https://s3.rbx.io.cloud.ovh.net

# Tu devrais voir tes buckets : makla-videos, makla-images
```

---

## 🐳 Déploiement Docker

### **Étape 1 : Créer le fichier .env**

```bash
cd /srv/infrastructure

# Copier le template
cp /srv/apps/api/makla-api/backend/.env.example .env

# Éditer avec nano
nano .env
```

**Contenu du `.env` :**

```bash
# =================================
# DATABASE
# =================================
DATABASE_URL="postgresql://makla:makla_secure_password_123@postgres_makla:5432/makla?schema=public"

# =================================
# JWT SECRETS (GÉNÉRER DES VRAIS SECRETS !)
# =================================
# Générer avec: openssl rand -base64 32
JWT_ACCESS_SECRET="CHANGE_ME_WITH_32_CHARS_MIN_SECRET_KEY_12345678"
JWT_REFRESH_SECRET="CHANGE_ME_WITH_32_CHARS_MIN_REFRESH_KEY_87654321"
JWT_ACCESS_TTL="30d"
JWT_REFRESH_TTL="60d"

# =================================
# EMAIL SMTP CONFIGURATION
# =================================
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-16-char-app-password"

# =================================
# OVH OBJECT STORAGE (S3)
# =================================
S3_ACCESS_KEY_ID="YOUR_OVH_ACCESS_KEY"
S3_SECRET_ACCESS_KEY="YOUR_OVH_SECRET_KEY"
S3_BUCKET_VIDEOS="makla-videos"
S3_BUCKET_IMAGES="makla-images"
S3_ENDPOINT="https://s3.rbx.io.cloud.ovh.net"
S3_PUBLIC_ENDPOINT="https://makla-videos.s3.rbx.io.cloud.ovh.net"
AWS_REGION="rbx"
S3_FORCE_PATH_STYLE="true"
S3_USE_OBJECT_ACL="true"

# =================================
# APPLICATION
# =================================
NODE_ENV="production"
PORT=3000
CORS_ORIGINS="https://makla.dz,https://app.makla.dz,http://localhost:5173"

# =================================
# REDIS (Optionnel - pour le cache)
# =================================
REDIS_URL="redis://redis_makla:6379"
```

**Sauvegarder :** `Ctrl+O` puis `Enter`, puis `Ctrl+X`

---

### **Étape 2 : Créer le docker-compose.yml**

```bash
cd /srv/infrastructure
nano docker-compose.yml
```

**Contenu :**

```yaml
version: '3.8'

services:
  # =================================
  # PostgreSQL Database
  # =================================
  postgres_makla:
    image: postgres:15-alpine
    container_name: postgres_makla
    restart: unless-stopped
    environment:
      POSTGRES_DB: makla
      POSTGRES_USER: makla
      POSTGRES_PASSWORD: makla_secure_password_123
    volumes:
      - postgres_makla_data:/var/lib/postgresql/data
    ports:
      - "5433:5432"  # 5433 pour éviter conflit avec Vegece (5432)
    networks:
      - makla_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U makla"]
      interval: 10s
      timeout: 5s
      retries: 5

  # =================================
  # Redis (Cache - Optionnel)
  # =================================
  redis_makla:
    image: redis:7-alpine
    container_name: redis_makla
    restart: unless-stopped
    ports:
      - "6380:6379"  # 6380 pour éviter conflit
    volumes:
      - redis_makla_data:/data
    networks:
      - makla_network
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # =================================
  # MAKLA Backend API
  # =================================
  makla_api:
    image: makla-backend:latest
    container_name: makla_api
    restart: unless-stopped
    build:
      context: /srv/apps/api/makla-api/backend
      dockerfile: Dockerfile
    ports:
      - "3001:3000"  # 3001 pour éviter conflit avec Vegece (3000)
      - "5556:5555"  # Prisma Studio (5556 pour éviter conflit)
    environment:
      # Database
      DATABASE_URL: ${DATABASE_URL}

      # JWT
      JWT_ACCESS_SECRET: ${JWT_ACCESS_SECRET}
      JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET}
      JWT_ACCESS_TTL: ${JWT_ACCESS_TTL}
      JWT_REFRESH_TTL: ${JWT_REFRESH_TTL}

      # Email
      SMTP_HOST: ${SMTP_HOST}
      SMTP_PORT: ${SMTP_PORT}
      SMTP_USER: ${SMTP_USER}
      SMTP_PASS: ${SMTP_PASS}

      # S3 OVH
      S3_ACCESS_KEY_ID: ${S3_ACCESS_KEY_ID}
      S3_SECRET_ACCESS_KEY: ${S3_SECRET_ACCESS_KEY}
      S3_BUCKET_VIDEOS: ${S3_BUCKET_VIDEOS}
      S3_BUCKET_IMAGES: ${S3_BUCKET_IMAGES}
      S3_ENDPOINT: ${S3_ENDPOINT}
      S3_PUBLIC_ENDPOINT: ${S3_PUBLIC_ENDPOINT}
      AWS_REGION: ${AWS_REGION}
      S3_FORCE_PATH_STYLE: ${S3_FORCE_PATH_STYLE}
      S3_USE_OBJECT_ACL: ${S3_USE_OBJECT_ACL}

      # App
      NODE_ENV: ${NODE_ENV}
      PORT: 3000
      CORS_ORIGINS: ${CORS_ORIGINS}

      # Redis
      REDIS_URL: ${REDIS_URL}
    depends_on:
      postgres_makla:
        condition: service_healthy
      redis_makla:
        condition: service_healthy
    networks:
      - makla_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  makla_network:
    driver: bridge

volumes:
  postgres_makla_data:
    driver: local
  redis_makla_data:
    driver: local
```

**Sauvegarder et quitter**

---

### **Étape 3 : Build l'image Docker**

```bash
cd /srv/apps/api/makla-api/backend

# Donner les permissions au script
chmod +x docker-build.sh

# Build l'image
./docker-build.sh

# Ou manuellement :
docker build -t makla-backend:latest .

# Vérifier l'image
docker images | grep makla
```

---

### **Étape 4 : Lancer les services**

```bash
cd /srv/infrastructure

# Lancer tous les services
docker compose up -d

# Vérifier les logs
docker compose logs -f makla_api

# Vérifier que tous les services sont UP
docker compose ps
```

**Tu devrais voir :**
```
NAME            STATE    PORTS
postgres_makla  Up       0.0.0.0:5433->5432/tcp
redis_makla     Up       0.0.0.0:6380->6379/tcp
makla_api       Up       0.0.0.0:3001->3000/tcp, 0.0.0.0:5556->5555/tcp
```

---

### **Étape 5 : Vérifier que ça marche**

```bash
# Tester l'API
curl http://localhost:3001/health

# Tu devrais recevoir :
# {"status":"ok","timestamp":"2026-02-10T..."}

# Accéder à Prisma Studio
# Ouvre dans ton navigateur : http://YOUR_VPS_IP:5556
```

---

## 🌐 Configuration Nginx

### **Étape 1 : Installer Nginx**

```bash
sudo apt install -y nginx

# Vérifier l'installation
nginx -v
```

---

### **Étape 2 : Créer la config pour MAKLA**

```bash
sudo nano /etc/nginx/sites-available/makla.dz
```

**Contenu :**

```nginx
# Redirection HTTP -> HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name api.makla.dz;

    # Certbot ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Rediriger vers HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.makla.dz;

    # Certificats SSL (à configurer avec Certbot)
    ssl_certificate /etc/letsencrypt/live/api.makla.dz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.makla.dz/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Headers de sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logs
    access_log /var/log/nginx/makla-api-access.log;
    error_log /var/log/nginx/makla-api-error.log;

    # Proxy vers le backend Docker
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;

        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (pour Prisma Studio)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Prisma Studio (optionnel - à protéger !)
    location /prisma/ {
        proxy_pass http://localhost:5556/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Authentification basique (IMPORTANT !)
        auth_basic "Prisma Studio";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
```

---

### **Étape 3 : Activer le site**

```bash
# Créer un lien symbolique
sudo ln -s /etc/nginx/sites-available/makla.dz /etc/nginx/sites-enabled/

# Tester la config
sudo nginx -t

# Recharger Nginx
sudo systemctl reload nginx
```

---

### **Étape 4 : Configurer SSL avec Certbot**

```bash
# Installer Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtenir le certificat
sudo certbot --nginx -d api.makla.dz

# Le certificat sera auto-renouvelé par cron
sudo certbot renew --dry-run
```

---

### **Étape 5 : Protéger Prisma Studio**

```bash
# Créer un mot de passe pour Prisma Studio
sudo apt install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Entre ton mot de passe
# Recharger Nginx
sudo systemctl reload nginx
```

---

## 🔧 Maintenance

### **Mettre à jour le code**

```bash
# Se connecter au VPS
ssh ubuntu@YOUR_VPS_IP

# Aller dans le dossier
cd /srv/apps/api/makla-api

# Pull les changements
git pull origin claude/discuss-project-B8RAy

# Rebuild l'image
cd backend
docker build -t makla-backend:latest .

# Redémarrer le service
cd /srv/infrastructure
docker compose up -d --no-deps --force-recreate makla_api

# Vérifier les logs
docker compose logs -f makla_api
```

---

### **Voir les logs**

```bash
# Logs en temps réel
docker compose logs -f makla_api

# Dernières 100 lignes
docker compose logs --tail=100 makla_api

# Logs PostgreSQL
docker compose logs -f postgres_makla

# Logs Redis
docker compose logs -f redis_makla
```

---

### **Restart les services**

```bash
cd /srv/infrastructure

# Restart un seul service
docker compose restart makla_api

# Restart tous les services
docker compose restart

# Stop/Start
docker compose stop
docker compose start
```

---

### **Backup de la base de données**

```bash
# Créer un dossier backups
mkdir -p /srv/backups/makla

# Backup manuel
docker exec postgres_makla pg_dump -U makla makla > /srv/backups/makla/backup-$(date +%Y%m%d-%H%M%S).sql

# Automatiser avec cron (tous les jours à 2h du matin)
crontab -e

# Ajouter :
0 2 * * * docker exec postgres_makla pg_dump -U makla makla > /srv/backups/makla/backup-$(date +\%Y\%m\%d).sql

# Garder seulement les 7 derniers backups
0 3 * * * find /srv/backups/makla -name "backup-*.sql" -mtime +7 -delete
```

---

### **Restore de la base de données**

```bash
# Arrêter l'API
cd /srv/infrastructure
docker compose stop makla_api

# Restore
docker exec -i postgres_makla psql -U makla makla < /srv/backups/makla/backup-20260210.sql

# Redémarrer l'API
docker compose start makla_api
```

---

### **Monitoring**

```bash
# Voir l'utilisation des ressources
docker stats

# Voir les processus
docker compose top

# Inspecter un container
docker inspect makla_api

# Santé du container
docker inspect --format='{{json .State.Health}}' makla_api | jq
```

---

## 🔍 Troubleshooting

### **L'API ne démarre pas**

```bash
# Vérifier les logs
docker compose logs makla_api

# Problèmes courants :
# 1. Database non connectée
docker compose logs postgres_makla

# 2. Variables d'environnement manquantes
docker exec makla_api env | grep JWT_ACCESS_SECRET

# 3. Port déjà utilisé
sudo lsof -i :3001
```

---

### **Images S3 non accessibles**

```bash
# Vérifier que S3_USE_OBJECT_ACL=true
cat /srv/infrastructure/.env | grep S3_USE_OBJECT_ACL

# Rendre toutes les vidéos publiques
aws s3 ls s3://makla-videos --recursive --endpoint-url https://s3.rbx.io.cloud.ovh.net | \
awk '{print $4}' | while read key; do
  echo "Setting ACL for: $key"
  aws s3api put-object-acl \
    --bucket makla-videos \
    --key "$key" \
    --acl public-read \
    --endpoint-url https://s3.rbx.io.cloud.ovh.net \
    --region rbx
done
```

---

### **Migrations Prisma bloquées**

```bash
# Entrer dans le container
docker exec -it makla_api sh

# Lancer les migrations manuellement
npx prisma migrate deploy

# Voir l'état des migrations
npx prisma migrate status

# Reset complet (ATTENTION : perte de données !)
npx prisma migrate reset
```

---

## 📊 Résumé des ports

| Service | Port local | Port VPS | Accès |
|---------|------------|----------|-------|
| MAKLA API | 3000 | 3001 | https://api.makla.dz |
| Prisma Studio | 5555 | 5556 | https://api.makla.dz/prisma |
| PostgreSQL | 5432 | 5433 | Localhost uniquement |
| Redis | 6379 | 6380 | Localhost uniquement |

---

## 🎯 Checklist finale

- [ ] Docker installé et fonctionnel
- [ ] PostgreSQL démarré et accessible
- [ ] Redis démarré (optionnel)
- [ ] Variables d'environnement configurées dans `.env`
- [ ] Bucket OVH créé et credentials configurés
- [ ] Image Docker buildée
- [ ] Containers démarrés (`docker compose ps`)
- [ ] API accessible sur `http://localhost:3001/health`
- [ ] Nginx configuré et SSL actif
- [ ] Prisma Studio protégé par mot de passe
- [ ] Backup automatique configuré

---

## 🚀 Et après ?

1. **Configurer le domaine** : Pointer `api.makla.dz` vers ton IP VPS (DNS A record)
2. **Tester les endpoints** : Utiliser Postman ou Swagger (`/api/docs`)
3. **Monitoring** : Installer Grafana + Prometheus
4. **CI/CD** : Automatiser le déploiement avec GitHub Actions

---

**Dernière mise à jour :** 2026-02-10
**Version :** 1.0.0
