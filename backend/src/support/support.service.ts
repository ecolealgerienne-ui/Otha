import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TicketCategory, TicketStatus, TicketPriority } from '@prisma/client';

@Injectable()
export class SupportService {
  constructor(private prisma: PrismaService) {}

  private requireUserId(user: any): string {
    const userId = user?.sub || user?.id || user?.userId;
    if (!userId) throw new ForbiddenException('User ID required');
    return userId;
  }

  // ==================== USER ENDPOINTS ====================

  /**
   * Créer un nouveau ticket
   */
  async createTicket(
    user: any,
    data: {
      subject: string;
      category?: TicketCategory;
      message: string;
      relatedSanctionId?: string;
    },
  ) {
    const userId = this.requireUserId(user);

    // Si c'est une contestation, vérifier que la sanction existe et appartient à l'utilisateur
    if (data.relatedSanctionId) {
      const sanction = await this.prisma.userSanction.findUnique({
        where: { id: data.relatedSanctionId },
      });
      if (!sanction || sanction.userId !== userId) {
        throw new BadRequestException('Sanction not found');
      }
    }

    // Vérifier qu'il n'y a pas déjà un ticket ouvert pour cette sanction
    if (data.relatedSanctionId) {
      const existingTicket = await this.prisma.supportTicket.findFirst({
        where: {
          userId,
          relatedSanctionId: data.relatedSanctionId,
          status: { in: ['OPEN', 'IN_PROGRESS', 'WAITING_USER'] },
        },
      });
      if (existingTicket) {
        throw new BadRequestException('Un ticket de contestation est déjà ouvert pour cette sanction');
      }
    }

    // Créer le ticket
    const ticket = await this.prisma.supportTicket.create({
      data: {
        userId,
        subject: data.subject,
        category: data.category || (data.relatedSanctionId ? 'APPEAL' : 'GENERAL'),
        priority: data.relatedSanctionId ? 'HIGH' : 'NORMAL',
        relatedSanctionId: data.relatedSanctionId,
      },
    });

    // Créer le premier message
    await this.prisma.supportMessage.create({
      data: {
        ticketId: ticket.id,
        senderId: userId,
        content: data.message,
        isFromAdmin: false,
      },
    });

    return ticket;
  }

  /**
   * Récupérer les tickets de l'utilisateur
   */
  async getUserTickets(user: any) {
    const userId = this.requireUserId(user);

    const tickets = await this.prisma.supportTicket.findMany({
      where: { userId },
      include: {
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
        relatedSanction: {
          select: {
            id: true,
            type: true,
            reason: true,
            issuedAt: true,
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return tickets.map((t) => ({
      id: t.id,
      subject: t.subject,
      category: t.category,
      status: t.status,
      priority: t.priority,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
      relatedSanction: t.relatedSanction,
      lastMessage: t.messages[0]
        ? {
            content: t.messages[0].content.substring(0, 100),
            createdAt: t.messages[0].createdAt,
            isFromAdmin: t.messages[0].isFromAdmin,
          }
        : null,
      unreadCount: 0, // Sera calculé séparément si nécessaire
    }));
  }

  /**
   * Récupérer un ticket avec ses messages
   */
  async getTicketMessages(user: any, ticketId: string) {
    const userId = this.requireUserId(user);

    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
      include: {
        messages: {
          orderBy: { createdAt: 'asc' },
          include: {
            sender: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                role: true,
              },
            },
          },
        },
        relatedSanction: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
          },
        },
      },
    });

    if (!ticket) throw new NotFoundException('Ticket not found');

    // Vérifier l'accès (utilisateur ou admin)
    const isAdmin = user?.role === 'ADMIN' || user?.role === 'admin';
    if (ticket.userId !== userId && !isAdmin) {
      throw new ForbiddenException('Not your ticket');
    }

    // Marquer les messages comme lus
    await this.prisma.supportMessage.updateMany({
      where: {
        ticketId,
        senderId: { not: userId },
        readAt: null,
      },
      data: { readAt: new Date() },
    });

