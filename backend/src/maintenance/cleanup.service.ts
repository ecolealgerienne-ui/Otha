import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CleanupService {
  private readonly logger = new Logger(CleanupService.name);

  constructor(private prisma: PrismaService) {}

  // toutes les heures
  @Cron('0 * * * *')
  async cleanupTokens() {
    await this.prisma.refreshToken.deleteMany({ where: { expiresAt: { lt: new Date() } } });
  }

  // Tous les jours à 3h du matin - nettoyer les RDV "fantômes" passés
  // Ces RDV sont restés en PENDING/CONFIRMED mais leur date est passée (ex: test, abandon...)
  @Cron('0 3 * * *')
  async cleanupPhantomBookings() {
    const now = new Date();
    // Grâce de 24h après la date prévue avant d'expirer
    const graceDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // 1. Expirer les RDV véto passés (> 24h après la date)
    const expiredVetBookings = await this.prisma.booking.updateMany({
      where: {
        status: { in: ['PENDING', 'CONFIRMED', 'AWAITING_CONFIRMATION', 'PENDING_PRO_VALIDATION'] },
        scheduledAt: { lt: graceDate },
      },
      data: {
        status: 'EXPIRED',
      },
    });

    if (expiredVetBookings.count > 0) {
      this.logger.log(`Nettoyage: ${expiredVetBookings.count} RDV véto fantômes marqués EXPIRED`);
    }

    // 2. Annuler les réservations garderie passées (> 24h après endDate)
    // Note: DaycareBookingStatus n'a pas de statut EXPIRED, donc on utilise CANCELLED
    const expiredDaycareBookings = await this.prisma.daycareBooking.updateMany({
      where: {
        status: { in: ['PENDING', 'CONFIRMED'] },
        endDate: { lt: graceDate },
      },
      data: {
        status: 'CANCELLED',
      },
    });

    if (expiredDaycareBookings.count > 0) {
      this.logger.log(`Nettoyage: ${expiredDaycareBookings.count} réservations garderie fantômes marquées CANCELLED`);
    }
  }
}
