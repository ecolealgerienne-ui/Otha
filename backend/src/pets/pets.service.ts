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
        weightKg: dto.weightKg ?? null,
        temperatureC: dto.temperatureC ?? null,
        heartRate: dto.heartRate ?? null,
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

  async generateAccessToken(ownerId: string, petId: string, expiresInMinutes = 1440) { // 24h par défaut au lieu de 30min
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

  /**
   * PRO: Generate access token for a pet from a recent confirmed booking
   * Allows vets to access pet health records within 24h of a confirmed appointment
   */
  async generateProAccessToken(proUserId: string, petId: string) {
    // Find the provider profile
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId: proUserId },
    });
    if (!provider) throw new ForbiddenException('No provider profile');

    // Check if pet exists
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');

    // Check for a recent confirmed booking (within 24h window)
    const now = new Date();
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const recentBooking = await this.prisma.booking.findFirst({
      where: {
        providerId: provider.id,
        status: { in: ['CONFIRMED', 'COMPLETED'] },
        scheduledAt: { gte: yesterday },
        OR: [
          { petIds: { has: petId } }, // Pet is linked to booking
          { user: { pets: { some: { id: petId } } } }, // Pet belongs to booking's user
        ],
      },
    });

    if (!recentBooking) {
      throw new ForbiddenException(
        'Aucun rendez-vous confirmé récent avec ce patient. L\'accès est limité à 24h après le RDV.'
      );
    }

    // Clean expired tokens
    await this.prisma.petAccessToken.deleteMany({
      where: { petId, expiresAt: { lt: new Date() } },
    });

    // Generate token valid for 24h
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

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
            prescriptions: { orderBy: { date: 'desc' } },
            diseaseTrackings: {
              orderBy: { diagnosisDate: 'desc' },
              include: { progressEntries: { orderBy: { date: 'desc' }, take: 5 } },
            },
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

    // Get provider ID from user ID
    const provider = await this.prisma.providerProfile.findFirst({ where: { userId: vetId } });

    return this.prisma.medicalRecord.create({
      data: {
        petId: accessToken.petId,
        type: dto.type,
        title: dto.title,
        description: dto.description ?? null,
        date: dto.date ? new Date(dto.date) : new Date(),
        vetId,
        vetName,
        notes: dto.notes ?? null,
        images: dto.images ?? [],
        providerId: provider?.id ?? null,
      },
    });
  }

  // Vet ajoute une ordonnance via token
  async createPrescriptionByToken(token: string, userId: string, dto: any) {
    const accessToken = await this.prisma.petAccessToken.findUnique({
      where: { token },
      include: { pet: true },
    });

    if (!accessToken) throw new NotFoundException('Token not found');
    if (accessToken.expiresAt < new Date()) {
      throw new ForbiddenException('Token expired');
    }

    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });

    return this.prisma.prescription.create({
      data: {
        petId: accessToken.petId,
        providerId: provider?.id ?? null,
        title: dto.title,
        description: dto.description ?? null,
        imageUrl: dto.imageUrl ?? null,
        date: new Date(),
      },
    });
  }

  // Vet ajoute un suivi de maladie via token
  async createDiseaseByToken(token: string, userId: string, dto: any) {
    const accessToken = await this.prisma.petAccessToken.findUnique({
      where: { token },
      include: { pet: true },
    });

    if (!accessToken) throw new NotFoundException('Token not found');
    if (accessToken.expiresAt < new Date()) {
      throw new ForbiddenException('Token expired');
    }

    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });

    return this.prisma.diseaseTracking.create({
      data: {
        petId: accessToken.petId,
        providerId: provider?.id ?? null,
        name: dto.name,
        description: dto.description ?? null,
        status: dto.status ?? 'ONGOING',
        diagnosisDate: new Date(),
        images: dto.images ?? [],
        notes: dto.notes ?? null,
      },
    });
  }

  // Vet ajoute une vaccination via token
  async createVaccinationByToken(token: string, userId: string, dto: any) {
    const accessToken = await this.prisma.petAccessToken.findUnique({
      where: { token },
      include: { pet: true },
    });

    if (!accessToken) throw new NotFoundException('Token not found');
    if (accessToken.expiresAt < new Date()) {
      throw new ForbiddenException('Token expired');
    }

    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });

    return this.prisma.vaccination.create({
      data: {
        petId: accessToken.petId,
        vetId: userId,
        vetName: dto.veterinarian ?? provider?.displayName ?? null,
        name: dto.name,
        date: dto.date ? new Date(dto.date) : new Date(),
        nextDueDate: dto.nextDueDate ? new Date(dto.nextDueDate) : null,
        batchNumber: dto.batchNumber ?? null,
        notes: dto.notes ?? null,
      },
    });
  }

  // Vet ajoute un traitement via token
  async createTreatmentByToken(token: string, userId: string, dto: any) {
    const accessToken = await this.prisma.petAccessToken.findUnique({
      where: { token },
      include: { pet: true },
    });

    if (!accessToken) throw new NotFoundException('Token not found');
    if (accessToken.expiresAt < new Date()) {
      throw new ForbiddenException('Token expired');
    }

    return this.prisma.treatment.create({
      data: {
        petId: accessToken.petId,
        name: dto.name,
        dosage: dto.dosage ?? null,
        frequency: dto.frequency ?? null,
        startDate: dto.startDate ? new Date(dto.startDate) : new Date(),
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        isActive: dto.isActive ?? true,
        notes: dto.notes ?? null,
        attachments: dto.attachments ?? [],
      },
    });
  }

  // Vet ajoute un poids via token
  async createWeightRecordByToken(token: string, userId: string, dto: any) {
    const accessToken = await this.prisma.petAccessToken.findUnique({
      where: { token },
      include: { pet: true },
    });

    if (!accessToken) throw new NotFoundException('Token not found');
    if (accessToken.expiresAt < new Date()) {
      throw new ForbiddenException('Token expired');
    }

    return this.prisma.weightRecord.create({
      data: {
        petId: accessToken.petId,
        weightKg: parseFloat(dto.weightKg),
        date: dto.date ? new Date(dto.date) : new Date(),
        notes: dto.context ?? dto.notes ?? null, // Accept both context and notes
      },
    });
  }

  // Delete medical record by provider (only own records)
  async deleteMedicalRecordByProvider(userId: string, recordId: string) {
    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!provider) throw new ForbiddenException('Not a provider');

    const record = await this.prisma.medicalRecord.findUnique({ where: { id: recordId } });
    if (!record) throw new NotFoundException('Record not found');
    if (record.providerId !== provider.id) throw new ForbiddenException('Not your record');

    return this.prisma.medicalRecord.delete({ where: { id: recordId } });
  }

  // List prescriptions for a pet
  async listPrescriptions(userId: string, petId: string) {
    return this.prisma.prescription.findMany({
      where: { petId },
      include: { provider: { select: { id: true, displayName: true } } },
      orderBy: { date: 'desc' },
    });
  }

  // Update prescription by provider (only own records)
  async updatePrescriptionByProvider(userId: string, prescriptionId: string, dto: any) {
    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!provider) throw new ForbiddenException('Not a provider');

    const prescription = await this.prisma.prescription.findUnique({ where: { id: prescriptionId } });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.providerId !== provider.id) throw new ForbiddenException('Not your prescription');

    return this.prisma.prescription.update({
      where: { id: prescriptionId },
      data: {
        title: dto.title ?? prescription.title,
        description: dto.description ?? prescription.description,
        imageUrl: dto.imageUrl ?? prescription.imageUrl,
      },
      include: { provider: { select: { id: true, displayName: true } } },
    });
  }

  // Delete prescription by provider (only own records)
  async deletePrescriptionByProvider(userId: string, prescriptionId: string) {
    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!provider) throw new ForbiddenException('Not a provider');

    const prescription = await this.prisma.prescription.findUnique({ where: { id: prescriptionId } });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.providerId !== provider.id) throw new ForbiddenException('Not your prescription');

    return this.prisma.prescription.delete({ where: { id: prescriptionId } });
  }

  // Update disease by provider (only own records)
  async updateDiseaseByProvider(userId: string, diseaseId: string, dto: any) {
    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!provider) throw new ForbiddenException('Not a provider');

    const disease = await this.prisma.diseaseTracking.findUnique({ where: { id: diseaseId } });
    if (!disease) throw new NotFoundException('Disease not found');
    if (disease.providerId !== provider.id) throw new ForbiddenException('Not your record');

    return this.prisma.diseaseTracking.update({
      where: { id: diseaseId },
      data: {
        name: dto.name ?? disease.name,
        description: dto.description ?? disease.description,
        status: dto.status ?? disease.status,
        notes: dto.notes ?? disease.notes,
        images: dto.images ?? disease.images,
      },
      include: { provider: { select: { id: true, displayName: true } } },
    });
  }

  // Delete disease by provider (only own records)
  async deleteDiseaseByProvider(userId: string, diseaseId: string) {
    const provider = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!provider) throw new ForbiddenException('Not a provider');

    const disease = await this.prisma.diseaseTracking.findUnique({ where: { id: diseaseId } });
    if (!disease) throw new NotFoundException('Disease not found');
    if (disease.providerId !== provider.id) throw new ForbiddenException('Not your record');

    return this.prisma.diseaseTracking.delete({ where: { id: diseaseId } });
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
        attachments: dto.attachments ?? [],
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
        attachments: dto.attachments !== undefined ? dto.attachments : treatment.attachments,
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

  // ============ HEALTH STATISTICS ============

  /**
   * Obtenir les statistiques de santé d'un animal
   * Agrège les données de poids, température, fréquence cardiaque depuis:
   * - MedicalRecord (enregistrées lors des visites)
   * - WeightRecord (pesées dédiées)
   */
  async getHealthStats(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    // Récupérer les données de santé depuis MedicalRecord (visites vétérinaires)
    const medicalRecords = await this.prisma.medicalRecord.findMany({
      where: {
        petId,
        OR: [
          { weightKg: { not: null } },
          { temperatureC: { not: null } },
          { heartRate: { not: null } },
        ],
      },
      select: {
        id: true,
        date: true,
        type: true,
        title: true,
        vetName: true,
        weightKg: true,
        temperatureC: true,
        heartRate: true,
      },
      orderBy: { date: 'asc' },
    });

    // Récupérer les pesées dédiées
    const weightRecords = await this.prisma.weightRecord.findMany({
      where: { petId },
      select: {
        id: true,
        date: true,
        weightKg: true,
        notes: true,
      },
      orderBy: { date: 'asc' },
    });

    // Fusionner les données de poids (MedicalRecord + WeightRecord)
    const weightData = [
      ...medicalRecords
        .filter((r) => r.weightKg != null)
        .map((r) => ({
          date: r.date,
          weightKg: Number(r.weightKg),
          source: 'visit',
          context: r.title,
          vetName: r.vetName,
        })),
      ...weightRecords.map((r) => ({
        date: r.date,
        weightKg: Number(r.weightKg),
        source: 'manual',
        notes: r.notes,
      })),
    ].sort((a, b) => a.date.getTime() - b.date.getTime());

    // Données de température (uniquement depuis MedicalRecord)
    const temperatureData = medicalRecords
      .filter((r) => r.temperatureC != null)
      .map((r) => ({
        date: r.date,
        temperatureC: Number(r.temperatureC),
        context: r.title,
        vetName: r.vetName,
      }));

    // Données de fréquence cardiaque (uniquement depuis MedicalRecord)
    const heartRateData = medicalRecords
      .filter((r) => r.heartRate != null)
      .map((r) => ({
        date: r.date,
        heartRate: r.heartRate!,
        context: r.title,
        vetName: r.vetName,
      }));

    return {
      petId,
      weight: {
        data: weightData,
        current: weightData.length > 0 ? weightData[weightData.length - 1].weightKg : null,
        min: weightData.length > 0 ? Math.min(...weightData.map((d) => d.weightKg)) : null,
        max: weightData.length > 0 ? Math.max(...weightData.map((d) => d.weightKg)) : null,
      },
      temperature: {
        data: temperatureData,
        current: temperatureData.length > 0 ? temperatureData[temperatureData.length - 1].temperatureC : null,
        average: temperatureData.length > 0
          ? temperatureData.reduce((sum, d) => sum + d.temperatureC, 0) / temperatureData.length
          : null,
      },
      heartRate: {
        data: heartRateData,
        current: heartRateData.length > 0 ? heartRateData[heartRateData.length - 1].heartRate : null,
        average: heartRateData.length > 0
          ? Math.round(heartRateData.reduce((sum, d) => sum + d.heartRate!, 0) / heartRateData.length)
          : null,
      },
    };
  }

  // ============ DISEASE TRACKING ============

  async listDiseaseTrackings(ownerId: string, petId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.diseaseTracking.findMany({
      where: { petId },
      include: {
        progressEntries: {
          orderBy: { date: 'desc' },
          take: 3, // Les 3 dernières entrées par maladie
        },
      },
      orderBy: [
        { status: 'asc' }, // ONGOING en premier
        { diagnosisDate: 'desc' },
      ],
    });
  }

  async getDiseaseTracking(ownerId: string, petId: string, diseaseId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const disease = await this.prisma.diseaseTracking.findFirst({
      where: { id: diseaseId, petId },
      include: {
        progressEntries: {
          orderBy: { date: 'desc' },
        },
      },
    });

    if (!disease) throw new NotFoundException('Disease tracking not found');
    return disease;
  }

  async createDiseaseTracking(ownerId: string, petId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    return this.prisma.diseaseTracking.create({
      data: {
        petId,
        name: dto.name,
        description: dto.description ?? null,
        status: dto.status ?? 'ONGOING',
        severity: dto.severity ?? null,
        diagnosisDate: new Date(dto.diagnosisDate),
        curedDate: dto.curedDate ? new Date(dto.curedDate) : null,
        vetId: dto.vetId ?? null,
        vetName: dto.vetName ?? null,
        symptoms: dto.symptoms ?? null,
        treatment: dto.treatment ?? null,
        images: dto.images ?? [],
        notes: dto.notes ?? null,
      },
    });
  }

  async updateDiseaseTracking(ownerId: string, petId: string, diseaseId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const disease = await this.prisma.diseaseTracking.findFirst({
      where: { id: diseaseId, petId },
    });
    if (!disease) throw new NotFoundException('Disease tracking not found');

    return this.prisma.diseaseTracking.update({
      where: { id: diseaseId },
      data: {
        name: dto.name ?? disease.name,
        description: dto.description ?? disease.description,
        status: dto.status ?? disease.status,
        severity: dto.severity ?? disease.severity,
        diagnosisDate: dto.diagnosisDate ? new Date(dto.diagnosisDate) : disease.diagnosisDate,
        curedDate: dto.curedDate ? new Date(dto.curedDate) : disease.curedDate,
        vetId: dto.vetId ?? disease.vetId,
        vetName: dto.vetName ?? disease.vetName,
        symptoms: dto.symptoms ?? disease.symptoms,
        treatment: dto.treatment ?? disease.treatment,
        images: dto.images ?? disease.images,
        notes: dto.notes ?? disease.notes,
      },
    });
  }

  async deleteDiseaseTracking(ownerId: string, petId: string, diseaseId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const disease = await this.prisma.diseaseTracking.findFirst({
      where: { id: diseaseId, petId },
    });
    if (!disease) throw new NotFoundException('Disease tracking not found');

    return this.prisma.diseaseTracking.delete({ where: { id: diseaseId } });
  }

  // Ajouter une entrée de progression
  async addProgressEntry(ownerId: string, petId: string, diseaseId: string, dto: any) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const disease = await this.prisma.diseaseTracking.findFirst({
      where: { id: diseaseId, petId },
    });
    if (!disease) throw new NotFoundException('Disease tracking not found');

    return this.prisma.diseaseProgressEntry.create({
      data: {
        diseaseId,
        date: new Date(dto.date ?? new Date()),
        notes: dto.notes,
        images: dto.images ?? [],
        severity: dto.severity ?? null,
        treatmentUpdate: dto.treatmentUpdate ?? null,
      },
    });
  }

  async deleteProgressEntry(ownerId: string, petId: string, diseaseId: string, entryId: string) {
    const pet = await this.prisma.pet.findUnique({ where: { id: petId } });
    if (!pet) throw new NotFoundException('Pet not found');
    if (pet.ownerId !== ownerId) throw new ForbiddenException();

    const disease = await this.prisma.diseaseTracking.findFirst({
      where: { id: diseaseId, petId },
    });
    if (!disease) throw new NotFoundException('Disease tracking not found');

    const entry = await this.prisma.diseaseProgressEntry.findUnique({
      where: { id: entryId },
    });
    if (!entry || entry.diseaseId !== diseaseId) {
      throw new NotFoundException('Progress entry not found');
    }

    return this.prisma.diseaseProgressEntry.delete({ where: { id: entryId } });
  }
}
