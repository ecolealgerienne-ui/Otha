# Plan d'implémentation Backend - Feature Adoption

## ✅ Déjà fait

1. Schema Prisma mis à jour avec :
   - `AdoptPost` : ajout `animalName`, `adoptedAt`
   - `AdoptRequest` : demandes d'adoption (PENDING/ACCEPTED/REJECTED)
   - `AdoptConversation` : conversations anonymes
   - `AdoptMessage` : messages dans les conversations
   - `User` : quotas quotidiens (`dailySwipeCount`, `dailyPostCount`, `lastSwipeDate`, `lastPostDate`)

2. Migration SQL créée : `20251120232445_adopt_messaging_and_quotas/migration.sql`

3. Générateur de noms anonymes : `lib/backend/src/adopt/anonymous-names.util.ts`

---

## 🔧 Modifications à faire

### 1. Mettre à jour `lib/backend/src/adopt/adopt.service.ts`

#### A. Imports et constantes (lignes 1-16)

**Actuellement :**
```typescript
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAdoptPostDto } from './dto/create-adopt-post.dto';
import { UpdateAdoptPostDto } from './dto/update-adopt-post.dto';
import { FeedQueryDto } from './dto/feed.dto';
import { SwipeDto, SwipeAction } from './dto/swipe.dto';
import { AdoptStatus, Prisma, Sex } from '@prisma/client';
import { bboxFromCenter, clampLat, clampLng, haversineKm, parseLatLngFromGoogleUrl } from './geo.util';

type ImgLike = { id?: string; url?: string; width?: number | null; height?: number | null; order?: number };
```

**Remplacer par :**
```typescript
import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAdoptPostDto } from './dto/create-adopt-post.dto';
import { UpdateAdoptPostDto } from './dto/update-adopt-post.dto';
import { FeedQueryDto } from './dto/feed.dto';
import { SwipeDto, SwipeAction } from './dto/swipe.dto';
import { AdoptStatus, AdoptRequestStatus, Prisma, Sex } from '@prisma/client';
import { bboxFromCenter, clampLat, clampLng, haversineKm, parseLatLngFromGoogleUrl } from './geo.util';
import { generateAnonymousName } from './anonymous-names.util';

// Constantes de quotas et limites
const MAX_SWIPES_PER_DAY = 5;
const MAX_POSTS_PER_DAY = 1;
const MAX_IMAGES_PER_POST = 3;

type ImgLike = { id?: string; url?: string; width?: number | null; height?: number | null; order?: number };
```

#### B. Ajouter helpers de quotas (après la méthode `asSex`, vers ligne 58)

