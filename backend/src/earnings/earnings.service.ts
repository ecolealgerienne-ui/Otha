// src/earnings/earnings.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { COMMISSION_DA } from '../config/commission';

type Counts = { PENDING: number; CONFIRMED: number; COMPLETED: number; CANCELLED: number };
type OrderCounts = { PENDING: number; CONFIRMED: number; SHIPPED: number; DELIVERED: number; CANCELLED: number };

function monthStartEndUtc(ym: string) {
  const y = +ym.slice(0, 4);
  const m = +ym.slice(5, 7);
  const from = new Date(Date.UTC(y, m - 1, 1));
  const to   = new Date(Date.UTC(m === 12 ? y + 1 : y, m === 12 ? 1 : m, 1));
  return { from, to };
}

function canonYm(raw: string) {
  const t = (raw || '').replace('/', '-').trim();
  const m = t.match(/^(\d{4})-(\d{1,2})/);
  if (!m) return t;
  return `${m[1]}-${(+m[2]).toString().padStart(2, '0')}`;
}

@Injectable()
export class EarningsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Récupère la commission vétérinaire personnalisée du provider
   * Retourne la valeur par défaut si non trouvé
   */
  private async getProviderVetCommission(providerId: string): Promise<number> {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      select: { vetCommissionDa: true },
    });
    return provider?.vetCommissionDa ?? COMMISSION_DA;
  }

  private async countsFor(providerId: string, ym: string): Promise<Counts> {
    const { from, to } = monthStartEndUtc(ym);
    const rows = await this.prisma.booking.groupBy({
      by: ['status'],
      where: { providerId, scheduledAt: { gte: from, lt: to } },
      _count: { _all: true },
    });

    const out: Counts = { PENDING: 0, CONFIRMED: 0, COMPLETED: 0, CANCELLED: 0 };
    for (const r of rows) out[r.status as keyof Counts] = r._count._all;
    return out;
  }

  private async collectedOverlay(providerId: string, ym: string, dueDa: number, kind: string = 'vet'): Promise<number> {
    const rec = await this.prisma.adminCollection.findUnique({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
    });
    if (!rec) return 0;
    return Math.min(rec.amountDa, dueDa);
  }

  // Ligne normalisée d'un mois
  async monthRow(providerId: string, ymRaw: string) {
    const ym = canonYm(ymRaw);
    const counts = await this.countsFor(providerId, ym);
    const completed = counts.COMPLETED;

    // Utiliser la commission personnalisée du provider
    const commissionDa = await this.getProviderVetCommission(providerId);
    const dueDa = completed * commissionDa;

    // 1) overlay admin (collecte figée)
    const collectedDa = await this.collectedOverlay(providerId, ym, dueDa);

    // 2) (optionnel) si vous avez une table de paiements réels, agrégez ici, puis clamp:
    // collectedDa = Math.min(collectedDa + realPaymentsDa, dueDa);

    const netDa = Math.max(dueDa - collectedDa, 0);

    // Retourner le format attendu par le frontend
    return {
      month: ym,
      bookingCount: completed,
      totalAmount: dueDa, // Pour l'instant, on utilise la commission comme montant total
      totalCommission: dueDa,
      netAmount: netDa,
      collected: collectedDa >= dueDa && dueDa > 0,
      collectedAmount: collectedDa,
      // Champs legacy pour compatibilité
      ...counts,
      dueDa,
      collectedDa,
      netDa,
    };
  }

  // Liste des N derniers mois (courant inclus)
  async historyMonthly(providerId: string, months: number) {
    const now = new Date();
    const curYm = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    const y = +curYm.slice(0, 4);
    const m = +curYm.slice(5, 7);

    const yms: string[] = [];
    for (let i = 0; i < Math.max(1, months); i++) {
      const d = new Date(Date.UTC(y, m - 1 - i, 1));
      yms.push(`${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}`);
    }

    const rows = await Promise.all(yms.map(ym => this.monthRow(providerId, ym)));
    return rows;
  }

  // Résumé d’un mois (pour /me/earnings?month=YYYY-MM)
  async earningsForMonth(providerId: string, ym: string) {
    return this.monthRow(providerId, canonYm(ym));
  }

  // Marquer collecté: on peut spécifier un montant personnalisé ou collecter tout
  async collectMonth(providerId: string, ymRaw: string, note?: string, customAmount?: number) {
    const ym = canonYm(ymRaw);
    const row = await this.monthRow(providerId, ym);
    const kind = 'vet';

    // Si un montant personnalisé est fourni, l'utiliser (limité au maximum dû)
    const amountToCollect = customAmount !== undefined
      ? Math.min(Math.max(0, customAmount), row.dueDa)
      : row.dueDa;

    await this.prisma.adminCollection.upsert({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
      update: { amountDa: amountToCollect, note },
      create: { providerId, month: ym, kind, amountDa: amountToCollect, note },
    });
    // Retourner la ligne normalisée recalculée
    return this.monthRow(providerId, ym);
  }

  // Ajouter un montant à la collecte existante
  async addToCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);
    const row = await this.monthRow(providerId, ym);
    const kind = 'vet';

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
    });

    const currentAmount = existing?.amountDa ?? 0;
    // Ajouter le montant mais ne pas dépasser le dû
    const newAmount = Math.min(currentAmount + amountDa, row.dueDa);

    await this.prisma.adminCollection.upsert({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
      update: { amountDa: newAmount, note: note || existing?.note },
      create: { providerId, month: ym, kind, amountDa: newAmount, note },
    });

    return this.monthRow(providerId, ym);
  }

  // Retirer un montant de la collecte
  async subtractFromCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);
    const kind = 'vet';

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
    });

    if (!existing) {
      return this.monthRow(providerId, ym);
    }

    const newAmount = Math.max(0, existing.amountDa - amountDa);

    if (newAmount === 0) {
      // Si le montant devient 0, supprimer l'enregistrement
      await this.prisma.adminCollection.delete({
        where: { providerId_month_kind: { providerId, month: ym, kind } },
      });
    } else {
      await this.prisma.adminCollection.update({
        where: { providerId_month_kind: { providerId, month: ym, kind } },
        data: { amountDa: newAmount, note: note || existing.note },
      });
    }

    return this.monthRow(providerId, ym);
  }

  async uncollectMonth(providerId: string, ymRaw: string) {
    const ym = canonYm(ymRaw);
    const kind = 'vet';
    await this.prisma.adminCollection.deleteMany({
      where: { providerId, month: ym, kind },
    });
    return this.monthRow(providerId, ym);
  }

  // Stats globales pour tous les providers (commission totale, collectée, restante)
  async globalStats(months = 12) {
    // Récupérer tous les providers approuvés
    const providers = await this.prisma.providerProfile.findMany({
      where: { isApproved: true },
      select: { id: true, vetCommissionDa: true },
    });

    // Générer la liste des mois à analyser
    const now = new Date();
    const curYm = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    const y = +curYm.slice(0, 4);
    const m = +curYm.slice(5, 7);

    const yms: string[] = [];
    for (let i = 0; i < Math.max(1, months); i++) {
      const d = new Date(Date.UTC(y, m - 1 - i, 1));
      yms.push(`${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}`);
    }

    let totalCommissionGenerated = 0;
    let totalCollected = 0;
    let totalBookings = 0;

    // Pour chaque provider, calculer les totaux
    for (const provider of providers) {
      const commissionDa = provider.vetCommissionDa ?? COMMISSION_DA;

      for (const ym of yms) {
        const counts = await this.countsFor(provider.id, ym);
        const completed = counts.COMPLETED;
        const dueDa = completed * commissionDa;

        totalBookings += completed;
        totalCommissionGenerated += dueDa;

        // Récupérer le montant collecté
        const collectedDa = await this.collectedOverlay(provider.id, ym, dueDa);
        totalCollected += collectedDa;
      }
    }

    return {
      totalProviders: providers.length,
      totalBookings,
      totalCommissionGenerated,
      totalCollected,
      totalRemaining: totalCommissionGenerated - totalCollected,
      months,
    };
  }

  // ==================== PETSHOP EARNINGS ====================

  /**
   * Count petshop orders by status for a given month
   */
  private async petshopCountsFor(providerId: string, ym: string): Promise<OrderCounts> {
    const { from, to } = monthStartEndUtc(ym);
    const rows = await this.prisma.order.groupBy({
      by: ['status'],
      where: { providerId, createdAt: { gte: from, lt: to } },
      _count: { _all: true },
    });

    const out: OrderCounts = { PENDING: 0, CONFIRMED: 0, SHIPPED: 0, DELIVERED: 0, CANCELLED: 0 };
    for (const r of rows) out[r.status as keyof OrderCounts] = r._count._all;
    return out;
  }

  /**
   * Get total commission from delivered petshop orders for a given month
   */
  private async petshopCommissionFor(providerId: string, ym: string): Promise<{ orderCount: number; totalCommission: number; totalRevenue: number }> {
    const { from, to } = monthStartEndUtc(ym);
    const orders = await this.prisma.order.findMany({
      where: {
        providerId,
        status: 'DELIVERED',
        createdAt: { gte: from, lt: to },
      },
      select: {
        commissionDa: true,
        subtotalDa: true,
        totalDa: true,
      },
    });

    return {
      orderCount: orders.length,
      totalCommission: orders.reduce((sum, o) => sum + (o.commissionDa || 0), 0),
      totalRevenue: orders.reduce((sum, o) => sum + (o.subtotalDa || 0), 0),
    };
  }

  /**
   * Get petshop earnings row for a specific month
   */
  async petshopMonthRow(providerId: string, ymRaw: string) {
    const ym = canonYm(ymRaw);
    const counts = await this.petshopCountsFor(providerId, ym);
    const { orderCount, totalCommission, totalRevenue } = await this.petshopCommissionFor(providerId, ym);

    // Get collected amount using kind: 'petshop'
    const collectedDa = await this.collectedOverlay(providerId, ym, totalCommission, 'petshop');

    const netDa = Math.max(totalCommission - collectedDa, 0);

    return {
      month: ym,
      // Match frontend MonthlyEarnings interface
      bookingCount: orderCount,
      totalAmount: totalRevenue,
      totalCommission,
      netAmount: netDa,
      collected: collectedDa >= totalCommission && totalCommission > 0,
      collectedAmount: collectedDa,
      // Legacy fields
      orderCount,
      totalRevenue,
      dueDa: totalCommission,
      collectedDa,
      netDa,
      ...counts,
    };
  }

  /**
   * Get petshop earnings history for last N months
   */
  async petshopHistoryMonthly(providerId: string, months: number) {
    const now = new Date();
    const curYm = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    const y = +curYm.slice(0, 4);
    const m = +curYm.slice(5, 7);

    const yms: string[] = [];
    for (let i = 0; i < Math.max(1, months); i++) {
      const d = new Date(Date.UTC(y, m - 1 - i, 1));
      yms.push(`${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}`);
    }

    const rows = await Promise.all(yms.map(ym => this.petshopMonthRow(providerId, ym)));
    return rows;
  }

  /**
   * Collect petshop commission for a month
   */
  async petshopCollectMonth(providerId: string, ymRaw: string, note?: string, customAmount?: number) {
    const ym = canonYm(ymRaw);
    const row = await this.petshopMonthRow(providerId, ym);
    const kind = 'petshop';

    const amountToCollect = customAmount !== undefined
      ? Math.min(Math.max(0, customAmount), row.dueDa)
      : row.dueDa;

    await this.prisma.adminCollection.upsert({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
      update: { amountDa: amountToCollect, note },
      create: { providerId, month: ym, kind, amountDa: amountToCollect, note },
    });

    return this.petshopMonthRow(providerId, ym);
  }

  /**
   * Add amount to petshop collection
   */
  async petshopAddCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);
    const row = await this.petshopMonthRow(providerId, ym);
    const kind = 'petshop';

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
    });

    const currentAmount = existing?.amountDa ?? 0;
    const newAmount = Math.min(currentAmount + amountDa, row.dueDa);

    await this.prisma.adminCollection.upsert({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
      update: { amountDa: newAmount, note: note || existing?.note },
      create: { providerId, month: ym, kind, amountDa: newAmount, note },
    });

    return this.petshopMonthRow(providerId, ym);
  }

  /**
   * Subtract amount from petshop collection
   */
  async petshopSubtractCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);
    const kind = 'petshop';

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
    });

    if (!existing) {
      return this.petshopMonthRow(providerId, ym);
    }

    const newAmount = Math.max(0, existing.amountDa - amountDa);

    if (newAmount === 0) {
      await this.prisma.adminCollection.delete({
        where: { providerId_month_kind: { providerId, month: ym, kind } },
      });
    } else {
      await this.prisma.adminCollection.update({
        where: { providerId_month_kind: { providerId, month: ym, kind } },
        data: { amountDa: newAmount, note: note || existing.note },
      });
    }

    return this.petshopMonthRow(providerId, ym);
  }

  /**
   * Uncollect petshop month (remove all collection)
   */
  async petshopUncollectMonth(providerId: string, ymRaw: string) {
    const ym = canonYm(ymRaw);
    const kind = 'petshop';
    await this.prisma.adminCollection.deleteMany({
      where: { providerId, month: ym, kind },
    });
    return this.petshopMonthRow(providerId, ym);
  }

  /**
   * Global petshop stats across all petshop providers
   */
  async petshopGlobalStats(months = 12) {
    // Get all approved petshop providers
    const providers = await this.prisma.providerProfile.findMany({
      where: {
        isApproved: true,
        specialties: { path: ['kind'], equals: 'petshop' },
      },
      select: { id: true },
    });

    const now = new Date();
    const curYm = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    const y = +curYm.slice(0, 4);
    const m = +curYm.slice(5, 7);

    const yms: string[] = [];
    for (let i = 0; i < Math.max(1, months); i++) {
      const d = new Date(Date.UTC(y, m - 1 - i, 1));
      yms.push(`${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}`);
    }

    let totalCommissionGenerated = 0;
    let totalCollected = 0;
    let totalOrders = 0;
    let totalRevenue = 0;

    for (const provider of providers) {
      for (const ym of yms) {
        const row = await this.petshopMonthRow(provider.id, ym);
        totalOrders += row.orderCount;
        totalCommissionGenerated += row.totalCommission;
        totalRevenue += row.totalRevenue;
        totalCollected += row.collectedDa;
      }
    }

    return {
      totalProviders: providers.length,
      totalOrders,
      totalRevenue,
      totalCommissionGenerated,
      totalCollected,
      totalRemaining: totalCommissionGenerated - totalCollected,
      months,
    };
  }

  // ==================== DAYCARE EARNINGS ====================

  /**
   * Get daycare commission for a provider
   */
  private async getProviderDaycareCommission(providerId: string): Promise<{ hourly: number; daily: number }> {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      select: { daycareHourlyCommissionDa: true, daycareDailyCommissionDa: true },
    });
    return {
      hourly: provider?.daycareHourlyCommissionDa ?? 10,
      daily: provider?.daycareDailyCommissionDa ?? 100,
    };
  }

  /**
   * Count daycare bookings by status for a given month
   */
  private async daycareCountsFor(providerId: string, ym: string): Promise<{ PENDING: number; CONFIRMED: number; COMPLETED: number; CANCELLED: number }> {
    const { from, to } = monthStartEndUtc(ym);
    const rows = await this.prisma.daycareBooking.groupBy({
      by: ['status'],
      where: { providerId, startDate: { gte: from, lt: to } },
      _count: { _all: true },
    });

    const out = { PENDING: 0, CONFIRMED: 0, COMPLETED: 0, CANCELLED: 0 };
    for (const r of rows) {
      const count = (r._count as { _all: number })._all;
      out[r.status as keyof typeof out] = count;
    }
    return out;
  }

  /**
   * Get total commission from completed daycare bookings for a given month
   */
  private async daycareCommissionFor(providerId: string, ym: string): Promise<{ bookingCount: number; totalCommission: number; totalRevenue: number }> {
    const { from, to } = monthStartEndUtc(ym);

    const bookings = await this.prisma.daycareBooking.findMany({
      where: {
        providerId,
        status: 'COMPLETED',
        startDate: { gte: from, lt: to },
      },
      select: {
        priceDa: true,
        commissionDa: true,
        totalDa: true,
      },
    });

    let totalCommission = 0;
    let totalRevenue = 0;

    for (const b of bookings) {
      totalRevenue += b.totalDa || b.priceDa || 0;
      // Use stored commissionDa directly (100 DA default per booking)
      totalCommission += b.commissionDa || 100;
    }

    return {
      bookingCount: bookings.length,
      totalCommission,
      totalRevenue,
    };
  }

  /**
   * Get daycare earnings row for a specific month
   */
  async daycareMonthRow(providerId: string, ymRaw: string) {
    const ym = canonYm(ymRaw);
    const counts = await this.daycareCountsFor(providerId, ym);
    const { bookingCount, totalCommission, totalRevenue } = await this.daycareCommissionFor(providerId, ym);

    // Get collected amount using kind: 'daycare'
    const collectedDa = await this.collectedOverlay(providerId, ym, totalCommission, 'daycare');

    const netDa = Math.max(totalCommission - collectedDa, 0);

    return {
      month: ym,
      // Match frontend MonthlyEarnings interface
      bookingCount,
      totalAmount: totalRevenue,
      totalCommission,
      netAmount: netDa,
      collected: collectedDa >= totalCommission && totalCommission > 0,
      collectedAmount: collectedDa,
      // Legacy fields
      totalRevenue,
      dueDa: totalCommission,
      collectedDa,
      netDa,
      ...counts,
    };
  }

  /**
   * Get daycare earnings history for last N months
   */
  async daycareHistoryMonthly(providerId: string, months: number) {
    const now = new Date();
    const curYm = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    const y = +curYm.slice(0, 4);
    const m = +curYm.slice(5, 7);

    const yms: string[] = [];
    for (let i = 0; i < Math.max(1, months); i++) {
      const d = new Date(Date.UTC(y, m - 1 - i, 1));
      yms.push(`${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}`);
    }

    const rows = await Promise.all(yms.map(ym => this.daycareMonthRow(providerId, ym)));
    return rows;
  }

  /**
   * Collect daycare commission for a month
   */
  async daycareCollectMonth(providerId: string, ymRaw: string, note?: string, customAmount?: number) {
    const ym = canonYm(ymRaw);
    const row = await this.daycareMonthRow(providerId, ym);
    const kind = 'daycare';

    const amountToCollect = customAmount !== undefined
      ? Math.min(Math.max(0, customAmount), row.dueDa)
      : row.dueDa;

    await this.prisma.adminCollection.upsert({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
      update: { amountDa: amountToCollect, note },
      create: { providerId, month: ym, kind, amountDa: amountToCollect, note },
    });

    return this.daycareMonthRow(providerId, ym);
  }

  /**
   * Add amount to daycare collection
   */
  async daycareAddCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);
    const row = await this.daycareMonthRow(providerId, ym);
    const kind = 'daycare';

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
    });

    const currentAmount = existing?.amountDa ?? 0;
    const newAmount = Math.min(currentAmount + amountDa, row.dueDa);

    await this.prisma.adminCollection.upsert({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
      update: { amountDa: newAmount, note: note || existing?.note },
      create: { providerId, month: ym, kind, amountDa: newAmount, note },
    });

    return this.daycareMonthRow(providerId, ym);
  }

  /**
   * Subtract amount from daycare collection
   */
  async daycareSubtractCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);
    const kind = 'daycare';

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month_kind: { providerId, month: ym, kind } },
    });

    if (!existing) {
      return this.daycareMonthRow(providerId, ym);
    }

    const newAmount = Math.max(0, existing.amountDa - amountDa);

    if (newAmount === 0) {
      await this.prisma.adminCollection.delete({
        where: { providerId_month_kind: { providerId, month: ym, kind } },
      });
    } else {
      await this.prisma.adminCollection.update({
        where: { providerId_month_kind: { providerId, month: ym, kind } },
        data: { amountDa: newAmount, note: note || existing.note },
      });
    }

    return this.daycareMonthRow(providerId, ym);
  }

  /**
   * Uncollect daycare month (remove all collection)
   */
  async daycareUncollectMonth(providerId: string, ymRaw: string) {
    const ym = canonYm(ymRaw);
    const kind = 'daycare';
    await this.prisma.adminCollection.deleteMany({
      where: { providerId, month: ym, kind },
    });
    return this.daycareMonthRow(providerId, ym);
  }

  /**
   * Global daycare stats across all daycare providers
   */
  async daycareGlobalStats(months = 12) {
    const providers = await this.prisma.providerProfile.findMany({
      where: {
        isApproved: true,
        specialties: { path: ['kind'], equals: 'daycare' },
      },
      select: { id: true },
    });

    const now = new Date();
    const curYm = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    const y = +curYm.slice(0, 4);
    const m = +curYm.slice(5, 7);

    const yms: string[] = [];
    for (let i = 0; i < Math.max(1, months); i++) {
      const d = new Date(Date.UTC(y, m - 1 - i, 1));
      yms.push(`${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}`);
    }

    let totalCommissionGenerated = 0;
    let totalCollected = 0;
    let totalBookings = 0;
    let totalRevenue = 0;

    for (const provider of providers) {
      for (const ym of yms) {
        const row = await this.daycareMonthRow(provider.id, ym);
        totalBookings += row.bookingCount;
        totalCommissionGenerated += row.totalCommission;
        totalRevenue += row.totalRevenue;
        totalCollected += row.collectedDa;
      }
    }

    return {
      totalProviders: providers.length,
      totalBookings,
      totalRevenue,
      totalCommissionGenerated,
      totalCollected,
      totalRemaining: totalCommissionGenerated - totalCollected,
      months,
    };
  }
}
