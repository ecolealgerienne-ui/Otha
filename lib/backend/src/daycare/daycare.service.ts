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

    return this.prisma.daycareBooking.update({
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
}
