import { Module, forwardRef } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminModule } from '../admin/admin.module';
import { DaycareService } from './daycare.service';
import { DaycareController } from './daycare.controller';

@Module({
  imports: [PrismaModule, NotificationsModule, forwardRef(() => AdminModule)],
  controllers: [DaycareController],
  providers: [DaycareService],
  exports: [DaycareService],
})
export class DaycareModule {}
