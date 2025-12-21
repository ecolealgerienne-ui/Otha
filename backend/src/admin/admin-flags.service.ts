import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AdminFlag } from '@prisma/client';

// Types de flags pour les UTILISATEURS (clients)
export type UserFlagType =
  | 'NO_SHOW'                    // Client n'est pas venu
  | 'DAYCARE_DISPUTE'            // Litige garderie
  | 'MULTIPLE_NO_SHOWS'          // 3+ no-shows consécutifs
  | 'SUSPICIOUS_BOOKING_PATTERN' // Beaucoup d'annulations
  | 'LATE_CANCELLATION'          // Annulations tardives répétées
  | 'FRAUD'                      // Fraude détectée
  | 'ABUSE'                      // Abus du système
  | 'SUSPICIOUS_BEHAVIOR'        // Comportement suspect
  | 'OTHER';                     // Autre

// Types de flags pour les PROFESSIONNELS
export type ProFlagType =
  | 'PRO_HIGH_CANCELLATION'      // Pro annule > 15% des RDV
  | 'PRO_LOW_VERIFICATION'       // Pro vérifie < 50% des RDV (pas OTP/QR)
  | 'PRO_GHOST_COMPLETIONS'      // RDV complétés sans aucune vérification
  | 'PRO_UNRESPONSIVE'           // Pro ne répond pas aux demandes (RDV expirés)
  | 'PRO_LATE_CONFIRMATIONS'     // Pro met > 24h à confirmer
  | 'PRO_LOW_COMPLETION'         // Taux de complétion < 50%
  | 'PRO_SUSPICIOUS'             // Comportement suspect général
  | 'PRO_LATE_PAYMENT';          // Retard de paiement des commissions

export type FlagType = UserFlagType | ProFlagType;

export interface FlagUser {
  id: string;
  email: string;
  firstName: string | null;
  lastName: string | null;
  phone: string | null;
  trustStatus: string | null;
  role?: string;
}

export interface FlagWithUser extends AdminFlag {
  user: FlagUser | null;
  providerInfo?: {
    displayName: string;
    type: string;
  } | null;
}

// Seuils de détection
const THRESHOLDS = {
  PRO_CANCELLATION_RATE: 15,      // % max d'annulations par le pro
  PRO_VERIFICATION_RATE: 50,      // % min de vérification OTP/QR
  PRO_COMPLETION_RATE: 50,        // % min de complétion
  PRO_GHOST_COMPLETIONS: 3,       // Nombre max de RDV sans vérification
  PRO_LATE_PAYMENT_MONTHS: 1,     // Nombre de mois impayés avant flag
  USER_LATE_CANCELLATIONS: 3,     // Nombre d'annulations tardives avant flag
  USER_CANCELLATION_RATE: 40,     // % max d'annulations par l'utilisateur
  MIN_BOOKINGS_FOR_ANALYSIS: 5,   // Minimum de RDV pour analyser les stats
};

// Commission par défaut (même valeur que dans config/commission.ts)
const DEFAULT_COMMISSION_DA = 100;

@Injectable()
export class AdminFlagsService {
  constructor(private prisma: PrismaService) {}

