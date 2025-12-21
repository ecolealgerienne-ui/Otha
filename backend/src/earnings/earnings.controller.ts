// src/earnings/earnings.controller.ts
import { Controller, Get, Post, Body, Query, UseGuards, Req } from '@nestjs/common';
import { EarningsService } from './earnings.service';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller({ path: 'earnings', version: '1' })
export class EarningsController {
  constructor(
    private earnings: EarningsService,
    private prisma: PrismaService,
  ) {}

  // ---------- ADMIN ----------
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/history-monthly')
  async adminHistoryMonthly(
    @Query('months') months = '12',
    @Query('providerId') providerId?: string,
  ) {
    if (!providerId) return [];
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.historyMonthly(providerId, m);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/collect-month')
  async adminCollectMonth(@Body() dto: { providerId: string; month: string; note?: string; amount?: number }) {
    return this.earnings.collectMonth(dto.providerId, dto.month, dto.note, dto.amount);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/uncollect-month')
  async adminUncollectMonth(@Body() dto: { providerId: string; month: string }) {
    return this.earnings.uncollectMonth(dto.providerId, dto.month);
  }

  // Ajouter un montant à la collecte
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/add-collection')
  async adminAddCollection(@Body() dto: { providerId: string; month: string; amount: number; note?: string }) {
    return this.earnings.addToCollection(dto.providerId, dto.month, dto.amount, dto.note);
  }

  // Retirer un montant de la collecte
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/subtract-collection')
  async adminSubtractCollection(@Body() dto: { providerId: string; month: string; amount: number; note?: string }) {
    return this.earnings.subtractFromCollection(dto.providerId, dto.month, dto.amount, dto.note);
  }

  // ---------- PRO (ME) ----------
  @UseGuards(JwtAuthGuard)
  @Get('me/history-monthly')
  async myHistoryMonthly(@Req() req: any, @Query('months') months = '12') {
    const userId = req.user?.sub ?? req.user?.id;
    const me = await this.prisma.providerProfile.findFirst({ where: { userId } }); // <-- model correct
    if (!me) return [];
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.historyMonthly(me.id, m);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/earnings')
  async myEarnings(@Req() req: any, @Query('month') month: string) {
    const userId = req.user?.sub ?? req.user?.id;
    const me = await this.prisma.providerProfile.findFirst({ where: { userId } }); // <-- model correct
    if (!me || !month) return {};
    return this.earnings.earningsForMonth(me.id, month);
  }
}
