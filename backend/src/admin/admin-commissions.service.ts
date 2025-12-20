import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface CommissionData {
  vetCommissionDa: number;
  daycareHourlyCommissionDa: number;
  daycareDailyCommissionDa: number;
}

export interface ProviderCommission {
  providerId: string;
  userId: string;
  displayName: string;
  email: string;
  isApproved: boolean;
  vetCommissionDa: number;
  daycareHourlyCommissionDa: number;
  daycareDailyCommissionDa: number;
}

@Injectable()
export class AdminCommissionsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Liste tous les professionnels avec leurs commissions
   */
  async listProviderCommissions(filters?: {
    q?: string;
    isApproved?: boolean;
  }): Promise<ProviderCommission[]> {
    const where: any = {};

    if (filters?.isApproved !== undefined) {
      where.isApproved = filters.isApproved;
    }

    if (filters?.q) {
      const search = filters.q.toLowerCase();
      where.OR = [
        { displayName: { contains: search, mode: 'insensitive' } },
        { user: { email: { contains: search, mode: 'insensitive' } } },
        { user: { firstName: { contains: search, mode: 'insensitive' } } },
        { user: { lastName: { contains: search, mode: 'insensitive' } } },
      ];
    }

    const providers = await this.prisma.providerProfile.findMany({
      where,
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
          },
        },
      },
      orderBy: { displayName: 'asc' },
    });

    return providers.map((p) => ({
      providerId: p.id,
      userId: p.userId,
      displayName: p.displayName,
      email: p.user.email,
      isApproved: p.isApproved,
      vetCommissionDa: p.vetCommissionDa,
      daycareHourlyCommissionDa: p.daycareHourlyCommissionDa,
      daycareDailyCommissionDa: p.daycareDailyCommissionDa,
    }));
  }

  /**
   * Récupère les commissions d'un professionnel spécifique
   */
  async getProviderCommission(providerId: string): Promise<ProviderCommission> {
    const provider = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
          },
        },
      },
    });

    if (!provider) {
      throw new NotFoundException(`Provider ${providerId} not found`);
    }

    return {
      providerId: provider.id,
      userId: provider.userId,
      displayName: provider.displayName,
      email: provider.user.email,
      isApproved: provider.isApproved,
      vetCommissionDa: provider.vetCommissionDa,
      daycareHourlyCommissionDa: provider.daycareHourlyCommissionDa,
      daycareDailyCommissionDa: provider.daycareDailyCommissionDa,
    };
  }

  /**
   * Met à jour les commissions d'un professionnel
   */
  async updateProviderCommission(
    providerId: string,
    data: Partial<CommissionData>,
  ): Promise<ProviderCommission> {
    // Vérifier que le provider existe
    const existing = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
    });

    if (!existing) {
      throw new NotFoundException(`Provider ${providerId} not found`);
    }

    // Préparer les données à mettre à jour (seulement les champs fournis)
    const updateData: any = {};
    if (data.vetCommissionDa !== undefined) {
      updateData.vetCommissionDa = Math.max(0, Math.floor(data.vetCommissionDa));
    }
    if (data.daycareHourlyCommissionDa !== undefined) {
      updateData.daycareHourlyCommissionDa = Math.max(0, Math.floor(data.daycareHourlyCommissionDa));
    }
    if (data.daycareDailyCommissionDa !== undefined) {
      updateData.daycareDailyCommissionDa = Math.max(0, Math.floor(data.daycareDailyCommissionDa));
    }

    const updated = await this.prisma.providerProfile.update({
      where: { id: providerId },
      data: updateData,
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
          },
        },
      },
    });

    return {
      providerId: updated.id,
      userId: updated.userId,
      displayName: updated.displayName,
      email: updated.user.email,
      isApproved: updated.isApproved,
      vetCommissionDa: updated.vetCommissionDa,
      daycareHourlyCommissionDa: updated.daycareHourlyCommissionDa,
      daycareDailyCommissionDa: updated.daycareDailyCommissionDa,
    };
  }

  /**
   * Réinitialise les commissions d'un professionnel aux valeurs par défaut
   */
  async resetProviderCommission(providerId: string): Promise<ProviderCommission> {
    return this.updateProviderCommission(providerId, {
      vetCommissionDa: 100,
      daycareHourlyCommissionDa: 10,
      daycareDailyCommissionDa: 100,
    });
  }
}
