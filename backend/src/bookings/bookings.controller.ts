// src/bookings/bookings.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { BookingStatus } from '@prisma/client';
import { DateTime } from 'luxon';

import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';

import { BookingsService } from './bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability/availability.service';

@ApiTags('bookings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'bookings', version: '1' })
export class BookingsController {
  constructor(
    private svc: BookingsService,
    private prisma: PrismaService,
    private availability: AvailabilityService,
  ) {}

  // ---------- utils ----------
  private parseWhen(raw: any): Date | null {
    const ok = (d: Date) => d instanceof Date && !Number.isNaN(d.valueOf());
    if (raw == null) return null;

    if (raw instanceof Date) return ok(raw) ? raw : null;
    if (typeof raw === 'number') { const d = new Date(raw); return ok(d) ? d : null; }
    if (Array.isArray(raw)) return this.parseWhen(raw[0]);

    if (typeof raw === 'object') {
      if ('scheduledAt' in raw) return this.parseWhen((raw as any).scheduledAt);
      if ('value' in raw) return this.parseWhen((raw as any).value);
      return null;
    }

    if (typeof raw === 'string') {
      const s0 = raw.trim().replace(/^"+|"+$/g, '');
      if (!s0) return null;

      // ISO/Date natif
      let d = new Date(s0);
      if (ok(d)) return d;

      // Luxon fallback (ISO/RFC/HTTP/SQL + formats usuels)
      let dt = DateTime.fromISO(s0, { setZone: true });
      if (dt.isValid) return dt.toUTC().toJSDate();

      dt = DateTime.fromRFC2822(s0, { setZone: true });
      if (dt.isValid) return dt.toUTC().toJSDate();

      dt = DateTime.fromHTTP(s0, { setZone: true });
      if (dt.isValid) return dt.toUTC().toJSDate();

      dt = DateTime.fromSQL(s0, { setZone: true });
      if (dt.isValid) return dt.toUTC().toJSDate();

      const formats = [
        'dd/MM/yyyy HH:mm', 'd/M/yyyy HH:mm', 'dd-MM-yyyy HH:mm',
        'yyyy-MM-dd HH:mm', "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ssZZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZZ",
      ];
      for (const f of formats) {
        dt = DateTime.fromFormat(s0, f, { setZone: true });
        if (dt.isValid) return dt.toUTC().toJSDate();
      }

      // Unix epoch
      const n = Number(s0);
      if (!Number.isNaN(n)) {
        const ms = s0.length === 10 ? n * 1000 : n;
        d = new Date(ms);
        if (ok(d)) return d;
      }
    }
    return null;
  }

  // ---------- endpoints ----------

  // ========= ADMIN =========

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin')
  async adminList(
    @Query('providerId') providerId?: string,
    @Query('status') status?: BookingStatus | 'ALL',
    // accepte plusieurs clés: from | fromIso | start | scheduledFrom
    @Query('from') fromA?: string,
    @Query('fromIso') fromB?: string,
    @Query('start') fromC?: string,
    @Query('scheduledFrom') fromD?: string,
    // idem pour "to"
    @Query('to') toA?: string,
    @Query('toIso') toB?: string,
    @Query('end') toC?: string,
    @Query('scheduledTo') toD?: string,
    @Query('limit') limitStr?: string,
    @Query('offset') offsetStr?: string,
  ) {
    const fromIso = fromA ?? fromB ?? fromC ?? fromD;
    const toIso   = toA   ?? toB   ?? toC   ?? toD;
    const from = fromIso ? this.parseWhen(fromIso) ?? undefined : undefined;
    const to   = toIso   ? this.parseWhen(toIso)   ?? undefined : undefined;
    const limit = Number(limitStr ?? 50);
    const offset = Number(offsetStr ?? 0);
    return this.svc.adminList({ providerId, status: status ?? 'ALL', from, to, limit, offset });
  }

  // alias fallback: GET /bookings (utilisé par le front en dernier recours)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get()
  async adminListAlias(
    @Query('providerId') providerId?: string,
    @Query('status') status?: BookingStatus | 'ALL',
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('limit') limitStr?: string,
    @Query('offset') offsetStr?: string,
  ) {
    const f = from ? this.parseWhen(from) ?? undefined : undefined;
    const t = to   ? this.parseWhen(to)   ?? undefined : undefined;
    const limit = Number(limitStr ?? 50);
    const offset = Number(offsetStr ?? 0);
    return this.svc.adminList({ providerId, status: status ?? 'ALL', from: f, to: t, limit, offset });
  }

  // résumé commissions mois courant: utilisé par l’admin pour aller vite
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/commissions/summary')
  adminCommissionsSummary() {
    return this.svc.adminCommissionsSummaryCurrentMonth();
  }

  /** Client: reprogrammer un rendez-vous */
  @Patch(':id/reschedule')
  async reschedule(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { scheduledAt: any },
  ) {
    if (!body?.scheduledAt) throw new BadRequestException('scheduledAt is required');
    const when = this.parseWhen(body.scheduledAt);
    if (!when) throw new BadRequestException('Invalid scheduledAt');
    return this.svc.reschedule(req.user.sub, id, when);
  }

  /** Client: mes réservations */
  @Get('mine')
  mine(@Req() req: any) {
    return this.svc.listMine(req.user.sub);
  }

  /** Client: créer une réservation */
  @Post()
  async create(@Req() req: any, @Body() body: { serviceId: string; scheduledAt: any }) {
    if (!body?.serviceId || body?.scheduledAt == null) {
      throw new BadRequestException('serviceId and scheduledAt are required');
    }

    const when = this.parseWhen(body.scheduledAt);
    if (!when) throw new BadRequestException('Invalid scheduledAt');

    // transaction + re-check
    return this.prisma.$transaction(async (tx) => {
      const service = await tx.service.findUnique({ where: { id: body.serviceId } });
      if (!service) throw new NotFoundException('Service not found');

      // Re-vérifie que le slot est dispo (weekly + time-offs + bookings), côté serveur
      const ok = await this.availability.isSlotFree(service.providerId, when, service.durationMin);
      if (!ok) throw new BadRequestException('Slot not available');

      return tx.booking.create({
        data: {
          userId: req.user.sub,
          serviceId: service.id,
          providerId: service.providerId,
          scheduledAt: when, // UTC côté DB
          status: 'PENDING',
        },
      });
    }, { isolationLevel: 'Serializable' });
  }

  /** Client: changer le statut de SA résa (ex. annuler) */
  @Patch(':id/status')
  updateStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { status: BookingStatus },
  ) {
    return this.svc.updateStatus(req.user.sub, id, body.status);
  }

  // ========= ADMIN: Stats / Historique / Collecte =========
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/stats')
  async adminStats(
    @Query('providerId') providerId?: string,
    @Query('from') fromQ?: string,
    @Query('to') toQ?: string,
  ) {
    const from = fromQ ? this.parseWhen(fromQ) ?? undefined : undefined;
    const to   = toQ   ? this.parseWhen(toQ)   ?? undefined : undefined;
    return this.svc.adminStatsPeriod({ from, to, providerId });
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/history/monthly')
  adminHistoryMonthly(
    @Query('months') months?: string,
    @Query('providerId') providerId?: string,
  ) {
    const n = Number(months ?? 12);
    return this.svc.adminHistoryMonthly({ months: Number.isFinite(n) ? n : 12, providerId });
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/collect-month')
  collectMonth(@Body() body: { month: string; providerId?: string }) {
    if (!body?.month || !/^\d{4}-\d{2}$/.test(body.month)) {
      throw new BadRequestException('month must be YYYY-MM');
    }
    return this.svc.adminCollectMonth(body.month, body.providerId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/uncollect-month')
  uncollectMonth(@Body() body: { month: string; providerId?: string }) {
    if (!body?.month || !/^\d{4}-\d{2}$/.test(body.month)) {
      throw new BadRequestException('month must be YYYY-MM');
    }
    return this.svc.adminUncollectMonth(body.month, body.providerId);
  }

  /** PRO/ADMIN: changer le statut d’une résa qui m’appartient */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Patch(':id/provider-status')
  async providerStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { status: BookingStatus },
  ) {
    const allowed: BookingStatus[] = ['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'] as any;
    if (!body?.status || !allowed.includes(body.status)) {
      throw new BadRequestException('Invalid status');
    }
    return this.svc.providerSetStatus(req.user.sub, id, body.status);
  }

  /** PRO: agenda (enrichi, sans email) */
  @Get('provider/me')
  agenda(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('includeCancelled') includeCancelled?: string, // 'true' | 'false' | undefined
  ) {
    const f = from ? this.parseWhen(from) : undefined;
    const t = to ? this.parseWhen(to) : undefined;

    // défaut = true (on montre les annulés pour éviter l'effet “il a disparu”)
    const inc =
      includeCancelled == null
        ? true
        : /^(1|true|yes)$/i.test(includeCancelled);

    return this.svc.providerAgenda(req.user.sub, f ?? undefined, t ?? undefined, inc);
  }

  /** PRO: mes gains (totaux + lignes) */
  @Get('provider/me/earnings')
  myEarnings(@Req() req: any, @Query('month') month?: string) {
    return this.svc.myEarnings(req.user.sub, month);
  }

  /** PRO: historique mensuel normalisé (pour l’écran Pro) */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO','ADMIN')
  @Get('provider/me/history/monthly')
  providerHistoryMonthly(@Req() req: any, @Query('months') months?: string) {
    const n = Number(months ?? 12);
    return this.svc.providerHistoryMonthly(
      req.user.sub,
      Number.isFinite(n) ? n : 12,
    );
  }
}
