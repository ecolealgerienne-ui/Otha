// src/bookings/bookings.service.ts
import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { BookingStatus, Prisma, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability/availability.service';
import { NotificationsService } from '../notifications/notifications.service';

const COMMISSION_DA = Number(process.env.APP_COMMISSION_DA ?? 100);

@Injectable()
export class BookingsService {
  constructor(
    private prisma: PrismaService,
    private availability: AvailabilityService,
    private notificationsService: NotificationsService,
  ) {}

  /** --------- Client: mes réservations --------- */
  async listMine(userId: string) {
    const rows = await this.prisma.booking.findMany({
      where: { userId },
      orderBy: { scheduledAt: 'desc' },
      select: {
        id: true,
        status: true,
        scheduledAt: true,
        providerId: true, // ✅ important pour activer “Modifier”
        provider: {
          select: {
            id: true,
            displayName: true,
            address: true,
            lat: true,
            lng: true,
            specialties: true, // mapsUrl éventuel pour itinéraire
          },
        },
        service: {
          select: {
            id: true,
            title: true,
            price: true,
            durationMin: true,
            providerId: true,
          },
        },
      },
    });

    return rows.map((b) => ({
      id: b.id,
      status: b.status,
      scheduledAt: b.scheduledAt.toISOString(),
      providerId: b.providerId, // ✅ top-level direct
      provider: {
        id: b.provider?.id ?? b.providerId,
        displayName: b.provider?.displayName ?? '',
        address: b.provider?.address ?? null,
        lat: b.provider?.lat ?? null,
        lng: b.provider?.lng ?? null,
        specialties: b.provider?.specialties ?? null,
      },
      service: {
        id: b.service.id,
        title: b.service.title,
        durationMin: b.service.durationMin,
        price:
          b.service.price == null
            ? null
            : (b.service.price as Prisma.Decimal).toNumber(),
        providerId: b.service.providerId,
      },
    }));
  }

  /** --------- Client: changer mon statut (ex: annuler) --------- */
  async updateStatus(userId: string, id: string, status: BookingStatus) {
    const b = await this.prisma.booking.findUnique({
      where: { id },
      include: { service: true },
    });
    if (!b) throw new NotFoundException('Booking not found');
    if (b.userId !== userId) throw new ForbiddenException();

    // Interdire de modifier un RDV terminé
    if (b.status === 'COMPLETED') {
      throw new ForbiddenException('Completed booking cannot be modified');
    }

    const updated = await this.prisma.booking.update({
      where: { id },
      data: {
        status,
        // si tu as ces champs en DB, dé-commente:
        // cancelledAt: status === 'CANCELLED' ? new Date() : null,
        // cancelledBy: status === 'CANCELLED' ? 'USER' : null,
      },
    });

    // Si on annule => supprimer l’earning éventuel
    if (status === 'CANCELLED') {
      await this.prisma.providerEarning.deleteMany({ where: { bookingId: id } });
    }

    return updated;
  }

  /** --------- Client: reprogrammer mon rendez-vous --------- */
  async reschedule(userId: string, id: string, when: Date) {
    const b = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        service: {
          select: {
            id: true,
            durationMin: true,
            providerId: true,
            price: true,
            title: true,
          },
        },
      },
    });
    if (!b) throw new NotFoundException('Booking not found');
    if (b.userId !== userId) throw new ForbiddenException();

    if (b.status === 'COMPLETED') {
      throw new ForbiddenException('Completed booking cannot be rescheduled');
    }
    if (b.status === 'CANCELLED') {
      throw new ForbiddenException('Cancelled booking cannot be rescheduled');
    }

    // Vérifie côté serveur que le slot est libre pour ce provider & durée
    const duration = b.service.durationMin;
    const isFree = await this.availability.isSlotFree(
      b.service.providerId,
      when,
      duration,
    );
    if (!isFree) {
      throw new BadRequestException('Slot not available');
    }

    // Conserve le statut actuel (pas de “reset” en PENDING)
    const updated = await this.prisma.booking.update({
      where: { id },
      data: { scheduledAt: when },
      include: {
        service: {
          select: {
            id: true,
            title: true,
            price: true,
            durationMin: true,
            providerId: true,
          },
        },
      },
    });

    return {
      id: updated.id,
      status: updated.status,
      scheduledAt: updated.scheduledAt.toISOString(),
      service: {
        id: updated.service.id,
        title: updated.service.title,
        durationMin: updated.service.durationMin,
        providerId: updated.service.providerId,
        price:
          updated.service.price == null
            ? null
            : (updated.service.price as Prisma.Decimal).toNumber(),
      },
    };
  }

  /** --------- PRO: agenda enrichi (par défaut inclut les CANCELLED) --------- */
  async providerAgenda(
    userId: string,
    from?: Date,
    to?: Date,
    includeCancelled = true,
  ) {
    console.log('📅 providerAgenda appelé pour userId:', userId);

    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });
    if (!prov) {
      console.error('❌ No provider profile for userId:', userId);
      throw new ForbiddenException('No provider profile');
    }

    console.log('✅ Provider profile trouvé:', { id: prov.id, displayName: prov.displayName });

    const rows = await this.prisma.booking.findMany({
      where: {
        providerId: prov.id,
        ...(includeCancelled ? {} : { status: { not: 'CANCELLED' } }),
        ...(from || to
          ? { scheduledAt: { gte: from ?? undefined, lt: to ?? undefined } }
          : {}),
      },
      orderBy: { scheduledAt: 'asc' },
      select: {
        id: true,
        status: true,
        scheduledAt: true,
        service: { select: { id: true, title: true, price: true } },
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            phone: true, // ⚠️ pas d'email
            pets: {
              orderBy: { updatedAt: 'desc' },
              take: 1,
              select: { idNumber: true, breed: true, name: true },
            },
          },
        },
      },
    });

    console.log(`📊 Nombre de réservations trouvées: ${rows.length}`);
    if (rows.length > 0) {
      console.log('📋 Première réservation:', {
        id: rows[0].id,
        status: rows[0].status,
        serviceTitle: rows[0].service.title,
      });
    }

    return rows.map((b) => {
      const price =
        b.service.price == null
          ? null
          : (b.service.price as Prisma.Decimal).toNumber();
      const displayName =
        [b.user.firstName, b.user.lastName].filter(Boolean).join(' ').trim() ||
        'Client';
      const pet = b.user.pets?.[0];
      const petType = (pet?.idNumber || pet?.breed || '').trim();

      return {
        id: b.id,
        status: b.status,
        scheduledAt: b.scheduledAt.toISOString(),
        service: { id: b.service.id, title: b.service.title, price },
        user: { id: b.user.id, displayName, phone: b.user.phone ?? null },
        pet: { label: petType || null, name: pet?.name ?? null },
      };
    });
  }

  /** --------- PRO: changer le statut (écrit la commission à COMPLETED) --------- */
  async providerSetStatus(
    userId: string,
    bookingId: string,
    status: BookingStatus,
  ) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
      include: { user: { select: { firstName: true, lastName: true } } },
    });
    if (!prov) throw new ForbiddenException('No provider profile');

    const b = await this.prisma.booking.findFirst({
      where: { id: bookingId, providerId: prov.id },
      include: { service: true },
    });
    if (!b) throw new NotFoundException('Booking not found');

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: { status },
    });

    // Créer une notification pour le client
    const providerName = `${prov.user.firstName || ''} ${prov.user.lastName || ''}`.trim() || 'Le vétérinaire';
    const serviceName = b.service.title || 'Votre rendez-vous';

    if (status === 'CONFIRMED') {
      try {
        await this.notificationsService.createNotification(
          b.userId,
          NotificationType.BOOKING_CONFIRMED,
          'Rendez-vous confirmé',
          `${providerName} a confirmé votre rendez-vous pour ${serviceName}`,
          {
            bookingId: b.id,
            providerId: prov.id,
            serviceId: b.serviceId,
          },
        );
      } catch (e) {
        console.error('Failed to create notification:', e);
      }
    } else if (status === 'CANCELLED') {
      try {
        await this.notificationsService.createNotification(
          b.userId,
          NotificationType.BOOKING_CANCELLED,
          'Rendez-vous annulé',
          `${providerName} a annulé votre rendez-vous pour ${serviceName}`,
          {
            bookingId: b.id,
            providerId: prov.id,
            serviceId: b.serviceId,
          },
        );
      } catch (e) {
        console.error('Failed to create notification:', e);
      }
      // Pro annule => on supprime l'earning éventuel
      await this.prisma.providerEarning.deleteMany({
        where: { bookingId: b.id },
      });
    }

    if (status === 'COMPLETED') {
      const gross = Number((b.service.price as Prisma.Decimal).toNumber());
      const commission = COMMISSION_DA;
      const net = Math.max(gross - commission, 0);

      await this.prisma.providerEarning.upsert({
        where: { bookingId: b.id },
        update: {},
        create: {
          providerId: prov.id,
          bookingId: b.id,
          serviceId: b.serviceId,
          grossPriceDa: gross,
          commissionDa: commission,
          netToProviderDa: net,
        },
      });
    }

    return updated;
  }

  // ==================== ADMIN ====================

  // ==================== ADMIN: Stats & Historique ====================

  private monthBounds(month: string) {
    // month = 'YYYY-MM'
    const y = Number(month.slice(0, 4));
    const m = Number(month.slice(5, 7));
    const from = new Date(Date.UTC(y, m - 1, 1));
    const to = new Date(Date.UTC(y, m, 1));
    return { from, to };
  }

  async adminStatsPeriod(opts: {
    from?: Date;
    to?: Date;
    providerId?: string;
  }) {
    const { from, to, providerId } = opts;

    const where: Prisma.BookingWhereInput = {
      ...(providerId ? { providerId } : {}),
      ...(from || to
        ? { scheduledAt: { gte: from ?? undefined, lt: to ?? undefined } }
        : {}),
    };

    const [pending, confirmed, completed, cancelled] = await Promise.all([
      this.prisma.booking.count({
        where: { ...where, status: 'PENDING' },
      }),
      this.prisma.booking.count({
        where: { ...where, status: 'CONFIRMED' },
      }),
      this.prisma.booking.count({
        where: { ...where, status: 'COMPLETED' },
      }),
      this.prisma.booking.count({
        where: { ...where, status: 'CANCELLED' },
      }),
    ]);

    // collecté = somme commissions payées dans la période (via paidAt)
    const collected = await this.prisma.providerEarning.aggregate({
      _sum: { commissionDa: true },
      where: {
        ...(providerId ? { providerId } : {}),
        paidAt: from || to ? { gte: from ?? undefined, lt: to ?? undefined } : { not: null },
      },
    });

    return {
      pending,
      confirmed,
      completed,
      cancelled,
      dueDa: completed * COMMISSION_DA,
      collectedDa: Number(collected._sum.commissionDa ?? 0),
    };
  }

  /** Historique mensuel: dernier N mois, counts par statut + due + collected (cash & accrual) */
  async adminHistoryMonthly(opts: { months?: number; providerId?: string }) {
    const months = Math.max(1, Math.min(36, opts.months ?? 12));
    const now = new Date();
    const from = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - (months - 1), 1),
    );
    const to = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1),
    );

    // Group by mois (PostgreSQL) — par mois de RDV (scheduledAt)
    const providerClause = opts.providerId ? 'AND "providerId" = $3' : '';
    const params: any[] = [from, to];
    if (opts.providerId) params.push(opts.providerId);

    const rows: Array<{
      month: string;
      pending: number;
      confirmed: number;
      completed: number;
      cancelled: number;
    }> = await this.prisma.$queryRawUnsafe(
      `
      SELECT to_char(date_trunc('month', "scheduledAt"), 'YYYY-MM') AS month,
             SUM(CASE WHEN status='PENDING'   THEN 1 ELSE 0 END)::int    AS pending,
             SUM(CASE WHEN status='CONFIRMED' THEN 1 ELSE 0 END)::int    AS confirmed,
             SUM(CASE WHEN status='COMPLETED' THEN 1 ELSE 0 END)::int    AS completed,
             SUM(CASE WHEN status='CANCELLED' THEN 1 ELSE 0 END)::int    AS cancelled
      FROM "Booking"
      WHERE "scheduledAt" >= $1 AND "scheduledAt" < $2 ${providerClause}
      GROUP BY 1
      ORDER BY 1 DESC
      `,
      ...params,
    );

    // Collected par mois de paiement (cash) — groupé sur paidAt
    const rowsCollectedPaid: Array<{
      month: string;
      collected_paid_da: number;
    }> = await this.prisma.$queryRawUnsafe(
      `
        SELECT to_char(date_trunc('month', "paidAt"), 'YYYY-MM') AS month,
               COALESCE(SUM("commissionDa"), 0)::int AS collected_paid_da
        FROM "ProviderEarning"
        WHERE "paidAt" IS NOT NULL
          AND "paidAt" >= $1 AND "paidAt" < $2
          ${opts.providerId ? 'AND "providerId" = $3' : ''}
        GROUP BY 1
        `,
      ...params,
    );

    // Collected “au mois de réalisation” (accrual) — groupé sur createdAt, uniquement les lignes payées
    const rowsCollectedSched: Array<{
      month: string;
      collected_sched_da: number;
    }> = await this.prisma.$queryRawUnsafe(
      `
        SELECT to_char(date_trunc('month', "createdAt"), 'YYYY-MM') AS month,
               COALESCE(SUM("commissionDa"), 0)::int AS collected_sched_da
        FROM "ProviderEarning"
        WHERE "createdAt" >= $1 AND "createdAt" < $2
          ${opts.providerId ? 'AND "providerId" = $3' : ''}
          AND "paidAt" IS NOT NULL
        GROUP BY 1
        `,
      ...params,
    );

    const mapPaid = new Map(
      rowsCollectedPaid.map((r) => [r.month, Number(r.collected_paid_da || 0)]),
    );
    const mapSched = new Map(
      rowsCollectedSched.map((r) => [
        r.month,
        Number(r.collected_sched_da || 0),
      ]),
    );

    // Assure qu’on couvre chaque mois même s’il n’y a pas de lignes
    const out: Array<any> = [];
    for (let i = 0; i < months; i++) {
      const dt = new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1),
      );
      const key = `${dt.getUTCFullYear()}-${String(
        dt.getUTCMonth() + 1,
      ).padStart(2, '0')}`;
      const r = rows.find((x) => x.month === key);
      const pending = r?.pending ?? 0;
      const confirmed = r?.confirmed ?? 0;
      const completed = r?.completed ?? 0;
      const cancelled = r?.cancelled ?? 0;

      const dueDa = completed * COMMISSION_DA;
      const collectedDa = mapPaid.get(key) ?? 0; // cash (par paidAt)
      const collectedDaScheduled = mapSched.get(key) ?? 0; // accrual (payé mais rattaché au mois d’origine)

      out.push({
        month: key,
        pending,
        confirmed,
        completed,
        cancelled,
        dueDa,
        collectedDa,
        collectedDaScheduled,
      });
    }
    return out; // déjà trié du plus récent au plus ancien
  }

  /** --------- PRO: historique mensuel normalisé (mêmes règles que l’admin) --------- */
  async providerHistoryMonthly(userId: string, months = 12) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });
    if (!prov) throw new ForbiddenException('No provider profile');
    return this.adminHistoryMonthly({ months, providerId: prov.id });
  }

  /** Marquer collecté: applique paidAt sur earnings d’un mois
   *  IMPORTANT: on cible le mois de RDV (Booking.scheduledAt ∈ [month]),
   *  et on fixe paidAt DANS le mois concerné pour que `collectedDa` tombe bien sur ce mois.
   */
  async adminCollectMonth(month: string, providerId?: string) {
    const { from, to } = this.monthBounds(month);

    // paidAt dans le mois ciblé (ex: jour 15 à midi UTC)
    const paidAtInsideMonth = new Date(
      Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), 15, 12, 0, 0),
    );

    const res = await this.prisma.providerEarning.updateMany({
      where: {
        ...(providerId ? { providerId } : {}),
        booking: { scheduledAt: { gte: from, lt: to }, status: 'COMPLETED' },
      },
      data: { paidAt: paidAtInsideMonth },
    });
    return { updated: res.count };
  }

  /** Annuler collecte: remet paidAt à NULL pour les earnings du mois de RDV */
  async adminUncollectMonth(month: string, providerId?: string) {
    const { from, to } = this.monthBounds(month);
    const res = await this.prisma.providerEarning.updateMany({
      where: {
        ...(providerId ? { providerId } : {}),
        booking: { scheduledAt: { gte: from, lt: to } },
        paidAt: { not: null },
      },
      data: { paidAt: null },
    });
    return { updated: res.count };
  }

  async adminList(opts: {
    providerId?: string;
    status?: BookingStatus | 'ALL';
    from?: Date;
    to?: Date;
    limit?: number;
    offset?: number;
  }) {
    const {
      providerId,
      status = 'ALL',
      from,
      to,
      limit = 50,
      offset = 0,
    } = opts;

    const where: Prisma.BookingWhereInput = {
      ...(providerId ? { providerId } : {}),
      ...(status !== 'ALL' ? { status: status as BookingStatus } : {}),
      ...(from || to
        ? { scheduledAt: { gte: from ?? undefined, lt: to ?? undefined } }
        : {}),
    };

    const rows = await this.prisma.booking.findMany({
      where,
      orderBy: { scheduledAt: 'desc' },
      skip: offset,
      take: limit,
      select: {
        id: true,
        status: true,
        scheduledAt: true,
        providerId: true,
        userId: true,
        service: {
          select: { id: true, title: true, durationMin: true, price: true },
        },
      },
    });

    return rows.map((b) => ({
      id: b.id,
      status: b.status,
      scheduledAt: b.scheduledAt.toISOString(),
      providerId: b.providerId,
      userId: b.userId,
      service: {
        id: b.service.id,
        title: b.service.title,
        durationMin: b.service.durationMin,
        price:
          b.service.price == null
            ? null
            : (b.service.price as Prisma.Decimal).toNumber(),
      },
    }));
  }

  async adminCountForProvider(providerId: string, from: Date, to: Date) {
    const count = await this.prisma.booking.count({
      where: {
        providerId,
        status: 'COMPLETED',
        scheduledAt: { gte: from, lt: to },
      },
    });
    return { count };
  }

  async adminCommissionsSummaryCurrentMonth() {
    const now = new Date();
    const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const to = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1),
    );

    const completed = await this.prisma.booking.count({
      where: { status: 'COMPLETED', scheduledAt: { gte: from, lt: to } },
    });

    const totalDueMonthDa = completed * COMMISSION_DA;

    const collectedAgg = await this.prisma.providerEarning.aggregate({
      _sum: { commissionDa: true },
      where: { paidAt: { gte: from, lt: to } },
    });
    const totalCollectedMonthDa = Number(
      collectedAgg._sum.commissionDa ?? 0,
    );

    return { totalDueMonthDa, totalCollectedMonthDa };
  }

  /** --------- PRO: mes gains (mois courant ou ?month=YYYY-MM) --------- */
  async myEarnings(userId: string, month?: string) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });
    if (!prov) throw new ForbiddenException('No provider profile');

    let where: Prisma.ProviderEarningWhereInput = { providerId: prov.id };

    if (month) {
      const y = Number(month.slice(0, 4));
      const m = Number(month.slice(5, 7));
      const from = new Date(Date.UTC(y, m - 1, 1));
      const to = new Date(Date.UTC(y, m, 1));
      where = { providerId: prov.id, createdAt: { gte: from, lt: to } };
    }

    const items = await this.prisma.providerEarning.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        bookingId: true,
        serviceId: true,
        createdAt: true,
        grossPriceDa: true,
        commissionDa: true,
        netToProviderDa: true,
        paidAt: true,
      },
    });

    type Totals = { grossDa: number; commissionDa: number; netDa: number };
    const totals = items.reduce<Totals>(
      (a, x) => ({
        grossDa: a.grossDa + x.grossPriceDa,
        commissionDa: a.commissionDa + x.commissionDa,
        netDa: a.netDa + x.netToProviderDa,
      }),
      { grossDa: 0, commissionDa: 0, netDa: 0 },
    );

    return { month: month ?? null, totals, items };
  }
}
