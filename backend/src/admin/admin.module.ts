import { Module } from '@nestjs/common';
import { AdminFlagsController } from './admin-flags.controller';
import { AdminFlagsService } from './admin-flags.service';
import { AdminUsersController } from './admin-users.controller';
import { AdminUsersService } from './admin-users.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [AdminFlagsController, AdminUsersController],
  providers: [AdminFlagsService, AdminUsersService],
  exports: [AdminFlagsService, AdminUsersService],
})
export class AdminModule {}
