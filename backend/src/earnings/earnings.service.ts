// src/earnings/earnings.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { COMMISSION_DA } from '../config/commission';

type Counts = { PENDING: number; CONFIRMED: number; COMPLETED: number; CANCELLED: number };

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

  private async collectedOverlay(providerId: string, ym: string, dueDa: number): Promise<number> {
    const rec = await this.prisma.adminCollection.findUnique({
      where: { providerId_month: { providerId, month: ym } },
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

    // Si un montant personnalisé est fourni, l'utiliser (limité au maximum dû)
    const amountToCollect = customAmount !== undefined
      ? Math.min(Math.max(0, customAmount), row.dueDa)
      : row.dueDa;

    await this.prisma.adminCollection.upsert({
      where: { providerId_month: { providerId, month: ym } },
      update: { amountDa: amountToCollect, note },
      create: { providerId, month: ym, amountDa: amountToCollect, note },
    });
    // Retourner la ligne normalisée recalculée
    return this.monthRow(providerId, ym);
  }

  // Ajouter un montant à la collecte existante
  async addToCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);
    const row = await this.monthRow(providerId, ym);

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month: { providerId, month: ym } },
    });

    const currentAmount = existing?.amountDa ?? 0;
    // Ajouter le montant mais ne pas dépasser le dû
    const newAmount = Math.min(currentAmount + amountDa, row.dueDa);

    await this.prisma.adminCollection.upsert({
      where: { providerId_month: { providerId, month: ym } },
      update: { amountDa: newAmount, note: note || existing?.note },
      create: { providerId, month: ym, amountDa: newAmount, note },
    });

    return this.monthRow(providerId, ym);
  }

  // Retirer un montant de la collecte
  async subtractFromCollection(providerId: string, ymRaw: string, amountDa: number, note?: string) {
    const ym = canonYm(ymRaw);

    const existing = await this.prisma.adminCollection.findUnique({
      where: { providerId_month: { providerId, month: ym } },
    });

    if (!existing) {
      return this.monthRow(providerId, ym);
    }

    const newAmount = Math.max(0, existing.amountDa - amountDa);

    if (newAmount === 0) {
      // Si le montant devient 0, supprimer l'enregistrement
      await this.prisma.adminCollection.delete({
        where: { providerId_month: { providerId, month: ym } },
      });
    } else {
      await this.prisma.adminCollection.update({
        where: { providerId_month: { providerId, month: ym } },
        data: { amountDa: newAmount, note: note || existing.note },
      });
    }

    return this.monthRow(providerId, ym);
  }

  async uncollectMonth(providerId: string, ymRaw: string) {
    const ym = canonYm(ymRaw);
    await this.prisma.adminCollection.deleteMany({
      where: { providerId, month: ym },
    });
    return this.monthRow(providerId, ym);
  }
}
