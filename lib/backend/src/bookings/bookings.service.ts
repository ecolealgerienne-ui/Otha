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
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const rows = await this.prisma.booking.findMany({
      where: {
        userId,
        // ✅ Ne cacher que les RDV terminés/annulés/expirés de plus de 7 jours
        // OU garder visibles tous les RDV en attente de confirmation
        OR: [
          { status: { in: ['PENDING', 'CONFIRMED', 'AWAITING_CONFIRMATION', 'PENDING_PRO_VALIDATION'] } },
          {
            status: { in: ['COMPLETED', 'CANCELLED', 'EXPIRED', 'DISPUTED'] },
            scheduledAt: { gte: sevenDaysAgo }
          }
        ]
      },
      orderBy: { scheduledAt: 'desc' },
      select: {
        id: true,
        status: true,
        scheduledAt: true,
        providerId: true, // ✅ important pour activer "Modifier"
        petIds: true, // ✅ IDs des animaux associés au RDV
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

    // ✅ Récupérer les infos des animaux pour chaque booking
    const allPetIds = [...new Set(rows.flatMap(b => b.petIds || []))];
    const pets = allPetIds.length > 0
      ? await this.prisma.pet.findMany({
          where: { id: { in: allPetIds } },
          select: { id: true, name: true, species: true, breed: true },
        })
      : [];
    const petsMap = new Map(pets.map(p => [p.id, p]));

    return rows.map((b) => {
      // Récupérer les infos des animaux de ce booking
      const bookingPets = (b.petIds || [])
        .map(id => petsMap.get(id))
        .filter(Boolean);

      return {
        id: b.id,
        status: b.status,
        scheduledAt: b.scheduledAt.toISOString(),
        providerId: b.providerId, // ✅ top-level direct
        petIds: b.petIds || [], // ✅ Liste des IDs d'animaux
        pet: bookingPets[0] || null, // ✅ Premier animal (rétro-compatibilité)
        pets: bookingPets, // ✅ Tous les animaux
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
      };
    });
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
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });
    if (!prov) throw new ForbiddenException('No provider profile');

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
            phone: true, // ⚠️ pas d’email
            pets: {
              orderBy: { updatedAt: 'desc' },
              take: 1,
              select: { idNumber: true, breed: true, name: true },
            },
          },
        },
      },
    });

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

  // ==================== NOUVEAU: Système de Confirmation ====================

  /**
   * Cron job: Passer les RDV en AWAITING_CONFIRMATION 4h après la FIN du RDV
   * À appeler toutes les heures
   */
  async checkGracePeriods() {
    const now = new Date();

    // 1️⃣ Trouver les RDV passés (sans confirmation) avec leur durée
    const bookings = await this.prisma.booking.findMany({
      where: {
        scheduledAt: { lte: now }, // RDV déjà commencé
        status: { in: ['PENDING', 'CONFIRMED'] },
        gracePeriodEndsAt: null,
      },
      include: {
        service: {
          select: { durationMin: true },
        },
      },
    });

    // 2️⃣ Filtrer ceux qui sont passés depuis 4h après la FIN du RDV
    const toUpdate = [];
    for (const b of bookings) {
      const durationMin = b.service?.durationMin ?? 30;
      const endTime = new Date(b.scheduledAt.getTime() + durationMin * 60 * 1000);
      const fourHoursAfterEnd = new Date(endTime.getTime() + 4 * 60 * 60 * 1000);

      // Si 4h se sont écoulées après la fin du RDV
      if (now >= fourHoursAfterEnd) {
        toUpdate.push(b.id);
      }
    }

    // 3️⃣ Passer en AWAITING_CONFIRMATION avec grace period de 7 jours
    for (const id of toUpdate) {
      await this.prisma.booking.update({
        where: { id },
        data: {
          status: 'AWAITING_CONFIRMATION',
          gracePeriodEndsAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
        },
      });
    }

    // 4️⃣ Expirer les RDV sans réponse après grace period
    const expired = await this.prisma.booking.findMany({
      where: {
        status: { in: ['AWAITING_CONFIRMATION', 'PENDING_PRO_VALIDATION'] },
        gracePeriodEndsAt: { lte: now },
      },
    });

    for (const b of expired) {
      await this.prisma.booking.update({
        where: { id: b.id },
        data: { status: 'EXPIRED' },
      });
    }

    return {
      awaitingConfirmation: toUpdate.length,
      expired: expired.length,
    };
  }

  /**
   * Chercher un booking actif pour un pet (pour le scan QR vet)
   */
  async findActiveBookingForPet(petId: string) {
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

    // ✅ FIX CRITIQUE : Vérifier que le petId scanné est bien dans le booking
    const booking = await this.prisma.booking.findFirst({
      where: {
        userId: pet.ownerId,
        petIds: { has: petId },  // ✅ Le pet scanné DOIT être dans le booking
        scheduledAt: { gte: startOfDay, lte: endOfDay },  // ✅ RDV aujourd'hui
        status: { notIn: ['COMPLETED', 'CANCELLED', 'EXPIRED'] },
      },
      orderBy: { scheduledAt: 'asc' },
      include: {
        service: true,
        provider: {
          select: {
            id: true,
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

  /**
   * PRO confirme le booking (après scan QR ou manuellement)
   */
  async proConfirmBooking(userId: string, bookingId: string) {
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

    // ✅ Marquer comme confirmé par le pro
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        proConfirmedAt: new Date(),
        status: 'COMPLETED',
      },
    });

    // ✅ Créer la commission
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

    // 🏥 NOUVEAU: Créer automatiquement un acte médical pour chaque animal
    const providerName = `${prov.user.firstName || ''} ${prov.user.lastName || ''}`.trim() || prov.displayName || 'Vétérinaire';
    const petIds = Array.isArray(b.petIds) ? b.petIds : [];

    for (const petId of petIds) {
      await this.prisma.medicalRecord.create({
        data: {
          petId: petId,
          type: 'VET_VISIT',
          title: `Visite vétérinaire - ${b.service.title}`,
          description: `Rendez-vous confirmé chez ${providerName}`,
          date: b.scheduledAt,
          vetId: prov.id,
          vetName: providerName,
          providerType: 'VET',
          bookingId: b.id,
          durationMinutes: b.service.durationMin || 30,
          notes: `Service: ${b.service.title}\nDurée: ${b.service.durationMin || 30} minutes`,
        },
      });
    }

    return { success: true };
  }

  /**
   * CLIENT demande confirmation (via popup avis)
   * ⚠️ NE CRÉE PAS la commission directement
   */
  async clientRequestConfirmation(
    userId: string,
    bookingId: string,
    rating: number,
    comment?: string,
  ) {
    const b = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
      include: { provider: true },
    });
    if (!b) throw new NotFoundException('Booking not found');

    // 1️⃣ Créer la review (en attente validation pro)
    await this.prisma.review.upsert({
      where: { bookingId },
      update: {
        rating,
        comment,
        isPending: true,
      },
      create: {
        bookingId,
        userId,
        rating,
        comment,
        isPending: true,
      },
    });

    // 2️⃣ Marquer la confirmation client
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        clientConfirmedAt: new Date(),
        status: 'PENDING_PRO_VALIDATION',
        proResponseDeadline: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    // 3️⃣ Créer notification pour le pro
    try {
      await this.notificationsService.createNotification(
        b.provider.userId,
        NotificationType.BOOKING_NEEDS_VALIDATION,
        '⚠️ Validation requise',
        'Un client a confirmé son rendez-vous. Validez-vous ?',
        { bookingId: b.id },
      );
    } catch (e) {
      console.error('Failed to create notification:', e);
    }

    return { success: true };
  }

  /**
   * CLIENT dit "je n'y suis pas allé"
   */
  async clientCancelBooking(userId: string, bookingId: string) {
    const b = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
    });
    if (!b) throw new NotFoundException('Booking not found');

    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: 'CANCELLED',
        cancellationReason: 'Client did not attend',
      },
    });

    // Supprimer l'earning éventuel
    await this.prisma.providerEarning.deleteMany({
      where: { bookingId },
    });

    return { success: true };
  }

  /**
   * PRO valide ou refuse la confirmation client
   */
  async proValidateClientConfirmation(
    userId: string,
    bookingId: string,
    approved: boolean,
  ) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });
    if (!prov) throw new ForbiddenException('No provider profile');

    const b = await this.prisma.booking.findFirst({
      where: { id: bookingId, providerId: prov.id },
      include: { service: true },
    });
    if (!b) throw new NotFoundException('Booking not found');

    if (approved) {
      // ✅ PRO APPROUVE
      await this.prisma.booking.update({
        where: { id: bookingId },
        data: {
          proConfirmedAt: new Date(),
          status: 'COMPLETED',
        },
      });

      // ✅ Créer la commission
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

      // ✅ Publier la review
      await this.prisma.review.updateMany({
        where: { bookingId: b.id },
        data: { isPending: false },
      });
    } else {
      // ❌ PRO REFUSE = CLIENT MENT
      await this.prisma.booking.update({
        where: { id: bookingId },
        data: {
          status: 'DISPUTED',
          disputeNote: 'Pro claims client did not attend',
        },
      });

      // ❌ Créer signalement admin
      await this.prisma.adminFlag.create({
        data: {
          userId: b.userId,
          type: 'BOOKING_DISPUTE',
          bookingId: b.id,
          note: 'Pro claims client did not attend (DISPUTED)',
        },
      });
    }

    return { success: true };
  }

  /**
   * Liste des bookings en attente de validation pro
   */
  async getPendingValidations(userId: string) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
    });
    if (!prov) throw new ForbiddenException('No provider profile');

    const bookings = await this.prisma.booking.findMany({
      where: {
        providerId: prov.id,
        status: 'PENDING_PRO_VALIDATION',
      },
      orderBy: { proResponseDeadline: 'asc' },
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            phone: true,
          },
        },
        service: {
          select: {
            id: true,
            title: true,
            price: true,
          },
        },
      },
    });

    return bookings.map((b) => ({
      id: b.id,
      scheduledAt: b.scheduledAt.toISOString(),
      proResponseDeadline: b.proResponseDeadline?.toISOString(),
      user: {
        id: b.user.id,
        displayName:
          [b.user.firstName, b.user.lastName].filter(Boolean).join(' ').trim() ||
          'Client',
        phone: b.user.phone,
      },
      service: {
        id: b.service.id,
        title: b.service.title,
        price:
          b.service.price == null
            ? null
            : (b.service.price as Prisma.Decimal).toNumber(),
      },
    }));
  }

  // ==================== SYSTÈME OTP DE CONFIRMATION ====================

  /**
   * Génère un code OTP 6 chiffres pour un booking
   * Le client peut demander ce code pour le montrer au pro
   */
  async generateBookingOtp(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
      include: { provider: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    // Vérifier que le RDV n'est pas déjà terminé/annulé
    if (['COMPLETED', 'CANCELLED', 'EXPIRED'].includes(booking.status)) {
      throw new BadRequestException('Ce rendez-vous ne peut plus être confirmé');
    }

    // Générer un code 6 chiffres
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        confirmationOtp: otp,
        confirmationOtpExpiresAt: expiresAt,
        confirmationOtpAttempts: 0,
      },
    });

    return {
      otp,
      expiresAt: expiresAt.toISOString(),
      expiresInSeconds: 600,
    };
  }

  /**
   * Récupère l'OTP actif pour un booking (côté client)
   * Si l'OTP est expiré, en génère un nouveau
   */
  async getBookingOtp(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    // Vérifier si un OTP valide existe
    if (
      booking.confirmationOtp &&
      booking.confirmationOtpExpiresAt &&
      booking.confirmationOtpExpiresAt > new Date()
    ) {
      const remainingMs = booking.confirmationOtpExpiresAt.getTime() - Date.now();
      return {
        otp: booking.confirmationOtp,
        expiresAt: booking.confirmationOtpExpiresAt.toISOString(),
        expiresInSeconds: Math.floor(remainingMs / 1000),
      };
    }

    // Sinon, générer un nouveau
    return this.generateBookingOtp(userId, bookingId);
  }

  /**
   * Le PRO vérifie l'OTP donné par le client
   * Si valide → confirme le booking et crée la commission
   */
  async verifyBookingOtpByPro(proUserId: string, bookingId: string, otp: string) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId: proUserId },
    });
    if (!prov) throw new ForbiddenException('No provider profile');

    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, providerId: prov.id },
      include: { service: true, user: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    // Vérifier le statut
    if (['COMPLETED', 'CANCELLED', 'EXPIRED'].includes(booking.status)) {
      throw new BadRequestException('Ce rendez-vous ne peut plus être confirmé');
    }

    // Vérifier le nombre de tentatives
    if (booking.confirmationOtpAttempts >= 5) {
      throw new BadRequestException('Trop de tentatives. Demandez au client de régénérer le code.');
    }

    // Vérifier l'expiration
    if (!booking.confirmationOtp || !booking.confirmationOtpExpiresAt) {
      throw new BadRequestException('Aucun code OTP actif. Le client doit en générer un.');
    }
    if (booking.confirmationOtpExpiresAt < new Date()) {
      throw new BadRequestException('Code OTP expiré. Le client doit en régénérer un.');
    }

    // Vérifier le code
    if (booking.confirmationOtp !== otp) {
      await this.prisma.booking.update({
        where: { id: bookingId },
        data: { confirmationOtpAttempts: { increment: 1 } },
      });
      throw new BadRequestException('Code OTP invalide');
    }

    // ✅ OTP valide → Confirmer le booking
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: 'COMPLETED',
        proConfirmedAt: new Date(),
        clientConfirmedAt: new Date(), // Les deux confirment via OTP
        confirmationMethod: 'OTP',
        confirmationOtp: null, // Nettoyer l'OTP
        confirmationOtpExpiresAt: null,
      },
    });

    // Créer la commission
    const gross = Number((booking.service.price as any)?.toNumber?.() ?? 0);
    const commission = COMMISSION_DA;
    const net = Math.max(gross - commission, 0);

    await this.prisma.providerEarning.upsert({
      where: { bookingId: booking.id },
      update: {},
      create: {
        providerId: prov.id,
        bookingId: booking.id,
        serviceId: booking.serviceId,
        grossPriceDa: gross,
        commissionDa: commission,
        netToProviderDa: net,
      },
    });

    // Créer l'acte médical pour chaque animal
    const petIds = Array.isArray(booking.petIds) ? booking.petIds : [];
    for (const petId of petIds) {
      await this.prisma.medicalRecord.create({
        data: {
          petId,
          type: 'VET_VISIT',
          title: `Visite vétérinaire - ${booking.service.title}`,
          description: `Rendez-vous confirmé par OTP`,
          date: booking.scheduledAt,
          vetId: prov.id,
          vetName: prov.displayName,
          providerType: 'VET',
          bookingId: booking.id,
          durationMinutes: booking.service.durationMin || 30,
        },
      });
    }

    return { success: true, message: 'Rendez-vous confirmé avec succès' };
  }

  // ==================== CHECK-IN GÉOLOCALISÉ ====================

  /**
   * Le client fait check-in quand il arrive au cabinet
   * Vérifie qu'il est bien à proximité (< 500m)
   */
  async clientCheckin(
    userId: string,
    bookingId: string,
    clientLat: number,
    clientLng: number,
  ) {
    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
      include: { provider: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    // Vérifier que le RDV n'est pas déjà terminé
    if (['COMPLETED', 'CANCELLED', 'EXPIRED'].includes(booking.status)) {
      throw new BadRequestException('Ce rendez-vous ne peut plus faire l\'objet d\'un check-in');
    }

    // Vérifier la proximité avec le cabinet
    const providerLat = booking.provider?.lat;
    const providerLng = booking.provider?.lng;

    if (providerLat == null || providerLng == null) {
      // Si le provider n'a pas de coordonnées, on accepte quand même
      // mais on ne peut pas vérifier la distance
    } else {
      const distance = this.haversineDistance(
        clientLat,
        clientLng,
        providerLat,
        providerLng,
      );

      if (distance > 0.5) {
        // > 500m
        throw new BadRequestException(
          `Vous êtes trop loin du cabinet (${distance.toFixed(2)} km). Rapprochez-vous pour faire le check-in.`,
        );
      }
    }

    // Enregistrer le check-in
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        checkinAt: new Date(),
        checkinLat: clientLat,
        checkinLng: clientLng,
      },
    });

    return {
      success: true,
      message: 'Check-in enregistré',
      checkinAt: new Date().toISOString(),
    };
  }

  /**
   * Calcul de distance Haversine (en km)
   */
  private haversineDistance(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const R = 6371; // Rayon de la Terre en km
    const toRad = (deg: number) => (deg * Math.PI) / 180;

    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Vérifier si le client est proche du cabinet (pour afficher la page de confirmation)
   */
  async checkProximity(userId: string, bookingId: string, clientLat: number, clientLng: number) {
    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
      include: { provider: true, service: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const providerLat = booking.provider?.lat;
    const providerLng = booking.provider?.lng;

    let isNearby = false;
    let distanceKm: number | null = null;

    if (providerLat != null && providerLng != null) {
      distanceKm = this.haversineDistance(clientLat, clientLng, providerLat, providerLng);
      isNearby = distanceKm <= 0.5; // <= 500m
    }

    return {
      bookingId: booking.id,
      isNearby,
      distanceKm,
      hasCheckedIn: !!booking.checkinAt,
      status: booking.status,
      provider: {
        id: booking.provider?.id,
        displayName: booking.provider?.displayName,
        address: booking.provider?.address,
      },
      service: {
        title: booking.service?.title,
      },
      scheduledAt: booking.scheduledAt.toISOString(),
    };
  }

  /**
   * Confirmation simplifiée par le client (avec méthode spécifiée)
   * Utilisé pour le bouton "Confirmer ma visite" simple
   */
  async clientConfirmWithMethod(
    userId: string,
    bookingId: string,
    method: 'SIMPLE' | 'OTP' | 'QR_SCAN',
    rating?: number,
    comment?: string,
  ) {
    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
      include: { provider: true, service: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    // Vérifier que le RDV n'est pas déjà terminé
    if (['COMPLETED', 'CANCELLED', 'EXPIRED'].includes(booking.status)) {
      throw new BadRequestException('Ce rendez-vous est déjà terminé');
    }

    // Créer la review si rating fourni
    if (rating) {
      await this.prisma.review.upsert({
        where: { bookingId },
        update: { rating, comment, isPending: true },
        create: { bookingId, userId, rating, comment, isPending: true },
      });
    }

    // Mettre à jour le booking
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        clientConfirmedAt: new Date(),
        confirmationMethod: method,
        status: 'PENDING_PRO_VALIDATION',
        proResponseDeadline: new Date(Date.now() + 48 * 60 * 60 * 1000), // 48h pour répondre
      },
    });

    // Notifier le pro
    try {
      await this.notificationsService.createNotification(
        booking.provider.userId,
        'BOOKING_NEEDS_VALIDATION' as any,
        '⚠️ Confirmation client reçue',
        `Un client a confirmé son rendez-vous (${method}). Validez-vous ?`,
        { bookingId: booking.id, method },
      );
    } catch (e) {
      console.error('Failed to create notification:', e);
    }

    return {
      success: true,
      message: 'Votre confirmation a été envoyée au professionnel',
      status: 'PENDING_PRO_VALIDATION',
    };
  }

  // ============ ADMIN: Traçabilité par provider ============

  /**
   * Statistiques de traçabilité pour détecter les fraudes potentielles
   * Calcule les taux d'annulation, confirmation, no-show par provider
   */
  async adminTraceabilityStats(opts: { from?: Date; to?: Date } = {}) {
    const { from, to } = opts;

    // Récupérer tous les providers approuvés
    const providers = await this.prisma.providerProfile.findMany({
      where: { isApproved: true },
      select: {
        id: true,
        displayName: true,
        userId: true,
        user: { select: { email: true } },
      },
    });

    // Pour chaque provider, calculer les stats de booking
    const stats = await Promise.all(
      providers.map(async (provider) => {
        const where: Prisma.BookingWhereInput = {
          providerId: provider.id,
          ...(from || to
            ? { scheduledAt: { gte: from ?? undefined, lt: to ?? undefined } }
            : {}),
        };

        // Compter les bookings par statut
        const [
          totalBookings,
          pending,
          confirmed,
          completed,
          cancelledByPro,
          cancelledByUser,
          cancelled,
          expired,
          disputed,
          pendingProValidation,
          awaitingConfirmation,
        ] = await Promise.all([
          this.prisma.booking.count({ where }),
          this.prisma.booking.count({ where: { ...where, status: 'PENDING' } }),
          this.prisma.booking.count({ where: { ...where, status: 'CONFIRMED' } }),
          this.prisma.booking.count({ where: { ...where, status: 'COMPLETED' } }),
          // Annulés par le pro (après confirmation client)
          this.prisma.booking.count({
            where: {
              ...where,
              status: 'CANCELLED',
              clientConfirmedAt: { not: null },
              proConfirmedAt: null,
            },
          }),
          // Annulés par l'utilisateur
          this.prisma.booking.count({
            where: {
              ...where,
              status: 'CANCELLED',
              clientConfirmedAt: null,
            },
          }),
          this.prisma.booking.count({ where: { ...where, status: 'CANCELLED' } }),
          this.prisma.booking.count({ where: { ...where, status: 'EXPIRED' } }),
          this.prisma.booking.count({ where: { ...where, status: 'DISPUTED' } }),
          this.prisma.booking.count({ where: { ...where, status: 'PENDING_PRO_VALIDATION' } }),
          this.prisma.booking.count({ where: { ...where, status: 'AWAITING_CONFIRMATION' } }),
        ]);

        // Calculer les bookings avec OTP vérifié vs non vérifié
        const otpVerified = await this.prisma.booking.count({
          where: {
            ...where,
            status: 'COMPLETED',
            confirmationMethod: 'OTP',
          },
        });

        const qrVerified = await this.prisma.booking.count({
          where: {
            ...where,
            status: 'COMPLETED',
            confirmationMethod: 'QR_SCAN',
          },
        });

        const simpleConfirm = await this.prisma.booking.count({
          where: {
            ...where,
            status: 'COMPLETED',
            confirmationMethod: 'SIMPLE',
          },
        });

        // Bookings complétés SANS méthode de confirmation (suspect)
        const completedWithoutConfirmation = await this.prisma.booking.count({
          where: {
            ...where,
            status: 'COMPLETED',
            confirmationMethod: null,
          },
        });

        // Calcul des taux
        const cancellationRate = totalBookings > 0
          ? Math.round((cancelled / totalBookings) * 100)
          : 0;

        const completionRate = totalBookings > 0
          ? Math.round((completed / totalBookings) * 100)
          : 0;

        const proCancellationRate = totalBookings > 0
          ? Math.round((cancelledByPro / totalBookings) * 100)
          : 0;

        const verificationRate = completed > 0
          ? Math.round(((otpVerified + qrVerified) / completed) * 100)
          : 0;

        // Alerte si taux d'annulation pro > 15% ou completion < 50%
        const isSuspicious = proCancellationRate > 15 ||
          (totalBookings > 5 && completionRate < 50) ||
          completedWithoutConfirmation > 3;

        return {
          providerId: provider.id,
          providerName: provider.displayName,
          email: provider.user.email,

          // Compteurs bruts
          totalBookings,
          pending,
          confirmed,
          completed,
          cancelled,
          cancelledByPro,
          cancelledByUser,
          expired,
          disputed,
          pendingProValidation,
          awaitingConfirmation,

          // Méthodes de confirmation
          otpVerified,
          qrVerified,
          simpleConfirm,
          completedWithoutConfirmation,

          // Taux en %
          cancellationRate,
          completionRate,
          proCancellationRate,
          verificationRate,

          // Alerte
          isSuspicious,
        };
      }),
    );

    // Trier par taux d'annulation pro décroissant (les plus suspects en premier)
    stats.sort((a, b) => b.proCancellationRate - a.proCancellationRate);

    // Calculs globaux
    const global = {
      totalProviders: stats.length,
      suspiciousCount: stats.filter((s) => s.isSuspicious).length,
      totalBookings: stats.reduce((sum, s) => sum + s.totalBookings, 0),
      totalCompleted: stats.reduce((sum, s) => sum + s.completed, 0),
      totalCancelled: stats.reduce((sum, s) => sum + s.cancelled, 0),
      totalCancelledByPro: stats.reduce((sum, s) => sum + s.cancelledByPro, 0),
      totalOtpVerified: stats.reduce((sum, s) => sum + s.otpVerified, 0),
      totalQrVerified: stats.reduce((sum, s) => sum + s.qrVerified, 0),
      avgCancellationRate: stats.length > 0
        ? Math.round(stats.reduce((sum, s) => sum + s.cancellationRate, 0) / stats.length)
        : 0,
      avgCompletionRate: stats.length > 0
        ? Math.round(stats.reduce((sum, s) => sum + s.completionRate, 0) / stats.length)
        : 0,
    };

    return { global, providers: stats };
  }
}
