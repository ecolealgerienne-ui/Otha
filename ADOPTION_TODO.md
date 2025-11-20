# Adoption Feature - TODO Backend

## ✅ Terminé

1. ✅ Schema Prisma complet (models, enums, quotas)
2. ✅ Migration SQL créée
3. ✅ Générateur de noms anonymes (`anonymous-names.util.ts`)
4. ✅ Plan d'implémentation détaillé (`ADOPTION_BACKEND_PLAN.md`)
5. ✅ Imports et constantes ajoutés à adopt.service.ts

## 🔧 À faire (code complet dans ADOPTION_BACKEND_PLAN.md)

### 1. `lib/backend/src/adopt/adopt.service.ts`

**Insérer après la méthode `asSex()` (ligne ~58) :**
- Helpers de quotas : `checkAndUpdateSwipeQuota()`, `checkAndUpdatePostQuota()`, `getQuotas()`

**Modifier méthode `pickPublic()` (ligne ~64) :**
- Ajouter `animalName: post.animalName || post.title,` dans l'objet retourné
- Ajouter `adoptedAt: post.adoptedAt,` dans l'objet retourné

**Modifier méthode `create()` (ligne ~110) :**
- Ajouter `await this.checkAndUpdatePostQuota(userId);` au début
- Changer `.slice(0, 6)` en `.slice(0, MAX_IMAGES_PER_POST)`
- Ajouter `animalName: dto.title,` dans le `create()`

**Modifier méthode `update()` (ligne ~145) :**
- Changer `.slice(0, 6)` en `.slice(0, MAX_IMAGES_PER_POST)`

**Modifier méthode `feed()` (ligne ~234) :**
- Changer `const limit = q.limit ?? 20;` en `const limit = q.limit ?? 10;`

**Modifier complètement méthode `swipe()` (ligne ~297) :**
- Voir code complet dans ADOPTION_BACKEND_PLAN.md section F
- Ajoute vérification quota + création AdoptRequest automatique

**Ajouter AVANT la section Admin (ligne ~358) :**

Toutes ces nouvelles méthodes (code complet dans le plan) :
- `myIncomingRequests(user)` - Demandes reçues sur mes annonces
- `myOutgoingRequests(user)` - Mes demandes envoyées
- `acceptRequest(user, requestId)` - Accepter demande → crée conversation
- `rejectRequest(user, requestId)` - Refuser demande
- `myConversations(user)` - Liste mes conversations
- `getConversationMessages(user, conversationId)` - Messages conversation
- `sendMessage(user, conversationId, content)` - Envoyer message
- `markAsAdopted(user, postId)` - Marquer annonce adoptée

### 2. `lib/backend/src/adopt/dto/send-message.dto.ts` (CRÉER)

```typescript
import { IsString, MinLength, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendMessageDto {
  @ApiProperty({ minLength: 1, maxLength: 5000 })
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  content: string;
}
```

### 3. `lib/backend/src/adopt/dto/create-adopt-post.dto.ts` (MODIFIER)

Ajouter après `title` :
```typescript
@ApiPropertyOptional()
@IsOptional()
@IsString()
@MaxLength(100)
animalName?: string;
```

Modifier:
```typescript
@ApiPropertyOptional({ type: [AdoptImageDto], maxItems: 3 }) // était 6
```

### 4. `lib/backend/src/adopt/adopt.controller.ts` (REMPLACER COMPLÈTEMENT)

Voir code complet dans ADOPTION_BACKEND_PLAN.md section 3.

Nouveaux endpoints à ajouter:
- `GET /my/quotas` - Quotas restants
- `POST /posts/:id/adopted` - Marquer adopté
- `GET /my/requests/incoming` - Demandes reçues
- `GET /my/requests/outgoing` - Demandes envoyées
- `POST /requests/:id/accept` - Accepter
- `POST /requests/:id/reject` - Refuser
- `GET /my/conversations` - Conversations
- `GET /conversations/:id/messages` - Messages
- `POST /conversations/:id/messages` - Envoyer message

## 🧪 Test

```bash
cd /home/user/Otha/lib/backend
npm run build
```

## 📊 Statistiques

- **Lignes de code à ajouter**: ~600 lignes
- **Nouveaux endpoints**: 9
- **Nouvelles méthodes service**: 8
- **DTOs à créer/modifier**: 2

## 🚀 Déploiement

Après implémentation et test compilation:

```bash
# 1. Merge la PR sur GitHub
# 2. Sur le VPS:
cd /srv/apps/api/vethome-api
git pull origin main
npm install
npx prisma migrate deploy  # ← IMPORTANT: Appliquer la migration!
sudo docker build -t vethome_api:v0.1 /srv/apps/api/vethome-api/lib/backend
sudo docker compose up -d --no-deps --force-recreate vethome_api
```
