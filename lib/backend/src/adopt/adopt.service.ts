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

@Injectable()
export class AdoptService {
  constructor(private prisma: PrismaService) {}

  // ---------- Helpers ----------
  private getUserId(user: any): string | null {
    // Accept multiple shapes coming from different auth strategies or legacy JWT payloads
    return user?.id ?? user?.userId ?? user?.sub ?? user?.payload?.sub ?? user?.payload?.id ?? null;
  }

  private requireUserId(user: any): string {
    const id = this.getUserId(user);
    if (!id) throw new ForbiddenException('Unauthorized');
    return id;
  }

  private assertOwnerOrAdmin(user: any, post: { createdById: string }) {
    const userId = this.requireUserId(user);
    if (user.role === 'ADMIN') return;
    if (userId !== post.createdById) throw new ForbiddenException('Forbidden');
  }

  private normalizeGeo(input: { lat?: number; lng?: number; mapsUrl?: string }) {
    let lat = clampLat(input.lat);
    let lng = clampLng(input.lng);
    if ((lat == null || lng == null) && input.mapsUrl) {
      const p = parseLatLngFromGoogleUrl(input.mapsUrl);
      lat = clampLat(p.lat);
      lng = clampLng(p.lng);
    }
    return { lat, lng };
  }

  private asSex(v: unknown): Sex | undefined {
    if (v == null) return undefined;
    const s = String(v).toUpperCase();
    if (s === 'M') return Sex.M;
    if (s === 'F') return Sex.F;
    if (s === 'U') return Sex.U;
    return undefined;
  }

  // ---------- Quota Helpers ----------
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

