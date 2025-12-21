import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SanctionType, Prisma } from '@prisma/client';

@Injectable()
export class AdminUsersService {
  constructor(private prisma: PrismaService) {}

  /**
   * Liste tous les utilisateurs avec filtres
   */
  async listUsers(options: {
    q?: string;
    role?: string;
    isBanned?: boolean;
    trustStatus?: string;
    limit?: number;
    offset?: number;
  }) {
    const { q, role, isBanned, trustStatus, limit = 50, offset = 0 } = options;

    const where: Prisma.UserWhereInput = {};

    if (q) {
      where.OR = [
        { email: { contains: q, mode: 'insensitive' } },
        { firstName: { contains: q, mode: 'insensitive' } },
        { lastName: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
      ];
    }

    if (role) {
      where.role = role as any;
    }

    if (isBanned !== undefined) {
      where.isBanned = isBanned;
    }

    if (trustStatus) {
      where.trustStatus = trustStatus as any;
    }

    return this.prisma.user.findMany({
      where,
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        city: true,
        lat: true,
        lng: true,
        photoUrl: true,
        role: true,
        createdAt: true,
        trustStatus: true,
        restrictedUntil: true,
        noShowCount: true,
        isBanned: true,
        bannedAt: true,
        bannedReason: true,
        suspendedUntil: true,
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });
  }

  /**
   * Récupère le profil complet d'un utilisateur avec TOUTES ses données
   */
  async getFullProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        providerProfile: {
          select: {
            id: true,
            displayName: true,
            bio: true,
            address: true,
            lat: true,
            lng: true,
            specialties: true,
            isApproved: true,
            appliedAt: true,
          },
        },
        sanctions: {
          orderBy: { issuedAt: 'desc' },
          take: 20,
        },
      },
    });

    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    // Récupérer les données en parallèle
    const [
      pets,
      bookings,
      daycareBookings,
      orders,
      adoptPosts,
      flags,
      adoptConversations,
    ] = await Promise.all([
      // Animaux
      this.prisma.pet.findMany({
        where: { ownerId: userId },
        select: {
          id: true,
          name: true,
          species: true,
          breed: true,
          gender: true,
          birthDate: true,
          photoUrl: true,
          isNeutered: true,
        },
        orderBy: { createdAt: 'desc' },
      }),

      // RDV Véto
      this.prisma.booking.findMany({
        where: { userId },
        select: {
          id: true,
          referenceCode: true,
          status: true,
          scheduledAt: true,
          createdAt: true,
          confirmationMethod: true,
          provider: {
            select: {
              id: true,
              displayName: true,
            },
          },
          service: {
            select: {
              id: true,
              title: true,
              price: true,
            },
          },
        },
        orderBy: { scheduledAt: 'desc' },
        take: 50,
      }),

      // RDV Garderie
      this.prisma.daycareBooking.findMany({
        where: { userId },
        select: {
          id: true,
          status: true,
          startDate: true,
          endDate: true,
          actualDropOff: true,
          actualPickup: true,
          priceDa: true,
          lateFeeDa: true,
          disputeNote: true,
          createdAt: true,
          provider: {
            select: {
              id: true,
              displayName: true,
            },
          },
          pet: {
            select: {
              id: true,
              name: true,
              species: true,
            },
          },
        },
        orderBy: { startDate: 'desc' },
        take: 50,
      }),

      // Commandes Petshop
      this.prisma.order.findMany({
        where: { userId },
        select: {
          id: true,
          status: true,
          totalDa: true,
          createdAt: true,
          deliveryAddress: true,
          provider: {
            select: {
              id: true,
              displayName: true,
            },
          },
          items: {
            select: {
              quantity: true,
              priceDa: true,
              product: {
                select: {
                  id: true,
                  title: true,
                },
              },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),

      // Annonces adoption
      this.prisma.adoptPost.findMany({
        where: { createdById: userId },
        select: {
          id: true,
          animalName: true,
          species: true,
          status: true,
          city: true,
          createdAt: true,
          images: true,
        },
        orderBy: { createdAt: 'desc' },
      }),

      // Flags
      this.prisma.adminFlag.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
      }),

      // Conversations adoption
      this.prisma.adoptConversation.findMany({
        where: {
          OR: [{ ownerId: userId }, { adopterId: userId }],
        },
        select: {
          id: true,
          createdAt: true,
          post: {
            select: {
              id: true,
              animalName: true,
            },
          },
          ownerId: true,
          adopterId: true,
        },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);

    // Stats résumées
    const stats = {
      totalPets: pets.length,
      totalBookings: bookings.length,
      completedBookings: bookings.filter((b) => b.status === 'COMPLETED').length,
      cancelledBookings: bookings.filter((b) => b.status === 'CANCELLED').length,
      disputedBookings: bookings.filter((b) => b.status === 'DISPUTED').length,
      totalDaycareBookings: daycareBookings.length,
      completedDaycare: daycareBookings.filter((b) => b.status === 'COMPLETED').length,
      disputedDaycare: daycareBookings.filter((b) => b.status === 'DISPUTED').length,
      totalOrders: orders.length,
      deliveredOrders: orders.filter((o) => o.status === 'DELIVERED').length,
      totalAdoptPosts: adoptPosts.length,
      approvedAdoptPosts: adoptPosts.filter((p) => p.status === 'APPROVED').length,
      activeFlags: flags.filter((f) => !f.resolved).length,
      totalFlags: flags.length,
    };

    return {
      user,
      pets,
      bookings,
      daycareBookings,
      orders,
      adoptPosts,
      adoptConversations,
      flags,
      stats,
    };
  }

  /**
   * Modifier les informations d'un utilisateur
   */
  async updateUser(
    userId: string,
    data: {
      firstName?: string;
      lastName?: string;
      email?: string;
      phone?: string;
      city?: string;
    },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    // Vérifier l'unicité de l'email si modifié
    if (data.email && data.email !== user.email) {
      const existing = await this.prisma.user.findUnique({
        where: { email: data.email },
      });
      if (existing) {
        throw new BadRequestException('Cet email est déjà utilisé');
      }
    }

    // Vérifier l'unicité du téléphone si modifié
    if (data.phone && data.phone !== user.phone) {
      const existing = await this.prisma.user.findFirst({
        where: { phone: data.phone },
      });
      if (existing) {
        throw new BadRequestException('Ce numéro de téléphone est déjà utilisé');
      }
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
        phone: data.phone,
        city: data.city,
      },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        city: true,
        role: true,
        trustStatus: true,
        isBanned: true,
        suspendedUntil: true,
      },
    });
  }

  /**
   * Émettre un avertissement
   */
  async warnUser(userId: string, adminId: string, reason: string, metadata?: any) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    const sanction = await this.prisma.userSanction.create({
      data: {
        userId,
        type: SanctionType.WARNING,
        reason,
        issuedBy: adminId,
        metadata,
      },
    });

    return {
      ok: true,
      message: 'Avertissement émis',
      sanction,
    };
  }

  /**
   * Suspendre un utilisateur temporairement
   */
  async suspendUser(
    userId: string,
    adminId: string,
    reason: string,
    durationDays: number,
    metadata?: any,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    if (user.isBanned) {
      throw new BadRequestException('Utilisateur déjà banni');
    }

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + durationDays);

    const [updatedUser, sanction] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          suspendedUntil: expiresAt,
        },
      }),
      this.prisma.userSanction.create({
        data: {
          userId,
          type: SanctionType.SUSPENSION,
          reason,
          duration: durationDays,
          expiresAt,
          issuedBy: adminId,
          metadata,
        },
      }),
    ]);

    return {
      ok: true,
      message: `Utilisateur suspendu pour ${durationDays} jour(s)`,
      user: updatedUser,
      sanction,
    };
  }

  /**
   * Bannir un utilisateur définitivement
   */
  async banUser(userId: string, adminId: string, reason: string, metadata?: any) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    if (user.isBanned) {
      throw new BadRequestException('Utilisateur déjà banni');
    }

    if (user.role === 'ADMIN') {
      throw new ForbiddenException('Impossible de bannir un administrateur');
    }

    const [updatedUser, sanction] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          isBanned: true,
          bannedAt: new Date(),
          bannedReason: reason,
          bannedBy: adminId,
          suspendedUntil: null, // Lever la suspension si existante
        },
      }),
      this.prisma.userSanction.create({
        data: {
          userId,
          type: SanctionType.BAN,
          reason,
          issuedBy: adminId,
          metadata,
        },
      }),
    ]);

    return {
      ok: true,
      message: 'Utilisateur banni définitivement',
      user: updatedUser,
      sanction,
    };
  }

  /**
   * Lever le ban d'un utilisateur
   */
  async unbanUser(userId: string, adminId: string, reason?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    if (!user.isBanned) {
      throw new BadRequestException('Utilisateur non banni');
    }

    const [updatedUser, sanction] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          isBanned: false,
          bannedAt: null,
          bannedReason: null,
          bannedBy: null,
        },
      }),
      this.prisma.userSanction.create({
        data: {
          userId,
          type: SanctionType.UNBAN,
          reason: reason || 'Ban levé par admin',
          issuedBy: adminId,
        },
      }),
    ]);

    return {
      ok: true,
      message: 'Ban levé',
      user: updatedUser,
      sanction,
    };
  }

  /**
   * Lever la suspension d'un utilisateur
   */
  async liftSuspension(userId: string, adminId: string, reason?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    if (!user.suspendedUntil) {
      throw new BadRequestException('Utilisateur non suspendu');
    }

    const [updatedUser, sanction] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          suspendedUntil: null,
        },
      }),
      this.prisma.userSanction.create({
        data: {
          userId,
          type: SanctionType.LIFT,
          reason: reason || 'Suspension levée par admin',
          issuedBy: adminId,
        },
      }),
    ]);

    return {
      ok: true,
      message: 'Suspension levée',
      user: updatedUser,
      sanction,
    };
  }

  /**
   * Récupérer l'historique des sanctions d'un utilisateur
   */
  async getSanctions(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    const sanctions = await this.prisma.userSanction.findMany({
      where: { userId },
      orderBy: { issuedAt: 'desc' },
    });

    // Récupérer les infos des admins qui ont émis les sanctions
    const adminIds = [...new Set(sanctions.map((s) => s.issuedBy))];
    const admins = await this.prisma.user.findMany({
      where: { id: { in: adminIds } },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
      },
    });

    const adminMap = new Map(admins.map((a) => [a.id, a]));

    return sanctions.map((s) => ({
      ...s,
      issuedByAdmin: adminMap.get(s.issuedBy) || null,
    }));
  }

  /**
   * Récupérer les commandes petshop d'un utilisateur
   */
  async getUserOrders(userId: string) {
    return this.prisma.order.findMany({
      where: { userId },
      include: {
        provider: {
          select: {
            id: true,
            displayName: true,
          },
        },
        items: {
          include: {
            product: {
              select: {
                id: true,
                title: true,
                imageUrls: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Récupérer les réservations garderie d'un utilisateur
   */
  async getUserDaycareBookings(userId: string) {
    return this.prisma.daycareBooking.findMany({
      where: { userId },
      include: {
        provider: {
          select: {
            id: true,
            displayName: true,
            address: true,
          },
        },
        pet: {
          select: {
            id: true,
            name: true,
            species: true,
            photoUrl: true,
          },
        },
      },
      orderBy: { startDate: 'desc' },
    });
  }

  /**
   * Vérifier si un utilisateur est suspendu/banni (pour middleware)
   */
  async checkUserAccess(userId: string): Promise<{
    allowed: boolean;
    reason?: string;
    until?: Date;
  }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        isBanned: true,
        bannedReason: true,
        suspendedUntil: true,
      },
    });

    if (!user) {
      return { allowed: false, reason: 'Utilisateur non trouvé' };
    }

    if (user.isBanned) {
      return {
        allowed: false,
        reason: user.bannedReason || 'Compte banni',
      };
    }

    if (user.suspendedUntil && user.suspendedUntil > new Date()) {
      return {
        allowed: false,
        reason: 'Compte suspendu temporairement',
        until: user.suspendedUntil,
      };
    }

    // Lever automatiquement la suspension expirée
    if (user.suspendedUntil && user.suspendedUntil <= new Date()) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { suspendedUntil: null },
      });
    }

    return { allowed: true };
  }
}
