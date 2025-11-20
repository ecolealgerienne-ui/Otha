# Guide de déploiement - VetHome API

## Variables S3 manquantes dans docker-compose.yml

Le fichier `/srv/infrastructure/docker-compose.yml` sur le VPS doit être mis à jour pour inclure les variables S3 manquantes.

### Variables à ajouter dans la section `vethome_api.environment`

```yaml
services:
  vethome_api:
    environment:
      # ... variables existantes ...

      # Ajouter ces 3 lignes manquantes :
      S3_PUBLIC_ENDPOINT: ${S3_PUBLIC_ENDPOINT}
      AWS_REGION: ${AWS_REGION}
      S3_USE_OBJECT_ACL: ${S3_USE_OBJECT_ACL}
```

### Commandes de déploiement complètes

```bash
# 1. Se connecter au VPS
ssh ubuntu@vps-ab0a0d87

# 2. Mettre à jour docker-compose.yml
sudo nano /srv/infrastructure/docker-compose.yml

# Dans la section vethome_api -> environment, ajouter après S3_FORCE_PATH_STYLE :
#   S3_PUBLIC_ENDPOINT: ${S3_PUBLIC_ENDPOINT}
#   AWS_REGION: ${AWS_REGION}
#   S3_USE_OBJECT_ACL: ${S3_USE_OBJECT_ACL}

# 3. Pull des derniers changements
cd /srv/apps/api/vethome-api
git pull origin claude/docker-hot-reload-setup-01VMJZcZG8reWxrgzA8MUfWw

# 4. Appliquer la migration Prisma
cd /srv/apps/api/vethome-api/backend
npx prisma migrate dev --name add_pet_fields

# OU en production :
npx prisma migrate deploy

# 5. Rebuild l'image Docker
cd /srv/infrastructure
sudo docker build -t vethome_api:v0.1 /srv/apps/api/vethome-api/backend

# 6. Restart le service
sudo docker compose up -d --no-deps --force-recreate vethome_api

# 7. Vérifier les logs
sudo docker logs -f vethome_api
```

## Nouveaux champs Pet

La migration Prisma ajoutera ces nouveaux champs au modèle Pet :

- `birthDate` (DateTime?) - Date de naissance de l'animal
- `microchipNumber` (String?) - Numéro de puce électronique
- `allergiesNotes` (String?) - Notes sur les allergies et conditions médicales
- `description` (String?) - Description détaillée de l'animal

## Nouveau endpoint S3

### POST /v1/uploads/confirm

Endpoint pour définir l'ACL public-read après l'upload S3 (nécessaire pour OVH).

**Body:**
```json
{
  "key": "pets/userId/filename.jpg"
}
```

**Response:**
```json
{
  "success": true
}
```

## Service de nettoyage S3

Le S3Service nettoie automatiquement les anciennes images lorsque :
- Un utilisateur met à jour son avatar
- Un pet est mis à jour avec une nouvelle photo
- Un pet est supprimé

## Développement local

Pour le développement local avec hot-reload :

```bash
cd backend

# Copier le .env
cp .env.example .env
# Renseigner les variables S3_ACCESS_KEY_ID et S3_SECRET_ACCESS_KEY

# Lancer les services
docker-compose -f docker-compose.dev.yml up
```

Accès :
- API : http://localhost:3000
- MailDev : http://localhost:1080
- PostgreSQL : localhost:5432
- Redis : localhost:6379
