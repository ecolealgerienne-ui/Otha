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

// Caractères pour le code de référence (sans 0/O, 1/I/L pour éviter confusion)
const REF_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/** Génère un code de référence unique (ex: VGC-A2B3C4) */
function generateReferenceCode(): string {
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += REF_CHARS.charAt(Math.floor(Math.random() * REF_CHARS.length));
  }
  return `VGC-${code}`;
}

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
  async create(@Req() req: any, @Body() body: { serviceId: string; scheduledAt: any; petIds?: string[] }) {
    if (!body?.serviceId || body?.scheduledAt == null) {
      throw new BadRequestException('serviceId and scheduledAt are required');
    }

    // ✅ TRUST SYSTEM: Vérifier si l'utilisateur peut réserver
    const trustCheck = await this.svc.checkUserCanBook(req.user.sub);
    if (!trustCheck.canBook) {
      throw new ForbiddenException(trustCheck.reason || 'Vous ne pouvez pas réserver pour le moment');
    }

    const when = this.parseWhen(body.scheduledAt);
    if (!when) throw new BadRequestException('Invalid scheduledAt');

    // Valider les petIds si fournis
    const petIds = Array.isArray(body.petIds) ? body.petIds.filter(id => typeof id === 'string' && id.length > 0) : [];

    // transaction + re-check
    return this.prisma.$transaction(async (tx) => {
      const service = await tx.service.findUnique({ where: { id: body.serviceId } });
      if (!service) throw new NotFoundException('Service not found');

      // Re-vérifie que le slot est dispo (weekly + time-offs + bookings), côté serveur
      const ok = await this.availability.isSlotFree(service.providerId, when, service.durationMin);
      if (!ok) throw new BadRequestException('Slot not available');

      // Générer un code de référence unique (avec retry si collision)
      let referenceCode = generateReferenceCode();
      let attempts = 0;
      while (attempts < 5) {
        const existing = await tx.booking.findUnique({ where: { referenceCode } });
        if (!existing) break;
        referenceCode = generateReferenceCode();
        attempts++;
      }

      return tx.booking.create({
        data: {
          userId: req.user.sub,
          serviceId: service.id,
          providerId: service.providerId,
          scheduledAt: when, // UTC côté DB
          status: 'PENDING',
          petIds, // IDs des animaux concernés
          referenceCode, // Code de référence unique (ex: VGC-A2B3C4)
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

  /**
   * ADMIN: Statistiques de traçabilité par provider
   * Calcule les taux d'annulation, confirmation, vérification OTP/QR
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/traceability')
  adminTraceability(
    @Query('from') fromQ?: string,
    @Query('to') toQ?: string,
  ) {
    const from = fromQ ? this.parseWhen(fromQ) ?? undefined : undefined;
    const to = toQ ? this.parseWhen(toQ) ?? undefined : undefined;
    return this.svc.adminTraceabilityStats({ from, to });
  }

  /** PRO/ADMIN: changer le statut d'une résa qui m'appartient */
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

  /** PRO: historique mensuel normalisé (pour l'écran Pro) */
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

  // ==================== NOUVEAU: Endpoints Système de Confirmation ====================

  /**
   * Chercher un booking actif pour un pet (pour le scan QR vet)
   * GET /bookings/active-for-pet/:petId
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Get('active-for-pet/:petId')
  findActiveBookingForPet(@Param('petId') petId: string) {
    return this.svc.findActiveBookingForPet(petId);
  }

  // ==================== CONFIRMATION PAR CODE DE RÉFÉRENCE ====================
  // ⚠️ IMPORTANT: Cette route DOIT être AVANT les routes :id pour éviter les conflits

  /**
   * PRO: Confirmer un booking par son code de référence (VGC-XXXXXX)
   * POST /bookings/confirm-by-reference
   * @body referenceCode - Le code de référence (ex: VGC-A2B3C4)
   * Retourne le booking confirmé avec les infos du pet pour afficher le carnet de santé
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Post('confirm-by-reference')
  confirmByReferenceCode(
    @Req() req: any,
    @Body() body: { referenceCode: string },
  ) {
    if (!body?.referenceCode || typeof body.referenceCode !== 'string') {
      throw new BadRequestException('referenceCode is required');
    }
    return this.svc.confirmByReferenceCode(req.user.sub, body.referenceCode.toUpperCase().trim());
  }

  /**
   * PRO confirme un booking (après scan QR ou manuellement)
   * POST /bookings/:id/pro-confirm
   * @body method - 'QR_SCAN' | 'SIMPLE' | 'AUTO' (défaut: AUTO)
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Post(':id/pro-confirm')
  proConfirmBooking(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body?: { method?: string },
  ) {
    const method = body?.method || 'AUTO';
    return this.svc.proConfirmBooking(req.user.sub, id, method);
  }

  /**
   * CLIENT demande confirmation (via popup avis)
   * POST /bookings/:id/client-confirm
   */
  @Post(':id/client-confirm')
  clientRequestConfirmation(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { rating: number; comment?: string },
  ) {
    if (!body?.rating || body.rating < 1 || body.rating > 5) {
      throw new BadRequestException('rating must be between 1 and 5');
    }
    return this.svc.clientRequestConfirmation(
      req.user.sub,
      id,
      body.rating,
      body.comment,
    );
  }

  /**
   * CLIENT dit "je n'y suis pas allé"
   * POST /bookings/:id/client-cancel
   */
  @Post(':id/client-cancel')
  clientCancelBooking(@Req() req: any, @Param('id') id: string) {
    return this.svc.clientCancelBooking(req.user.sub, id);
  }

  /**
   * PRO valide ou refuse la confirmation client
   * POST /bookings/:id/pro-validate
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Post(':id/pro-validate')
  proValidateClientConfirmation(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { approved: boolean },
  ) {
    if (typeof body?.approved !== 'boolean') {
      throw new BadRequestException('approved must be a boolean');
    }
    return this.svc.proValidateClientConfirmation(req.user.sub, id, body.approved);
  }

  /**
   * PRO: liste des bookings en attente de validation
   * GET /bookings/provider/me/pending-validations
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Get('provider/me/pending-validations')
  getPendingValidations(@Req() req: any) {
    return this.svc.getPendingValidations(req.user.sub);
  }

  /**
   * ADMIN/CRON: Cron job pour checker les grace periods
   * POST /bookings/admin/check-grace-periods
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/check-grace-periods')
  checkGracePeriods() {
    return this.svc.checkGracePeriods();
  }

  // ==================== SYSTÈME OTP DE CONFIRMATION ====================

  /**
   * CLIENT: Récupérer son code OTP (le génère si nécessaire)
   * GET /bookings/:id/otp
   */
  @Get(':id/otp')
  getBookingOtp(@Req() req: any, @Param('id') id: string) {
    return this.svc.getBookingOtp(req.user.sub, id);
  }

  /**
   * CLIENT: Générer un nouveau code OTP
   * POST /bookings/:id/otp/generate
   */
  @Post(':id/otp/generate')
  generateBookingOtp(@Req() req: any, @Param('id') id: string) {
    return this.svc.generateBookingOtp(req.user.sub, id);
  }

  /**
   * PRO: Vérifier le code OTP donné par le client
   * POST /bookings/:id/otp/verify
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Post(':id/otp/verify')
  verifyBookingOtp(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { otp: string },
  ) {
    if (!body?.otp || typeof body.otp !== 'string') {
      throw new BadRequestException('otp is required');
    }
    return this.svc.verifyBookingOtpByPro(req.user.sub, id, body.otp);
  }

  // ==================== CHECK-IN GÉOLOCALISÉ ====================

  /**
   * CLIENT: Vérifier s'il est proche du cabinet (pour afficher page confirmation)
   * POST /bookings/:id/check-proximity
   */
  @Post(':id/check-proximity')
  checkProximity(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { lat: number; lng: number },
  ) {
    if (typeof body?.lat !== 'number' || typeof body?.lng !== 'number') {
      throw new BadRequestException('lat and lng are required');
    }
    return this.svc.checkProximity(req.user.sub, id, body.lat, body.lng);
  }

  /**
   * CLIENT: Faire check-in (enregistre position GPS)
   * POST /bookings/:id/checkin
   */
  @Post(':id/checkin')
  clientCheckin(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { lat: number; lng: number },
  ) {
    if (typeof body?.lat !== 'number' || typeof body?.lng !== 'number') {
      throw new BadRequestException('lat and lng are required');
    }
    return this.svc.clientCheckin(req.user.sub, id, body.lat, body.lng);
  }

  /**
   * CLIENT: Confirmer avec une méthode spécifique
   * POST /bookings/:id/confirm-with-method
   */
  @Post(':id/confirm-with-method')
  clientConfirmWithMethod(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { method: 'SIMPLE' | 'OTP' | 'QR_SCAN'; rating?: number; comment?: string },
  ) {
    const validMethods = ['SIMPLE', 'OTP', 'QR_SCAN'];
    if (!body?.method || !validMethods.includes(body.method)) {
      throw new BadRequestException('method must be SIMPLE, OTP, or QR_SCAN');
    }
    return this.svc.clientConfirmWithMethod(
      req.user.sub,
      id,
      body.method,
      body.rating,
      body.comment,
    );
  }

  // ==================== SYSTÈME DE CONFIANCE (ANTI-TROLL) ====================

  /**
   * CLIENT: Vérifier si l'utilisateur peut réserver
   * GET /bookings/me/trust-status
   * Retourne { canBook, reason?, trustStatus, isFirstBooking?, restrictedUntil? }
   */
  @Get('me/trust-status')
  checkUserCanBook(@Req() req: any) {
    return this.svc.checkUserCanBook(req.user.sub);
  }

  /**
   * CLIENT: Vérifier si l'utilisateur peut annuler un RDV
   * GET /bookings/:id/can-cancel
   * Retourne { canCancel, reason?, isNoShow? }
   */
  @Get(':id/can-cancel')
  checkUserCanCancel(@Req() req: any, @Param('id') id: string) {
    return this.svc.checkUserCanCancel(req.user.sub, id);
  }

  /**
   * CLIENT: Vérifier si l'utilisateur peut modifier un RDV
   * GET /bookings/:id/can-reschedule
   * Retourne { canReschedule, reason? }
   */
  @Get(':id/can-reschedule')
  checkUserCanReschedule(@Req() req: any, @Param('id') id: string) {
    return this.svc.checkUserCanReschedule(req.user.sub, id);
  }

  /**
   * PRO: Récupérer les infos de confiance d'un client
   * GET /bookings/user/:userId/trust-info
   * Retourne { trustStatus, isFirstBooking, noShowCount, totalCompletedBookings }
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Get('user/:userId/trust-info')
  getUserTrustInfo(@Param('userId') userId: string) {
    return this.svc.getUserTrustInfo(userId);
  }
}
