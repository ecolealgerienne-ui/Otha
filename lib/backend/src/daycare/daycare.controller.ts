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
    return this.daycareService.createBooking(req.user.userId, dto);
  }

  /**
   * GET /api/v1/daycare/my/bookings
   * Obtenir mes réservations (client)
   */
  @Get('my/bookings')
  async getMyBookings(@Req() req: any) {
    return this.daycareService.getMyBookings(req.user.userId);
  }

  /**
   * GET /api/v1/daycare/provider/bookings
   * Obtenir les réservations de ma garderie (provider)
   */
  @Get('provider/bookings')
  async getProviderBookings(@Req() req: any) {
    return this.daycareService.getProviderBookings(req.user.userId);
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
    return this.daycareService.updateBookingStatus(req.user.userId, id, dto.status);
  }

  /**
   * PATCH /api/v1/daycare/bookings/:id/drop-off
   * Marquer l'animal comme déposé (IN_PROGRESS)
   */
  @Patch('bookings/:id/drop-off')
  async markDropOff(@Req() req: any, @Param('id') id: string) {
    return this.daycareService.markDropOff(req.user.userId, id);
  }

  /**
   * PATCH /api/v1/daycare/bookings/:id/pickup
   * Marquer l'animal comme récupéré (COMPLETED)
   */
  @Patch('bookings/:id/pickup')
  async markPickup(@Req() req: any, @Param('id') id: string) {
    return this.daycareService.markPickup(req.user.userId, id);
  }

  /**
   * GET /api/v1/daycare/provider/calendar?date=2025-11-22
   * Obtenir les animaux présents pour une date donnée (calendrier)
   */
  @Get('provider/calendar')
  async getCalendar(@Req() req: any, @Query('date') date: string) {
    return this.daycareService.getCalendar(req.user.userId, date);
  }
}
