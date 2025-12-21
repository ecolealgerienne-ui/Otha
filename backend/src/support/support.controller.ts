import {
  Controller,
  Get,
  Post,
  Patch,
  Query,
  Param,
  Body,
  Req,
  UseGuards,
  Injectable,
  CanActivate,
  ExecutionContext,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { SupportService } from './support.service';
import { TicketCategory, TicketStatus, TicketPriority } from '@prisma/client';

@Injectable()
class AdminOnlyGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const role = req?.user?.role;
    return role === 'ADMIN' || role === 'admin';
  }
}

// ==================== USER ENDPOINTS ====================

@UseGuards(AuthGuard('jwt'))
@Controller({ path: 'support', version: '1' })
export class SupportController {
  constructor(private readonly supportService: SupportService) {}

  /**
   * POST /support/tickets
   * Créer un nouveau ticket
   */
  @Post('tickets')
  async createTicket(
    @Req() req: any,
    @Body()
    body: {
      subject: string;
      category?: TicketCategory;
      message: string;
      relatedSanctionId?: string;
    },
  ) {
    return this.supportService.createTicket(req.user, body);
  }

  /**
   * GET /support/tickets
   * Liste mes tickets
   */
  @Get('tickets')
  async getMyTickets(@Req() req: any) {
    return this.supportService.getUserTickets(req.user);
  }

  /**
   * GET /support/tickets/:id
   * Récupérer un ticket avec ses messages
   */
  @Get('tickets/:id')
  async getTicket(@Req() req: any, @Param('id') id: string) {
    return this.supportService.getTicketMessages(req.user, id);
  }

  /**
   * POST /support/tickets/:id/messages
   * Envoyer un message dans un ticket
   */
  @Post('tickets/:id/messages')
  async sendMessage(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { content: string },
  ) {
    return this.supportService.sendMessage(req.user, id, body.content);
  }

  /**
   * GET /support/unread
   * Compter les tickets avec messages non lus
   */
  @Get('unread')
  async getUnreadCount(@Req() req: any) {
    const userId = req.user?.sub || req.user?.id;
    const count = await this.supportService.getUnreadCountForUser(userId);
    return { count };
  }
}

// ==================== ADMIN ENDPOINTS ====================

@UseGuards(AuthGuard('jwt'), AdminOnlyGuard)
@Controller({ path: 'admin/support', version: '1' })
export class AdminSupportController {
  constructor(private readonly supportService: SupportService) {}

  /**
   * GET /admin/support/tickets
   * Liste tous les tickets avec filtres
   */
  @Get('tickets')
  async listTickets(
    @Query('status') status?: TicketStatus,
    @Query('category') category?: TicketCategory,
    @Query('priority') priority?: TicketPriority,
    @Query('assignedToId') assignedToId?: string,
    @Query('userId') userId?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.supportService.listAllTickets({
      status,
      category,
      priority,
      assignedToId,
      userId,
      limit: limit ? parseInt(limit, 10) : 50,
      offset: offset ? parseInt(offset, 10) : 0,
    });
  }

  /**
   * GET /admin/support/tickets/:id
   * Récupérer un ticket avec ses messages
   */
  @Get('tickets/:id')
  async getTicket(@Req() req: any, @Param('id') id: string) {
    return this.supportService.getTicketMessages(req.user, id);
  }

  /**
   * POST /admin/support/tickets/:id/messages
   * Répondre à un ticket
   */
  @Post('tickets/:id/messages')
  async sendMessage(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { content: string },
  ) {
    return this.supportService.sendMessage(req.user, id, body.content);
  }

  /**
   * PATCH /admin/support/tickets/:id/assign
   * Assigner un ticket à un admin
   */
  @Patch('tickets/:id/assign')
  async assignTicket(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { adminId?: string },
  ) {
    const adminId = body.adminId || req.user?.sub || req.user?.id;
    return this.supportService.assignTicket(id, adminId);
  }

  /**
   * PATCH /admin/support/tickets/:id/status
   * Changer le statut d'un ticket
   */
  @Patch('tickets/:id/status')
  async updateStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { status: TicketStatus },
  ) {
    const adminId = req.user?.sub || req.user?.id;
    return this.supportService.updateTicketStatus(id, body.status, adminId);
  }

  /**
   * PATCH /admin/support/tickets/:id/priority
   * Changer la priorité d'un ticket
   */
  @Patch('tickets/:id/priority')
  async updatePriority(
    @Param('id') id: string,
    @Body() body: { priority: TicketPriority },
  ) {
    return this.supportService.updateTicketPriority(id, body.priority);
  }

  /**
   * GET /admin/support/stats
   * Statistiques des tickets
   */
  @Get('stats')
  async getStats() {
    return this.supportService.getTicketStats();
  }

  /**
   * GET /admin/support/unread
   * Compter les tickets non lus
   */
  @Get('unread')
  async getUnreadCount() {
    const count = await this.supportService.getUnreadCountForAdmin();
    return { count };
  }
}