```typescript
  // ---------- Quota Helpers ----------
  /**
   * Vérifie et met à jour le quota quotidien de swipes
   * @throws BadRequestException si quota épuisé
   */
  private async checkAndUpdateSwipeQuota(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { dailySwipeCount: true, lastSwipeDate: true },
    });
    if (!user) throw new ForbiddenException('User not found');

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const lastSwipe = user.lastSwipeDate ? new Date(user.lastSwipeDate) : null;
    const lastSwipeDay = lastSwipe ? new Date(lastSwipe.getFullYear(), lastSwipe.getMonth(), lastSwipe.getDate()) : null;

    // Reset quota si nouveau jour
    if (!lastSwipeDay || lastSwipeDay < today) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { dailySwipeCount: 1, lastSwipeDate: now },
      });
      return;
    }

    // Même jour : vérifier quota
    if (user.dailySwipeCount >= MAX_SWIPES_PER_DAY) {
      throw new BadRequestException(`Quota quotidien atteint (${MAX_SWIPES_PER_DAY} swipes droits/jour)`);
    }

    // Incrémenter
    await this.prisma.user.update({
      where: { id: userId },
      data: { dailySwipeCount: { increment: 1 }, lastSwipeDate: now },
    });
  }

  /**
   * Vérifie et met à jour le quota quotidien de posts
   * @throws BadRequestException si quota épuisé
   */
  private async checkAndUpdatePostQuota(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { dailyPostCount: true, lastPostDate: true },
    });
    if (!user) throw new ForbiddenException('User not found');

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const lastPost = user.lastPostDate ? new Date(user.lastPostDate) : null;
    const lastPostDay = lastPost ? new Date(lastPost.getFullYear(), lastPost.getMonth(), lastPost.getDate()) : null;

    // Reset quota si nouveau jour
    if (!lastPostDay || lastPostDay < today) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { dailyPostCount: 1, lastPostDate: now },
      });
      return;
    }

    // Même jour : vérifier quota
    if (user.dailyPostCount >= MAX_POSTS_PER_DAY) {
      throw new BadRequestException(`Quota quotidien atteint (${MAX_POSTS_PER_DAY} annonce/jour)`);
    }

    // Incrémenter
    await this.prisma.user.update({
      where: { id: userId },
      data: { dailyPostCount: { increment: 1 }, lastPostDate: now },
    });
  }

  /**
   * Récupère les quotas restants pour un user
   */
  async getQuotas(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { dailySwipeCount: true, dailyPostCount: true, lastSwipeDate: true, lastPostDate: true },
    });
    if (!user) return { swipesRemaining: MAX_SWIPES_PER_DAY, postsRemaining: MAX_POSTS_PER_DAY };

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Swipes
    const lastSwipe = user.lastSwipeDate ? new Date(user.lastSwipeDate) : null;
    const lastSwipeDay = lastSwipe ? new Date(lastSwipe.getFullYear(), lastSwipe.getMonth(), lastSwipe.getDate()) : null;
    const swipesUsed = (!lastSwipeDay || lastSwipeDay < today) ? 0 : user.dailySwipeCount;
    const swipesRemaining = Math.max(0, MAX_SWIPES_PER_DAY - swipesUsed);

    // Posts
    const lastPost = user.lastPostDate ? new Date(user.lastPostDate) : null;
    const lastPostDay = lastPost ? new Date(lastPost.getFullYear(), lastPost.getMonth(), lastPost.getDate()) : null;
    const postsUsed = (!lastPostDay || lastPostDay < today) ? 0 : user.dailyPostCount;
    const postsRemaining = Math.max(0, MAX_POSTS_PER_DAY - postsUsed);

    return { swipesRemaining, postsRemaining };
  }
```

#### C. Modifier `pickPublic` pour ajouter `animalName` et `adoptedAt`

**Dans la méthode `pickPublic` (vers ligne 64), ajouter ces champs dans l'objet `out` :**

```typescript
  private pickPublic(post: any, center?: { lat: number; lng: number }) {
    const out: any = {
      id: post.id,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      status: post.status,
      animalName: post.animalName || post.title, // ← AJOUTER
      title: post.title,
      description: post.description,
      species: post.species,
      sex: post.sex,
      ageMonths: post.ageMonths,
      size: post.size,
      color: post.color,
      city: post.city,
      address: post.address,
      mapsUrl: post.mapsUrl,
      lat: post.lat,
      lng: post.lng,
      adoptedAt: post.adoptedAt, // ← AJOUTER
      createdById: post.createdById,
      images: this.toPublicImages(post.images),
    };
    if (center && post.lat != null && post.lng != null) {
      out.distance_km = Number(haversineKm(center.lat, center.lng, post.lat, post.lng).toFixed(3));
    }
    return out;
  }
```

#### D. Modifier la méthode `create` (vers ligne 110)

**Changer de :**
```typescript
const images = (dto.images ?? []).slice(0, 6).map(...)
```

**À :**
```typescript
const images = (dto.images ?? []).slice(0, MAX_IMAGES_PER_POST).map(...)
```

**Et ajouter vérification quota + animalName AVANT la création :**

```typescript
async create(user: any, dto: CreateAdoptPostDto) {
  const userId = this.requireUserId(user);

  // Vérifier quota quotidien
  await this.checkAndUpdatePostQuota(userId);

  const { lat, lng } = this.normalizeGeo(dto);
  const images = (dto.images ?? []).slice(0, MAX_IMAGES_PER_POST).map((i: any, idx: number) => ({
    url: i.url,
    width: i.width ?? null,
    height: i.height ?? null,
    order: i.order ?? idx,
  }));

  const post = await this.prisma.adoptPost.create({
    data: {
      animalName: dto.title, // Utiliser title comme animalName pour compatibilité
      title: dto.title,
      description: dto.description ?? null,
      species: dto.species,
      sex: this.asSex(dto.sex),
      ageMonths: dto.ageMonths ?? null,
      size: dto.size ?? null,
      color: dto.color ?? null,
      city: dto.city ?? null,
      address: dto.address ?? null,
      mapsUrl: dto.mapsUrl ?? null,
      lat: lat ?? null,
      lng: lng ?? null,
      createdById: userId,
      status: AdoptStatus.PENDING,
      images: { create: images },
    },
    include: { images: true },
  });

  return this.pickPublic(post);
}
```

