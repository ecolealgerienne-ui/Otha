import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { ReqUser } from '../auth/req-user.decorator';
import { PetshopService } from './petshop.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { CreateOrderDto } from './dto/create-order.dto';

@ApiTags('petshop')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'petshop/me', version: '1' })
export class PetshopController {
  constructor(private readonly petshop: PetshopService) {}

  // ========= Products =========

  @Get('products')
  async listMyProducts(@ReqUser() user: { id: string }) {
    return this.petshop.listMyProducts(user.id);
  }

  @Post('products')
  async createProduct(
    @ReqUser() user: { id: string },
    @Body() dto: CreateProductDto,
  ) {
    return this.petshop.createProduct(user.id, dto);
  }

  @Patch('products/:id')
  async updateProduct(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
  ) {
    return this.petshop.updateProduct(user.id, id, dto);
  }

  @Delete('products/:id')
  async deleteProduct(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.petshop.deleteProduct(user.id, id);
  }

  // ========= Orders =========

  @Get('orders')
  async listMyOrders(
    @ReqUser() user: { id: string },
    @Query('status') status?: string,
  ) {
    return this.petshop.listMyOrders(user.id, status);
  }

  @Get('orders/:id')
  async getOrder(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.petshop.getOrder(user.id, id);
  }

  @Patch('orders/:id/status')
  async updateOrderStatus(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateOrderStatusDto,
  ) {
    return this.petshop.updateOrderStatus(user.id, id, dto.status);
  }
}

// Routes alternatives pour compatibilité avec /providers/me/products
@ApiTags('petshop')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'providers/me', version: '1' })
export class ProvidersPetshopController {
  constructor(private readonly petshop: PetshopService) {}

  @Get('products')
  async listMyProducts(@ReqUser() user: { id: string }) {
    return this.petshop.listMyProducts(user.id);
  }

  @Post('products')
  async createProduct(
    @ReqUser() user: { id: string },
    @Body() dto: CreateProductDto,
  ) {
    return this.petshop.createProduct(user.id, dto);
  }

  @Patch('products/:id')
  async updateProduct(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
  ) {
    return this.petshop.updateProduct(user.id, id, dto);
  }

  @Delete('products/:id')
  async deleteProduct(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.petshop.deleteProduct(user.id, id);
  }

  @Get('orders')
  async listMyOrders(
    @ReqUser() user: { id: string },
    @Query('status') status?: string,
  ) {
    return this.petshop.listMyOrders(user.id, status);
  }

  @Get('orders/:id')
  async getOrder(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.petshop.getOrder(user.id, id);
  }

  @Patch('orders/:id/status')
  async updateOrderStatus(
    @ReqUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateOrderStatusDto,
  ) {
    return this.petshop.updateOrderStatus(user.id, id, dto.status);
  }
}

// ========= Public endpoints (pas d'auth requise) =========

@ApiTags('petshop')
@Controller({ path: 'providers/:id', version: '1' })
export class PublicPetshopController {
  constructor(private readonly petshop: PetshopService) {}

  @Get('products')
  async listPublicProducts(@Param('id') providerId: string) {
    return this.petshop.listPublicProducts(providerId);
  }
}

// ========= Customer Order Creation (auth requise) =========

@ApiTags('orders')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'orders', version: '1' })
export class CustomerOrderController {
  constructor(private readonly petshop: PetshopService) {}

  @Post()
  async createOrder(
    @ReqUser() user: { id: string },
    @Body() dto: CreateOrderDto,
  ) {
    return this.petshop.createOrder(user.id, dto.providerId, dto.items);
  }

  @Get('me')
  async myOrders(
    @ReqUser() user: { id: string },
    @Query('status') status?: string,
  ) {
    return this.petshop.listClientOrders(user.id, status);
  }
}

// Alternative route for petshop/orders
@ApiTags('petshop')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'petshop/orders', version: '1' })
export class PetshopOrderController {
  constructor(private readonly petshop: PetshopService) {}

  @Post()
  async createOrder(
    @ReqUser() user: { id: string },
    @Body() dto: CreateOrderDto,
  ) {
    return this.petshop.createOrder(user.id, dto.providerId, dto.items);
  }
}
