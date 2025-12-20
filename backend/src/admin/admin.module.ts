import { Module } from '@nestjs/common';
import { AdminFlagsController } from './admin-flags.controller';
import { AdminFlagsService } from './admin-flags.service';
import { AdminUsersController } from './admin-users.controller';
import { AdminUsersService } from './admin-users.service';
import { AdminCommissionsController } from './admin-commissions.controller';
import { AdminCommissionsService } from './admin-commissions.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [AdminFlagsController, AdminUsersController, AdminCommissionsController],
  providers: [AdminFlagsService, AdminUsersService, AdminCommissionsService],
  exports: [AdminFlagsService, AdminUsersService, AdminCommissionsService],
})
export class AdminModule {}