#### E. Modifier la méthode `update` (vers ligne 145)

**Changer limite images de 6 à 3 :**

```typescript
const imgs = dto.images.slice(0, MAX_IMAGES_PER_POST).map(...)
```

#### F. Modifier la méthode `feed` (vers ligne 234)

**Changer le default limit à 10 :**

```typescript
async feed(user: any | null, q: FeedQueryDto) {
  const limit = q.limit ?? 10; // ← Changer de 20 à 10
  // ... reste du code identique
}
```

#### G. Modifier complètement la méthode `swipe` (vers ligne 297)

**Remplacer toute la méthode par :**

```typescript
async swipe(user: any, postId: string, dto: SwipeDto) {
  const userId = this.requireUserId(user);
  const post = await this.prisma.adoptPost.findUnique({ where: { id: postId } });

  if (!post || post.status !== AdoptStatus.APPROVED) {
    throw new NotFoundException('Post not found');
  }
  if (post.createdById === userId) {
    throw new ForbiddenException('Cannot swipe own post');
  }

  // Vérifier si déjà adopté
  if (post.adoptedAt) {
    return {
      ok: false,
      action: dto.action,
      message: 'Cet animal a déjà été adopté',
      alreadyAdopted: true,
    };
  }

  // Vérifier quota uniquement pour LIKE
  if (dto.action === SwipeAction.LIKE) {
    await this.checkAndUpdateSwipeQuota(userId);
  }

  // Upsert swipe
  const rec = await this.prisma.adoptSwipe.upsert({
    where: { userId_postId: { userId, postId } },
    create: { userId, postId, action: dto.action },
    update: { action: dto.action },
  });

  // Si LIKE, créer une demande d'adoption
  if (dto.action === SwipeAction.LIKE) {
    await this.prisma.adoptRequest.upsert({
      where: { requesterId_postId: { requesterId: userId, postId } },
      create: {
        requesterId: userId,
        postId,
        status: AdoptRequestStatus.PENDING,
      },
      update: {
        status: AdoptRequestStatus.PENDING, // Réactiver si refusée avant
      },
    });
  }

  return { ok: true, action: rec.action };
}
```

#### H. Ajouter nouvelles méthodes pour les REQUESTS (après la méthode `incomingRequests`)

