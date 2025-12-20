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
import { AdminUsersService } from './admin-users.service';

@Injectable()
class AdminOnlyGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const role = req?.user?.role;
    return role === 'ADMIN' || role === 'admin';
  }
}

@UseGuards(AuthGuard('jwt'), AdminOnlyGuard)
@Controller({ path: 'admin/users', version: '1' })
export class AdminUsersController {
  constructor(private readonly adminUsersService: AdminUsersService) {}

  /**
   * GET /admin/users
   * Liste tous les utilisateurs avec filtres
   */
  @Get()
  async listUsers(
    @Query('q') q?: string,
    @Query('role') role?: string,
    @Query('isBanned') isBanned?: string,
    @Query('trustStatus') trustStatus?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.adminUsersService.listUsers({
      q,
      role,
      isBanned: isBanned === 'true' ? true : isBanned === 'false' ? false : undefined,
      trustStatus,
      limit: limit ? parseInt(limit, 10) : 50,
      offset: offset ? parseInt(offset, 10) : 0,
    });
  }

  /**
   * GET /admin/users/:id/full
   * Récupère le profil complet d'un utilisateur
   */
  @Get(':id/full')
  async getFullProfile(@Param('id') id: string) {
    return this.adminUsersService.getFullProfile(id);
  }

  /**
   * PATCH /admin/users/:id
   * Modifier les informations d'un utilisateur
   */
  @Patch(':id')
  async updateUser(
    @Param('id') id: string,
    @Body()
    body: {
      firstName?: string;
      lastName?: string;
      email?: string;
      phone?: string;
      city?: string;
    },
  ) {
    return this.adminUsersService.updateUser(id, body);
  }

  /**
   * POST /admin/users/:id/warn
   * Émettre un avertissement
   */
  @Post(':id/warn')
  async warnUser(
    @Param('id') id: string,
    @Body() body: { reason: string; metadata?: any },
    @Req() req: any,
  ) {
    return this.adminUsersService.warnUser(id, req.user.sub, body.reason, body.metadata);
  }

  /**
   * POST /admin/users/:id/suspend
   * Suspendre un utilisateur
   */
  @Post(':id/suspend')
  async suspendUser(
    @Param('id') id: string,
    @Body() body: { reason: string; durationDays: number; metadata?: any },
    @Req() req: any,
  ) {
    return this.adminUsersService.suspendUser(
      id,
      req.user.sub,
      body.reason,
      body.durationDays,
      body.metadata,
    );
  }

  /**
   * POST /admin/users/:id/ban
   * Bannir un utilisateur
   */
  @Post(':id/ban')
  async banUser(
    @Param('id') id: string,
    @Body() body: { reason: string; metadata?: any },
    @Req() req: any,
  ) {
    return this.adminUsersService.banUser(id, req.user.sub, body.reason, body.metadata);
  }

  /**
   * POST /admin/users/:id/unban
   * Lever le ban d'un utilisateur
   */
  @Post(':id/unban')
  async unbanUser(
    @Param('id') id: string,
    @Body() body: { reason?: string },
    @Req() req: any,
  ) {
    return this.adminUsersService.unbanUser(id, req.user.sub, body.reason);
  }

  /**
   * POST /admin/users/:id/lift-suspension
   * Lever la suspension d'un utilisateur
   */
  @Post(':id/lift-suspension')
  async liftSuspension(
    @Param('id') id: string,
    @Body() body: { reason?: string },
    @Req() req: any,
  ) {
    return this.adminUsersService.liftSuspension(id, req.user.sub, body.reason);
  }

  /**
   * GET /admin/users/:id/sanctions
   * Historique des sanctions
   */
  @Get(':id/sanctions')
  async getSanctions(@Param('id') id: string) {
    return this.adminUsersService.getSanctions(id);
  }

  /**
   * GET /admin/users/:id/orders
   * Commandes petshop
   */
  @Get(':id/orders')
  async getUserOrders(@Param('id') id: string) {
    return this.adminUsersService.getUserOrders(id);
  }

  /**
   * GET /admin/users/:id/daycare
   * Réservations garderie
   */
  @Get(':id/daycare')
  async getUserDaycareBookings(@Param('id') id: string) {
    return this.adminUsersService.getUserDaycareBookings(id);
  }
}
