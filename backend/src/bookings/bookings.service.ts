// src/bookings/bookings.service.ts
import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { BookingStatus, Prisma, NotificationType, TrustStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability/availability.service';
import { NotificationsService } from '../notifications/notifications.service';

const COMMISSION_DA = Number(process.env.APP_COMMISSION_DA ?? 100);

// Durées de restriction progressives (en jours)
const RESTRICTION_DURATIONS = [3, 7, 14, 30]; // 1er no-show: 3j, 2ème: 7j, 3ème: 14j, 4ème+: 30j

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
        referenceCode: true, // ✅ Code de référence (ex: VGC-A2B3C4)
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
        referenceCode: b.referenceCode, // ✅ Code de référence (ex: VGC-A2B3C4)
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

    // ✅ TRUST SYSTEM: Vérifier si annulation tardive pour NEW user
    if (status === 'CANCELLED') {
      const cancelCheck = await this.checkUserCanCancel(userId, id);
      if (cancelCheck.isNoShow) {
        // Annulation < 12h avant le RDV → appliquer pénalité no-show
        await this.applyNoShowPenalty(userId);
      }
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

    // Si on annule => supprimer l'earning éventuel
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

    // ✅ TRUST SYSTEM: Vérifier si NEW user peut modifier (limite 1 modif)
    const rescheduleCheck = await this.checkUserCanReschedule(userId, id);
    if (!rescheduleCheck.canReschedule) {
      throw new ForbiddenException(rescheduleCheck.reason || 'Modification non autorisée');
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

    // Conserve le statut actuel (pas de "reset" en PENDING)
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

    // ✅ TRUST SYSTEM: Tracker la modification pour NEW users
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true },
    });
    if (user?.trustStatus === 'NEW') {
      await this.prisma.user.update({
        where: { id: userId },
        data: { lastModifiedBooking: id },
      });
    }

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
        petIds: true, // ✅ IDs des animaux du booking
        service: { select: { id: true, title: true, price: true } },
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            phone: true, // ⚠️ pas d'email
            trustStatus: true, // ✅ TRUST SYSTEM
            pets: {
              orderBy: { updatedAt: 'desc' },
              take: 1,
              select: { id: true, idNumber: true, breed: true, name: true, species: true, photoUrl: true }, // ✅ Include id and photoUrl for fallback
            },
          },
        },
      },
    });

    // ✅ Récupérer les infos des pets pour tous les bookings
    const allPetIds = [...new Set(rows.flatMap(r => r.petIds || []))];
    const pets = allPetIds.length > 0
      ? await this.prisma.pet.findMany({
          where: { id: { in: allPetIds } },
          select: { id: true, name: true, species: true, breed: true, photoUrl: true },
        })
      : [];
    const petsMap = new Map(pets.map(p => [p.id, p]));

    // ✅ TRUST SYSTEM: Récupérer le nombre de RDV complétés par user pour détecter les "premiers RDV"
    const userIds = [...new Set(rows.map(r => r.user.id))];
    const completedCounts = await Promise.all(
      userIds.map(async (uid) => ({
        userId: uid,
        count: await this.prisma.booking.count({
          where: { userId: uid, status: 'COMPLETED' },
        }),
      }))
    );
    const completedMap = new Map(completedCounts.map(c => [c.userId, c.count]));

    return rows.map((b) => {
      const price =
        b.service.price == null
          ? null
          : (b.service.price as Prisma.Decimal).toNumber();
      const displayName =
        [b.user.firstName, b.user.lastName].filter(Boolean).join(' ').trim() ||
        'Client';
      const userPet = b.user.pets?.[0];
      const petType = (userPet?.idNumber || userPet?.breed || '').trim();

      // ✅ Récupérer le premier animal du booking (avec son ID pour les patients récents)
      const bookingPet = (b.petIds || []).map(id => petsMap.get(id)).find(Boolean);

      // ✅ TRUST SYSTEM: Déterminer si c'est le premier RDV du client
      const isFirstBooking = b.user.trustStatus === 'NEW' && (completedMap.get(b.user.id) ?? 0) === 0;

      // ✅ Fallback: use user's pet if booking doesn't have petIds
      const fallbackPet = userPet?.id
        ? { id: userPet.id, name: userPet.name, species: userPet.species, breed: userPet.breed, photoUrl: userPet.photoUrl }
        : null;

      return {
        id: b.id,
        status: b.status,
        scheduledAt: b.scheduledAt.toISOString(),
        petIds: b.petIds || [], // ✅ Liste des IDs des animaux
        service: { id: b.service.id, title: b.service.title, price },
        user: {
          id: b.user.id,
          displayName,
          phone: b.user.phone ?? null,
          isFirstBooking, // ✅ Pour afficher "Nouveau client" côté PRO
          trustStatus: b.user.trustStatus, // ✅ Statut de confiance
        },
        // ✅ Pet avec ID et photoUrl pour permettre le chargement du dossier médical
        // Fallback to user's pet if booking doesn't have petIds linked
        pet: bookingPet
          ? { id: bookingPet.id, name: bookingPet.name, species: bookingPet.species, breed: bookingPet.breed, photoUrl: bookingPet.photoUrl }
          : fallbackPet || { label: petType || null, name: userPet?.name ?? null },
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
   * @param method - 'QR_SCAN' | 'SIMPLE' | 'AUTO' (défaut: AUTO)
   */
  async proConfirmBooking(userId: string, bookingId: string, method: string = 'AUTO') {
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

    // ✅ Marquer comme confirmé par le pro avec la méthode de confirmation
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        proConfirmedAt: new Date(),
        status: 'COMPLETED',
        confirmationMethod: method, // 'QR_SCAN', 'SIMPLE', 'AUTO', etc.
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

    // ✅ TRUST SYSTEM: Vérifier l'utilisateur (NEW → VERIFIED)
    await this.verifyUserIfNeeded(b.userId);

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
   * Intègre le système de confiance anti-troll
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

      // ✅ TRUST SYSTEM: Vérifier l'utilisateur (NEW → VERIFIED)
      await this.verifyUserIfNeeded(b.userId);
    } else {
      // ❌ PRO REFUSE = CLIENT MENT (NO-SHOW)
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

      // ❌ TRUST SYSTEM: Appliquer la pénalité no-show
      await this.applyNoShowPenalty(b.userId);
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
    method: 'SIMPLE' | 'QR_SCAN',
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

  // ==================== SYSTÈME DE CONFIANCE (ANTI-TROLL) ====================

  /**
   * Calcule la durée de restriction en jours selon le nombre de no-shows
   */
  private getRestrictionDays(noShowCount: number): number {
    const index = Math.min(noShowCount - 1, RESTRICTION_DURATIONS.length - 1);
    return RESTRICTION_DURATIONS[Math.max(0, index)];
  }

  /**
   * Applique une pénalité no-show à un utilisateur
   * Incrémente le compteur et définit la date de fin de restriction
   */
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

  /**
   * Vérifie et passe un utilisateur NEW en VERIFIED après son premier RDV complété
   */
  private async verifyUserIfNeeded(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true, verifiedAt: true },
    });
    if (!user) return;

    // Si l'utilisateur est NEW, le passer en VERIFIED
    if (user.trustStatus === 'NEW') {
      await this.prisma.user.update({
        where: { id: userId },
        data: {
          trustStatus: 'VERIFIED',
          verifiedAt: new Date(),
          noShowCount: 0, // Reset si jamais
        },
      });
    }
  }

  /**
   * Vérifie si un utilisateur peut créer un booking
   * Retourne { canBook: boolean, reason?: string, isFirstBooking?: boolean }
   */
  async checkUserCanBook(userId: string): Promise<{
    canBook: boolean;
    reason?: string;
    isFirstBooking?: boolean;
    trustStatus?: TrustStatus;
    restrictedUntil?: Date | null;
  }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        trustStatus: true,
        restrictedUntil: true,
        noShowCount: true,
      },
    });

    if (!user) {
      return { canBook: false, reason: 'Utilisateur non trouvé' };
    }

    // Vérifier si la restriction est expirée
    if (user.trustStatus === 'RESTRICTED') {
      if (user.restrictedUntil && user.restrictedUntil <= new Date()) {
        // Restriction expirée → remettre en NEW pour un nouveau test
        await this.prisma.user.update({
          where: { id: userId },
          data: {
            trustStatus: 'NEW',
            restrictedUntil: null,
          },
        });
        // Continuer avec le statut NEW
      } else {
        // Toujours restreint
        const remainingDays = user.restrictedUntil
          ? Math.ceil((user.restrictedUntil.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
          : 0;
        return {
          canBook: false,
          reason: `Votre compte est restreint pour encore ${remainingDays} jour(s) suite à des annulations tardives ou absences répétées.`,
          trustStatus: user.trustStatus,
          restrictedUntil: user.restrictedUntil,
        };
      }
    }

    // Vérifier si NEW user a déjà un RDV VETO actif
    // Note: Les systèmes vet/daycare/petshop sont indépendants - un RDV garderie ne bloque PAS le véto
    if (user.trustStatus === 'NEW') {
      // Vérifier uniquement les bookings véto actifs (pas les garderies!)
      const activeVetBooking = await this.prisma.booking.findFirst({
        where: {
          userId,
          status: { in: ['PENDING', 'CONFIRMED', 'AWAITING_CONFIRMATION', 'PENDING_PRO_VALIDATION'] },
        },
      });

      if (activeVetBooking) {
        return {
          canBook: false,
          reason: 'En tant que nouveau client, vous devez d\'abord honorer votre rendez-vous vétérinaire en cours.',
          trustStatus: user.trustStatus,
          isFirstBooking: false,
        };
      }

      return {
        canBook: true,
        trustStatus: user.trustStatus,
        isFirstBooking: true,
      };
    }

    // VERIFIED → vérifier qu'il n'a pas déjà un RDV véto actif
    const activeVetBooking = await this.prisma.booking.findFirst({
      where: {
        userId,
        status: { in: ['PENDING', 'CONFIRMED', 'AWAITING_CONFIRMATION', 'PENDING_PRO_VALIDATION'] },
      },
      select: { id: true, scheduledAt: true, provider: { select: { displayName: true } } },
    });

    if (activeVetBooking) {
      const dateStr = activeVetBooking.scheduledAt
        ? activeVetBooking.scheduledAt.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })
        : 'bientôt';
      const providerName = activeVetBooking.provider?.displayName || 'un vétérinaire';
      return {
        canBook: false,
        reason: `Vous avez déjà un rendez-vous prévu ${dateStr} chez ${providerName}. Veuillez l'annuler avant d'en prendre un nouveau.`,
        trustStatus: user.trustStatus,
        isFirstBooking: false,
      };
    }

    return {
      canBook: true,
      trustStatus: user.trustStatus,
      isFirstBooking: false,
    };
  }

  /**
   * Vérifie si un utilisateur NEW peut annuler son RDV (> 12h avant)
   */
  async checkUserCanCancel(userId: string, bookingId: string): Promise<{
    canCancel: boolean;
    reason?: string;
    isNoShow?: boolean;
  }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true },
    });
    if (!user) return { canCancel: false, reason: 'Utilisateur non trouvé' };

    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
    });
    if (!booking) return { canCancel: false, reason: 'RDV non trouvé' };

    // VERIFIED users peuvent toujours annuler (mais avec conséquences si < 12h)
    if (user.trustStatus === 'VERIFIED') {
      return { canCancel: true, isNoShow: false };
    }

    // NEW users: vérifier si > 12h avant le RDV
    const hoursUntilBooking = (booking.scheduledAt.getTime() - Date.now()) / (1000 * 60 * 60);

    if (hoursUntilBooking < 12) {
      // Peut annuler mais sera compté comme no-show
      return {
        canCancel: true,
        isNoShow: true,
        reason: 'Annuler moins de 12h avant le rendez-vous sera compté comme une absence.',
      };
    }

    return { canCancel: true, isNoShow: false };
  }

  /**
   * Vérifie si un utilisateur NEW peut modifier son RDV (limite: 1 modif)
   */
  async checkUserCanReschedule(userId: string, bookingId: string): Promise<{
    canReschedule: boolean;
    reason?: string;
  }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true, lastModifiedBooking: true },
    });
    if (!user) return { canReschedule: false, reason: 'Utilisateur non trouvé' };

    // VERIFIED users peuvent toujours modifier
    if (user.trustStatus === 'VERIFIED') {
      return { canReschedule: true };
    }

    // NEW users: une seule modification autorisée
    if (user.lastModifiedBooking === bookingId) {
      return {
        canReschedule: false,
        reason: 'En tant que nouveau client, vous ne pouvez modifier ce rendez-vous qu\'une seule fois.',
      };
    }

    return { canReschedule: true };
  }

  /**
   * Récupère les infos de confiance d'un utilisateur (pour affichage PRO)
   */
  async getUserTrustInfo(userId: string): Promise<{
    trustStatus: TrustStatus;
    isFirstBooking: boolean;
    noShowCount: number;
    totalCompletedBookings: number;
  }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true, noShowCount: true, verifiedAt: true },
    });

    const completedBookings = await this.prisma.booking.count({
      where: { userId, status: 'COMPLETED' },
    });

    return {
      trustStatus: user?.trustStatus ?? 'NEW',
      isFirstBooking: user?.trustStatus === 'NEW' && completedBookings === 0,
      noShowCount: user?.noShowCount ?? 0,
      totalCompletedBookings: completedBookings,
    };
  }

  // ==================== CONFIRMATION PAR CODE DE RÉFÉRENCE ====================

  /**
   * PRO confirme un booking par son code de référence (VGC-XXXXXX)
   * Utilisé pour les vétérinaires sans caméra QR
   * Retourne le booking confirmé + infos du pet pour afficher le carnet de santé
   */
  async confirmByReferenceCode(proUserId: string, referenceCode: string) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId: proUserId },
      include: { user: { select: { firstName: true, lastName: true } } },
    });
    if (!prov) throw new ForbiddenException('No provider profile');

    // Chercher le booking par code de référence
    const booking = await this.prisma.booking.findUnique({
      where: { referenceCode },
      include: {
        service: true,
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

    if (!booking) {
      throw new NotFoundException('Aucun rendez-vous trouvé avec ce code');
    }

    // Vérifier que le booking appartient bien à ce provider
    if (booking.providerId !== prov.id) {
      throw new ForbiddenException('Ce rendez-vous ne vous appartient pas');
    }

    // Vérifier que le booking n'est pas déjà terminé
    if (['COMPLETED', 'CANCELLED', 'EXPIRED'].includes(booking.status)) {
      throw new BadRequestException('Ce rendez-vous est déjà terminé ou annulé');
    }

    // Vérifier que le booking est prévu aujourd'hui (tolérance: ±12h)
    const now = new Date();
    const scheduledTime = new Date(booking.scheduledAt);
    const hoursDiff = Math.abs(now.getTime() - scheduledTime.getTime()) / (1000 * 60 * 60);

    if (hoursDiff > 12) {
      throw new BadRequestException(
        'Ce rendez-vous ne peut être confirmé que le jour même (±12h)'
      );
    }

    // ✅ Confirmer le booking avec méthode REFERENCE_CODE
    await this.prisma.booking.update({
      where: { id: booking.id },
      data: {
        proConfirmedAt: new Date(),
        status: 'COMPLETED',
        confirmationMethod: 'REFERENCE_CODE',
      },
    });

    // ✅ Créer la commission
    const gross = Number((booking.service.price as Prisma.Decimal).toNumber());
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

    // ✅ TRUST SYSTEM: Vérifier l'utilisateur (NEW → VERIFIED)
    await this.verifyUserIfNeeded(booking.userId);

    // 🏥 Créer l'acte médical pour chaque animal
    const providerName = `${prov.user.firstName || ''} ${prov.user.lastName || ''}`.trim() || prov.displayName || 'Vétérinaire';
    const petIds = Array.isArray(booking.petIds) ? booking.petIds : [];

    for (const petId of petIds) {
      await this.prisma.medicalRecord.create({
        data: {
          petId: petId,
          type: 'VET_VISIT',
          title: `Visite vétérinaire - ${booking.service.title}`,
          description: `Rendez-vous confirmé par code de référence`,
          date: booking.scheduledAt,
          vetId: prov.id,
          vetName: providerName,
          providerType: 'VET',
          bookingId: booking.id,
          durationMinutes: booking.service.durationMin || 30,
        },
      });
    }

    // ✅ Récupérer les infos des animaux pour le carnet de santé
    const pets = petIds.length > 0
      ? await this.prisma.pet.findMany({
          where: { id: { in: petIds } },
          include: {
            medicalRecords: { orderBy: { date: 'desc' }, take: 10 },
            vaccinations: { orderBy: { date: 'desc' } },
          },
        })
      : [];

    // Générer un token d'accès pour le premier pet (pour le carnet de santé)
    let accessToken: string | null = null;
    if (pets.length > 0) {
      const tokenRecord = await this.prisma.petAccessToken.create({
        data: {
          petId: pets[0].id,
          token: require('crypto').randomBytes(32).toString('hex'),
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24h
        },
      });
      accessToken = tokenRecord.token;
    }

    return {
      success: true,
      message: 'Rendez-vous confirmé avec succès',
      booking: {
        id: booking.id,
        referenceCode: booking.referenceCode,
        status: 'COMPLETED',
        scheduledAt: booking.scheduledAt.toISOString(),
        service: {
          id: booking.service.id,
          title: booking.service.title,
        },
        user: {
          displayName: [booking.user.firstName, booking.user.lastName]
            .filter(Boolean)
            .join(' ')
            .trim() || 'Client',
          phone: booking.user.phone,
        },
      },
      pet: pets[0] || null,
      pets,
      accessToken, // Token pour accéder au carnet de santé
    };
  }
}