  async list(query: {
    resolved?: boolean;
    type?: string;
    userId?: string;
    limit?: number;
  }): Promise<FlagWithUser[]> {
    const where: {
      resolved?: boolean;
      type?: string;
      userId?: string;
    } = {};

    if (query.resolved !== undefined) {
      where.resolved = query.resolved;
    }
    if (query.type) {
      where.type = query.type;
    }
    if (query.userId) {
      where.userId = query.userId;
    }

    const flags = await this.prisma.adminFlag.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: query.limit || 50,
    });

    // Get user info for each flag
    const userIds = [...new Set(flags.map((f: AdminFlag) => f.userId))];
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        trustStatus: true,
      },
    });

    const userMap = new Map(users.map((u: FlagUser) => [u.id, u]));

    return flags.map((flag: AdminFlag) => ({
      ...flag,
      user: userMap.get(flag.userId) || null,
    }));
  }

  async getStats() {
    const [total, active, resolved, byType] = await Promise.all([
      this.prisma.adminFlag.count(),
      this.prisma.adminFlag.count({ where: { resolved: false } }),
      this.prisma.adminFlag.count({ where: { resolved: true } }),
      this.prisma.adminFlag.groupBy({
        by: ['type'],
        _count: { type: true },
        where: { resolved: false },
      }),
    ]);

    return {
      total,
      active,
      resolved,
      byType: byType.map((t: { type: string; _count: { type: number } }) => ({
        type: t.type,
        count: t._count.type,
      })),
    };
  }

  async getById(id: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: flag.userId },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        trustStatus: true,
        noShowCount: true,
        restrictedUntil: true,
      },
    });

    // If bookingId, get booking info
    let booking = null;
    if (flag.bookingId) {
      booking = await this.prisma.daycareBooking.findUnique({
        where: { id: flag.bookingId },
        include: {
          pet: { select: { name: true, species: true } },
          provider: {
            include: {
              user: { select: { firstName: true, lastName: true } },
            },
          },
        },
      });
    }

    return {
      ...flag,
      user,
      booking,
    };
  }

  async create(dto: { userId: string; type: string; bookingId?: string; note?: string }) {
    return this.prisma.adminFlag.create({
      data: {
        userId: dto.userId,
        type: dto.type,
        bookingId: dto.bookingId,
        note: dto.note,
      },
    });
  }

  /**
   * Crée automatiquement un flag pour un événement suspect
   * Appelé par d'autres services (daycare, bookings, etc.)
   */
  async createAutoFlag(
    userId: string,
    type: FlagType,
    note: string,
    bookingId?: string,
  ) {
    // Vérifier si un flag similaire existe déjà (non résolu)
    const existingFlag = await this.prisma.adminFlag.findFirst({
      where: {
        userId,
        type,
        bookingId: bookingId || undefined,
        resolved: false,
      },
    });

    if (existingFlag) {
      // Ne pas dupliquer si la note contient déjà un message similaire
      // Extraire la partie principale du message (avant les chiffres spécifiques)
      const notePrefix = note.split(/\d/)[0].trim();
      if (existingFlag.note && existingFlag.note.includes(notePrefix)) {
        // Le message existe déjà, ne pas dupliquer
        return existingFlag;
      }

      // Mettre à jour la note existante
      return this.prisma.adminFlag.update({
        where: { id: existingFlag.id },
        data: {
          note: existingFlag.note ? `${existingFlag.note} | ${note}` : note,
        },
      });
    }

    return this.prisma.adminFlag.create({
      data: {
        userId,
        type,
        bookingId,
        note,
      },
    });
  }

  async resolve(id: string, note?: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    return this.prisma.adminFlag.update({
      where: { id },
      data: {
        resolved: true,
        note: note ? (flag.note ? `${flag.note} | RESOLVED: ${note}` : `RESOLVED: ${note}`) : flag.note,
      },
    });
  }

  async unresolve(id: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    return this.prisma.adminFlag.update({
      where: { id },
      data: {
        resolved: false,
        note: flag.note ? `${flag.note} | RÉOUVERT` : 'RÉOUVERT',
      },
    });
  }

  async delete(id: string) {
    const flag = await this.prisma.adminFlag.findUnique({
      where: { id },
    });

    if (!flag) {
      throw new NotFoundException('Flag not found');
    }

    await this.prisma.adminFlag.delete({ where: { id } });
    return { ok: true };
  }

  async getByUser(userId: string) {
    return this.prisma.adminFlag.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ============================================
  // AUTO-FLAGS INTELLIGENTS
  // ============================================

  /**
   * Analyse tous les pros et crée des flags pour ceux qui ont des comportements suspects
   * Peut être appelé manuellement ou par un cron job
   */
  async analyzeAllPros(): Promise<{ analyzed: number; flagged: number; flags: string[] }> {
    const providers = await this.prisma.providerProfile.findMany({
      where: { isApproved: true },
      include: { user: { select: { id: true, firstName: true, lastName: true, email: true } } },
    });

    let flagged = 0;
    const flagMessages: string[] = [];

    for (const provider of providers) {
      const result = await this.analyzeProBehavior(provider.userId);
      if (result.flagsCreated > 0) {
        flagged++;
        flagMessages.push(...result.messages);
      }
    }

    return { analyzed: providers.length, flagged, flags: flagMessages };
  }

  /**
   * Analyse le comportement d'un pro spécifique et crée des flags si nécessaire
   */
  async analyzeProBehavior(proUserId: string): Promise<{ flagsCreated: number; messages: string[] }> {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId: proUserId },
      include: { user: { select: { firstName: true, lastName: true } } },
    });

    if (!provider) return { flagsCreated: 0, messages: [] };

    const proName = `${provider.user.firstName || ''} ${provider.user.lastName || ''}`.trim() || provider.displayName || 'Pro';
    const messages: string[] = [];
    let flagsCreated = 0;

    // Récupérer les stats des 30 derniers jours
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const where = { providerId: provider.id, createdAt: { gte: thirtyDaysAgo } };

    const [total, completed, cancelled, cancelledByPro, expired, otpVerified, qrVerified, noConfirmation] = await Promise.all([
      this.prisma.booking.count({ where }),
      this.prisma.booking.count({ where: { ...where, status: 'COMPLETED' } }),
      this.prisma.booking.count({ where: { ...where, status: 'CANCELLED' } }),
      this.prisma.booking.count({ where: { ...where, status: 'CANCELLED', clientConfirmedAt: { not: null }, proConfirmedAt: null } }),
      this.prisma.booking.count({ where: { ...where, status: 'EXPIRED' } }),
      this.prisma.booking.count({ where: { ...where, status: 'COMPLETED', confirmationMethod: 'OTP' } }),
      this.prisma.booking.count({ where: { ...where, status: 'COMPLETED', confirmationMethod: 'QR_SCAN' } }),
      this.prisma.booking.count({ where: { ...where, status: 'COMPLETED', confirmationMethod: null } }),
    ]);

    // Pas assez de données pour analyser
    if (total < THRESHOLDS.MIN_BOOKINGS_FOR_ANALYSIS) {
      return { flagsCreated: 0, messages: [] };
    }

    // 1. Taux d'annulation par le pro trop élevé
    const proCancellationRate = Math.round((cancelledByPro / total) * 100);
    if (proCancellationRate > THRESHOLDS.PRO_CANCELLATION_RATE) {
      await this.createAutoFlag(
        proUserId,
        'PRO_HIGH_CANCELLATION',
        `${proName} annule ${proCancellationRate}% des RDV (${cancelledByPro}/${total}) - Seuil: ${THRESHOLDS.PRO_CANCELLATION_RATE}%`,
      );
      messages.push(`${proName}: Taux d'annulation élevé (${proCancellationRate}%)`);
      flagsCreated++;
    }

    // 2. Taux de vérification trop bas
    const verificationRate = completed > 0 ? Math.round(((otpVerified + qrVerified) / completed) * 100) : 100;
    if (completed >= 3 && verificationRate < THRESHOLDS.PRO_VERIFICATION_RATE) {
      await this.createAutoFlag(
        proUserId,
        'PRO_LOW_VERIFICATION',
        `${proName} ne vérifie que ${verificationRate}% des RDV (OTP/QR). ${noConfirmation} RDV sans vérification`,
      );
      messages.push(`${proName}: Faible taux de vérification (${verificationRate}%)`);
      flagsCreated++;
    }

    // 3. RDV complétés sans aucune vérification (fantômes)
    if (noConfirmation > THRESHOLDS.PRO_GHOST_COMPLETIONS) {
      await this.createAutoFlag(
        proUserId,
        'PRO_GHOST_COMPLETIONS',
        `${proName} a ${noConfirmation} RDV complétés sans vérification (OTP/QR) - Potentiellement fictifs`,
      );
      messages.push(`${proName}: ${noConfirmation} RDV fantômes`);
      flagsCreated++;
    }

    // 4. Pro ne répond pas (beaucoup de RDV expirés)
    const expiredRate = Math.round((expired / total) * 100);
    if (expired >= 3 && expiredRate > 20) {
      await this.createAutoFlag(
        proUserId,
        'PRO_UNRESPONSIVE',
        `${proName} laisse expirer ${expiredRate}% des RDV (${expired}/${total}) - Ne répond pas aux demandes`,
      );
      messages.push(`${proName}: ${expired} RDV expirés (${expiredRate}%)`);
      flagsCreated++;
    }

    // 5. Taux de complétion trop bas
    const completionRate = Math.round((completed / total) * 100);
    if (completionRate < THRESHOLDS.PRO_COMPLETION_RATE) {
      await this.createAutoFlag(
        proUserId,
        'PRO_LOW_COMPLETION',
        `${proName} n'a que ${completionRate}% de RDV complétés (${completed}/${total}) - Seuil: ${THRESHOLDS.PRO_COMPLETION_RATE}%`,
      );
      messages.push(`${proName}: Faible complétion (${completionRate}%)`);
      flagsCreated++;
    }

    // 6. Retard de paiement des commissions
    const unpaidMonths = await this.checkUnpaidMonths(provider.id, provider.vetCommissionDa ?? DEFAULT_COMMISSION_DA);
    if (unpaidMonths.count > THRESHOLDS.PRO_LATE_PAYMENT_MONTHS) {
      await this.createAutoFlag(
        proUserId,
        'PRO_LATE_PAYMENT',
        `${proName} a ${unpaidMonths.count} mois impayé(s) - Total dû: ${unpaidMonths.totalDue} DA, Collecté: ${unpaidMonths.totalCollected} DA`,
      );
      messages.push(`${proName}: ${unpaidMonths.count} mois de retard de paiement`);
      flagsCreated++;
    }

    return { flagsCreated, messages };
  }

  /**
   * Vérifie les mois impayés pour un provider
   */
  private async checkUnpaidMonths(providerId: string, commissionDa: number): Promise<{
    count: number;
    totalDue: number;
    totalCollected: number;
  }> {
    // Générer les 12 derniers mois
    const now = new Date();
    const months: string[] = [];
    for (let i = 0; i < 12; i++) {
      const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
      months.push(`${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}`);
    }

    let unpaidCount = 0;
    let totalDue = 0;
    let totalCollected = 0;

    for (const month of months) {
      const [year, monthNum] = month.split('-').map(Number);
      const from = new Date(Date.UTC(year, monthNum - 1, 1));
      const to = new Date(Date.UTC(monthNum === 12 ? year + 1 : year, monthNum === 12 ? 1 : monthNum, 1));

      // Compter les bookings complétés ce mois
      const completedCount = await this.prisma.booking.count({
        where: {
          providerId,
          status: 'COMPLETED',
          scheduledAt: { gte: from, lt: to },
        },
      });

      const dueDa = completedCount * commissionDa;
      if (dueDa === 0) continue; // Pas de commission due ce mois

      totalDue += dueDa;

      // Vérifier le montant collecté
      const collection = await this.prisma.adminCollection.findUnique({
        where: { providerId_month: { providerId, month } },
      });

      const collectedDa = collection ? Math.min(collection.amountDa, dueDa) : 0;
      totalCollected += collectedDa;

      // Si pas entièrement payé, c'est un mois impayé
      if (collectedDa < dueDa) {
        unpaidCount++;
      }
    }

    return { count: unpaidCount, totalDue, totalCollected };
  }

  /**
   * Analyse tous les utilisateurs et crée des flags pour comportements suspects
   */
  async analyzeAllUsers(): Promise<{ analyzed: number; flagged: number; flags: string[] }> {
    // Récupérer les utilisateurs avec des bookings récents
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const usersWithBookings = await this.prisma.user.findMany({
      where: {
        role: 'USER',
        OR: [
          { bookings: { some: { createdAt: { gte: thirtyDaysAgo } } } },
          { daycareBookings: { some: { createdAt: { gte: thirtyDaysAgo } } } },
        ],
      },
      select: { id: true, firstName: true, lastName: true, noShowCount: true },
    });

    let flagged = 0;
    const flagMessages: string[] = [];

    for (const user of usersWithBookings) {
      const result = await this.analyzeUserBehavior(user.id);
      if (result.flagsCreated > 0) {
        flagged++;
        flagMessages.push(...result.messages);
      }
    }

    return { analyzed: usersWithBookings.length, flagged, flags: flagMessages };
  }

  /**
   * Analyse le comportement d'un utilisateur spécifique
   */
  async analyzeUserBehavior(userId: string): Promise<{ flagsCreated: number; messages: string[] }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { firstName: true, lastName: true, noShowCount: true, email: true },
    });

    if (!user) return { flagsCreated: 0, messages: [] };

    const userName = `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.email || 'Utilisateur';
    const messages: string[] = [];
    let flagsCreated = 0;

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Stats véto
    const [totalVet, cancelledVet, lateCancelledVet] = await Promise.all([
      this.prisma.booking.count({ where: { userId, createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.booking.count({ where: { userId, status: 'CANCELLED', createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.booking.count({
        where: {
          userId,
          status: 'CANCELLED',
          createdAt: { gte: thirtyDaysAgo },
          // Annulation tardive = moins de 12h avant le RDV
          clientConfirmedAt: { not: null },
        },
      }),
    ]);

    // Stats garderie
    const [totalDaycare, cancelledDaycare, disputedDaycare] = await Promise.all([
      this.prisma.daycareBooking.count({ where: { userId, createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.daycareBooking.count({ where: { userId, status: 'CANCELLED', createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.daycareBooking.count({ where: { userId, status: 'DISPUTED', createdAt: { gte: thirtyDaysAgo } } }),
    ]);

    const total = totalVet + totalDaycare;
    const cancelled = cancelledVet + cancelledDaycare;

    if (total < 3) return { flagsCreated: 0, messages: [] };

    // 1. Multiple no-shows (basé sur noShowCount du user)
    if ((user.noShowCount || 0) >= 3) {
      await this.createAutoFlag(
        userId,
        'MULTIPLE_NO_SHOWS',
        `${userName} a ${user.noShowCount} no-shows consécutifs - Comportement récidiviste`,
      );
      messages.push(`${userName}: ${user.noShowCount} no-shows`);
      flagsCreated++;
    }

    // 2. Taux d'annulation trop élevé
    const cancellationRate = Math.round((cancelled / total) * 100);
    if (total >= 5 && cancellationRate > THRESHOLDS.USER_CANCELLATION_RATE) {
      await this.createAutoFlag(
        userId,
        'SUSPICIOUS_BOOKING_PATTERN',
        `${userName} annule ${cancellationRate}% de ses réservations (${cancelled}/${total}) - Pattern suspect`,
      );
      messages.push(`${userName}: Taux d'annulation élevé (${cancellationRate}%)`);
      flagsCreated++;
    }

    // 3. Annulations tardives répétées
    if (lateCancelledVet >= THRESHOLDS.USER_LATE_CANCELLATIONS) {
      await this.createAutoFlag(
        userId,
        'LATE_CANCELLATION',
        `${userName} a ${lateCancelledVet} annulations tardives (après confirmation) - Pénalise les pros`,
      );
      messages.push(`${userName}: ${lateCancelledVet} annulations tardives`);
      flagsCreated++;
    }

    // 4. Plusieurs litiges garderie
    if (disputedDaycare >= 2) {
      await this.createAutoFlag(
        userId,
        'DAYCARE_DISPUTE',
        `${userName} a ${disputedDaycare} litiges garderie ce mois - Comportement problématique`,
      );
      messages.push(`${userName}: ${disputedDaycare} litiges garderie`);
      flagsCreated++;
    }

    return { flagsCreated, messages };
  }

  /**
   * Endpoint pour lancer l'analyse complète (pros + users)
   */
  async runFullAnalysis(): Promise<{
    pros: { analyzed: number; flagged: number; flags: string[] };
    users: { analyzed: number; flagged: number; flags: string[] };
    totalNewFlags: number;
  }> {
    const [prosResult, usersResult] = await Promise.all([
      this.analyzeAllPros(),
      this.analyzeAllUsers(),
    ]);

    return {
      pros: prosResult,
      users: usersResult,
      totalNewFlags: prosResult.flagged + usersResult.flagged,
    };
  }

  /**
   * Récupère les flags groupés par type avec statistiques
   */
  async getDetailedStats() {
    const [basic, proFlags, userFlags, recentFlags] = await Promise.all([
      this.getStats(),
      // Flags pro actifs
      this.prisma.adminFlag.count({
        where: { type: { startsWith: 'PRO_' }, resolved: false },
      }),
      // Flags utilisateur actifs
      this.prisma.adminFlag.count({
        where: { type: { not: { startsWith: 'PRO_' } }, resolved: false },
      }),
      // Flags des 7 derniers jours
      this.prisma.adminFlag.count({
        where: { createdAt: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } },
      }),
    ]);

    return {
      ...basic,
      proFlags,
      userFlags,
      recentFlags,
      thresholds: THRESHOLDS,
    };
  }
}
