import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CareerStatus, CareerType, Role } from '@prisma/client';
import { CreateCareerPostDto } from './dto/create-career-post.dto';
import { UpdateCareerPostDto } from './dto/update-career-post.dto';
import { CareerFeedQueryDto } from './dto/feed.dto';

// Noms anonymes pour les conversations entre clients
const ANONYMOUS_NAMES = [
  'Étoile Brillante', 'Cœur Vaillant', 'Esprit Libre', 'Âme Généreuse',
  'Lumière Douce', 'Vent Frais', 'Horizon Lointain', 'Rêveur Éveillé',
  'Voyageur Sage', 'Gardien Bienveillant', 'Explorateur Curieux', 'Penseur Profond',
];

@Injectable()
export class CareerService {
  constructor(private prisma: PrismaService) {}

  private requireUserId(user: any): string {
    const userId = user?.id ?? user?.sub;
    if (!userId) throw new ForbiddenException('User ID required');
    return userId;
  }

  private isPro(user: any): boolean {
    return user?.role === Role.PRO || user?.role === Role.ADMIN;
  }

  private getRandomAnonymousName(): string {
    return ANONYMOUS_NAMES[Math.floor(Math.random() * ANONYMOUS_NAMES.length)];
  }

  // ==================== FEED ====================

  async feed(user: any, query: CareerFeedQueryDto) {
    const userId = this.requireUserId(user);
    const userIsPro = this.isPro(user);
    const limit = Math.min(query.limit ?? 20, 50);

    const where: any = {
      status: CareerStatus.APPROVED,
    };

    if (query.type) {
      where.type = query.type;
    }

    if (query.city) {
      where.city = { contains: query.city, mode: 'insensitive' };
    }

    if (query.domain) {
      where.domain = { contains: query.domain, mode: 'insensitive' };
    }

    if (query.cursor) {
      where.id = { lt: query.cursor };
    }

    const posts = await this.prisma.careerPost.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      include: {
        createdBy: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            photoUrl: true,
            role: true,
          },
        },
      },
    });

    const hasMore = posts.length > limit;
    if (hasMore) posts.pop();

    // Filtrer les infos privées pour les non-pros
    const sanitizedPosts = posts.map((post) => {
      const isOwnPost = post.createdById === userId;
      const canSeePrivate = userIsPro || isOwnPost || post.type === CareerType.OFFER;

      return {
        id: post.id,
        type: post.type,
        title: post.title,
        publicBio: post.publicBio,
        city: post.city,
        domain: post.domain,
        duration: post.duration,
        createdAt: post.createdAt,
        // Infos privées (seulement pour pros ou propre annonce ou offres)
        ...(canSeePrivate && {
          fullName: post.fullName,
          email: post.email,
          phone: post.phone,
          detailedBio: post.detailedBio,
          cvImageUrl: post.cvImageUrl,
        }),
        // Infos offre
        ...(post.type === CareerType.OFFER && {
          salary: post.salary,
          requirements: post.requirements,
        }),
        createdBy: canSeePrivate
          ? post.createdBy
          : { id: post.createdBy.id, photoUrl: post.createdBy.photoUrl },
        isOwn: isOwnPost,
      };
    });

    return {
      data: sanitizedPosts,
      nextCursor: hasMore ? posts[posts.length - 1]?.id : null,
    };
  }

  // ==================== GET PUBLIC POST ====================

  async getPublic(id: string, user?: any) {
    const userId = user ? this.requireUserId(user) : null;
    const userIsPro = user ? this.isPro(user) : false;

    const post = await this.prisma.careerPost.findUnique({
      where: { id },
      include: {
        createdBy: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            photoUrl: true,
            role: true,
          },
        },
      },
    });

    if (!post) throw new NotFoundException('Post not found');
    if (post.status !== CareerStatus.APPROVED && post.createdById !== userId) {
      throw new NotFoundException('Post not found');
    }

    const isOwnPost = post.createdById === userId;
    const canSeePrivate = userIsPro || isOwnPost || post.type === CareerType.OFFER;

    return {
      id: post.id,
      type: post.type,
      status: post.status,
      title: post.title,
      publicBio: post.publicBio,
      city: post.city,
      domain: post.domain,
      duration: post.duration,
      createdAt: post.createdAt,
      ...(canSeePrivate && {
        fullName: post.fullName,
        email: post.email,
        phone: post.phone,
        detailedBio: post.detailedBio,
        cvImageUrl: post.cvImageUrl,
      }),
      ...(post.type === CareerType.OFFER && {
        salary: post.salary,
        requirements: post.requirements,
      }),
      createdBy: canSeePrivate
        ? post.createdBy
        : { id: post.createdBy.id, photoUrl: post.createdBy.photoUrl },
      isOwn: isOwnPost,
    };
  }

  // ==================== CREATE POST ====================

  async create(user: any, dto: CreateCareerPostDto) {
    const userId = this.requireUserId(user);

    // Vérifier si l'utilisateur a déjà un post de ce type
    const existing = await this.prisma.careerPost.findFirst({
      where: {
        createdById: userId,
        type: dto.type as CareerType,
        status: { not: CareerStatus.ARCHIVED },
      },
    });

    if (existing) {
      throw new BadRequestException(
        `Vous avez déjà une annonce de type ${dto.type === 'REQUEST' ? 'demande' : 'offre'}. Vous devez la supprimer ou l'archiver avant d'en créer une nouvelle.`,
      );
    }

    // Si c'est une OFFER, vérifier que l'utilisateur est un PRO
    if (dto.type === 'OFFER' && !this.isPro(user)) {
      throw new ForbiddenException('Seuls les professionnels peuvent publier des offres');
    }

    const post = await this.prisma.careerPost.create({
      data: {
        type: dto.type as CareerType,
        title: dto.title,
        publicBio: dto.publicBio,
        city: dto.city,
        domain: dto.domain,
        duration: dto.duration,
        fullName: dto.fullName,
        email: dto.email,
        phone: dto.phone,
        detailedBio: dto.detailedBio,
        cvImageUrl: dto.cvImageUrl,
        salary: dto.salary,
        requirements: dto.requirements,
        createdById: userId,
        status: CareerStatus.PENDING,
      },
    });

    return post;
  }

  // ==================== UPDATE POST ====================

  async update(user: any, id: string, dto: UpdateCareerPostDto) {
    const userId = this.requireUserId(user);

    const post = await this.prisma.careerPost.findUnique({ where: { id } });
    if (!post) throw new NotFoundException('Post not found');
    if (post.createdById !== userId) throw new ForbiddenException('Not your post');

    // Si le post était approuvé, le remettre en pending pour re-modération
    const newStatus =
      post.status === CareerStatus.APPROVED ? CareerStatus.PENDING : post.status;

    return this.prisma.careerPost.update({
      where: { id },
      data: {
        ...dto,
        status: newStatus,
        approvedAt: newStatus === CareerStatus.PENDING ? null : post.approvedAt,
      },
    });
  }

  // ==================== DELETE POST ====================

  async remove(user: any, id: string) {
    const userId = this.requireUserId(user);

    const post = await this.prisma.careerPost.findUnique({ where: { id } });
    if (!post) throw new NotFoundException('Post not found');
    if (post.createdById !== userId) throw new ForbiddenException('Not your post');

    await this.prisma.careerPost.delete({ where: { id } });
    return { success: true };
  }

  // ==================== MY POST ====================

  async myPost(user: any, type?: CareerType) {
    const userId = this.requireUserId(user);

    const where: any = {
      createdById: userId,
      status: { not: CareerStatus.ARCHIVED },
    };

    if (type) {
      where.type = type;
    }

    const posts = await this.prisma.careerPost.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    });

    return posts;
  }

  // ==================== CONVERSATIONS ====================

  async myConversations(user: any) {
    const userId = this.requireUserId(user);

    // Conversations où je suis l'auteur du post
    const asOwner = await this.prisma.careerConversation.findMany({
      where: {
        post: { createdById: userId },
        hiddenByOwner: false,
      },
      include: {
        post: { select: { id: true, title: true, type: true } },
        participant: {
          select: { id: true, firstName: true, lastName: true, photoUrl: true, role: true },
        },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { updatedAt: 'desc' },
    });

    // Conversations où je suis participant
    const asParticipant = await this.prisma.careerConversation.findMany({
      where: {
        participantId: userId,
        hiddenByParticipant: false,
      },
      include: {
        post: {
          select: { id: true, title: true, type: true, createdById: true },
          include: {
            createdBy: {
              select: { id: true, firstName: true, lastName: true, photoUrl: true, role: true },
            },
          },
        },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { updatedAt: 'desc' },
    });

    const userIsPro = this.isPro(user);

    // Formatter les conversations
    const conversations = [
      ...asOwner.map((c) => ({
        id: c.id,
        postId: c.post.id,
        postTitle: c.post.title,
        postType: c.post.type,
        isOwner: true,
        otherPerson: userIsPro
          ? c.participant
          : { id: c.participant.id, photoUrl: c.participant.photoUrl, anonymousName: c.participantAnonymousName },
        lastMessage: c.messages[0]?.content ?? null,
        updatedAt: c.updatedAt,
      })),
      ...asParticipant.map((c) => ({
        id: c.id,
        postId: c.post.id,
        postTitle: c.post.title,
        postType: c.post.type,
        isOwner: false,
        otherPerson: c.post.createdBy,
        lastMessage: c.messages[0]?.content ?? null,
        updatedAt: c.updatedAt,
      })),
    ].sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());

    return conversations;
  }

  // ==================== CONTACT POST (START CONVERSATION) ====================

  async contactPost(user: any, postId: string) {
    const userId = this.requireUserId(user);

    const post = await this.prisma.careerPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('Post not found');
    if (post.status !== CareerStatus.APPROVED) {
      throw new BadRequestException('Post is not available');
    }
    if (post.createdById === userId) {
      throw new BadRequestException('Cannot contact your own post');
    }

    // Vérifier si une conversation existe déjà
    let conversation = await this.prisma.careerConversation.findUnique({
      where: { postId_participantId: { postId, participantId: userId } },
    });

    if (!conversation) {
      conversation = await this.prisma.careerConversation.create({
        data: {
          postId,
          participantId: userId,
          participantAnonymousName: this.getRandomAnonymousName(),
        },
      });
    }

    return { conversationId: conversation.id };
  }

  // ==================== GET CONVERSATION MESSAGES ====================

  async getConversationMessages(user: any, conversationId: string) {
    const userId = this.requireUserId(user);
    const userIsPro = this.isPro(user);

    const conversation = await this.prisma.careerConversation.findUnique({
      where: { id: conversationId },
      include: {
        post: {
          include: {
            createdBy: {
              select: { id: true, firstName: true, lastName: true, photoUrl: true, role: true },
            },
          },
        },
        participant: {
          select: { id: true, firstName: true, lastName: true, photoUrl: true, role: true },
        },
        messages: {
          orderBy: { createdAt: 'asc' },
          include: {
            sender: { select: { id: true, firstName: true, lastName: true, photoUrl: true } },
          },
        },
      },
    });

    if (!conversation) throw new NotFoundException('Conversation not found');

    const isOwner = conversation.post.createdById === userId;
    const isParticipant = conversation.participantId === userId;

    if (!isOwner && !isParticipant) {
      throw new ForbiddenException('Not your conversation');
    }

    // Marquer les messages comme lus
    await this.prisma.careerMessage.updateMany({
      where: {
        conversationId,
        senderId: { not: userId },
        readAt: null,
      },
      data: { readAt: new Date() },
    });

    return {
      id: conversation.id,
      post: {
        id: conversation.post.id,
        title: conversation.post.title,
        type: conversation.post.type,
      },
      isOwner,
      otherPerson: isOwner
        ? userIsPro
          ? conversation.participant
          : { id: conversation.participant.id, photoUrl: conversation.participant.photoUrl, anonymousName: conversation.participantAnonymousName }
        : conversation.post.createdBy,
      messages: conversation.messages,
    };
  }

  // ==================== SEND MESSAGE ====================

  async sendMessage(user: any, conversationId: string, content: string) {
    const userId = this.requireUserId(user);

    const conversation = await this.prisma.careerConversation.findUnique({
      where: { id: conversationId },
      include: { post: true },
    });

    if (!conversation) throw new NotFoundException('Conversation not found');

    const isOwner = conversation.post.createdById === userId;
    const isParticipant = conversation.participantId === userId;

    if (!isOwner && !isParticipant) {
      throw new ForbiddenException('Not your conversation');
    }

    const message = await this.prisma.careerMessage.create({
      data: {
        conversationId,
        senderId: userId,
        content,
      },
    });

    // Mettre à jour la date de la conversation
    await this.prisma.careerConversation.update({
      where: { id: conversationId },
      data: { updatedAt: new Date() },
    });

    return message;
  }

  // ==================== HIDE CONVERSATION ====================

  async hideConversation(user: any, conversationId: string) {
    const userId = this.requireUserId(user);

    const conversation = await this.prisma.careerConversation.findUnique({
      where: { id: conversationId },
      include: { post: true },
    });

    if (!conversation) throw new NotFoundException('Conversation not found');

    const isOwner = conversation.post.createdById === userId;
    const isParticipant = conversation.participantId === userId;

    if (!isOwner && !isParticipant) {
      throw new ForbiddenException('Not your conversation');
    }

    await this.prisma.careerConversation.update({
      where: { id: conversationId },
      data: isOwner ? { hiddenByOwner: true } : { hiddenByParticipant: true },
    });

    return { success: true };
  }

  // ==================== ADMIN METHODS ====================

  async adminList(status?: CareerStatus, type?: CareerType, limit = 30, cursor?: string) {
    const where: any = {};
    if (status) where.status = status;
    if (type) where.type = type;
    if (cursor) where.id = { lt: cursor };

    const posts = await this.prisma.careerPost.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      include: {
        createdBy: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
            photoUrl: true,
            role: true,
          },
        },
      },
    });

    const hasMore = posts.length > limit;
    if (hasMore) posts.pop();

    // Compter par status
    const counts = await this.prisma.careerPost.groupBy({
      by: ['status'],
      _count: true,
    });

    const countMap: Record<string, number> = {};
    for (const c of counts) {
      countMap[c.status] = c._count;
    }

    return {
      data: posts,
      nextCursor: hasMore ? posts[posts.length - 1]?.id : null,
      counts: countMap,
    };
  }

  async adminApprove(_admin: any, id: string) {
    const post = await this.prisma.careerPost.findUnique({ where: { id } });
    if (!post) throw new NotFoundException('Post not found');

    return this.prisma.careerPost.update({
      where: { id },
      data: {
        status: CareerStatus.APPROVED,
        approvedAt: new Date(),
        moderationNote: null,
        rejectedAt: null,
      },
    });
  }

  async adminReject(_admin: any, id: string, note?: string) {
    const post = await this.prisma.careerPost.findUnique({ where: { id } });
    if (!post) throw new NotFoundException('Post not found');

    return this.prisma.careerPost.update({
      where: { id },
      data: {
        status: CareerStatus.REJECTED,
        rejectedAt: new Date(),
        moderationNote: note,
      },
    });
  }

  async adminArchive(_admin: any, id: string) {
    const post = await this.prisma.careerPost.findUnique({ where: { id } });
    if (!post) throw new NotFoundException('Post not found');

    return this.prisma.careerPost.update({
      where: { id },
      data: {
        status: CareerStatus.ARCHIVED,
        archivedAt: new Date(),
      },
    });
  }

  async adminApproveAll(_admin: any) {
    const result = await this.prisma.careerPost.updateMany({
      where: { status: CareerStatus.PENDING },
      data: {
        status: CareerStatus.APPROVED,
        approvedAt: new Date(),
      },
    });

    return { count: result.count };
  }

  async adminGetPost(id: string) {
    const post = await this.prisma.careerPost.findUnique({
      where: { id },
      include: {
        createdBy: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
            photoUrl: true,
            role: true,
          },
        },
        _count: {
          select: { conversations: true },
        },
      },
    });

    if (!post) throw new NotFoundException('Post not found');
    return post;
  }

  async adminGetPostConversations(postId: string) {
    const conversations = await this.prisma.careerConversation.findMany({
      where: { postId },
      orderBy: { updatedAt: 'desc' },
      include: {
        participant: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
            photoUrl: true,
            role: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'asc' },
          include: {
            sender: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                photoUrl: true,
              },
            },
          },
        },
        _count: {
          select: { messages: true },
        },
      },
    });

    return conversations;
  }

  async adminGetConversationMessages(conversationId: string) {
    const conversation = await this.prisma.careerConversation.findUnique({
      where: { id: conversationId },
      include: {
        post: {
          select: {
            id: true,
            title: true,
            type: true,
            createdById: true,
            createdBy: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
                photoUrl: true,
              },
            },
          },
        },
        participant: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
            photoUrl: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'asc' },
          include: {
            sender: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                photoUrl: true,
              },
            },
          },
        },
      },
    });

    if (!conversation) throw new NotFoundException('Conversation not found');
    return conversation;
  }
}
