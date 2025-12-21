# Guide de déploiement VetHome API 🚀

> ⚠️ **IMPORTANT** : Ce guide contient des informations critiques pour le déploiement S3 sur OVH.

## Structure des fichiers S3

La nouvelle structure organise les fichiers par utilisateur :

```
vethome/
├── {userId}/
│   ├── avatar/
│   │   └── {uuid}.jpg         # Photo de profil
│   ├── pets/
│   │   ├── {uuid}.jpg         # Photos d'animaux
│   │   └── {uuid}.jpg
│   ├── adopt/
│   │   └── {uuid}.jpg         # Photos d'adoption
│   └── products/
│       └── {uuid}.jpg         # Photos de produits
```

## Problème : Images non accessibles publiquement

### Cause

OVH Object Storage ne supporte pas l'ACL `public-read` dans les presigned URLs. Il faut définir l'ACL **après** l'upload via un appel séparé.

### Solution

L'application Flutter appelle automatiquement `/uploads/confirm` après chaque upload pour définir l'ACL.

**IMPORTANT** : Vérifiez que la variable `S3_USE_OBJECT_ACL=true` est bien dans votre `.env` :

```bash
# Sur le VPS
cd /srv/infrastructure
grep S3_USE_OBJECT_ACL .env
```

Si elle n'existe pas, ajoutez-la :

```bash
echo "S3_USE_OBJECT_ACL=true" >> /srv/infrastructure/.env
```

### Logs de débogage

Pour vérifier que l'ACL est bien défini, consultez les logs du container :

```bash
sudo docker logs -f vethome_api
```

Vous devriez voir :
```
[S3] Setting ACL public-read for: vethome/userId/avatar/uuid.jpg
[S3] ACL set successfully for: userId/avatar/uuid.jpg
```