    if (!lastSwipeDay || lastSwipeDay < today) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { dailySwipeCount: 1, lastSwipeDate: now },
      });
      return;
    }

    if (user.dailySwipeCount >= MAX_SWIPES_PER_DAY) {
      throw new BadRequestException(`Quota quotidien atteint (${MAX_SWIPES_PER_DAY} swipes droits/jour)`);
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { dailySwipeCount: { increment: 1 }, lastSwipeDate: now },
    });
  }

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

    if (!lastPostDay || lastPostDay < today) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { dailyPostCount: 1, lastPostDate: now },
      });
      return;
    }

    if (user.dailyPostCount >= MAX_POSTS_PER_DAY) {
      throw new BadRequestException(`Quota quotidien atteint (${MAX_POSTS_PER_DAY} annonce/jour)`);
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { dailyPostCount: { increment: 1 }, lastPostDate: now },
    });
  }

  async getQuotas(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { dailySwipeCount: true, lastSwipeDate: true, dailyPostCount: true, lastPostDate: true },
    });

    if (!user) throw new ForbiddenException('User not found');

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const lastSwipe = user.lastSwipeDate ? new Date(user.lastSwipeDate) : null;
    const lastSwipeDay = lastSwipe ? new Date(lastSwipe.getFullYear(), lastSwipe.getMonth(), lastSwipe.getDate()) : null;
    const swipesUsed = (!lastSwipeDay || lastSwipeDay < today) ? 0 : user.dailySwipeCount;
    const swipesRemaining = Math.max(0, MAX_SWIPES_PER_DAY - swipesUsed);

    const lastPost = user.lastPostDate ? new Date(user.lastPostDate) : null;
    const lastPostDay = lastPost ? new Date(lastPost.getFullYear(), lastPost.getMonth(), lastPost.getDate()) : null;
    const postsUsed = (!lastPostDay || lastPostDay < today) ? 0 : user.dailyPostCount;
    const postsRemaining = Math.max(0, MAX_POSTS_PER_DAY - postsUsed);

    return { swipesRemaining, postsRemaining };
  }

  private toPublicImages(images: unknown): { id: string; url: string; width: number | null; height: number | null; order: number }[] {
    const arr = (Array.isArray(images) ? (images as ImgLike[]) : []) as ImgLike[];
    return arr.map((img) => ({
      id: img.id ?? '',
      url: img.url ?? '',
      width: img.width ?? null,
      height: img.height ?? null,
      order: img.order ?? 0,
    }));
  }

  private pickPublic(post: any, center?: { lat: number; lng: number }) {
    const out: any = {
      id: post.id,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      status: post.status,
      animalName: post.animalName || post.title,
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
      adoptedAt: post.adoptedAt,
      createdById: post.createdById,
      images: this.toPublicImages(post.images),
    };
    if (center && post.lat != null && post.lng != null) {
      out.distance_km = Number(haversineKm(center.lat, center.lng, post.lat, post.lng).toFixed(3));
    }
    return out;
  }

  private pickAdmin(post: any, center?: { lat: number; lng: number }) {
    const base = this.pickPublic(post, center);
    return {
      ...base,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      approvedAt: post.approvedAt,
      rejectedAt: post.rejectedAt,
      archivedAt: post.archivedAt,
      moderationNote: post.moderationNote ?? null,
      createdBy: post.createdBy
        ? {
            id: post.createdBy.id,
            firstName: post.createdBy.firstName ?? null,
            lastName: post.createdBy.lastName ?? null,
            // rétrocompatibilité avec l'ancien front
            firstname: post.createdBy.firstName ?? post.createdBy.firstname ?? null,
            lastname: post.createdBy.lastName ?? post.createdBy.lastname ?? null,
            email: post.createdBy.email,
            phone: post.createdBy.phone ?? null,
            role: post.createdBy.role,
          }
        : null,
    };
  }

  // ---------- CRUD ----------
  async create(user: any, dto: CreateAdoptPostDto) {
    const { lat, lng } = this.normalizeGeo(dto);
    const userId = this.requireUserId(user);
    await this.checkAndUpdatePostQuota(userId);
    const images = (dto.images ?? []).slice(0, MAX_IMAGES_PER_POST).map((i: any, idx: number) => ({
      url: i.url,
      width: i.width ?? null,
      height: i.height ?? null,
      order: i.order ?? idx,
    }));

    const post = await this.prisma.adoptPost.create({
      data: {
        title: dto.title,
        animalName: dto.title,
        description: dto.description ?? null,
        species: dto.species,
        sex: this.asSex(dto.sex), // <-- enum Prisma
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

    // TODO: notify admin moderation queue
    return this.pickPublic(post);
  }

  async update(user: any, id: string, dto: UpdateAdoptPostDto) {
    this.requireUserId(user);
    const existing = await this.prisma.adoptPost.findUnique({ where: { id }, include: { images: true } });
    if (!existing) throw new NotFoundException('Post not found');
    this.assertOwnerOrAdmin(user, existing);

    const { lat, lng } = this.normalizeGeo(dto);
    const maybeSex = this.asSex(dto.sex);

    const data: any = {
      title: dto.title ?? existing.title,
      description: dto.description ?? existing.description,
      species: dto.species ?? existing.species,
      sex: maybeSex ?? existing.sex, // garder enum
      ageMonths: dto.ageMonths ?? existing.ageMonths,
      size: dto.size ?? existing.size,
      color: dto.color ?? existing.color,
      city: dto.city ?? existing.city,
      address: dto.address ?? existing.address,
      mapsUrl: dto.mapsUrl ?? existing.mapsUrl,
      lat: lat ?? existing.lat,
      lng: lng ?? existing.lng,
    };

    // Images (remplacement complet si fourni)
    let imagesOut = existing.images;
    if (dto.images) {
      await this.prisma.adoptImage.deleteMany({ where: { postId: id } });
      const imgs = dto.images.slice(0, MAX_IMAGES_PER_POST).map((i: any, idx: number) => ({
        url: i.url,
        width: i.width ?? null,
        height: i.height ?? null,
        order: i.order ?? idx,
        postId: id,
      }));
      await this.prisma.adoptImage.createMany({ data: imgs });
      imagesOut = await this.prisma.adoptImage.findMany({ where: { postId: id } });
    }

    const post = await this.prisma.adoptPost.update({
      where: { id },
      data,
      include: { images: true },
    });

    return this.pickPublic({ ...post, images: imagesOut });
  }

  async remove(user: any, id: string) {
    this.requireUserId(user);
    const existing = await this.prisma.adoptPost.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Post not found');
    this.assertOwnerOrAdmin(user, existing);

    // Archivage (soft-delete)
    const post = await this.prisma.adoptPost.update({
      where: { id },
      data: { status: AdoptStatus.ARCHIVED, archivedAt: new Date() },
      include: { images: true },
    });
    return this.pickPublic(post);
  }

  async getPublic(id: string) {
    const post = await this.prisma.adoptPost.findUnique({
      where: { id },
      include: { images: true },
    });
    if (!post || post.status === AdoptStatus.ARCHIVED) throw new NotFoundException('Post not found');
    // NB: autoriser lecture PENDING/REJECTED par owner/admin via contrôleur user/admin, pas ici
    if (post.status !== AdoptStatus.APPROVED) throw new NotFoundException('Post not found');
    return this.pickPublic(post);
  }

  async listMine(user: any) {
    const userId = this.requireUserId(user);
    const rows = await this.prisma.adoptPost.findMany({
      where: { createdById: userId },
      orderBy: { updatedAt: 'desc' },
      include: { images: true },
    });
    return rows.map((r) => this.pickPublic(r));
  }

  // ---------- Feed ----------
  async feed(user: any | null, q: FeedQueryDto) {
    const limit = q.limit ?? 10;

    const where: any = { status: AdoptStatus.APPROVED };
    const and: any[] = [];
    if (q.species) where.species = q.species;
    if (q.sex) where.sex = this.asSex(q.sex);

    // Pagination cursor simple par id
    if (q.cursor) {
      const cur = await this.prisma.adoptPost.findUnique({ where: { id: q.cursor } });
      if (cur) {
        and.push({ createdAt: { lte: cur.createdAt } });
        and.push({ id: { not: q.cursor } });
      }
    }

    // Bounding-box si lat/lng
    if (q.lat != null && q.lng != null) {
      const lat = Number(q.lat), lng = Number(q.lng);
      const bb = bboxFromCenter(lat, lng, q.radiusKm ?? 40000);
      and.push({ lat: { gte: bb.minLat, lte: bb.maxLat }, lng: { gte: bb.minLng, lte: bb.maxLng } });
    }

    // Exclure ses propres posts et ceux déjà swipés pour un flux façon "Tinder"
    if (user) {
      const userId = this.getUserId(user);
      if (userId) {
        and.push({ createdById: { not: userId } });

        const seen = await this.prisma.adoptSwipe.findMany({
          where: { userId },
          select: { postId: true },
          orderBy: { updatedAt: 'desc' },
          take: 500,
        });
        const seenIds = seen.map((s) => s.postId);
        if (seenIds.length) {
          and.push({ id: { notIn: seenIds } });
        }
      }
    }

    if (and.length) {
      where.AND = and;
    }

    const rows = await this.prisma.adoptPost.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit,
      include: { images: true },
    });

    const center = (q.lat != null && q.lng != null) ? { lat: Number(q.lat), lng: Number(q.lng) } : undefined;
    const data = rows.map((r) => this.pickPublic(r, center));

    // cursor suivant
    const nextCursor = rows.length === limit ? rows[rows.length - 1].id : null;

    return { data, nextCursor };
  }

  // ---------- Swipe ----------
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

  async myLikes(user: any) {
    const userId = this.requireUserId(user);
    const rows = await this.prisma.adoptSwipe.findMany({
      where: { userId, action: SwipeAction.LIKE },
      orderBy: { createdAt: 'desc' },
      include: { post: { include: { images: true } } },
    });
    return rows
      .filter((r) => r.post && r.post.status !== AdoptStatus.ARCHIVED)
      .map((r) => this.pickPublic(r.post));
  }

  // Swipes "LIKE" reçus sur mes annonces approuvées
  async incomingRequests(user: any) {
    const userId = this.requireUserId(user);
    type IncomingLike = Prisma.AdoptSwipeGetPayload<{
      include: {
        post: { include: { images: true } };
        user: { select: { id: true; firstName: true; lastName: true; photoUrl: true } };
      };
    }>;

    const rows: IncomingLike[] = await this.prisma.adoptSwipe.findMany({
      where: {
        action: SwipeAction.LIKE,
        post: { createdById: userId, status: AdoptStatus.APPROVED },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        post: { include: { images: true } },
        user: { select: { id: true, firstName: true, lastName: true, photoUrl: true } },
      },
      take: 200,
    });

    return rows
      .filter((r) => r.post)
      .map((r) => ({
        id: r.id,
        likedAt: r.createdAt,
        liker: r.user,
        post: this.pickPublic(r.post!),
      }));
  }

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

  // ---------- Admin ----------
  async adminList(status?: AdoptStatus, limit = 30, cursor?: string) {
    const where: any = {};
    if (status) where.status = status;

    const and: any[] = [];
    if (cursor) {
      const cur = await this.prisma.adoptPost.findUnique({ where: { id: cursor } });
      if (cur) {
        and.push({ createdAt: { lte: cur.createdAt } });
        and.push({ id: { not: cursor } });
      }
    }
    if (and.length) where.AND = and;

    const [rows, grouped] = await Promise.all([
      this.prisma.adoptPost.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit,
        include: { images: true, createdBy: true },
      }),
      this.prisma.adoptPost.groupBy({ by: ['status'], _count: true }),
    ]);

    const nextCursor = rows.length === limit ? rows[rows.length - 1].id : null;
    const counts: Record<string, number> = { PENDING: 0, APPROVED: 0, REJECTED: 0, ARCHIVED: 0 };
    grouped.forEach((g) => {
      counts[g.status] = g._count;
    });

    return {
      data: rows.map((r) => this.pickAdmin(r)),
      nextCursor,
      counts,
    };
  }

  async adminApprove(_admin: any, id: string) {
    const post = await this.prisma.adoptPost.update({
      where: { id },
      data: { status: AdoptStatus.APPROVED, approvedAt: new Date(), moderationNote: null, rejectedAt: null },
      include: { images: true, createdBy: true },
    });
    // TODO: notify owner (queue)
    return this.pickAdmin(post);
  }

  async adminReject(_admin: any, id: string, note?: string) {
    const post = await this.prisma.adoptPost.update({
      where: { id },
      data: { status: AdoptStatus.REJECTED, rejectedAt: new Date(), moderationNote: note ?? null, approvedAt: null },
      include: { images: true, createdBy: true },
    });
    // TODO: notify owner (queue)
    return this.pickAdmin(post);
  }

  async adminArchive(_admin: any, id: string) {
    const post = await this.prisma.adoptPost.update({
      where: { id },
      data: { status: AdoptStatus.ARCHIVED, archivedAt: new Date() },
      include: { images: true, createdBy: true },
    });
    return this.pickAdmin(post);
  }

  async adminApproveAll(_admin: any) {
    const result = await this.prisma.adoptPost.updateMany({
      where: { status: AdoptStatus.PENDING },
      data: { status: AdoptStatus.APPROVED, approvedAt: new Date(), moderationNote: null },
    });
    return { approved: result.count };
  }
}
