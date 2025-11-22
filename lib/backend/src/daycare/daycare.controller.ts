import {
  Controller,
  Post,
  Get,
  Patch,
  Body,
  Param,
  UseGuards,
  Request,
  Query,
} from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { DaycareService } from './daycare.service';
import { CreateDaycareBookingDto } from './dto/create-booking.dto';
import { UpdateBookingStatusDto } from './dto/update-status.dto';

@Controller('api/v1/daycare')
@UseGuards(JwtAuthGuard)
export class DaycareController {
  constructor(private daycareService: DaycareService) {}

  /**
   * POST /api/v1/daycare/bookings
   * Créer une réservation garderie (client)
   */
  @Post('bookings')
  async createBooking(@Request() req, @Body() dto: CreateDaycareBookingDto) {
    return this.daycareService.createBooking(req.user.userId, dto);
  }

  /**
   * GET /api/v1/daycare/my/bookings
   * Obtenir mes réservations (client)
   */
  @Get('my/bookings')
  async getMyBookings(@Request() req) {
    return this.daycareService.getMyBookings(req.user.userId);
  }

  /**
   * GET /api/v1/daycare/provider/bookings
   * Obtenir les réservations de ma garderie (provider)
   */
  @Get('provider/bookings')
  async getProviderBookings(@Request() req) {
    return this.daycareService.getProviderBookings(req.user.userId);
  }

  /**
   * PATCH /api/v1/daycare/bookings/:id/status
   * Mettre à jour le statut d'une réservation (provider)
   */
  @Patch('bookings/:id/status')
  async updateBookingStatus(
    @Request() req,
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
  async markDropOff(@Request() req, @Param('id') id: string) {
    return this.daycareService.markDropOff(req.user.userId, id);
  }

  /**
   * PATCH /api/v1/daycare/bookings/:id/pickup
   * Marquer l'animal comme récupéré (COMPLETED)
   */
  @Patch('bookings/:id/pickup')
  async markPickup(@Request() req, @Param('id') id: string) {
    return this.daycareService.markPickup(req.user.userId, id);
  }

  /**
   * GET /api/v1/daycare/provider/calendar?date=2025-11-22
   * Obtenir les animaux présents pour une date donnée (calendrier)
   */
  @Get('provider/calendar')
  async getCalendar(@Request() req, @Query('date') date: string) {
    return this.daycareService.getCalendar(req.user.userId, date);
  }
}
