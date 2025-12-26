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

  // Stats globales tous providers confondus
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/global-stats')
  async adminGlobalStats(@Query('months') months = '12') {
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.globalStats(m);
  }

  // ---------- ADMIN PETSHOP ----------
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/petshop/history-monthly')
  async adminPetshopHistoryMonthly(
    @Query('months') months = '12',
    @Query('providerId') providerId?: string,
  ) {
    if (!providerId) return [];
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.petshopHistoryMonthly(providerId, m);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/petshop/collect-month')
  async adminPetshopCollectMonth(@Body() dto: { providerId: string; month: string; note?: string; amount?: number }) {
    return this.earnings.petshopCollectMonth(dto.providerId, dto.month, dto.note, dto.amount);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/petshop/uncollect-month')
  async adminPetshopUncollectMonth(@Body() dto: { providerId: string; month: string }) {
    return this.earnings.petshopUncollectMonth(dto.providerId, dto.month);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/petshop/add-collection')
  async adminPetshopAddCollection(@Body() dto: { providerId: string; month: string; amount: number; note?: string }) {
    return this.earnings.petshopAddCollection(dto.providerId, dto.month, dto.amount, dto.note);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/petshop/subtract-collection')
  async adminPetshopSubtractCollection(@Body() dto: { providerId: string; month: string; amount: number; note?: string }) {
    return this.earnings.petshopSubtractCollection(dto.providerId, dto.month, dto.amount, dto.note);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/petshop/global-stats')
  async adminPetshopGlobalStats(@Query('months') months = '12') {
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.petshopGlobalStats(m);
  }

  // ---------- ADMIN DAYCARE ----------
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/daycare/history-monthly')
  async adminDaycareHistoryMonthly(
    @Query('months') months = '12',
    @Query('providerId') providerId?: string,
  ) {
    if (!providerId) return [];
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.daycareHistoryMonthly(providerId, m);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/daycare/collect-month')
  async adminDaycareCollectMonth(@Body() dto: { providerId: string; month: string; note?: string; amount?: number }) {
    return this.earnings.daycareCollectMonth(dto.providerId, dto.month, dto.note, dto.amount);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/daycare/uncollect-month')
  async adminDaycareUncollectMonth(@Body() dto: { providerId: string; month: string }) {
    return this.earnings.daycareUncollectMonth(dto.providerId, dto.month);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/daycare/add-collection')
  async adminDaycareAddCollection(@Body() dto: { providerId: string; month: string; amount: number; note?: string }) {
    return this.earnings.daycareAddCollection(dto.providerId, dto.month, dto.amount, dto.note);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/daycare/subtract-collection')
  async adminDaycareSubtractCollection(@Body() dto: { providerId: string; month: string; amount: number; note?: string }) {
    return this.earnings.daycareSubtractCollection(dto.providerId, dto.month, dto.amount, dto.note);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/daycare/global-stats')
  async adminDaycareGlobalStats(@Query('months') months = '12') {
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.daycareGlobalStats(m);
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

  // ---------- PRO PETSHOP (ME) ----------
  @UseGuards(JwtAuthGuard)
  @Get('me/petshop/current-month')
  async myPetshopCurrentMonth(@Req() req: any) {
    const userId = req.user?.sub ?? req.user?.id;
    const me = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!me) return null;
    const now = new Date();
    const ym = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    return this.earnings.petshopMonthRow(me.id, ym);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/petshop/history-monthly')
  async myPetshopHistoryMonthly(@Req() req: any, @Query('months') months = '12') {
    const userId = req.user?.sub ?? req.user?.id;
    const me = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!me) return [];
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.petshopHistoryMonthly(me.id, m);
  }

  // ---------- PRO DAYCARE (ME) ----------
  @UseGuards(JwtAuthGuard)
  @Get('me/daycare/current-month')
  async myDaycareCurrentMonth(@Req() req: any) {
    const userId = req.user?.sub ?? req.user?.id;
    const me = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!me) return null;
    const now = new Date();
    const ym = `${now.getUTCFullYear()}-${(now.getUTCMonth() + 1).toString().padStart(2, '0')}`;
    return this.earnings.daycareMonthRow(me.id, ym);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/daycare/history-monthly')
  async myDaycareHistoryMonthly(@Req() req: any, @Query('months') months = '12') {
    const userId = req.user?.sub ?? req.user?.id;
    const me = await this.prisma.providerProfile.findFirst({ where: { userId } });
    if (!me) return [];
    const m = Math.max(1, Math.min(120, parseInt(months, 10) || 12));
    return this.earnings.daycareHistoryMonthly(me.id, m);
  }
}
