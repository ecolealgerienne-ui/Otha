// src/adopt/adopt.module.ts
import { Module } from '@nestjs/common';
import { AdoptService } from './adopt.service';
import { AdoptController } from './adopt.controller';
import { AdoptAdminController } from './adopt.admin.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [AdoptController, AdoptAdminController],
  providers: [AdoptService],
})
export class AdoptModule {}
