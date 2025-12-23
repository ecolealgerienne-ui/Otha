import { Module } from '@nestjs/common';
import { CareerController } from './career.controller';
import { CareerAdminController } from './career.admin.controller';
import { CareerService } from './career.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [CareerController, CareerAdminController],
  providers: [CareerService],
  exports: [CareerService],
})
export class CareerModule {}
