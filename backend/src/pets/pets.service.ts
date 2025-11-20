// src/pets/pets.service.ts
import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { S3Service } from '../uploads/s3.service';
import { randomBytes } from 'crypto';

@Injectable()
export class PetsService {
  constructor(
    private prisma: PrismaService,
    private s3: S3Service,
  ) {}

  listMine(ownerId: string) {
    return this.prisma.pet.findMany({
      where: { ownerId },
      orderBy: { updatedAt: 'desc' },
    });
  }

  // ⚠️ ownerId imposé côté serveur, on ignore tout ownerId envoyé par le client
  create(ownerId: string, dto: any) {
    const data = {
      name: dto.name,
      gender: dto.gender,
      weightKg: dto.weightKg ?? null,
      color: dto.color ?? null,
      country: dto.country ?? null,
      idNumber: dto.idNumber ?? null,
      breed: dto.breed ?? null,
      neuteredAt: dto.neuteredAt ? new Date(dto.neuteredAt) : null,
      photoUrl: dto.photoUrl ?? null,
      birthDate: dto.birthDate ? new Date(dto.birthDate) : null,
      microchipNumber: dto.microchipNumber ?? null,
      allergiesNotes: dto.allergiesNotes ?? null,
      description: dto.description ?? null,
      ownerId, // <- ici on force
    };
    return this.prisma.pet.create({ data });
  }

  async update(ownerId: string, id: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    // Supprimer l'ancienne photo si une nouvelle est fournie
    if (dto.photoUrl && dto.photoUrl !== pet.photoUrl && pet.photoUrl) {
      this.s3.deleteByUrl(pet.photoUrl).catch(() => {});
    }

    const data: any = {
      name: dto.name ?? pet.name,
      gender: dto.gender ?? pet.gender,
      weightKg: dto.weightKg ?? pet.weightKg,
      color: dto.color ?? pet.color,
      country: dto.country ?? pet.country,
      idNumber: dto.idNumber ?? pet.idNumber,
      breed: dto.breed ?? pet.breed,
      photoUrl: dto.photoUrl ?? pet.photoUrl,
      microchipNumber: dto.microchipNumber ?? pet.microchipNumber,
      allergiesNotes: dto.allergiesNotes ?? pet.allergiesNotes,
      description: dto.description ?? pet.description,
    };
    if (dto.neuteredAt !== undefined) {
      data.neuteredAt = dto.neuteredAt ? new Date(dto.neuteredAt) : null;
    }
    if (dto.birthDate !== undefined) {
      data.birthDate = dto.birthDate ? new Date(dto.birthDate) : null;
    }
    return this.prisma.pet.update({ where: { id }, data });
  }

  // Outil de réparation : rattache un pet existant à l'utilisateur courant
  async reassignToOwner(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    return this.prisma.pet.update({
      where: { id: petId },
      data: { ownerId },
    });
  }

  // Supprimer un pet
  async delete(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    // Supprimer la photo S3 si elle existe
    if (pet.photoUrl) {
      this.s3.deleteByUrl(pet.photoUrl).catch(() => {});
    }

    return this.prisma.pet.delete({ where: { id: petId } });
  }

  // ============ MEDICAL RECORDS ============

  async listMedicalRecords(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.medicalRecord.findMany({
      where: { petId },
      orderBy: { date: 'desc' },
    });
  }

  async createMedicalRecord(ownerId: string, petId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.medicalRecord.create({
      data: {
        petId,
        type: dto.type,
        title: dto.title,
        description: dto.description ?? null,
        date: new Date(dto.date),
        vetId: dto.vetId ?? null,
        vetName: dto.vetName ?? null,
        notes: dto.notes ?? null,
        images: dto.images ?? [],
      },
    });
  }

  async updateMedicalRecord(ownerId: string, petId: string, recordId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const record = await this.prisma.medicalRecord.findUnique({ where: { id: recordId } });
    if (!record || record.petId !== petId) throw new NotFoundException('Record not found');

    return this.prisma.medicalRecord.update({
      where: { id: recordId },
      data: {
        type: dto.type ?? record.type,
        title: dto.title ?? record.title,
        description: dto.description ?? record.description,
        date: dto.date ? new Date(dto.date) : record.date,
        vetId: dto.vetId ?? record.vetId,
        vetName: dto.vetName ?? record.vetName,
        notes: dto.notes ?? record.notes,
        images: dto.images ?? record.images,
      },
    });
  }

  async deleteMedicalRecord(ownerId: string, petId: string, recordId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const record = await this.prisma.medicalRecord.findUnique({ where: { id: recordId } });
    if (!record || record.petId !== petId) throw new NotFoundException('Record not found');

    return this.prisma.medicalRecord.delete({ where: { id: recordId } });
  }

  // ============ ACCESS TOKENS (QR Code) ============

  async generateAccessToken(ownerId: string, petId: string, expiresInMinutes = 30) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    // Supprimer les anciens tokens expirés
    await this.prisma.petAccessToken.deleteMany({
      where: { petId, expiresAt: { lt: new Date() } },
    });

    // Générer un nouveau token
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + expiresInMinutes * 60 * 1000);

    return this.prisma.petAccessToken.create({
      data: { petId, token, expiresAt },
    });
  }

  async getPetByToken(token: string) {
    const accessToken = await this.prisma.petAccessToken.findUnique({
      where: { token },
      include: {
        pet: {
          include: {
            medicalRecords: { orderBy: { date: 'desc' } },
            owner: { select: { id: true, firstName: true, lastName: true, phone: true } },
          },
        },
      },
    });

    if (!accessToken) throw new NotFoundException('Token not found');
    if (accessToken.expiresAt < new Date()) {
      throw new ForbiddenException('Token expired');
    }

    return accessToken.pet;
  }

  // Vet ajoute un record via token (sans être owner)
  async createMedicalRecordByToken(token: string, vetId: string, vetName: string, dto: any) {
    const accessToken = await this.prisma.petAccessToken.findUnique({
      where: { token },
      include: { pet: true },
    });

    if (!accessToken) throw new NotFoundException('Token not found');
    if (accessToken.expiresAt < new Date()) {
      throw new ForbiddenException('Token expired');
    }

    return this.prisma.medicalRecord.create({
      data: {
        petId: accessToken.petId,
        type: dto.type,
        title: dto.title,
        description: dto.description ?? null,
        date: new Date(dto.date),
        vetId,
        vetName,
        notes: dto.notes ?? null,
        images: dto.images ?? [],
      },
    });
  }
}
