import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { PetshopService } from './petshop.service';
import {
  PetshopController,
  ProvidersPetshopController,
  PublicPetshopController,
  CustomerOrderController,
  PetshopOrderController,
} from './petshop.controller';

@Module({
  imports: [PrismaModule],
  controllers: [
    PetshopController,
    ProvidersPetshopController,
    PublicPetshopController,
    CustomerOrderController,
    PetshopOrderController,
  ],
  providers: [PetshopService],
  exports: [PetshopService],
})
export class PetshopModule {}

