// src/providers/providers.controller.ts
import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { ProvidersService } from './providers.service';
import { AvailabilityService } from '../availability/availability.service';

import { JwtAuthGuard } from '../auth/guards/jwt.guard';

// Rôles
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';

@ApiTags('providers')
@Controller({ path: 'providers', version: '1' })
export class ProvidersController {
  constructor(
    private providers: ProvidersService,
    private availability: AvailabilityService,
  ) {}

  /** -------- Helpers -------- */
  private getUserIdFromReq(req: any): string {
    const id = req?.user?.sub ?? req?.user?.id;
    if (!id) throw new BadRequestException('Missing user id');
    return String(id);
  }

  /** -------- Public: nearby -------- */
  @Get('nearby')
  async getNearby(
    @Query('lat') latStr?: string,
    @Query('lng') lngStr?: string,
    @Query('radiusKm') rStr?: string,
    @Query('limit') lStr?: string,
    @Query('offset') oStr?: string,
    @Query('status') statusRaw?: string, // 'approved' | 'pending' | 'all'
  ) {
    const lat = Number(latStr);
    const lng = Number(lngStr);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new BadRequestException('lat/lng are required and must be numbers');
    }

    const radiusKm = Number.isFinite(Number(rStr)) ? Number(rStr) : 25;
    let limit = Number.isFinite(Number(lStr)) ? Number(lStr) : 20;
    let offset = Number.isFinite(Number(oStr)) ? Number(oStr) : 0;

    if (limit < 1) limit = 1;
    if (limit > 5000) limit = 5000;
    if (offset < 0) offset = 0;

    const s = (statusRaw ?? 'approved').toString().toLowerCase();
    const status: 'approved' | 'pending' | 'all' =
      s === 'all' ? 'all' : s === 'pending' ? 'pending' : 'approved';

