# 📋 Commandes à exécuter sur ton VPS

> **Copie-colle ces commandes dans l'ordre sur ton VPS**

---

## 🔐 Étape 1 : Connexion SSH

```bash
# Remplace par ton IP VPS
ssh root@YOUR_VPS_IP
```

---

## 📦 Étape 2 : Installer Docker (si pas déjà fait)

```bash
# Mettre à jour
sudo apt update && sudo apt upgrade -y

# Installer Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Installer Docker Compose
sudo apt install -y docker-compose-plugin

# Vérifier
docker --version
docker compose version

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker
```

---

## 📁 Étape 3 : Créer la structure de dossiers

```bash
# Créer les dossiers
sudo mkdir -p /srv/infrastructure
sudo mkdir -p /srv/apps/api/makla-api
sudo mkdir -p /srv/backups/makla

# Donner les permissions
sudo chown -R $USER:$USER /srv/infrastructure
sudo chown -R $USER:$USER /srv/apps
sudo chown -R $USER:$USER /srv/backups
```

---

## 📥 Étape 4 : Cloner le projet

```bash
cd /srv/apps/api/makla-api

# Cloner le repo
git clone https://github.com/ecolealgerienne-ui/Otha.git .

# Vérifier
ls -la
```

---

## ⚙️ Étape 5 : Configurer les variables d'environnement

```bash
cd /srv/infrastructure

# Créer le fichier .env
nano .env
```

**Copie-colle et modifie les valeurs :**

```bash
# DATABASE
DATABASE_URL="postgresql://makla:CHANGE_PASSWORD@postgres_makla:5432/makla?schema=public"
POSTGRES_PASSWORD="CHANGE_PASSWORD"

# JWT (Générer avec: openssl rand -base64 32)
JWT_ACCESS_SECRET="CHANGE_ME_32_CHARS_MIN"
JWT_REFRESH_SECRET="CHANGE_ME_32_CHARS_MIN"
JWT_ACCESS_TTL="30d"
JWT_REFRESH_TTL="60d"

# EMAIL
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="YOUR_EMAIL@gmail.com"
SMTP_PASS="YOUR_APP_PASSWORD"

# OVH S3
S3_ACCESS_KEY_ID="YOUR_OVH_ACCESS_KEY"
S3_SECRET_ACCESS_KEY="YOUR_OVH_SECRET_KEY"
S3_BUCKET_VIDEOS="makla-videos"
S3_BUCKET_IMAGES="makla-images"
S3_ENDPOINT="https://s3.rbx.io.cloud.ovh.net"
S3_PUBLIC_ENDPOINT="https://makla-videos.s3.rbx.io.cloud.ovh.net"
AWS_REGION="rbx"
S3_FORCE_PATH_STYLE="true"
S3_USE_OBJECT_ACL="true"

# APP
NODE_ENV="production"
PORT=3000
CORS_ORIGINS="https://makla.dz,https://app.makla.dz"

# REDIS
REDIS_URL="redis://redis_makla:6379"
```

**Sauvegarder :** `Ctrl+O` puis `Enter`, puis `Ctrl+X`

---

## 🔑 Étape 6 : Générer les secrets JWT

```bash
# Générer JWT_ACCESS_SECRET
openssl rand -base64 32

# Générer JWT_REFRESH_SECRET
openssl rand -base64 32

# Copie les résultats et mets-les dans le .env
nano /srv/infrastructure/.env
```

---

## 🐳 Étape 7 : Copier le docker-compose.yml

```bash
# Copier depuis le repo
cp /srv/apps/api/makla-api/MAKLA/Backend/docker-compose.yml /srv/infrastructure/

# Vérifier
cat /srv/infrastructure/docker-compose.yml
```

---

## 🔨 Étape 8 : Build l'image Docker

```bash
cd /srv/apps/api/makla-api/MAKLA/Backend

# Donner les permissions au script
chmod +x docker-build.sh
chmod +x start.sh

# Build l'image
./docker-build.sh

# Vérifier l'image
docker images | grep makla
```

---

## 🚀 Étape 9 : Lancer les services

```bash
cd /srv/infrastructure

# Lancer tous les services
docker compose up -d

# Vérifier que tout est UP
docker compose ps

# Voir les logs en temps réel
docker compose logs -f makla_api
```

