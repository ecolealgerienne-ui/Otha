import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { DaycareService } from './daycare.service';
import { DaycareController } from './daycare.controller';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [DaycareController],
  providers: [DaycareService],
  exports: [DaycareService],
})
export class DaycareModule {}
