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
}