```typescript
// ---------- Adoption Requests ----------

/**
 * Liste des demandes d'adoption reçues sur mes annonces
 */
async myIncomingRequests(user: any) {
  const userId = this.requireUserId(user);

  const requests = await this.prisma.adoptRequest.findMany({
    where: {
      post: { createdById: userId },
      status: AdoptRequestStatus.PENDING,
    },
    include: {
      requester: {
        select: { id: true, firstName: true, lastName: true, photoUrl: true },
      },
      post: {
        include: { images: true },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  return requests.map((r) => ({
    id: r.id,
    createdAt: r.createdAt,
    status: r.status,
    requester: {
      id: r.requester.id,
      // Ne pas exposer le vrai nom - sera anonymisé dans la conversation
      anonymousName: generateAnonymousName(r.requester.id),
    },
    post: this.pickPublic(r.post),
  }));
}

/**
 * Mes demandes envoyées
 */
async myOutgoingRequests(user: any) {
  const userId = this.requireUserId(user);

  const requests = await this.prisma.adoptRequest.findMany({
    where: { requesterId: userId },
    include: {
      post: {
        include: { images: true, createdBy: true },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  return requests.map((r) => ({
    id: r.id,
    createdAt: r.createdAt,
    status: r.status,
    post: this.pickPublic(r.post),
  }));
}

/**
 * Accepter une demande d'adoption → crée la conversation
 */
async acceptRequest(user: any, requestId: string) {
  const userId = this.requireUserId(user);

  const request = await this.prisma.adoptRequest.findUnique({
    where: { id: requestId },
    include: { post: true },
  });

  if (!request) throw new NotFoundException('Request not found');
  if (request.post.createdById !== userId) {
    throw new ForbiddenException('Not your post');
  }
  if (request.status !== AdoptRequestStatus.PENDING) {
    throw new BadRequestException('Request already processed');
  }

  // Créer la conversation
  const conversation = await this.prisma.adoptConversation.create({
    data: {
      postId: request.postId,
      ownerId: userId,
      adopterId: request.requesterId,
      ownerAnonymousName: generateAnonymousName(userId),
      adopterAnonymousName: generateAnonymousName(request.requesterId),
    },
  });

  // Mettre à jour la demande
  await this.prisma.adoptRequest.update({
    where: { id: requestId },
    data: {
      status: AdoptRequestStatus.ACCEPTED,
      conversationId: conversation.id,
    },
  });

  return {
    ok: true,
    conversationId: conversation.id,
  };
}

/**
 * Refuser une demande d'adoption
 */
async rejectRequest(user: any, requestId: string) {
  const userId = this.requireUserId(user);

  const request = await this.prisma.adoptRequest.findUnique({
    where: { id: requestId },
    include: { post: true },
  });

  if (!request) throw new NotFoundException('Request not found');
  if (request.post.createdById !== userId) {
    throw new ForbiddenException('Not your post');
  }
  if (request.status !== AdoptRequestStatus.PENDING) {
    throw new BadRequestException('Request already processed');
  }

  await this.prisma.adoptRequest.update({
    where: { id: requestId },
    data: { status: AdoptRequestStatus.REJECTED },
  });

  return { ok: true };
}

// ---------- Conversations & Messages ----------

/**
 * Liste de mes conversations
 */
async myConversations(user: any) {
  const userId = this.requireUserId(user);

  const conversations = await this.prisma.adoptConversation.findMany({
    where: {
      OR: [
        { ownerId: userId },
        { adopterId: userId },
      ],
    },
    include: {
      post: { include: { images: true } },
      messages: {
        orderBy: { createdAt: 'desc' },
        take: 1, // Dernier message pour preview
      },
    },
    orderBy: { updatedAt: 'desc' },
  });

  return conversations.map((c) => {
    const isOwner = c.ownerId === userId;
    const lastMessage = c.messages[0];

    return {
      id: c.id,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
      post: this.pickPublic(c.post),
      myRole: isOwner ? 'owner' : 'adopter',
      otherPersonName: isOwner ? c.adopterAnonymousName : c.ownerAnonymousName,
      lastMessage: lastMessage ? {
        content: lastMessage.content,
        sentAt: lastMessage.createdAt,
        sentByMe: lastMessage.senderId === userId,
      } : null,
    };
  });
}

/**
 * Messages d'une conversation
 */
async getConversationMessages(user: any, conversationId: string) {
  const userId = this.requireUserId(user);

  const conversation = await this.prisma.adoptConversation.findUnique({
    where: { id: conversationId },
    include: {
      post: { include: { images: true } },
      messages: {
        orderBy: { createdAt: 'asc' },
      },
    },
  });

  if (!conversation) throw new NotFoundException('Conversation not found');

  // Vérifier accès
  if (conversation.ownerId !== userId && conversation.adopterId !== userId) {
    throw new ForbiddenException('Not your conversation');
  }

  const isOwner = conversation.ownerId === userId;

  // Marquer messages comme lus
  await this.prisma.adoptMessage.updateMany({
    where: {
      conversationId,
      senderId: { not: userId },
      readAt: null,
    },
    data: { readAt: new Date() },
  });

  return {
    id: conversation.id,
    post: this.pickPublic(conversation.post),
    myRole: isOwner ? 'owner' : 'adopter',
    myAnonymousName: isOwner ? conversation.ownerAnonymousName : conversation.adopterAnonymousName,
    otherPersonName: isOwner ? conversation.adopterAnonymousName : conversation.ownerAnonymousName,
    messages: conversation.messages.map((m) => ({
      id: m.id,
      content: m.content,
      sentAt: m.createdAt,
      sentByMe: m.senderId === userId,
      senderName: m.senderId === userId
        ? (isOwner ? conversation.ownerAnonymousName : conversation.adopterAnonymousName)
        : (isOwner ? conversation.adopterAnonymousName : conversation.ownerAnonymousName),
      read: !!m.readAt,
    })),
  };
}

/**
 * Envoyer un message dans une conversation
 */
async sendMessage(user: any, conversationId: string, content: string) {
  const userId = this.requireUserId(user);

  const conversation = await this.prisma.adoptConversation.findUnique({
    where: { id: conversationId },
  });

  if (!conversation) throw new NotFoundException('Conversation not found');

  // Vérifier accès
  if (conversation.ownerId !== userId && conversation.adopterId !== userId) {
    throw new ForbiddenException('Not your conversation');
  }

  const message = await this.prisma.adoptMessage.create({
    data: {
      conversationId,
      senderId: userId,
      content,
    },
  });

  // Mettre à jour conversation.updatedAt
  await this.prisma.adoptConversation.update({
    where: { id: conversationId },
    data: { updatedAt: new Date() },
  });

  return {
    id: message.id,
    content: message.content,
    sentAt: message.createdAt,
  };
}

/**
 * Marquer une annonce comme adoptée
 */
async markAsAdopted(user: any, postId: string) {
  const userId = this.requireUserId(user);

  const post = await this.prisma.adoptPost.findUnique({ where: { id: postId } });
  if (!post) throw new NotFoundException('Post not found');
  if (post.createdById !== userId) {
    throw new ForbiddenException('Not your post');
  }

  await this.prisma.adoptPost.update({
    where: { id: postId },
    data: { adoptedAt: new Date() },
  });

  return { ok: true };
}
```

