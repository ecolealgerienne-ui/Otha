import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminFlagsService {
  constructor(private prisma: PrismaService) {}

  async list(query: {
    resolved?: boolean;
    type?: string;
    userId?: string;
    limit?: number;
  }) {
    const where: any = {};

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
    const userIds = [...new Set(flags.map((f) => f.userId))];
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

    const userMap = new Map(users.map((u) => [u.id, u]));

    return flags.map((flag) => ({
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
      byType: byType.map((t) => ({ type: t.type, count: t._count.type })),
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