**Tu devrais voir :**
```
✅ postgres_makla  Up  0.0.0.0:5433->5432/tcp
✅ redis_makla     Up  0.0.0.0:6380->6379/tcp
✅ makla_api       Up  0.0.0.0:3001->3000/tcp
```

---

## ✅ Étape 10 : Tester l'API

```bash
# Tester le endpoint health
curl http://localhost:3001/health

# Tu devrais voir :
# {"status":"ok","timestamp":"..."}

# Voir les logs
docker compose logs makla_api | tail -50
```

---

## 🌐 Étape 11 : Configurer Nginx (Optionnel)

### **Installer Nginx**

```bash
sudo apt install -y nginx
```

### **Créer la config**

```bash
sudo nano /etc/nginx/sites-available/makla.dz
```

**Copie-colle :**

```nginx
server {
    listen 80;
    server_name api.makla.dz;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### **Activer le site**

```bash
sudo ln -s /etc/nginx/sites-available/makla.dz /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### **Installer SSL (Certbot)**

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.makla.dz
```

---

## 🔄 Commandes de maintenance

### **Voir les logs**

```bash
# Logs en temps réel
docker compose logs -f makla_api

# Dernières 100 lignes
docker compose logs --tail=100 makla_api

# Tous les services
docker compose logs -f
```

### **Restart les services**

```bash
cd /srv/infrastructure

# Restart un seul service
docker compose restart makla_api

# Restart tous
docker compose restart
```

### **Mettre à jour le code**

```bash
# Pull les changements
cd /srv/apps/api/makla-api
git pull origin claude/discuss-project-B8RAy

# Rebuild l'image
cd MAKLA/Backend
docker build -t makla-backend:latest .

# Redémarrer le service
cd /srv/infrastructure
docker compose up -d --no-deps --force-recreate makla_api

# Voir les logs
docker compose logs -f makla_api
```

### **Backup de la DB**

```bash
# Backup manuel
docker exec postgres_makla pg_dump -U makla makla > /srv/backups/makla/backup-$(date +%Y%m%d-%H%M%S).sql

# Automatiser (cron tous les jours à 2h)
crontab -e

# Ajouter :
0 2 * * * docker exec postgres_makla pg_dump -U makla makla > /srv/backups/makla/backup-$(date +\%Y\%m\%d).sql
```

### **Restore de la DB**

```bash
# Arrêter l'API
docker compose stop makla_api

# Restore
docker exec -i postgres_makla psql -U makla makla < /srv/backups/makla/backup-20260210.sql

# Redémarrer
docker compose start makla_api
```

---

## 🐛 Troubleshooting

### **L'API ne démarre pas**

```bash
# Voir les logs
docker compose logs makla_api

# Vérifier les variables d'env
docker exec makla_api env | grep JWT_ACCESS_SECRET

# Vérifier la connexion DB
docker compose logs postgres_makla
```

### **Port déjà utilisé**

```bash
# Voir ce qui utilise le port 3001
sudo lsof -i :3001

# Tuer le processus
sudo kill -9 PID
```

### **Prisma migrations bloquées**

```bash
# Entrer dans le container
docker exec -it makla_api sh

# Lancer les migrations
npx prisma migrate deploy

# Voir l'état
npx prisma migrate status
```

---

## 📊 Monitoring

```bash
# Voir l'utilisation des ressources
docker stats

# Inspecter un container
docker inspect makla_api

# Santé du container
docker inspect --format='{{json .State.Health}}' makla_api | jq
```

---

## ✅ Checklist finale

- [ ] Docker installé et fonctionnel
- [ ] Dossiers créés dans /srv/
- [ ] Projet cloné dans /srv/apps/api/makla-api
- [ ] Fichier .env configuré dans /srv/infrastructure/
- [ ] Secrets JWT générés
- [ ] Image Docker buildée
- [ ] Containers démarrés (postgres, redis, makla_api)
- [ ] API accessible sur http://localhost:3001/health
- [ ] Nginx configuré (optionnel)
- [ ] SSL installé (optionnel)
- [ ] Backup automatique configuré (optionnel)

---

🎉 **Ton backend MAKLA est maintenant déployé !**

**Prochaines étapes :**
1. Tester les endpoints avec Postman
2. Configurer le DNS (pointer api.makla.dz vers ton VPS)
3. Développer l'app Flutter
4. Monitorer avec Grafana (optionnel)

---

**Support :** Si tu rencontres un problème, vérifie les logs :
```bash
docker compose logs -f makla_api
```