    return this.providers.nearby(lat, lng, radiusKm, limit, offset, status);
  }

  /** -------- Auth: mon provider + mes services -------- */

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async myProvider(@Req() req: any) {
    const userId = this.getUserIdFromReq(req);
    return this.providers.myProvider(userId);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('me')
  async upsertMy(@Req() req: any, @Body() dto: any) {
    const userId = this.getUserIdFromReq(req);

    // Hotfix: propage dto.mapsUrl → specialties.mapsUrl si présent
    if (dto && typeof dto.mapsUrl === 'string' && dto.mapsUrl.trim().length > 0) {
      dto.specialties = { ...(dto.specialties ?? {}), mapsUrl: dto.mapsUrl.trim() };
    }

    await this.providers.upsertMyProvider(userId, dto);

    // Toujours renvoyer l’état DB normalisé
    return this.providers.myProvider(userId);
  }

  // ---- Services du pro connecté
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me/services')
  async myServices(@Req() req: any) {
    const userId = this.getUserIdFromReq(req);
    return this.providers.myServices(userId);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('me/services')
  async createMyService(@Req() req: any, @Body() dto: any) {
    const userId = this.getUserIdFromReq(req);
    return this.providers.createMyService(userId, dto);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch('me/services/:id')
  async updateMyService(@Req() req: any, @Param('id') id: string, @Body() dto: any) {
    const userId = this.getUserIdFromReq(req);
    return this.providers.updateMyService(userId, id, dto);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Delete('me/services/:id')
  async deleteMyService(@Req() req: any, @Param('id') id: string) {
    const userId = this.getUserIdFromReq(req);
    return this.providers.deleteMyService(userId, id);
  }

  // ---- Disponibilités hebdo
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me/availability')
  async getMyWeekly(@Req() req: any) {
    const userId = this.getUserIdFromReq(req);
    return this.availability.getWeeklyForUser(userId);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('me/availability')
  async setMyWeekly(@Req() req: any, @Body() body: any) {
    const userId = this.getUserIdFromReq(req);

    const entries: any[] = Array.isArray(body)
      ? body
      : (body?.entries ?? body?.items ?? []);

    const timezone: string | undefined =
      body?.timezone ?? body?.tz ?? body?.timeZone ?? undefined;

    if (!Array.isArray(entries)) {
      throw new BadRequestException('Body must be an array or { entries: [...] }');
    }
    return this.availability.setWeeklyForUser(userId, entries, timezone);
  }

  // ---- Indisponibilités (time-offs)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post(['me/time-offs', 'me/time-off'])
  async addMyTimeOff(@Req() req: any, @Body() dto: any) {
    const userId = this.getUserIdFromReq(req);

    const startsAtStr: string | undefined =
      dto?.startsAt ?? dto?.start ?? dto?.starts_at;
    const endsAtStr: string | undefined =
      dto?.endsAt ?? dto?.end ?? dto?.ends_at;

    if (!startsAtStr || !endsAtStr) {
      throw new BadRequestException('startsAt/endsAt (or start/end) are required (ISO8601)');
    }

    return this.availability.addTimeOffForUser(userId, startsAtStr, endsAtStr, dto?.reason);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me/time-offs')
  async listMyTimeOffs(@Req() req: any) {
    const userId = this.getUserIdFromReq(req);
    return this.availability.listTimeOffsForUser(userId);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Delete('me/time-offs/:id')
  async deleteMyTimeOff(@Req() req: any, @Param('id') id: string) {
    const userId = this.getUserIdFromReq(req);
    return this.availability.deleteTimeOffForUser(userId, id);
  }

  // ---- Créneaux publics
  @Get(':id/slots')
  async publicSlots(
    @Param('id') providerId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('step') step?: string,
    @Query('duration') duration?: string,
  ) {
    if (!from || !to) throw new BadRequestException('from/to are required ISO strings');
    const stepMin = Number.isFinite(Number(step)) ? Number(step) : 30;
    const durMin  = Number.isFinite(Number(duration)) ? Number(duration) : undefined;
    return this.availability.publicSlots(providerId, from, to, stepMin, durMin);
  }

  @Get(':id/slots-naive')
  async publicSlotsNaive(
    @Param('id') providerId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('step') step?: string,
    @Query('duration') duration?: string,
  ) {
    if (!from || !to) throw new BadRequestException('from/to are required ISO strings');
    const stepMin = Number.isFinite(Number(step)) ? Number(step) : 30;
    const durMin  = Number.isFinite(Number(duration)) ? Number(duration) : undefined;
    return this.availability.publicSlotsNaive(providerId, from, to, stepMin, durMin);
  }

  /** ===================== ADMIN ===================== */

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/applications')
  async listApplications(
    @Query('status') status?: 'pending' | 'approved' | 'rejected' | 'all',
    @Query('limit') l?: string,
    @Query('offset') o?: string,
  ) {
    const limit = isFinite(Number(l)) ? Number(l) : 50;
    const offset = isFinite(Number(o)) ? Number(o) : 0;
    return this.providers.listApplications(status ?? 'pending', limit, offset);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/applications/:id/approve')
  async approve(@Param('id') providerId: string) {
    return this.providers.approveProvider(providerId);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Post('admin/applications/:id/reject')
  async reject(@Param('id') providerId: string, @Body('reason') reason?: string) {
    return this.providers.rejectProvider(providerId, reason);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Patch('admin/:id')
  async adminUpdateProvider(@Param('id') providerId: string, @Body() dto: any) {
    return this.providers.adminUpdateProvider(providerId, dto);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('me/reapply')
  async reapplyMy(@Req() req: any) {
    const userId = this.getUserIdFromReq(req);
    return this.providers.reapplyMyProvider(userId);
  }

  /** -------- Public: provider par id + services -------- */

  @Get(':id')
  async getProvider(@Param('id') id: string) {
    return this.providers.providerDetails(id);
  }

  @Get(':id/services')
  async listServices(@Param('id') id: string) {
    return this.providers.listServices(id);
  }

  // Admin utilitaire pour backfill lat/lng
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @Get('admin/backfill-latlng')
  async backfill() {
    return this.providers.backfillLatLngAndExpandShortUrls(1000);
  }
}
