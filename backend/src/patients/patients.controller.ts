import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { PatientsService } from './patients.service';

@ApiTags('patients')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('PRO', 'ADMIN')
@Controller({ path: 'patients', version: '1' })
export class PatientsController {
  constructor(private readonly svc: PatientsService) {}

  // Liste les clients d'un PRO ayant au moins 1 RDV COMPLETED (après scan QR/OTP)
  @Get('provider')
  list(@Req() req: any, @Query('q') q?: string) {
    return this.svc.listPatientsForProvider(req.user.sub, q);
  }
}
