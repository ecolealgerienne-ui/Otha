import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AdminFlag } from '@prisma/client';

export interface FlagUser {
  id: string;
  email: string;
  firstName: string | null;
  lastName: string | null;
  phone: string | null;
  trustStatus: string | null;
}

export interface FlagWithUser extends AdminFlag {
  user: FlagUser | null;
}

@Injectable()
export class AdminFlagsService {
  constructor(private prisma: PrismaService) {}

  async list(query: {
    resolved?: boolean;
    type?: string;
    userId?: string;
    limit?: number;
  }): Promise<FlagWithUser[]> {
    const where: {
      resolved?: boolean;
      type?: string;
      userId?: string;
    } = {};

    if (query.resolved !== undefined) {
      where.resolved = query.resolved;
    }
    if (query.type) {
      where.type = query.type;
    }
    if (query.userId) {
      where.userId = query.userId;
    }

    const flags = await this.prisma.adminFlag.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: query.limit || 50,
    });

    // Get user info for each flag
    const userIds = [...new Set(flags.map((f: AdminFlag) => f.userId))];
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        trustStatus: true,
      },
    });

    const userMap = new Map(users.map((u: FlagUser) => [u.id, u]));

    return flags.map((flag: AdminFlag) => ({
      ...flag,
      user: userMap.get(flag.userId) || null,
    }));
  }

  async getStats() {
    const [total, active, resolved, byType] = await Promise.all([
      this.prisma.adminFlag.count(),
      this.prisma.adminFlag.count({ where: { resolved: false } }),
      this.prisma.adminFlag.count({ where: { resolved: true } }),
      this.prisma.adminFlag.groupBy({
        by: ['type'],
        _count: { type: true },
        where: { resolved: false },
      }),
    ]);

    return {
      total,
      active,
      resolved,
      byType: byType.map((t: { type: string; _count: { type: number } }) => ({
        type: t.type,
        count: t._count.type,
      })),
    };
  }

  async getById(id: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: flag.userId },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        trustStatus: true,
        noShowCount: true,
        restrictedUntil: true,
      },
    });

    // If bookingId, get booking info
    let booking = null;
    if (flag.bookingId) {
      booking = await this.prisma.daycareBooking.findUnique({
        where: { id: flag.bookingId },
        include: {
          pet: { select: { name: true, species: true } },
          provider: {
            include: {
              user: { select: { firstName: true, lastName: true } },
            },
          },
        },
      });
    }

    return {
      ...flag,
      user,
      booking,
    };
  }

  async create(dto: { userId: string; type: string; bookingId?: string; note?: string }) {
    return this.prisma.adminFlag.create({
      data: {
        userId: dto.userId,
        type: dto.type,
        bookingId: dto.bookingId,
        note: dto.note,
      },
    });
  }

  /**
   * Crée automatiquement un flag pour un événement suspect
   * Appelé par d'autres services (daycare, bookings, etc.)
   */
  async createAutoFlag(
    userId: string,
    type: 'FRAUD' | 'DAYCARE_DISPUTE' | 'NO_SHOW' | 'SUSPICIOUS_BEHAVIOR' | 'ABUSE' | 'OTHER',
    note: string,
    bookingId?: string,
  ) {
    // Vérifier si un flag similaire existe déjà (non résolu)
    const existingFlag = await this.prisma.adminFlag.findFirst({
      where: {
        userId,
        type,
        bookingId: bookingId || undefined,
        resolved: false,
      },
    });

    if (existingFlag) {
      // Mettre à jour la note existante
      return this.prisma.adminFlag.update({
        where: { id: existingFlag.id },
        data: {
          note: existingFlag.note ? `${existingFlag.note} | ${note}` : note,
        },
      });
    }

    return this.prisma.adminFlag.create({
      data: {
        userId,
        type,
        bookingId,
        note,
      },
    });
  }

  async resolve(id: string, note?: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    return this.prisma.adminFlag.update({
      where: { id },
      data: {
        resolved: true,
        note: note ? (flag.note ? `${flag.note} | RESOLVED: ${note}` : `RESOLVED: ${note}`) : flag.note,
      },
    });
  }

  async unresolve(id: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    return this.prisma.adminFlag.update({
      where: { id },
      data: { resolved: false },
    });
  }

  async delete(id: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    await this.prisma.adminFlag.delete({ where: { id } });
    return { ok: true };
  }

  async getByUser(userId: string) {
    return this.prisma.adminFlag.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
