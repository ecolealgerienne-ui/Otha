import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDaycareBookingDto } from './dto/create-booking.dto';
import { DaycareBookingStatus } from './dto/update-status.dto';

@Injectable()
export class DaycareService {
  constructor(private prisma: PrismaService) {}

  /**
   * Créer une réservation garderie (client)
   */
  async createBooking(userId: string, dto: CreateDaycareBookingDto) {
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

    return this.prisma.daycareBooking.findMany({
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
          },
        },
      },
      orderBy: { startDate: 'desc' },
    });
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

    // Générer un code OTP pour le dépôt
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000); // Expire dans 10 minutes

    return this.prisma.daycareBooking.update({
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
  }

  /**
   * Client: Confirmer le retrait de l'animal (avec géoloc)
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

    // Générer un code OTP pour le retrait
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

    return this.prisma.daycareBooking.update({
      where: { id: bookingId },
      data: {
        status: 'PENDING_PICKUP_VALIDATION',
        clientPickupConfirmedAt: new Date(),
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
      // ❌ REFUSER = CLIENT MENT
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
      return this.prisma.daycareBooking.update({
        where: { id: bookingId },
        data: {
          status: 'COMPLETED',
          actualPickup: new Date(),
          pickupConfirmationMethod: method,
        },
        include: { pet: true, user: { select: { id: true, firstName: true, lastName: true } } },
      });
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
   * Pro: Valider par code OTP
   */
  async validateByOtp(userId: string, bookingId: string, otpCode: string, phase: 'drop' | 'pickup') {
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

    if (phase === 'drop') {
      if (booking.status !== 'PENDING_DROP_VALIDATION') {
        throw new BadRequestException('Le client doit d\'abord confirmer son arrivée');
      }
      if (booking.dropOtpCode !== otpCode) {
        throw new BadRequestException('Code OTP incorrect');
      }
      if (!booking.dropOtpExpiresAt || new Date() > new Date(booking.dropOtpExpiresAt)) {
        throw new BadRequestException('Le code OTP a expiré');
      }
      return this.proValidateDropOff(userId, bookingId, true, 'OTP');
    } else {
      if (booking.status !== 'PENDING_PICKUP_VALIDATION') {
        throw new BadRequestException('Le client doit d\'abord confirmer le retrait');
      }
      if (booking.pickupOtpCode !== otpCode) {
        throw new BadRequestException('Code OTP incorrect');
      }
      if (!booking.pickupOtpExpiresAt || new Date() > new Date(booking.pickupOtpExpiresAt)) {
        throw new BadRequestException('Le code OTP a expiré');
      }
      return this.proValidatePickup(userId, bookingId, true, 'OTP');
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

    // Chercher les bookings où le client est à proximité (dernières 30 minutes)
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);

    return this.prisma.daycareBooking.findMany({
      where: {
        providerId: provider.id,
        clientNearbyAt: { gte: thirtyMinutesAgo },
        status: { in: ['CONFIRMED', 'IN_PROGRESS'] },
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
   * Appelé automatiquement lors du pickup
   */
  async calculateLateFee(bookingId: string) {
    const booking = await this.prisma.daycareBooking.findUnique({
      where: { id: bookingId },
      include: { provider: true },
    });

    if (!booking) throw new NotFoundException('Réservation non trouvée');

    const now = new Date();
    const endDate = new Date(booking.endDate);

    // Si pas de retard, pas de frais
    if (now <= endDate) {
      return { lateFeeDa: 0, lateFeeHours: 0 };
    }

    // Calculer le retard en heures
    const lateMs = now.getTime() - endDate.getTime();
    const lateHours = lateMs / (1000 * 60 * 60);

    // Récupérer le tarif horaire du provider (dans specialties.hourlyRateDa)
    const specialties = booking.provider?.specialties as any;
    const hourlyRate = specialties?.hourlyRateDa || specialties?.pricePerHourDa || 200; // 200 DA par défaut

    // Calculer les frais (arrondi à l'heure supérieure)
    const roundedHours = Math.ceil(lateHours);
    const lateFeeDa = roundedHours * hourlyRate;

    return {
      lateFeeDa,
      lateFeeHours: lateHours,
      roundedHours,
      hourlyRate,
    };
  }

  /**
   * Client: Confirmer le retrait avec calcul automatique des frais de retard
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

    // Calculer les frais de retard
    const lateFee = await this.calculateLateFee(bookingId);

    // Générer un code OTP pour le retrait
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

    return this.prisma.daycareBooking.update({
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
