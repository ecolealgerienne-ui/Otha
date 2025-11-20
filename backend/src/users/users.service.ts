import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { S3Service } from '../uploads/s3.service';
import { Prisma } from '@prisma/client';
import { UpdateMeDto } from './dto/update-me.dto';

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
    // Récupérer l'utilisateur actuel pour vérifier l'ancienne photo
    const currentUser = await this.prisma.user.findUnique({
      where: { id },
      select: { photoUrl: true },
    });

    const data: Prisma.UserUpdateInput = {};

    if (dto.firstName !== undefined) data.firstName = dto.firstName?.trim() || null;
    if (dto.lastName  !== undefined) data.lastName  = dto.lastName?.trim()  || null;

    // string vide -> null pour éviter des collisions absurdes sur ""
    if (dto.phone     !== undefined) data.phone     = dto.phone?.trim()     || null;

    if (dto.city      !== undefined) data.city      = dto.city?.trim()      || null;
    if (dto.lat       !== undefined) data.lat       = dto.lat;
    if (dto.lng       !== undefined) data.lng       = dto.lng;
    if (dto.photoUrl  !== undefined) data.photoUrl  = dto.photoUrl?.trim()  || null;

    // Supprimer l'ancienne photo si une nouvelle est fournie
    if (dto.photoUrl && currentUser?.photoUrl && dto.photoUrl !== currentUser.photoUrl) {
      this.s3.deleteByUrl(currentUser.photoUrl).catch(() => {});
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
}
