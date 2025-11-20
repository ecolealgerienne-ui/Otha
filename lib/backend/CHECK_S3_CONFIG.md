# Vérification configuration S3 ✅

**Dernière mise à jour** : 20/11/2025

## Problème : Erreur 400 lors de l'upload S3

L'erreur 400 de S3 signifie généralement :
1. **Credentials invalides** ou mal configurées
2. **Headers ne correspondent pas** à la signature de la presigned URL
3. **Region incorrecte** ou endpoint mal configuré

## Vérifications à faire

### 1. Vérifier les credentials dans le container

```bash
# Voir les variables d'environnement S3 du container
sudo docker exec vethome_api env | grep -E "S3_|AWS_"
```

Vous devriez voir :
```
S3_ACCESS_KEY_ID=8be211cd79404bebb5fa04fe507b443f
S3_SECRET_ACCESS_KEY=9c939ccc1fdb42c0ad4765b5ebcb520d
S3_BUCKET=vethome
S3_ENDPOINT=https://s3.rbx.io.cloud.ovh.net
S3_PUBLIC_ENDPOINT=https://vethome.s3.rbx.io.cloud.ovh.net
AWS_REGION=rbx
S3_FORCE_PATH_STYLE=true
S3_USE_OBJECT_ACL=true
```

### 2. Ajouter AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY

Le SDK AWS S3 cherche aussi les variables standard AWS. Dans `/srv/infrastructure/docker-compose.yml`, ajoutez :

```yaml
services:
  vethome_api:
    environment:
      # ... autres variables ...

      # Credentials S3 (format custom)
      S3_ACCESS_KEY_ID: ${S3_ACCESS_KEY_ID}
      S3_SECRET_ACCESS_KEY: ${S3_SECRET_ACCESS_KEY}

      # Credentials AWS (format standard pour SDK)
      AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY: ${S3_SECRET_ACCESS_KEY}
      AWS_REGION: ${AWS_REGION}

      # Config S3
      S3_BUCKET: ${S3_BUCKET}
      S3_ENDPOINT: ${S3_ENDPOINT}
      S3_PUBLIC_ENDPOINT: ${S3_PUBLIC_ENDPOINT}
      S3_FORCE_PATH_STYLE: ${S3_FORCE_PATH_STYLE}
      S3_USE_OBJECT_ACL: ${S3_USE_OBJECT_ACL}
```

### 3. Tester manuellement la presigned URL

Créez un fichier test et uploadez-le avec curl :

```bash
# 1. Générer une presigned URL depuis l'API
curl -X POST https://api.piecespro.com/api/v1/uploads/presign \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"mimeType":"image/jpeg","folder":"avatar","ext":"jpg"}' \
  | jq '.'

# 2. Récupérer l'URL retournée et tester l'upload
echo "test content" > test.jpg

curl -X PUT "PRESIGNED_URL_ICI" \
  -H "Content-Type: image/jpeg" \
  --data-binary @test.jpg \
  -v

# Si ça retourne 200 OK, le problème vient de Flutter
# Si ça retourne 400, le problème est dans la génération de la presigned URL
```

### 4. Vérifier les permissions du user S3 OVH

Connectez-vous à l'interface OVH et vérifiez que l'utilisateur S3 a les permissions :
- `s3:PutObject`
- `s3:PutObjectAcl`
- `s3:GetObject`

### 5. Debug détaillé côté backend

Ajoutez des logs dans `uploads.controller.ts` :

```typescript
@Post('presign')
async presign(
  @Req() req: Request & { user: { sub: string } },
  @Body() body: { mimeType: string; folder?: string; ext?: string },
) {
  console.log('[S3] Generating presigned URL with config:', {
    region: process.env.AWS_REGION,
    endpoint: process.env.S3_ENDPOINT,
    bucket: process.env.S3_BUCKET,
    forcePathStyle: process.env.S3_FORCE_PATH_STYLE,
    hasCredentials: !!(process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY),
  });

  // ... reste du code

  console.log('[S3] Generated presigned URL:', { key, url: url.substring(0, 100) + '...' });
  return { url, key, bucket, publicUrl, requiredHeaders, needsConfirm };
}
```

Puis regardez les logs :
```bash
sudo docker logs -f vethome_api | grep S3
```

## Solution probable

Le problème est très probablement que les **credentials AWS ne sont pas passées au SDK**.

**FIX** : Ajoutez dans docker-compose.yml :
```yaml
AWS_ACCESS_KEY_ID: ${S3_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY: ${S3_SECRET_ACCESS_KEY}
AWS_REGION: ${AWS_REGION}
```

Puis rebuild et restart :
```bash
sudo docker compose up -d --no-deps --force-recreate vethome_api
```