    return {
      id: ticket.id,
      subject: ticket.subject,
      category: ticket.category,
      status: ticket.status,
      priority: ticket.priority,
      createdAt: ticket.createdAt,
      updatedAt: ticket.updatedAt,
      closedAt: ticket.closedAt,
      relatedSanction: ticket.relatedSanction,
      user: ticket.user,
      messages: ticket.messages.map((m) => ({
        id: m.id,
        content: m.content,
        createdAt: m.createdAt,
        isFromAdmin: m.isFromAdmin,
        readAt: m.readAt,
        sender: {
          id: m.sender.id,
          name: m.isFromAdmin ? 'Support Vegece' : `${m.sender.firstName || ''} ${m.sender.lastName || ''}`.trim() || 'Utilisateur',
        },
      })),
    };
  }

  /**
   * Envoyer un message dans un ticket
   */
  async sendMessage(user: any, ticketId: string, content: string) {
    const userId = this.requireUserId(user);

    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) throw new NotFoundException('Ticket not found');

    // Vérifier l'accès
    const isAdmin = user?.role === 'ADMIN' || user?.role === 'admin';
    if (ticket.userId !== userId && !isAdmin) {
      throw new ForbiddenException('Not your ticket');
    }

    // Vérifier que le ticket n'est pas fermé
    if (ticket.status === 'CLOSED' || ticket.status === 'RESOLVED') {
      throw new BadRequestException('Le ticket est fermé');
    }

    // Créer le message
    const message = await this.prisma.supportMessage.create({
      data: {
        ticketId,
        senderId: userId,
        content,
        isFromAdmin: isAdmin,
      },
    });

    // Mettre à jour le statut du ticket
    const newStatus = isAdmin ? 'WAITING_USER' : 'IN_PROGRESS';
    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: newStatus,
        updatedAt: new Date(),
      },
    });

    return {
      id: message.id,
      content: message.content,
      createdAt: message.createdAt,
      isFromAdmin: message.isFromAdmin,
    };
  }

  // ==================== ADMIN ENDPOINTS ====================

  /**
   * Liste tous les tickets (admin)
   */
  async listAllTickets(filters: {
    status?: TicketStatus;
    category?: TicketCategory;
    priority?: TicketPriority;
    assignedToId?: string;
    userId?: string;
    limit?: number;
    offset?: number;
  }) {
    const where: any = {};

    if (filters.status) where.status = filters.status;
    if (filters.category) where.category = filters.category;
    if (filters.priority) where.priority = filters.priority;
    if (filters.assignedToId) where.assignedToId = filters.assignedToId;
    if (filters.userId) where.userId = filters.userId;

    const [tickets, total] = await Promise.all([
      this.prisma.supportTicket.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              isBanned: true,
              suspendedUntil: true,
            },
          },
          assignedTo: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
            },
          },
          messages: {
            orderBy: { createdAt: 'desc' },
            take: 1,
          },
          _count: {
            select: { messages: true },
          },
        },
        orderBy: [
          { priority: 'desc' },
          { updatedAt: 'desc' },
        ],
        take: filters.limit || 50,
        skip: filters.offset || 0,
      }),
      this.prisma.supportTicket.count({ where }),
    ]);

    return {
      tickets: tickets.map((t) => ({
        id: t.id,
        subject: t.subject,
        category: t.category,
        status: t.status,
        priority: t.priority,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
        user: t.user,
        assignedTo: t.assignedTo,
        messageCount: t._count.messages,
        lastMessage: t.messages[0]
          ? {
              content: t.messages[0].content.substring(0, 100),
              createdAt: t.messages[0].createdAt,
              isFromAdmin: t.messages[0].isFromAdmin,
            }
          : null,
      })),
      total,
    };
  }

  /**
   * Assigner un ticket à un admin
   */
  async assignTicket(ticketId: string, adminId: string) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) throw new NotFoundException('Ticket not found');

    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        assignedToId: adminId,
        status: ticket.status === 'OPEN' ? 'IN_PROGRESS' : ticket.status,
      },
    });
  }

  /**
   * Changer le statut d'un ticket
   */
  async updateTicketStatus(ticketId: string, status: TicketStatus, adminId?: string) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) throw new NotFoundException('Ticket not found');

    const updateData: any = { status };

    if (status === 'CLOSED' || status === 'RESOLVED') {
      updateData.closedAt = new Date();
      updateData.closedBy = adminId;
    }

    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: updateData,
    });
  }

  /**
   * Changer la priorité d'un ticket
   */
  async updateTicketPriority(ticketId: string, priority: TicketPriority) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) throw new NotFoundException('Ticket not found');

    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { priority },
    });
  }

  /**
   * Statistiques des tickets
   */
  async getTicketStats() {
    const [byStatus, byCategory, byPriority, recentActivity] = await Promise.all([
      this.prisma.supportTicket.groupBy({
        by: ['status'],
        _count: true,
      }),
      this.prisma.supportTicket.groupBy({
        by: ['category'],
        _count: true,
      }),
      this.prisma.supportTicket.groupBy({
        by: ['priority'],
        where: { status: { in: ['OPEN', 'IN_PROGRESS', 'WAITING_USER'] } },
        _count: true,
      }),
      this.prisma.supportTicket.count({
        where: {
          updatedAt: {
            gte: new Date(Date.now() - 24 * 60 * 60 * 1000), // Last 24h
          },
        },
      }),
    ]);

    const openCount = byStatus.find((s) => s.status === 'OPEN')?._count || 0;
    const inProgressCount = byStatus.find((s) => s.status === 'IN_PROGRESS')?._count || 0;
    const waitingUserCount = byStatus.find((s) => s.status === 'WAITING_USER')?._count || 0;
    const resolvedCount = byStatus.find((s) => s.status === 'RESOLVED')?._count || 0;
    const closedCount = byStatus.find((s) => s.status === 'CLOSED')?._count || 0;

    return {
      byStatus: {
        open: openCount,
        inProgress: inProgressCount,
        waitingUser: waitingUserCount,
        resolved: resolvedCount,
        closed: closedCount,
        activeTotal: openCount + inProgressCount + waitingUserCount,
      },
      byCategory: byCategory.reduce((acc, c) => {
        acc[c.category.toLowerCase()] = c._count;
        return acc;
      }, {} as Record<string, number>),
      byPriority: {
        urgent: byPriority.find((p) => p.priority === 'URGENT')?._count || 0,
        high: byPriority.find((p) => p.priority === 'HIGH')?._count || 0,
        normal: byPriority.find((p) => p.priority === 'NORMAL')?._count || 0,
        low: byPriority.find((p) => p.priority === 'LOW')?._count || 0,
      },
      recentActivity,
    };
  }

  /**
   * Compter les tickets non lus pour l'admin
   */
  async getUnreadCountForAdmin() {
    // Tickets avec des messages non lus de l'utilisateur (isFromAdmin = false, readAt = null)
    const ticketsWithUnread = await this.prisma.supportTicket.findMany({
      where: {
        status: { in: ['OPEN', 'IN_PROGRESS', 'WAITING_USER'] },
        messages: {
          some: {
            isFromAdmin: false,
            readAt: null,
          },
        },
      },
      select: { id: true },
    });

    return ticketsWithUnread.length;
  }

  /**
   * Compter les tickets non lus pour un utilisateur
   */
  async getUnreadCountForUser(userId: string) {
    const ticketsWithUnread = await this.prisma.supportTicket.findMany({
      where: {
        userId,
        status: { in: ['OPEN', 'IN_PROGRESS', 'WAITING_USER'] },
        messages: {
          some: {
            isFromAdmin: true,
            readAt: null,
          },
        },
      },
      select: { id: true },
    });

    return ticketsWithUnread.length;
  }
}