---

### 2. Créer les DTOs manquants

#### `lib/backend/src/adopt/dto/create-adopt-post.dto.ts`

**Ajouter le champ `animalName` (optionnel pour compatibilité) :**

```typescript
import { IsString, IsOptional, IsInt, Min, Max, IsUrl, IsArray, ValidateNested, MaxLength, IsEnum } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum AdoptSex {
  M = 'M',
  F = 'F',
  U = 'U',
}

class AdoptImageDto {
  @ApiProperty() @IsString() url: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() width?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() height?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() order?: number;
}

export class CreateAdoptPostDto {
  @ApiProperty({ maxLength: 140 })
  @IsString()
  @MaxLength(140)
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  animalName?: string; // ← AJOUTER (optionnel, fallback sur title)

  @ApiPropertyOptional({ maxLength: 2000 })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiProperty()
  @IsString()
  species: string;

  @ApiPropertyOptional({ enum: AdoptSex })
  @IsOptional()
  @IsEnum(AdoptSex)
  sex?: AdoptSex;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(600)
  ageMonths?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  size?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  color?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl()
  mapsUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  lat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  lng?: number;

  @ApiPropertyOptional({ type: [AdoptImageDto], maxItems: 3 })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AdoptImageDto)
  images?: AdoptImageDto[];
}
```

#### Créer `lib/backend/src/adopt/dto/send-message.dto.ts`

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

---

### 3. Mettre à jour `lib/backend/src/adopt/adopt.controller.ts`

**Ajouter ces nouveaux endpoints :**

