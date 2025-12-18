import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { TrustStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDaycareBookingDto } from './dto/create-booking.dto';
import { DaycareBookingStatus } from './dto/update-status.dto';

// Durées de restriction progressives (en jours) - mêmes que bookings
const RESTRICTION_DURATIONS = [3, 7, 14, 30];

// Configuration frais de retard
const LATE_FEE_GRACE_MINUTES = 15; // 15 min de grâce
const DEFAULT_HOURLY_RATE_DA = 200; // Tarif horaire par défaut si non configuré
const DEFAULT_DAILY_RATE_DA = 1500; // Tarif journalier par défaut si non configuré

// Rate limiting OTP
const OTP_MAX_ATTEMPTS = 3;
const OTP_BLOCK_DURATION_MS = 15 * 60 * 1000; // 15 minutes de blocage

@Injectable()
export class DaycareService {
  constructor(private prisma: PrismaService) {}

  // Rate limiting OTP - stockage en mémoire (simple mais efficace)
  // Key: bookingId_phase, Value: { attempts: number, blockedUntil: Date | null }
  private otpAttempts = new Map<string, { attempts: number; blockedUntil: Date | null }>();

  private checkOtpRateLimit(bookingId: string, phase: 'drop' | 'pickup'): void {
    const key = `${bookingId}_${phase}`;
    const record = this.otpAttempts.get(key);

    if (record) {
      // Vérifier si bloqué
      if (record.blockedUntil && record.blockedUntil > new Date()) {
        const remainingMinutes = Math.ceil((record.blockedUntil.getTime() - Date.now()) / 60000);
        throw new BadRequestException(
          `Trop de tentatives. Réessayez dans ${remainingMinutes} minute(s).`
        );
      }
      // Reset si blocage expiré
      if (record.blockedUntil && record.blockedUntil <= new Date()) {
        this.otpAttempts.delete(key);
      }
    }
  }

  private recordOtpFailure(bookingId: string, phase: 'drop' | 'pickup'): void {
    const key = `${bookingId}_${phase}`;
    const record = this.otpAttempts.get(key) || { attempts: 0, blockedUntil: null };

    record.attempts += 1;

    if (record.attempts >= OTP_MAX_ATTEMPTS) {
      record.blockedUntil = new Date(Date.now() + OTP_BLOCK_DURATION_MS);
    }

    this.otpAttempts.set(key, record);
  }

  private clearOtpAttempts(bookingId: string, phase: 'drop' | 'pickup'): void {
    const key = `${bookingId}_${phase}`;
    this.otpAttempts.delete(key);
  }

