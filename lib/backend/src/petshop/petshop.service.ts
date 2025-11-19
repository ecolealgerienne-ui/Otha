import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';

@Injectable()
export class PetshopService {
  constructor(private readonly prisma: PrismaService) {}

  private async getProviderIdForUser(userId: string) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { userId },
      select: { id: true, specialties: true },
    });
    if (!prov) throw new NotFoundException('Provider profile not found for current user');

    // Vérifier que c'est bien un petshop
    const kind = (prov.specialties as any)?.kind;
    if (kind !== 'petshop') {
      throw new BadRequestException('This endpoint is only available for petshop providers');
    }

    return prov.id;
  }

  // ========= Products =========

  async listMyProducts(userId: string) {
    const providerId = await this.getProviderIdForUser(userId);
    return this.prisma.product.findMany({
      where: { providerId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createProduct(userId: string, dto: CreateProductDto) {
    const providerId = await this.getProviderIdForUser(userId);

    return this.prisma.product.create({
      data: {
        providerId,
        title: dto.title,
        description: dto.description,
        priceDa: dto.priceDa,
        stock: dto.stock ?? undefined,
        category: dto.category ?? undefined,
        imageUrls: dto.imageUrls ? (dto.imageUrls as any) : undefined,
        active: dto.active ?? true,
      },
    });
  }

  async updateProduct(userId: string, productId: string, dto: UpdateProductDto) {
    const providerId = await this.getProviderIdForUser(userId);
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product || product.providerId !== providerId) {
      throw new NotFoundException('Product not found');
    }

    const data: Prisma.ProductUpdateInput = {
      title: dto.title ?? undefined,
      description: dto.description ?? undefined,
      priceDa: dto.priceDa ?? undefined,
      stock: dto.stock ?? undefined,
      category: dto.category ?? undefined,
      imageUrls: dto.imageUrls ? (dto.imageUrls as any) : undefined,
      active: dto.active ?? undefined,
    };

    return this.prisma.product.update({ where: { id: productId }, data });
  }

  async deleteProduct(userId: string, productId: string) {
    const providerId = await this.getProviderIdForUser(userId);
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product || product.providerId !== providerId) {
      throw new NotFoundException('Product not found');
    }

    await this.prisma.product.delete({ where: { id: productId } });
    return { success: true };
  }

  // ========= Orders =========

  private buildDisplayName(user: { firstName?: string | null; lastName?: string | null; email: string }): string {
    const parts = [user.firstName, user.lastName].filter(Boolean);
    return parts.length > 0 ? parts.join(' ') : user.email.split('@')[0];
  }

  async listMyOrders(userId: string, status?: string) {
    const providerId = await this.getProviderIdForUser(userId);

    const where: Prisma.OrderWhereInput = {
      providerId,
      ...(status && status !== 'ALL' ? { status: status as any } : {}),
    };

    const orders = await this.prisma.order.findMany({
      where,
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
          },
        },
        items: {
          include: {
            product: {
              select: {
                id: true,
                title: true,
                imageUrls: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    // Ajouter displayName pour chaque order
    return orders.map((order: any) => ({
      ...order,
      user: {
        ...order.user,
        displayName: this.buildDisplayName(order.user),
      },
    }));
  }

  async getOrder(userId: string, orderId: string) {
    const providerId = await this.getProviderIdForUser(userId);

    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        providerId,
      },
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phone: true,
          },
        },
        items: {
          include: {
            product: {
              select: {
                id: true,
                title: true,
                description: true,
                imageUrls: true,
              },
            },
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    // Ajouter displayName
    return {
      ...order,
      user: {
        ...order.user,
        displayName: this.buildDisplayName(order.user),
      },
    };
  }

  async updateOrderStatus(userId: string, orderId: string, status: string) {
    const providerId = await this.getProviderIdForUser(userId);

    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        providerId,
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    return this.prisma.order.update({
      where: { id: orderId },
      data: { status: status as any },
    });
  }

  // ========= Customer Order Creation =========

  async createOrder(userId: string, providerId: string, items: { productId: string; quantity: number }[]) {
    if (!items || items.length === 0) {
      throw new BadRequestException('Order must contain at least one item');
    }

    // Verify provider exists and is a petshop
    const provider = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      select: { id: true, specialties: true, isApproved: true },
    });

    if (!provider) {
      throw new NotFoundException('Provider not found');
    }

    if (!provider.isApproved) {
      throw new BadRequestException('Provider is not approved');
    }

    const kind = (provider.specialties as any)?.kind;
    if (kind !== 'petshop') {
      throw new BadRequestException('Provider is not a petshop');
    }

    // Fetch all products and verify they belong to this provider
    const productIds = items.map(i => i.productId);
    const products = await this.prisma.product.findMany({
      where: {
        id: { in: productIds },
        providerId,
        active: true,
      },
    });

    if (products.length !== productIds.length) {
      throw new BadRequestException('One or more products not found or not available');
    }

    // Build order items and calculate total
    const orderItems: { productId: string; quantity: number; priceDa: number }[] = [];
    let totalDa = 0;

    for (const item of items) {
      const product = products.find(p => p.id === item.productId);
      if (!product) {
        throw new BadRequestException(`Product ${item.productId} not found`);
      }

      // Check stock if applicable
      if (product.stock !== null && product.stock < item.quantity) {
        throw new BadRequestException(`Insufficient stock for product: ${product.title}`);
      }

      const itemTotal = product.priceDa * item.quantity;
      totalDa += itemTotal;

      orderItems.push({
        productId: item.productId,
        quantity: item.quantity,
        priceDa: product.priceDa,
      });
    }

    // Create order with items in a transaction
    const order = await this.prisma.$transaction(async (tx) => {
      // Create order
      const newOrder = await tx.order.create({
        data: {
          userId,
          providerId,
          totalDa,
          status: 'PENDING',
          items: {
            create: orderItems,
          },
        },
        include: {
          items: {
            include: {
              product: {
                select: {
                  id: true,
                  title: true,
                  imageUrls: true,
                },
              },
            },
          },
        },
      });

      // Update stock for each product
      for (const item of items) {
        const product = products.find(p => p.id === item.productId);
        if (product && product.stock !== null) {
          await tx.product.update({
            where: { id: item.productId },
            data: { stock: { decrement: item.quantity } },
          });
        }
      }

      return newOrder;
    });

    return order;
  }

  // ========= Client Orders =========

  async listClientOrders(userId: string, status?: string) {
    const where: any = {
      userId,
      ...(status && status !== 'ALL' ? { status: status as any } : {}),
    };

    const orders = await this.prisma.order.findMany({
      where,
      include: {
        provider: {
          select: {
            id: true,
            displayName: true,
            address: true,
          },
        },
        items: {
          include: {
            product: {
              select: {
                id: true,
                title: true,
                imageUrls: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return orders;
  }

  // ========= Public endpoints =========

  async listPublicProducts(providerId: string) {
    // Vérifier que le provider existe et est un petshop
    const prov = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      select: { id: true, specialties: true, isApproved: true },
    });

    if (!prov) {
      throw new NotFoundException('Provider not found');
    }

    if (!prov.isApproved) {
      throw new NotFoundException('Provider not approved');
    }

    const kind = (prov.specialties as any)?.kind;
    if (kind !== 'petshop') {
      throw new BadRequestException('This provider is not a petshop');
    }

    // Retourner uniquement les produits actifs
    return this.prisma.product.findMany({
      where: {
        providerId,
        active: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}

