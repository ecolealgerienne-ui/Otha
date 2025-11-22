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
      include: {
        weightRecords: { orderBy: { date: 'desc' }, take: 5 },
        vaccinations: { orderBy: { date: 'desc' }, take: 3 },
        treatments: { where: { isActive: true }, take: 5 },
        allergies: true,
        preventiveCare: { orderBy: { lastDate: 'desc' }, take: 3 },
      },
    });
  }

  // ⚠️ ownerId imposé côté serveur, on ignore tout ownerId envoyé par le client
  create(ownerId: string, dto: any) {
    const data = {
      name: dto.name,
      species: dto.species ?? null,
      gender: dto.gender,
      birthDate: dto.birthDate ? new Date(dto.birthDate) : null,
      weightKg: dto.weightKg ?? null,
      color: dto.color ?? null,
      country: dto.country ?? null,
      idNumber: dto.idNumber ?? null,
      microchipNumber: dto.microchipNumber ?? null,
      breed: dto.breed ?? null,
      bloodType: dto.bloodType ?? null,
      isNeutered: dto.isNeutered ?? false,
      neuteredAt: dto.neuteredAt ? new Date(dto.neuteredAt) : null,
      photoUrl: dto.photoUrl ?? null,
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

    // Supprime l'ancienne photo si une nouvelle est uploadée
    if (dto.photoUrl && dto.photoUrl !== pet.photoUrl && pet.photoUrl) {
      this.s3.deleteByUrl(pet.photoUrl).catch(() => {});
    }

    const data: any = {
      name: dto.name ?? pet.name,
      species: dto.species ?? pet.species,
      gender: dto.gender ?? pet.gender,
      weightKg: dto.weightKg ?? pet.weightKg,
      color: dto.color ?? pet.color,
      country: dto.country ?? pet.country,
      idNumber: dto.idNumber ?? pet.idNumber,
      microchipNumber: dto.microchipNumber ?? pet.microchipNumber,
      breed: dto.breed ?? pet.breed,
      bloodType: dto.bloodType ?? pet.bloodType,
      photoUrl: dto.photoUrl ?? pet.photoUrl,
      allergiesNotes: dto.allergiesNotes ?? pet.allergiesNotes,
      description: dto.description ?? pet.description,
    };
    if (dto.birthDate !== undefined) {
      data.birthDate = dto.birthDate ? new Date(dto.birthDate) : null;
    }
    if (dto.isNeutered !== undefined) {
      data.isNeutered = dto.isNeutered;
    }
    if (dto.neuteredAt !== undefined) {
      data.neuteredAt = dto.neuteredAt ? new Date(dto.neuteredAt) : null;
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

    // Supprime la photo du pet si elle existe
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
            weightRecords: { orderBy: { date: 'desc' }, take: 10 },
            vaccinations: { orderBy: { date: 'desc' } },
            treatments: { orderBy: { startDate: 'desc' } },
            allergies: true,
            preventiveCare: { orderBy: { lastDate: 'desc' } },
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

  // ============ WEIGHT RECORDS ============

  async listWeightRecords(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.weightRecord.findMany({
      where: { petId },
      orderBy: { date: 'desc' },
    });
  }

  async createWeightRecord(ownerId: string, petId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    // Mettre à jour aussi le poids actuel du pet
    await this.prisma.pet.update({
      where: { id: petId },
      data: { weightKg: dto.weightKg },
    });

    return this.prisma.weightRecord.create({
      data: {
        petId,
        weightKg: dto.weightKg,
        date: new Date(dto.date),
        notes: dto.notes ?? null,
      },
    });
  }

  async deleteWeightRecord(ownerId: string, petId: string, recordId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const record = await this.prisma.weightRecord.findUnique({ where: { id: recordId } });
    if (!record || record.petId !== petId) throw new NotFoundException('Record not found');

    return this.prisma.weightRecord.delete({ where: { id: recordId } });
  }

  // ============ VACCINATIONS ============

  async listVaccinations(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.vaccination.findMany({
      where: { petId },
      orderBy: { date: 'desc' },
    });
  }

  async createVaccination(ownerId: string, petId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.vaccination.create({
      data: {
        petId,
        name: dto.name,
        date: new Date(dto.date),
        nextDueDate: dto.nextDueDate ? new Date(dto.nextDueDate) : null,
        batchNumber: dto.batchNumber ?? null,
        vetId: dto.vetId ?? null,
        vetName: dto.vetName ?? null,
        notes: dto.notes ?? null,
      },
    });
  }

  async deleteVaccination(ownerId: string, petId: string, vaccinationId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const vax = await this.prisma.vaccination.findUnique({ where: { id: vaccinationId } });
    if (!vax || vax.petId !== petId) throw new NotFoundException('Vaccination not found');

    return this.prisma.vaccination.delete({ where: { id: vaccinationId } });
  }

  // ============ TREATMENTS ============

  async listTreatments(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.treatment.findMany({
      where: { petId },
      orderBy: { startDate: 'desc' },
    });
  }

  async createTreatment(ownerId: string, petId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.treatment.create({
      data: {
        petId,
        name: dto.name,
        dosage: dto.dosage ?? null,
        frequency: dto.frequency ?? null,
        startDate: new Date(dto.startDate),
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        isActive: dto.isActive ?? true,
        notes: dto.notes ?? null,
      },
    });
  }

  async updateTreatment(ownerId: string, petId: string, treatmentId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const treatment = await this.prisma.treatment.findUnique({ where: { id: treatmentId } });
    if (!treatment || treatment.petId !== petId) throw new NotFoundException('Treatment not found');

    return this.prisma.treatment.update({
      where: { id: treatmentId },
      data: {
        name: dto.name ?? treatment.name,
        dosage: dto.dosage ?? treatment.dosage,
        frequency: dto.frequency ?? treatment.frequency,
        startDate: dto.startDate ? new Date(dto.startDate) : treatment.startDate,
        endDate: dto.endDate ? new Date(dto.endDate) : treatment.endDate,
        isActive: dto.isActive ?? treatment.isActive,
        notes: dto.notes ?? treatment.notes,
      },
    });
  }

  async deleteTreatment(ownerId: string, petId: string, treatmentId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const treatment = await this.prisma.treatment.findUnique({ where: { id: treatmentId } });
    if (!treatment || treatment.petId !== petId) throw new NotFoundException('Treatment not found');

    return this.prisma.treatment.delete({ where: { id: treatmentId } });
  }

  // ============ ALLERGIES ============

  async listAllergies(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.allergy.findMany({
      where: { petId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createAllergy(ownerId: string, petId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.allergy.create({
      data: {
        petId,
        type: dto.type,
        allergen: dto.allergen,
        severity: dto.severity ?? null,
        notes: dto.notes ?? null,
      },
    });
  }

  async deleteAllergy(ownerId: string, petId: string, allergyId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const allergy = await this.prisma.allergy.findUnique({ where: { id: allergyId } });
    if (!allergy || allergy.petId !== petId) throw new NotFoundException('Allergy not found');

    return this.prisma.allergy.delete({ where: { id: allergyId } });
  }

  // ============ PREVENTIVE CARE ============

  async listPreventiveCare(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.preventiveCare.findMany({
      where: { petId },
      orderBy: { lastDate: 'desc' },
    });
  }

  async createPreventiveCare(ownerId: string, petId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.preventiveCare.create({
      data: {
        petId,
        type: dto.type,
        lastDate: new Date(dto.lastDate),
        nextDueDate: dto.nextDueDate ? new Date(dto.nextDueDate) : null,
        product: dto.product ?? null,
        notes: dto.notes ?? null,
      },
    });
  }

  async updatePreventiveCare(ownerId: string, petId: string, careId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const care = await this.prisma.preventiveCare.findUnique({ where: { id: careId } });
    if (!care || care.petId !== petId) throw new NotFoundException('Preventive care not found');

    return this.prisma.preventiveCare.update({
      where: { id: careId },
      data: {
        type: dto.type ?? care.type,
        lastDate: dto.lastDate ? new Date(dto.lastDate) : care.lastDate,
        nextDueDate: dto.nextDueDate ? new Date(dto.nextDueDate) : care.nextDueDate,
        product: dto.product ?? care.product,
        notes: dto.notes ?? care.notes,
      },
    });
  }

  async deletePreventiveCare(ownerId: string, petId: string, careId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const care = await this.prisma.preventiveCare.findUnique({ where: { id: careId } });
    if (!care || care.petId !== petId) throw new NotFoundException('Preventive care not found');

    return this.prisma.preventiveCare.delete({ where: { id: careId } });
  }
}
