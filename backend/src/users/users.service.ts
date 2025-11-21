import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { UpdateMeDto } from './dto/update-me.dto';
import { S3Service } from '../uploads/s3.service';

const userSelect = {
  id: true,
  email: true,
  role: true,
  firstName: true,
  lastName: true,
  phone: true,
  city: true,
  lat: true,
  lng: true,
  photoUrl: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserSelect;

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private s3: S3Service,
  ) {}

  findMe(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
      select: userSelect,
    });
  }

  async updateMe(id: string, dto: UpdateMeDto) {
    const data: Prisma.UserUpdateInput = {};

    if (dto.firstName !== undefined) data.firstName = dto.firstName?.trim() || null;
    if (dto.lastName  !== undefined) data.lastName  = dto.lastName?.trim()  || null;

    // string vide -> null pour éviter des collisions absurdes sur ""
    if (dto.phone     !== undefined) data.phone     = dto.phone?.trim()     || null;

    if (dto.city      !== undefined) data.city      = dto.city?.trim()      || null;
    if (dto.lat       !== undefined) data.lat       = dto.lat;
    if (dto.lng       !== undefined) data.lng       = dto.lng;

    // Gestion de la photo avec suppression de l'ancienne
    if (dto.photoUrl !== undefined) {
      const newPhotoUrl = dto.photoUrl?.trim() || null;

      // Récupère l'ancienne photo pour la supprimer
      const currentUser = await this.prisma.user.findUnique({
        where: { id },
        select: { photoUrl: true },
      });

      // Si une nouvelle photo est uploadée et différente de l'ancienne
      if (currentUser?.photoUrl && currentUser.photoUrl !== newPhotoUrl) {
        // Supprime l'ancienne photo du S3 (async, non-bloquant)
        this.s3.deleteByUrl(currentUser.photoUrl).catch(() => {});
      }

      data.photoUrl = newPhotoUrl;
    }

    try {
      const user = await this.prisma.user.update({
        where: { id },
        data,
        select: userSelect,
      });
      return user;
    } catch (e: any) {
      // Mappe l'unicité Prisma (P2002) → 409
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const target = (e.meta as any)?.target;
        const arr = Array.isArray(target) ? target : [target];
        const isPhone = arr?.some((t: any) => String(t).toLowerCase().includes('phone'));
        if (isPhone) {
          throw new ConflictException('Phone already in use');
        }
      }
      throw e;
    }
  }

  // Admin: list all users
  async listUsers(query?: { role?: string; q?: string; limit?: number; offset?: number }) {
    const where: Prisma.UserWhereInput = {};

    if (query?.role) {
      where.role = query.role as any;
    }

    if (query?.q && query.q.trim()) {
      const search = query.q.trim();
      where.OR = [
        { email: { contains: search, mode: 'insensitive' } },
        { firstName: { contains: search, mode: 'insensitive' } },
        { lastName: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search, mode: 'insensitive' } },
      ];
    }

    const users = await this.prisma.user.findMany({
      where,
      select: userSelect,
      orderBy: { createdAt: 'desc' },
      take: query?.limit ?? 100,
      skip: query?.offset ?? 0,
    });

    return users;
  }

  // Admin: reset quotas adoption d'un utilisateur
  async resetUserAdoptQuotas(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        dailySwipeCount: 0,
        dailyPostCount: 0,
        lastSwipeDate: null,
        lastPostDate: null,
      },
    });
    return { ok: true };
  }

  // Admin: get user quotas
  async getUserQuotas(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        dailySwipeCount: true,
        lastSwipeDate: true,
        dailyPostCount: true,
        lastPostDate: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Calculer les swipes utilisés aujourd'hui
    const lastSwipeDate = user.lastSwipeDate ? new Date(user.lastSwipeDate) : null;
    const lastSwipeDay = lastSwipeDate
      ? new Date(lastSwipeDate.getFullYear(), lastSwipeDate.getMonth(), lastSwipeDate.getDate())
      : null;
    const swipesUsed = (!lastSwipeDay || lastSwipeDay < today) ? 0 : user.dailySwipeCount;
    const swipesRemaining = Math.max(0, 5 - swipesUsed); // MAX_SWIPES_PER_DAY = 5

    // Calculer les posts utilisés aujourd'hui
    const lastPostDate = user.lastPostDate ? new Date(user.lastPostDate) : null;
    const lastPostDay = lastPostDate
      ? new Date(lastPostDate.getFullYear(), lastPostDate.getMonth(), lastPostDate.getDate())
      : null;
    const postsUsed = (!lastPostDay || lastPostDay < today) ? 0 : user.dailyPostCount;
    const postsRemaining = Math.max(0, 1 - postsUsed); // MAX_POSTS_PER_DAY = 1

    return {
      swipesUsed,
      swipesRemaining,
      postsUsed,
      postsRemaining,
      lastSwipeDate: user.lastSwipeDate,
      lastPostDate: user.lastPostDate,
    };
  }

  // Admin: update user info
  async adminUpdateUser(userId: string, dto: any) {
    const data: Prisma.UserUpdateInput = {};

    if (dto.firstName !== undefined) data.firstName = dto.firstName?.trim() || null;
    if (dto.lastName !== undefined) data.lastName = dto.lastName?.trim() || null;
    if (dto.phone !== undefined) data.phone = dto.phone?.trim() || null;
    if (dto.email !== undefined) data.email = dto.email?.trim();
    if (dto.city !== undefined) data.city = dto.city?.trim() || null;
    if (dto.lat !== undefined) data.lat = dto.lat;
    if (dto.lng !== undefined) data.lng = dto.lng;
    if (dto.role !== undefined) data.role = dto.role;

    try {
      const user = await this.prisma.user.update({
        where: { id: userId },
        data,
        select: userSelect,
      });
      return user;
    } catch (e: any) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const target = (e.meta as any)?.target;
        const arr = Array.isArray(target) ? target : [target];
        if (arr?.some((t: any) => String(t).toLowerCase().includes('phone'))) {
          throw new ConflictException('Phone already in use');
        }
        if (arr?.some((t: any) => String(t).toLowerCase().includes('email'))) {
          throw new ConflictException('Email already in use');
        }
      }
      throw e;
    }
  }
}