```typescript
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { AdoptService } from './adopt.service';
import { CreateAdoptPostDto } from './dto/create-adopt-post.dto';
import { UpdateAdoptPostDto } from './dto/update-adopt-post.dto';
import { FeedQueryDto } from './dto/feed.dto';
import { SwipeDto } from './dto/swipe.dto';
import { SendMessageDto } from './dto/send-message.dto';

@Controller({ path: 'adopt', version: '1' })
export class AdoptController {
  constructor(private readonly adoptService: AdoptService) {}

  // ====== Feed public ======
  @Get('feed')
  async feed(@Query() q: FeedQueryDto, @Req() req: any) {
    const user = req.user ?? null;
    return this.adoptService.feed(user, q);
  }

  @Get('posts/:id')
  async getPost(@Param('id') id: string) {
    return this.adoptService.getPublic(id);
  }

  // ====== Posts (authentifié) ======
  @UseGuards(JwtAuthGuard)
  @Post('posts')
  async create(@Req() req: any, @Body() dto: CreateAdoptPostDto) {
    return this.adoptService.create(req.user, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('posts/:id')
  async update(@Req() req: any, @Param('id') id: string, @Body() dto: UpdateAdoptPostDto) {
    return this.adoptService.update(req.user, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('posts/:id')
  async remove(@Req() req: any, @Param('id') id: string) {
    return this.adoptService.remove(req.user, id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('my/posts')
  async myPosts(@Req() req: any) {
    return this.adoptService.listMine(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('posts/:id/adopted')
  async markAdopted(@Req() req: any, @Param('id') id: string) {
    return this.adoptService.markAsAdopted(req.user, id);
  }

  // ====== Swipe ======
  @UseGuards(JwtAuthGuard)
  @Post('posts/:id/swipe')
  async swipe(@Req() req: any, @Param('id') id: string, @Body() dto: SwipeDto) {
    return this.adoptService.swipe(req.user, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('my/likes')
  async myLikes(@Req() req: any) {
    return this.adoptService.myLikes(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('my/quotas')
  async myQuotas(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    return this.adoptService.getQuotas(userId);
  }

  // ====== Requests (demandes d'adoption) ======
  @UseGuards(JwtAuthGuard)
  @Get('my/requests/incoming')
  async incomingRequests(@Req() req: any) {
    return this.adoptService.myIncomingRequests(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('my/requests/outgoing')
  async outgoingRequests(@Req() req: any) {
    return this.adoptService.myOutgoingRequests(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('requests/:id/accept')
  async acceptRequest(@Req() req: any, @Param('id') id: string) {
    return this.adoptService.acceptRequest(req.user, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('requests/:id/reject')
  async rejectRequest(@Req() req: any, @Param('id') id: string) {
    return this.adoptService.rejectRequest(req.user, id);
  }

  // ====== Conversations & Messages ======
  @UseGuards(JwtAuthGuard)
  @Get('my/conversations')
  async myConversations(@Req() req: any) {
    return this.adoptService.myConversations(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('conversations/:id/messages')
  async getMessages(@Req() req: any, @Param('id') id: string) {
    return this.adoptService.getConversationMessages(req.user, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('conversations/:id/messages')
  async sendMessage(@Req() req: any, @Param('id') id: string, @Body() dto: SendMessageDto) {
    return this.adoptService.sendMessage(req.user, id, dto.content);
  }
}
```

---

## 🧪 Test

Après implémentation, tester :

```bash
cd /home/user/Otha/lib/backend
npm run build
```

Si erreurs TypeScript, les corriger avant de continuer.

---

## 📝 Endpoints créés

### Publics
- `GET /api/v1/adopt/feed` - Feed d'annonces (10 par page)
- `GET /api/v1/adopt/posts/:id` - Détail annonce

### Authentifiés
- `POST /api/v1/adopt/posts` - Créer annonce (quota: 1/jour, max 3 images)
- `PATCH /api/v1/adopt/posts/:id` - Modifier annonce
- `DELETE /api/v1/adopt/posts/:id` - Supprimer (archiver) annonce
- `GET /api/v1/adopt/my/posts` - Mes annonces
- `POST /api/v1/adopt/posts/:id/adopted` - Marquer comme adopté
- `POST /api/v1/adopt/posts/:id/swipe` - Swiper (quota: 5 LIKE/jour)
- `GET /api/v1/adopt/my/likes` - Mes likes
- `GET /api/v1/adopt/my/quotas` - Mes quotas restants
- `GET /api/v1/adopt/my/requests/incoming` - Demandes reçues
- `GET /api/v1/adopt/my/requests/outgoing` - Demandes envoyées
- `POST /api/v1/adopt/requests/:id/accept` - Accepter demande
- `POST /api/v1/adopt/requests/:id/reject` - Refuser demande
- `GET /api/v1/adopt/my/conversations` - Mes conversations
- `GET /api/v1/adopt/conversations/:id/messages` - Messages conversation
- `POST /api/v1/adopt/conversations/:id/messages` - Envoyer message

### Admin (déjà existants, pas modifiés)
- `GET /api/v1/admin/adopt/posts`
- `PATCH /api/v1/admin/adopt/posts/:id/approve`
- `PATCH /api/v1/admin/adopt/posts/:id/reject`
- `PATCH /api/v1/admin/adopt/posts/:id/archive`
