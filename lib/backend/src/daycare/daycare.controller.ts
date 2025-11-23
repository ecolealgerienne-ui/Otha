import {
  Controller,
  Post,
  Get,
  Patch,
  Body,
  Param,
  UseGuards,
  Req,
  Query,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { DaycareService } from './daycare.service';
import { CreateDaycareBookingDto } from './dto/create-booking.dto';
import { UpdateBookingStatusDto } from './dto/update-status.dto';

@Controller({ path: 'daycare', version: '1' })
@UseGuards(JwtAuthGuard)
export class DaycareController {
  constructor(private daycareService: DaycareService) {}

  /**
   * POST /api/v1/daycare/bookings
   * Créer une réservation garderie (client)
   */
  @Post('bookings')
  async createBooking(@Req() req: any, @Body() dto: CreateDaycareBookingDto) {
    return this.daycareService.createBooking(req.user.sub, dto);
  }

  /**
   * GET /api/v1/daycare/my/bookings
   * Obtenir mes réservations (client)
   */
  @Get('my/bookings')
  async getMyBookings(@Req() req: any) {
    return this.daycareService.getMyBookings(req.user.sub);
  }

  /**
   * GET /api/v1/daycare/provider/bookings
   * Obtenir les réservations de ma garderie (provider)
   */
  @Get('provider/bookings')
  async getProviderBookings(@Req() req: any) {
    return this.daycareService.getProviderBookings(req.user.sub);
  }

  /**
   * PATCH /api/v1/daycare/bookings/:id/status
   * Mettre à jour le statut d'une réservation (provider)
   */
  @Patch('bookings/:id/status')
  async updateBookingStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateBookingStatusDto,
  ) {
    return this.daycareService.updateBookingStatus(req.user.sub, id, dto.status);
  }

  /**
   * PATCH /api/v1/daycare/bookings/:id/drop-off
   * Marquer l'animal comme déposé (IN_PROGRESS)
   */
  @Patch('bookings/:id/drop-off')
  async markDropOff(@Req() req: any, @Param('id') id: string) {
    return this.daycareService.markDropOff(req.user.sub, id);
  }

  /**
   * PATCH /api/v1/daycare/bookings/:id/pickup
   * Marquer l'animal comme récupéré (COMPLETED)
   */
  @Patch('bookings/:id/pickup')
  async markPickup(@Req() req: any, @Param('id') id: string) {
    return this.daycareService.markPickup(req.user.sub, id);
  }

  /**
   * GET /api/v1/daycare/provider/calendar?date=2025-11-22
   * Obtenir les animaux présents pour une date donnée (calendrier)
   */
  @Get('provider/calendar')
  async getCalendar(@Req() req: any, @Query('date') date: string) {
    return this.daycareService.getCalendar(req.user.sub, date);
  }

  /**
   * DELETE /api/v1/daycare/my/bookings/:id
   * Annuler une réservation (client)
   */
  @Patch('my/bookings/:id/cancel')
  async cancelMyBooking(@Req() req: any, @Param('id') id: string) {
    return this.daycareService.cancelMyBooking(req.user.sub, id);
  }

  /**
   * GET /api/v1/daycare/active-for-pet/:petId
   * Chercher un booking daycare actif pour un pet (pour le scan QR)
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Get('active-for-pet/:petId')
  async findActiveDaycareBookingForPet(@Param('petId') petId: string) {
    return this.daycareService.findActiveDaycareBookingForPet(petId);
  }
}