Si vous voyez des erreurs ACL, vérifiez :
1. Que `S3_USE_OBJECT_ACL=true` dans le .env
2. Que les credentials S3 ont les permissions `s3:PutObjectAcl`
3. Que le bucket OVH autorise les ACL (vérifier dans l'interface OVH)

## Rendre publiques les images existantes

Si vous avez déjà des images uploadées qui ne sont pas accessibles, utilisez ce script :

```bash
# Installer AWS CLI si nécessaire
apt-get install -y awscli

# Configurer les credentials
export AWS_ACCESS_KEY_ID=8be211cd79404bebb5fa04fe507b443f
export AWS_SECRET_ACCESS_KEY=9c939ccc1fdb42c0ad4765b5ebcb520d
export AWS_REGION=rbx

# Rendre toutes les images publiques
aws s3 ls s3://vethome --recursive --endpoint-url https://s3.rbx.io.cloud.ovh.net | awk '{print $4}' | while read key; do
  echo "Setting ACL for: $key"
  aws s3api put-object-acl \
    --bucket vethome \
    --key "$key" \
    --acl public-read \
    --endpoint-url https://s3.rbx.io.cloud.ovh.net \
    --region rbx
done
```

## Migration des anciennes images

Si vous avez des images dans l'ancienne structure (`folder/userId/`), migrez-les vers la nouvelle structure (`userId/folder/`) :

```bash
# Script de migration
aws s3 ls s3://vethome/avatars/ --recursive --endpoint-url https://s3.rbx.io.cloud.ovh.net | awk '{print $4}' | while read oldKey; do
  # oldKey format: avatars/userId/uuid.jpg
  # newKey format: userId/avatar/uuid.jpg
  userId=$(echo $oldKey | cut -d'/' -f2)
  filename=$(echo $oldKey | cut -d'/' -f3)
  newKey="${userId}/avatar/${filename}"

  echo "Copying: $oldKey -> $newKey"
  aws s3 cp \
    "s3://vethome/$oldKey" \
    "s3://vethome/$newKey" \
    --acl public-read \
    --endpoint-url https://s3.rbx.io.cloud.ovh.net \
    --region rbx
done

# Faire de même pour pets/
aws s3 ls s3://vethome/pets/ --recursive --endpoint-url https://s3.rbx.io.cloud.ovh.net | awk '{print $4}' | while read oldKey; do
  userId=$(echo $oldKey | cut -d'/' -f2)
  filename=$(echo $oldKey | cut -d'/' -f3)
  newKey="${userId}/pets/${filename}"

  echo "Copying: $oldKey -> $newKey"
  aws s3 cp \
    "s3://vethome/$oldKey" \
    "s3://vethome/$newKey" \
    --acl public-read \
    --endpoint-url https://s3.rbx.io.cloud.ovh.net \
    --region rbx
done
```

## Mise à jour de la base de données

Après la migration des fichiers, mettez à jour les URLs dans la base de données :

```sql
-- Mettre à jour les URLs des avatars
-- Ancienne : https://vethome.s3.rbx.io.cloud.ovh.net/avatars/userId/file.jpg
-- Nouvelle : https://vethome.s3.rbx.io.cloud.ovh.net/userId/avatar/file.jpg

UPDATE "User"
SET "photoUrl" = regexp_replace(
  "photoUrl",
  'avatars/([^/]+)/',
  '\1/avatar/'
)
WHERE "photoUrl" LIKE '%avatars/%';

-- Mettre à jour les URLs des pets
UPDATE "Pet"
SET "photoUrl" = regexp_replace(
  "photoUrl",
  'pets/([^/]+)/',
  '\1/pets/'
)
WHERE "photoUrl" LIKE '%pets/%';

-- Vérifier
SELECT "photoUrl" FROM "User" WHERE "photoUrl" IS NOT NULL LIMIT 5;
SELECT "photoUrl" FROM "Pet" WHERE "photoUrl" IS NOT NULL LIMIT 5;
```

## Déploiement backend

```bash
# 1. Se connecter au VPS
ssh ubuntu@vps-ab0a0d87

# 2. Pull les changements
cd /srv/apps/api/vethome-api
git pull origin claude/docker-hot-reload-setup-01VMJZcZG8reWxrgzA8MUfWw

# 3. Vérifier la variable S3_USE_OBJECT_ACL
cd /srv/infrastructure
grep S3_USE_OBJECT_ACL .env || echo "S3_USE_OBJECT_ACL=true" >> .env

# 4. Rebuild l'image
sudo docker build -t vethome_api:v0.1 /srv/apps/api/vethome-api/lib/backend

# 5. Restart le service
sudo docker compose up -d --no-deps --force-recreate vethome_api

# 6. Vérifier les logs
sudo docker logs -f vethome_api
```

## Tests

Après le déploiement, testez l'upload d'une image depuis l'app :

1. Uploadez une nouvelle photo de profil
2. Vérifiez dans les logs que l'ACL est défini :
   ```
   [S3] Setting ACL public-read for: vethome/clxxxx/avatar/uuid.jpg
   [S3] ACL set successfully for: clxxxx/avatar/uuid.jpg
   ```
3. Vérifiez que l'image est accessible :
   ```bash
   curl -I https://vethome.s3.rbx.io.cloud.ovh.net/clxxxx/avatar/uuid.jpg
   # Devrait retourner 200 OK
   ```

## Variables d'environnement requises

Dans `/srv/infrastructure/.env` :

```bash
# S3 OVH Object Storage
S3_ACCESS_KEY_ID=8be211cd79404bebb5fa04fe507b443f
S3_SECRET_ACCESS_KEY=9c939ccc1fdb42c0ad4765b5ebcb520d
S3_BUCKET=vethome
S3_ENDPOINT=https://s3.rbx.io.cloud.ovh.net
S3_PUBLIC_ENDPOINT=https://vethome.s3.rbx.io.cloud.ovh.net
AWS_REGION=rbx
S3_FORCE_PATH_STYLE=true
S3_USE_OBJECT_ACL=true  # ← IMPORTANT !
```

Dans `/srv/infrastructure/docker-compose.yml` :

```yaml
services:
  vethome_api:
    environment:
      # ... autres variables ...
      S3_ACCESS_KEY_ID: ${S3_ACCESS_KEY_ID}
      S3_SECRET_ACCESS_KEY: ${S3_SECRET_ACCESS_KEY}
      S3_BUCKET: ${S3_BUCKET}
      S3_ENDPOINT: ${S3_ENDPOINT}
      S3_PUBLIC_ENDPOINT: ${S3_PUBLIC_ENDPOINT}
      AWS_REGION: ${AWS_REGION}
      S3_FORCE_PATH_STYLE: ${S3_FORCE_PATH_STYLE}
      S3_USE_OBJECT_ACL: ${S3_USE_OBJECT_ACL}  # ← IMPORTANT !
```