  // Calcul de distance GPS (formule Haversine)
  private calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371000; // Rayon de la Terre en mètres
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c); // Distance en mètres
  }

  // ==================== TRUST SYSTEM HELPERS ====================

  private getRestrictionDays(noShowCount: number): number {
    const index = Math.min(noShowCount - 1, RESTRICTION_DURATIONS.length - 1);
    return RESTRICTION_DURATIONS[Math.max(0, index)];
  }

  private async applyNoShowPenalty(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { noShowCount: true },
    });
    if (!user) return;

    const newNoShowCount = user.noShowCount + 1;
    const restrictionDays = this.getRestrictionDays(newNoShowCount);
    const restrictedUntil = new Date();
    restrictedUntil.setDate(restrictedUntil.getDate() + restrictionDays);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        noShowCount: newNoShowCount,
        trustStatus: 'RESTRICTED',
        restrictedUntil,
      },
    });
  }

  private async verifyUserIfNeeded(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true },
    });
    if (!user) return;

    if (user.trustStatus === 'NEW') {
      await this.prisma.user.update({
        where: { id: userId },
        data: {
          trustStatus: 'VERIFIED',
          verifiedAt: new Date(),
          noShowCount: 0,
        },
      });
    }
  }

  async checkUserCanBookDaycare(userId: string): Promise<{
    canBook: boolean;
    reason?: string;
    isFirstBooking?: boolean;
    trustStatus?: TrustStatus;
  }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true, restrictedUntil: true, noShowCount: true },
    });

    if (!user) return { canBook: false, reason: 'Utilisateur non trouvé' };

    // Vérifier restriction expirée
    if (user.trustStatus === 'RESTRICTED') {
      if (user.restrictedUntil && user.restrictedUntil <= new Date()) {
        await this.prisma.user.update({
          where: { id: userId },
          data: { trustStatus: 'NEW', restrictedUntil: null },
        });
      } else {
        const remainingDays = user.restrictedUntil
          ? Math.ceil((user.restrictedUntil.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
          : 0;
        return {
          canBook: false,
          reason: `Votre compte est restreint pour encore ${remainingDays} jour(s).`,
          trustStatus: user.trustStatus,
        };
      }
    }

    // NEW user: vérifier s'il a déjà un RDV actif (garderie ou véto)
    if (user.trustStatus === 'NEW') {
      // Vérifier bookings véto actifs
      const activeVetBooking = await this.prisma.booking.findFirst({
        where: {
          userId,
          status: { in: ['PENDING', 'CONFIRMED', 'AWAITING_CONFIRMATION', 'PENDING_PRO_VALIDATION'] },
        },
      });

      // Vérifier bookings garderie actifs
      const activeDaycareBooking = await this.prisma.daycareBooking.findFirst({
        where: {
          userId,
          status: { in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'PENDING_DROP_VALIDATION', 'PENDING_PICKUP_VALIDATION'] },
        },
      });

      if (activeVetBooking || activeDaycareBooking) {
        return {
          canBook: false,
          reason: 'En tant que nouveau client, vous devez d\'abord honorer votre rendez-vous en cours.',
          trustStatus: user.trustStatus,
          isFirstBooking: false,
        };
      }

      return { canBook: true, trustStatus: user.trustStatus, isFirstBooking: true };
    }

    return { canBook: true, trustStatus: user.trustStatus, isFirstBooking: false };
  }

  /**
   * Créer une réservation garderie (client)
   */
  async createBooking(userId: string, dto: CreateDaycareBookingDto) {
    // ✅ TRUST SYSTEM: Vérifier si l'utilisateur peut réserver
    const trustCheck = await this.checkUserCanBookDaycare(userId);
    if (!trustCheck.canBook) {
      throw new ForbiddenException(trustCheck.reason || 'Réservation non autorisée');
    }

    // Vérifier que le pet appartient au user
    const pet = await this.prisma.pet.findUnique({
      where: { id: dto.petId },
    });

    if (!pet) {
      throw new NotFoundException('Animal non trouvé');
    }

    if (pet.ownerId !== userId) {
      throw new ForbiddenException('Cet animal ne vous appartient pas');
    }

    // Vérifier que le provider existe et est une garderie approuvée
    const provider = await this.prisma.providerProfile.findUnique({
      where: { id: dto.providerId },
    });

    if (!provider) {
      throw new NotFoundException('Garderie non trouvée');
    }

    if (!provider.isApproved) {
      throw new BadRequestException('Cette garderie n\'est pas encore approuvée');
    }

    const specialties = provider.specialties as any;
    if (specialties?.kind !== 'daycare') {
      throw new BadRequestException('Ce professionnel n\'est pas une garderie');
    }

    // Vérifier les dates
    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);

    if (start >= end) {
      throw new BadRequestException('La date de fin doit être après la date de début');
    }

    if (start < new Date()) {
      throw new BadRequestException('La date de début ne peut pas être dans le passé');
    }

    // Calculer le total (prix + commission)
    const totalDa = dto.priceDa + 100; // Commission fixe de 100 DA

    // Créer la réservation
    const booking = await this.prisma.daycareBooking.create({
      data: {
        userId,
        providerId: dto.providerId,
        petId: dto.petId,
        startDate: start,
        endDate: end,
        priceDa: dto.priceDa,
        commissionDa: 100,
        totalDa,
        notes: dto.notes,
      },
      include: {
        pet: true,
        provider: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
              },
            },
          },
        },
      },
    });

    return booking;
  }

  /**
   * Obtenir les réservations du client
   */
  async getMyBookings(userId: string) {
    return this.prisma.daycareBooking.findMany({
      where: { userId },
      include: {
        pet: true,
        provider: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
              },
            },
          },
        },
      },
      orderBy: { startDate: 'desc' },
    });
  }

  /**
   * Obtenir les détails d'une réservation par ID
   */
  async getBookingById(userId: string, bookingId: string) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
      include: {
        pet: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
          },
        },
        provider: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
              },
            },
          },
        },
      },
    });

    if (!booking) {
      throw new NotFoundException('Réservation non trouvée');
    }

    // Vérifier que l'utilisateur a accès à cette réservation
    // (soit c'est le client, soit c'est le provider)
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    const isClient = booking.userId === userId;
    const isProvider = provider && booking.providerId === provider.id;

    if (!isClient && !isProvider) {
      throw new ForbiddenException('Accès non autorisé à cette réservation');
    }

    return booking;
  }

  /**
   * Obtenir les réservations de ma garderie (provider)
   */
  async getProviderBookings(userId: string) {
    // Trouver le provider profile
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) {
      throw new NotFoundException('Profil professionnel non trouvé');
    }

    const bookings = await this.prisma.daycareBooking.findMany({
      where: { providerId: provider.id },
      include: {
        pet: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
            trustStatus: true, // ✅ TRUST SYSTEM
          },
        },
      },
      orderBy: { startDate: 'desc' },
    });

    // ✅ TRUST SYSTEM: Ajouter isFirstBooking pour chaque réservation
    const userIds = [...new Set(bookings.map(b => b.user.id))];
    const completedCounts = await Promise.all(
      userIds.map(async (uid) => ({
        userId: uid,
        vetCount: await this.prisma.booking.count({ where: { userId: uid, status: 'COMPLETED' } }),
        daycareCount: await this.prisma.daycareBooking.count({ where: { userId: uid, status: 'COMPLETED' } }),
      }))
    );
    const completedMap = new Map(completedCounts.map(c => [c.userId, c.vetCount + c.daycareCount]));

    return bookings.map((b: any) => ({
      ...b,
      user: {
        ...b.user,
        isFirstBooking: b.user.trustStatus === 'NEW' && (completedMap.get(b.user.id) ?? 0) === 0,
      },
    }));
  }

  /**
   * Mettre à jour le statut d'une réservation (provider uniquement)
   */
  async updateBookingStatus(
    userId: string,
    bookingId: string,
    status: DaycareBookingStatus,
  ) {
    // Vérifier que le user est bien le provider de cette réservation
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) {
      throw new ForbiddenException('Vous n\'êtes pas un professionnel');
    }

    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Réservation non trouvée');
    }

    if (booking.providerId !== provider.id) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    // Mettre à jour le statut
    return this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: { status },
      include: {
        pet: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
          },
        },
      },
    });
  }

  /**
   * Marquer l'heure de dépôt de l'animal (passage à IN_PROGRESS)
   */
  async markDropOff(userId: string, bookingId: string) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
      include: { user: { select: { firstName: true, lastName: true } } },
    });

    if (!provider) {
      throw new ForbiddenException('Vous n\'êtes pas un professionnel');
    }

    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Réservation non trouvée');
    }

    if (booking.providerId !== provider.id) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    if (booking.status !== 'CONFIRMED') {
      throw new BadRequestException('La réservation doit être confirmée pour marquer le dépôt');
    }

    const updatedBooking = await this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        status: 'IN_PROGRESS',
        actualDropOff: new Date(),
      },
      include: {
        pet: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
          },
        },
      },
    });

    // 🏥 NOUVEAU: Créer automatiquement un acte médical pour l'animal
    const providerName = `${provider.user.firstName || ''} ${provider.user.lastName || ''}`.trim() || provider.displayName || 'Garderie';
    const durationDays = Math.ceil((new Date(booking.endDate).getTime() - new Date(booking.startDate).getTime()) / (1000 * 60 * 60 * 24));

    await this.prisma.medicalRecord.create({
      data: {
        petId: booking.petId,
        type: 'DAYCARE_VISIT',
        title: `Séjour en garderie - ${providerName}`,
        description: `Séjour confirmé en garderie`,
        date: new Date(booking.startDate),
        vetId: provider.id,
        vetName: providerName,
        providerType: 'DAYCARE',
        daycareBookingId: booking.id,
        durationMinutes: durationDays * 24 * 60, // Convertir jours en minutes
        notes: `Séjour du ${new Date(booking.startDate).toLocaleDateString('fr-FR')} au ${new Date(booking.endDate).toLocaleDateString('fr-FR')}\nDurée: ${durationDays} jour(s)`,
      },
    });

    return updatedBooking;
  }

  /**
   * Marquer l'heure de récupération de l'animal (passage à COMPLETED)
   */
  async markPickup(userId: string, bookingId: string) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) {
      throw new ForbiddenException('Vous n\'êtes pas un professionnel');
    }

    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Réservation non trouvée');
    }

    if (booking.providerId !== provider.id) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    if (booking.status !== 'IN_PROGRESS') {
      throw new BadRequestException('L\'animal doit d\'abord être déposé');
    }

    return this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        status: 'COMPLETED',
        actualPickup: new Date(),
      },
      include: {
        pet: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
          },
        },
      },
    });
  }

  /**
   * Obtenir les animaux présents un jour donné (pour le calendrier)
   */
  async getCalendar(userId: string, date: string) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) {
      throw new NotFoundException('Profil professionnel non trouvé');
    }

    const targetDate = new Date(date);
    const dayStart = new Date(targetDate.setHours(0, 0, 0, 0));
    const dayEnd = new Date(targetDate.setHours(23, 59, 59, 999));

    return this.prisma.daycareBooking.findMany({
      where: {
        providerId: provider.id,
        startDate: {
          lte: dayEnd,
        },
        endDate: {
          gte: dayStart,
        },
        status: {
          in: ['CONFIRMED', 'IN_PROGRESS', 'COMPLETED'],
        },
      },
      include: {
        pet: true,
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            phone: true,
          },
        },
      },
      orderBy: { startDate: 'asc' },
    });
  }

  /**
   * Annuler une réservation (client uniquement)
   */
  async cancelMyBooking(userId: string, bookingId: string) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Réservation non trouvée');
    }

    // Vérifier que c'est bien la réservation du client
    if (booking.userId !== userId) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    // Vérifier que la réservation peut être annulée
    if (booking.status === 'CANCELLED') {
      throw new BadRequestException('Cette réservation est déjà annulée');
    }

    if (booking.status === 'COMPLETED') {
      throw new BadRequestException('Impossible d\'annuler une réservation terminée');
    }

    // ✅ TRUST SYSTEM: Vérifier si annulation tardive pour NEW user (< 24h pour garderie)
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true },
    });

    if (user?.trustStatus === 'NEW') {
      const hoursUntilStart = (new Date(booking.startDate).getTime() - Date.now()) / (1000 * 60 * 60);
      if (hoursUntilStart < 24) {
        // Annulation < 24h avant le début → appliquer pénalité no-show
        await this.applyNoShowPenalty(userId);
      }
    }

    // Annuler la réservation
    return this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: { status: 'CANCELLED' },
      include: {
        pet: true,
        provider: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
              },
            },
          },
        },
      },
    });
  }

  // ============================================
  // SYSTÈME ANTI-FRAUDE
  // ============================================

  /**
   * Client: Confirmer l'arrivée pour déposer l'animal (avec géoloc)
   * Calcule la distance au provider si GPS disponible (pour audit admin)
   */
  async clientConfirmDropOff(
    userId: string,
    bookingId: string,
    method: string = 'PROXIMITY',
    lat?: number,
    lng?: number,
  ) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
      include: { provider: true },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.userId !== userId) throw new ForbiddenException('Cette réservation ne vous appartient pas');
    if (booking.status !== 'CONFIRMED') {
      throw new BadRequestException(`La réservation doit être confirmée pour le dépôt (statut actuel: ${booking.status})`);
    }

    // Vérifier la date (doit être le jour du dépôt ou proche)
    const now = new Date();
    const startDate = new Date(booking.startDate);
    const diffHours = (startDate.getTime() - now.getTime()) / (1000 * 60 * 60);

    // Autoriser confirmation 24h avant jusqu'à 24h après le début prévu
    if (diffHours > 24 || diffHours < -24) {
      throw new BadRequestException('Vous ne pouvez confirmer que le jour du dépôt (24h avant/après)');
    }

    // Calculer la distance au provider si GPS client et provider disponibles
    let distanceMeters: number | null = null;
    if (lat && lng && booking.provider?.lat && booking.provider?.lng) {
      distanceMeters = this.calculateDistance(lat, lng, booking.provider.lat, booking.provider.lng);
    }

    // Si méthode OTP, on génère juste le code SANS changer le statut
    // Le statut changera quand le pro validera
    if (method === 'OTP') {
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

      const updated = await this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          // NE PAS changer le statut ici !
          clientDropConfirmedAt: now,
          dropConfirmationMethod: 'OTP',
          dropCheckinLat: lat,
          dropCheckinLng: lng,
          dropOtpCode: otpCode,
          dropOtpExpiresAt: otpExpiresAt,
          clientNearbyAt: now,
        },
        include: {
          pet: true,
          provider: true,
          user: { select: { id: true, firstName: true, lastName: true, phone: true } },
        },
      });

      // Retourner avec la distance calculée (pour info admin)
      return { ...updated, dropDistanceMeters: distanceMeters };
    }

    // Pour les autres méthodes (PROXIMITY, MANUAL), on met en attente de validation pro
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

    const updated = await this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        status: 'PENDING_DROP_VALIDATION',
        clientDropConfirmedAt: now,
        dropConfirmationMethod: method,
        dropCheckinLat: lat,
        dropCheckinLng: lng,
        dropOtpCode: otpCode,
        dropOtpExpiresAt: otpExpiresAt,
      },
      include: {
        pet: true,
        provider: true,
        user: { select: { id: true, firstName: true, lastName: true, phone: true } },
      },
    });

    // Retourner avec la distance calculée (pour info admin)
    return { ...updated, dropDistanceMeters: distanceMeters };
  }

  /**
   * Client: Confirmer le retrait de l'animal (avec géoloc)
   * Calcule la distance au provider si GPS disponible (pour audit admin)
   */
  async clientConfirmPickup(
    userId: string,
    bookingId: string,
    method: string = 'PROXIMITY',
    lat?: number,
    lng?: number,
  ) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
      include: { provider: true },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.userId !== userId) throw new ForbiddenException('Cette réservation ne vous appartient pas');
    if (booking.status !== 'IN_PROGRESS') {
      throw new BadRequestException('L\'animal doit d\'abord être déposé');
    }

    const now = new Date();
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // Calculer la distance au provider si GPS client et provider disponibles
    let distanceMeters: number | null = null;
    if (lat && lng && booking.provider?.lat && booking.provider?.lng) {
      distanceMeters = this.calculateDistance(lat, lng, booking.provider.lat, booking.provider.lng);
    }

    // Si méthode OTP, on génère juste le code SANS changer le statut
    if (method === 'OTP') {
      const updated = await this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          // NE PAS changer le statut ici !
          clientPickupConfirmedAt: now,
          pickupConfirmationMethod: 'OTP',
          pickupCheckinLat: lat,
          pickupCheckinLng: lng,
          pickupOtpCode: otpCode,
          pickupOtpExpiresAt: otpExpiresAt,
          clientNearbyAt: now,
        },
        include: {
          pet: true,
          provider: true,
          user: { select: { id: true, firstName: true, lastName: true, phone: true } },
        },
      });

      // Retourner avec la distance calculée (pour info admin)
      return { ...updated, pickupDistanceMeters: distanceMeters };
    }

    // Pour les autres méthodes, on met en attente de validation pro
    const updated = await this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        status: 'PENDING_PICKUP_VALIDATION',
        clientPickupConfirmedAt: now,
        pickupConfirmationMethod: method,
        pickupCheckinLat: lat,
        pickupCheckinLng: lng,
        pickupOtpCode: otpCode,
        pickupOtpExpiresAt: otpExpiresAt,
      },
      include: {
        pet: true,
        provider: true,
        user: { select: { id: true, firstName: true, lastName: true, phone: true } },
      },
    });

    // Retourner avec la distance calculée (pour info admin)
    return { ...updated, pickupDistanceMeters: distanceMeters };
  }

  /**
   * Pro: Valider le dépôt de l'animal (après confirmation client)
   */
  async proValidateDropOff(
    userId: string,
    bookingId: string,
    approved: boolean,
    method: string = 'MANUAL',
  ) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
      include: { user: { select: { firstName: true, lastName: true } } },
    });

    if (!provider) throw new ForbiddenException('Vous n\'êtes pas un professionnel');

    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.providerId !== provider.id) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    if (booking.status !== 'PENDING_DROP_VALIDATION') {
      throw new BadRequestException('Le client doit d\'abord confirmer son arrivée');
    }

    if (approved) {
      // ✅ VALIDER LE DÉPÔT
      const updatedBooking = await this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          status: 'IN_PROGRESS',
          actualDropOff: new Date(),
          dropConfirmationMethod: method,
        },
        include: { pet: true, user: { select: { id: true, firstName: true, lastName: true } } },
      });

      // Créer acte médical
      const providerName = `${provider.user.firstName || ''} ${provider.user.lastName || ''}`.trim() || provider.displayName || 'Garderie';
      const durationDays = Math.ceil((new Date(booking.endDate).getTime() - new Date(booking.startDate).getTime()) / (1000 * 60 * 60 * 24));

      await this.prisma.medicalRecord.create({
        data: {
          petId: booking.petId,
          type: 'DAYCARE_VISIT',
          title: `Séjour en garderie - ${providerName}`,
          description: `Séjour confirmé en garderie`,
          date: new Date(booking.startDate),
          vetId: provider.id,
          vetName: providerName,
          providerType: 'DAYCARE',
          daycareBookingId: booking.id,
          durationMinutes: durationDays * 24 * 60,
          notes: `Confirmation: ${method}`,
        },
      });

      return updatedBooking;
    } else {
      // ❌ REFUSER = CLIENT MENT (NO-SHOW)
      await this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          status: 'DISPUTED',
          disputeNote: 'Pro claims client did not arrive for drop-off',
        },
      });

      await this.prisma.adminFlag.create({
        data: {
          userId: booking.userId,
          type: 'DAYCARE_DISPUTE',
          note: 'Pro claims client did not arrive for daycare drop-off (DISPUTED)',
        },
      });

      // ❌ TRUST SYSTEM: Appliquer la pénalité no-show
      await this.applyNoShowPenalty(booking.userId);

      return { disputed: true, message: 'Réservation marquée en litige' };
    }
  }

  /**
   * Pro: Valider le retrait de l'animal (après confirmation client)
   */
  async proValidatePickup(
    userId: string,
    bookingId: string,
    approved: boolean,
    method: string = 'MANUAL',
  ) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) throw new ForbiddenException('Vous n\'êtes pas un professionnel');

    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.providerId !== provider.id) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    if (booking.status !== 'PENDING_PICKUP_VALIDATION') {
      throw new BadRequestException('Le client doit d\'abord confirmer le retrait');
    }

    if (approved) {
      const updatedBooking = await this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          status: 'COMPLETED',
          actualPickup: new Date(),
          pickupConfirmationMethod: method,
        },
        include: { pet: true, user: { select: { id: true, firstName: true, lastName: true } } },
      });

      // ✅ TRUST SYSTEM: Vérifier l'utilisateur (NEW → VERIFIED)
      await this.verifyUserIfNeeded(booking.userId);

      return updatedBooking;
    } else {
      await this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          status: 'DISPUTED',
          disputeNote: 'Pro claims client did not arrive for pickup',
        },
      });

      await this.prisma.adminFlag.create({
        data: {
          userId: booking.userId,
          type: 'DAYCARE_DISPUTE',
          note: 'Pro claims client did not arrive for daycare pickup (DISPUTED)',
        },
      });

      // ❌ TRUST SYSTEM: Appliquer la pénalité no-show
      await this.applyNoShowPenalty(booking.userId);

      return { disputed: true, message: 'Réservation marquée en litige' };
    }
  }

  /**
   * Pro: Obtenir les réservations en attente de validation
   */
  async getPendingValidations(userId: string) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) throw new NotFoundException('Profil professionnel non trouvé');

    return this.prisma.daycareBooking.findMany({
      where: {
        providerId: provider.id,
        status: { in: ['PENDING_DROP_VALIDATION', 'PENDING_PICKUP_VALIDATION'] },
      },
      include: {
        pet: true,
        user: { select: { id: true, firstName: true, lastName: true, phone: true } },
      },
      orderBy: { startDate: 'asc' },
    });
  }

  /**
   * Client: Obtenir le code OTP pour le dépôt
   */
  async getDropOtp(userId: string, bookingId: string) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.userId !== userId) throw new ForbiddenException('Cette réservation ne vous appartient pas');

    if (!booking.dropOtpCode || !booking.dropOtpExpiresAt) {
      throw new BadRequestException('Aucun code OTP disponible');
    }

    if (new Date() > new Date(booking.dropOtpExpiresAt)) {
      throw new BadRequestException('Le code OTP a expiré');
    }

    return { otp: booking.dropOtpCode, expiresAt: booking.dropOtpExpiresAt };
  }

  /**
   * Client: Obtenir le code OTP pour le retrait
   */
  async getPickupOtp(userId: string, bookingId: string) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.userId !== userId) throw new ForbiddenException('Cette réservation ne vous appartient pas');

    if (!booking.pickupOtpCode || !booking.pickupOtpExpiresAt) {
      throw new BadRequestException('Aucun code OTP disponible');
    }

    if (new Date() > new Date(booking.pickupOtpExpiresAt)) {
      throw new BadRequestException('Le code OTP a expiré');
    }

    return { otp: booking.pickupOtpCode, expiresAt: booking.pickupOtpExpiresAt };
  }

  /**
   * Pro: Valider par code OTP (avec rate-limiting)
   * Max 3 tentatives, puis blocage 15 min
   */
  async validateByOtp(userId: string, bookingId: string, otpCode: string, phase: 'drop' | 'pickup') {
    // Vérifier le rate-limiting AVANT tout
    this.checkOtpRateLimit(bookingId, phase);

    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) throw new ForbiddenException('Vous n\'êtes pas un professionnel');

    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.providerId !== provider.id) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    const now = new Date();

    if (phase === 'drop') {
      // Accepter CONFIRMED (avec OTP généré) ou PENDING_DROP_VALIDATION
      if (booking.status !== 'CONFIRMED' && booking.status !== 'PENDING_DROP_VALIDATION') {
        throw new BadRequestException('Le booking doit être en statut confirmé pour valider le dépôt');
      }
      if (!booking.dropOtpCode) {
        throw new BadRequestException('Le client n\'a pas encore généré de code OTP');
      }
      if (booking.dropOtpCode !== otpCode) {
        // Enregistrer l'échec pour le rate-limiting
        this.recordOtpFailure(bookingId, phase);
        throw new BadRequestException('Code OTP incorrect');
      }
      if (!booking.dropOtpExpiresAt || now > new Date(booking.dropOtpExpiresAt)) {
        throw new BadRequestException('Le code OTP a expiré');
      }

      // Succès : réinitialiser les tentatives
      this.clearOtpAttempts(bookingId, phase);

      // Valider directement en changeant le statut à IN_PROGRESS
      return this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          status: 'IN_PROGRESS',
          actualDropOff: now,
          dropConfirmationMethod: 'OTP',
          dropOtpCode: null, // Effacer l'OTP utilisé
          dropOtpExpiresAt: null,
        },
        include: {
          pet: true,
          provider: true,
          user: { select: { id: true, firstName: true, lastName: true, phone: true } },
        },
      });
    } else {
      // Accepter IN_PROGRESS (avec OTP généré) ou PENDING_PICKUP_VALIDATION
      if (booking.status !== 'IN_PROGRESS' && booking.status !== 'PENDING_PICKUP_VALIDATION') {
        throw new BadRequestException('L\'animal doit être déposé avant le retrait');
      }
      if (!booking.pickupOtpCode) {
        throw new BadRequestException('Le client n\'a pas encore généré de code OTP');
      }
      if (booking.pickupOtpCode !== otpCode) {
        // Enregistrer l'échec pour le rate-limiting
        this.recordOtpFailure(bookingId, phase);
        throw new BadRequestException('Code OTP incorrect');
      }
      if (!booking.pickupOtpExpiresAt || now > new Date(booking.pickupOtpExpiresAt)) {
        throw new BadRequestException('Le code OTP a expiré');
      }

      // Succès : réinitialiser les tentatives
      this.clearOtpAttempts(bookingId, phase);

      // Valider directement en changeant le statut à COMPLETED
      const updatedBooking = await this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          status: 'COMPLETED',
          actualPickup: now,
          pickupConfirmationMethod: 'OTP',
          pickupOtpCode: null, // Effacer l'OTP utilisé
          pickupOtpExpiresAt: null,
        },
        include: {
          pet: true,
          provider: true,
          user: { select: { id: true, firstName: true, lastName: true, phone: true } },
        },
      });

      // ✅ TRUST SYSTEM: Vérifier l'utilisateur (NEW → VERIFIED) après pickup réussi
      await this.verifyUserIfNeeded(booking.userId);

      return updatedBooking;
    }
  }

  /**
   * Chercher un booking daycare actif pour un pet (pour le scan QR)
   * Utilisé par la garderie pour trouver si un animal a un RDV aujourd'hui
   */
  async findActiveDaycareBookingForPet(petId: string) {
    const pet = await this.prisma.pet.findUnique({
      where: { id: petId },
      select: { ownerId: true },
    });
    if (!pet) return null;

    const now = new Date();
    // Chercher RDV du jour (début à 00h00, fin à 23h59)
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(now);
    endOfDay.setHours(23, 59, 59, 999);

    // Chercher un daycare booking qui commence aujourd'hui ou est en cours
    const booking = await this.prisma.daycareBooking.findFirst({
      where: {
        userId: pet.ownerId,
        petId: petId, // ✅ Le pet scanné DOIT correspondre
        startDate: { gte: startOfDay, lte: endOfDay }, // ✅ Commence aujourd'hui
        status: { in: ['PENDING', 'CONFIRMED'] }, // Pas encore déposé
      },
      orderBy: { startDate: 'asc' },
      include: {
        pet: true,
        provider: {
          select: {
            id: true,
            displayName: true,
            weekly: {
              select: {
                weekday: true,
                startMin: true,
                endMin: true,
              },
            },
          },
        },
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            phone: true,
          },
        },
      },
    });

    if (!booking) return null;

    // ✅ Vérifier si on est dans les heures d'ouverture du provider
    const currentWeekday = now.getDay(); // 0=dimanche, 1=lundi, ..., 6=samedi
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    const todaySchedule = booking.provider?.weekly?.find(
      (w) => w.weekday === currentWeekday,
    );

    // Si le provider a des heures d'ouverture définies pour aujourd'hui
    if (todaySchedule) {
      const isWithinOpeningHours =
        currentMinutes >= todaySchedule.startMin &&
        currentMinutes <= todaySchedule.endMin;

      if (!isWithinOpeningHours) {
        // Hors heures d'ouverture : refuser le scan
        return null;
      }
    }
    // Si pas d'horaires définis, on accepte (comportement par défaut)

    return booking;
  }

  // ============================================
  // NOTIFICATION CLIENT À PROXIMITÉ
  // ============================================

  /**
   * Client: Notifier qu'il est à proximité (pour alerter le pro)
   */
  async notifyClientNearby(userId: string, bookingId: string, lat?: number, lng?: number) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
      include: { provider: true, pet: true },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.userId !== userId) throw new ForbiddenException('Cette réservation ne vous appartient pas');

    // Mise à jour pour indiquer que le client est à proximité
    return this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        clientNearbyAt: new Date(),
        dropCheckinLat: lat,
        dropCheckinLng: lng,
      },
      include: {
        pet: true,
        provider: true,
        user: { select: { id: true, firstName: true, lastName: true, phone: true } },
      },
    });
  }

  /**
   * Pro: Obtenir les clients à proximité (pour le jour actuel)
   */
  async getNearbyClients(userId: string) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) throw new NotFoundException('Profil professionnel non trouvé');

    // Chercher les bookings où:
    // 1. Le client est à proximité (dernières 30 minutes) OU
    // 2. Le client a un code OTP actif (non expiré)
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    const now = new Date();

    // Requête séparée pour éviter les conflits avec les filtres OR imbriqués
    return this.prisma.daycareBooking.findMany({
      where: {
        providerId: provider.id,
        OR: [
          // Client à proximité récemment (pour dépôt CONFIRMED)
          {
            status: 'CONFIRMED',
            clientNearbyAt: { gte: thirtyMinutesAgo },
          },
          // Client à proximité récemment (pour retrait IN_PROGRESS)
          {
            status: 'IN_PROGRESS',
            clientNearbyAt: { gte: thirtyMinutesAgo },
          },
          // OTP de dépôt actif et non expiré
          {
            status: 'CONFIRMED',
            dropOtpCode: { not: null },
            dropOtpExpiresAt: { gte: now },
          },
          // OTP de retrait actif et non expiré
          {
            status: 'IN_PROGRESS',
            pickupOtpCode: { not: null },
            pickupOtpExpiresAt: { gte: now },
          },
        ],
      },
      include: {
        pet: true,
        user: { select: { id: true, firstName: true, lastName: true, phone: true } },
      },
      orderBy: { clientNearbyAt: 'desc' },
    });
  }

  // ============================================
  // CALCUL FRAIS DE RETARD
  // ============================================

  /**
   * Calculer les frais de retard lors du retrait
   * - Grace period de 15 min (pas de frais)
   * - Calcul par jours complets + heures restantes
   * - Utilise tarif journalier + horaire du provider
   */
  async calculateLateFee(bookingId: string, pickupTime?: Date) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
      include: { provider: true },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');

    const now = pickupTime || new Date();
    const endDate = new Date(booking.endDate);

    // Si pas de retard, pas de frais
    if (now <= endDate) {
      return {
        lateFeeDa: 0,
        lateFeeHours: 0,
        lateDays: 0,
        lateRemainingHours: 0,
        daysFee: 0,
        hoursFee: 0,
        graceApplied: false,
        hourlyRate: 0,
        dailyRate: 0,
      };
    }

    // Calculer le retard en minutes
    const lateMs = now.getTime() - endDate.getTime();
    const lateMinutes = lateMs / (1000 * 60);

    // Grace period : si retard <= 15 min, pas de frais
    if (lateMinutes <= LATE_FEE_GRACE_MINUTES) {
      return {
        lateFeeDa: 0,
        lateFeeHours: lateMinutes / 60,
        lateDays: 0,
        lateRemainingHours: 0,
        daysFee: 0,
        hoursFee: 0,
        graceApplied: true,
        hourlyRate: 0,
        dailyRate: 0,
      };
    }

    // Récupérer les tarifs du provider (dans specialties)
    const specialties = booking.provider?.specialties as any;
    const hourlyRate = specialties?.hourlyRateDa || specialties?.pricePerHourDa || DEFAULT_HOURLY_RATE_DA;
    const dailyRate = specialties?.dailyRateDa || specialties?.pricePerDayDa || DEFAULT_DAILY_RATE_DA;

    // Calculer le retard facturable (après grace period)
    const billableMinutes = lateMinutes - LATE_FEE_GRACE_MINUTES;
    const billableHours = billableMinutes / 60;

    // Séparer en jours complets + heures restantes
    const lateDays = Math.floor(billableHours / 24);
    const lateRemainingHours = Math.ceil(billableHours % 24); // Arrondi à l'heure supérieure

    // Calculer les frais
    const daysFee = lateDays * dailyRate;
    const hoursFee = lateRemainingHours * hourlyRate;
    const lateFeeDa = daysFee + hoursFee;

    return {
      lateFeeDa,
      lateFeeHours: billableHours,
      lateDays,
      lateRemainingHours,
      daysFee,
      hoursFee,
      graceApplied: false,
      hourlyRate,
      dailyRate,
    };
  }

  /**
   * Client: Confirmer le retrait avec calcul automatique des frais de retard
   * Calcule la distance au provider si GPS disponible (pour audit admin)
   */
  async clientConfirmPickupWithLateFee(
    userId: string,
    bookingId: string,
    method: string = 'PROXIMITY',
    lat?: number,
    lng?: number,
  ) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
      include: { provider: true },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.userId !== userId) throw new ForbiddenException('Cette réservation ne vous appartient pas');
    if (booking.status !== 'IN_PROGRESS') {
      throw new BadRequestException('L\'animal doit d\'abord être déposé');
    }

    // Calculer la distance au provider si GPS client et provider disponibles
    let distanceMeters: number | null = null;
    if (lat && lng && booking.provider?.lat && booking.provider?.lng) {
      distanceMeters = this.calculateDistance(lat, lng, booking.provider.lat, booking.provider.lng);
    }

    // Calculer les frais de retard
    const lateFee = await this.calculateLateFee(bookingId);

    // Générer un code OTP pour le retrait
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

    const updated = await this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        status: 'PENDING_PICKUP_VALIDATION',
        clientPickupConfirmedAt: new Date(),
        pickupConfirmationMethod: method,
        pickupCheckinLat: lat,
        pickupCheckinLng: lng,
        pickupOtpCode: otpCode,
        pickupOtpExpiresAt: otpExpiresAt,
        // Frais de retard
        lateFeeDa: lateFee.lateFeeDa > 0 ? lateFee.lateFeeDa : null,
        lateFeeHours: lateFee.lateFeeHours > 0 ? lateFee.lateFeeHours : null,
        lateFeeStatus: lateFee.lateFeeDa > 0 ? 'PENDING' : null,
      },
      include: {
        pet: true,
        provider: true,
        user: { select: { id: true, firstName: true, lastName: true, phone: true } },
      },
    });

    // Retourner avec distance et détails des frais de retard
    return {
      ...updated,
      pickupDistanceMeters: distanceMeters,
      lateFeeDetails: lateFee,
    };
  }

  /**
   * Pro: Accepter ou refuser les frais de retard
   */
  async handleLateFee(userId: string, bookingId: string, accept: boolean, note?: string) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) throw new NotFoundException('Profil professionnel non trouvé');

    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');
    if (booking.providerId !== provider.id) {
      throw new ForbiddenException('Cette réservation ne vous appartient pas');
    }

    if (!booking.lateFeeDa || booking.lateFeeStatus !== 'PENDING') {
      throw new BadRequestException('Pas de frais de retard en attente');
    }

    const newStatus = accept ? 'ACCEPTED' : 'REJECTED';
    const finalLateFeeDa = accept ? booking.lateFeeDa : 0;

    return this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        lateFeeStatus: newStatus,
        lateFeeAcceptedAt: new Date(),
        lateFeeNote: note,
        lateFeeDa: finalLateFeeDa,
        // Mettre à jour le total si accepté
        totalDa: accept ? booking.totalDa + finalLateFeeDa : booking.totalDa,
      },
      include: {
        pet: true,
        user: { select: { id: true, firstName: true, lastName: true } },
      },
    });
  }

  /**
   * Pro: Obtenir les bookings avec frais de retard en attente
   */
  async getPendingLateFees(userId: string) {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });

    if (!provider) throw new NotFoundException('Profil professionnel non trouvé');

    return this.prisma.daycareBooking.findMany({
      where: {
        providerId: provider.id,
        lateFeeStatus: 'PENDING',
        lateFeeDa: { gt: 0 },
      },
      include: {
        pet: true,
        user: { select: { id: true, firstName: true, lastName: true, phone: true } },
      },
      orderBy: { clientPickupConfirmedAt: 'desc' },
    });
  }
}
