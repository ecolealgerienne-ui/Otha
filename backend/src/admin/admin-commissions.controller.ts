import {
  Controller,
  Get,
  Patch,
  Post,
  Query,
  Param,
  Body,
  UseGuards,
  Injectable,
  CanActivate,
  ExecutionContext,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AdminCommissionsService, CommissionData } from './admin-commissions.service';

@Injectable()
class AdminOnlyGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const role = req?.user?.role;
    return role === 'ADMIN' || role === 'admin';
  }
}

@UseGuards(AuthGuard('jwt'), AdminOnlyGuard)
@Controller({ path: 'admin/commissions', version: '1' })
export class AdminCommissionsController {
  constructor(private readonly commissionsService: AdminCommissionsService) {}

  /**
   * GET /admin/commissions
   * Liste tous les professionnels avec leurs commissions
   */
  @Get()
  async listCommissions(
    @Query('q') q?: string,
    @Query('isApproved') isApproved?: string,
  ) {
    return this.commissionsService.listProviderCommissions({
      q,
      isApproved: isApproved === 'true' ? true : isApproved === 'false' ? false : undefined,
    });
  }

  /**
   * GET /admin/commissions/:providerId
   * Récupère les commissions d'un professionnel
   */
  @Get(':providerId')
  async getCommission(@Param('providerId') providerId: string) {
    return this.commissionsService.getProviderCommission(providerId);
  }

  /**
   * PATCH /admin/commissions/:providerId
   * Met à jour les commissions d'un professionnel
   */
  @Patch(':providerId')
  async updateCommission(
    @Param('providerId') providerId: string,
    @Body() body: Partial<CommissionData>,
  ) {
    return this.commissionsService.updateProviderCommission(providerId, body);
  }

  /**
   * POST /admin/commissions/:providerId/reset
   * Réinitialise les commissions aux valeurs par défaut
   */
  @Post(':providerId/reset')
  async resetCommission(@Param('providerId') providerId: string) {
    return this.commissionsService.resetProviderCommission(providerId);
  }
}
