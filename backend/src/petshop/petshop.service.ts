import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { Prisma, NotificationType, TrustStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';

@Injectable()
export class PetshopService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  // ==================== TRUST SYSTEM: Helper pour détecter les nouveaux clients ====================
  private async isUserFirstOrder(userId: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { trustStatus: true },
    });

    if (user?.trustStatus !== 'NEW') return false;

    // Compter les commandes complétées + bookings complétés
    const [completedOrders, completedBookings, completedDaycare] = await Promise.all([
      this.prisma.order.count({ where: { userId, status: 'DELIVERED' } }),
      this.prisma.booking.count({ where: { userId, status: 'COMPLETED' } }),
      this.prisma.daycareBooking.count({ where: { userId, status: 'COMPLETED' } }),
    ]);

    return completedOrders + completedBookings + completedDaycare === 0;
  }

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
            trustStatus: true, // ✅ TRUST SYSTEM
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

    // ✅ TRUST SYSTEM: Calculer isFirstBooking pour chaque user
    const userIds = [...new Set(orders.map((o: any) => o.user.id))];
    const firstOrderMap = new Map<string, boolean>();
    for (const uid of userIds) {
      firstOrderMap.set(uid, await this.isUserFirstOrder(uid));
    }

    // Ajouter displayName et isFirstBooking pour chaque order
    return orders.map((order: any) => ({
      ...order,
      user: {
        ...order.user,
        displayName: this.buildDisplayName(order.user),
        isFirstBooking: firstOrderMap.get(order.user.id) ?? false, // ✅ Pour afficher "Nouveau client"
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
      include: {
        provider: {
          include: {
            user: { select: { firstName: true, lastName: true } },
          },
        },
        items: {
          include: {
            product: { select: { title: true } },
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    const updated = await this.prisma.order.update({
      where: { id: orderId },
      data: { status: status as any },
    });

    // Créer des notifications pour le client
    const providerName = `${order.provider.user.firstName || ''} ${order.provider.user.lastName || ''}`.trim() || 'L\'animalerie';
    const itemCount = order.items.length;
    const firstProduct = order.items[0]?.product?.title || 'vos produits';

    if (status === 'SHIPPED') {
      try {
        await this.notificationsService.createNotification(
          order.userId,
          NotificationType.ORDER_SHIPPED,
          'Commande expédiée',
          `${providerName} a expédié votre commande (${itemCount} ${itemCount > 1 ? 'articles' : 'article'})`,
          {
            orderId: order.id,
            providerId: order.providerId,
          },
        );
      } catch (e) {
        console.error('Failed to create notification:', e);
      }
    } else if (status === 'DELIVERED') {
      try {
        await this.notificationsService.createNotification(
          order.userId,
          NotificationType.ORDER_DELIVERED,
          'Commande livrée',
          `Votre commande de ${itemCount} ${itemCount > 1 ? 'articles' : 'article'} a été livrée !`,
          {
            orderId: order.id,
            providerId: order.providerId,
          },
        );
      } catch (e) {
        console.error('Failed to create notification:', e);
      }
    }

    return updated;
  }

  // Client updates their own order status (confirm delivery or cancel)
  async updateClientOrderStatus(userId: string, orderId: string, status: string) {
    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        userId, // Verify order belongs to this customer
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    // Clients can only set DELIVERED or CANCELLED
    const allowedStatuses = ['DELIVERED', 'CANCELLED'];
    if (!allowedStatuses.includes(status)) {
      throw new BadRequestException(`Invalid status. Allowed: ${allowedStatuses.join(', ')}`);
    }

    return this.prisma.order.update({
      where: { id: orderId },
      data: { status: status as any },
    });
  }

  // ========= Customer Order Creation =========

  async createOrder(
    userId: string,
    providerId: string,
    items: { productId: string; quantity: number }[],
    options?: { phone?: string; deliveryAddress?: string; notes?: string }
  ) {
    if (!items || items.length === 0) {
      throw new BadRequestException('Order must contain at least one item');
    }

    // Verify provider exists and is a petshop
    const provider = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      select: { id: true, specialties: true, isApproved: true, petshopCommissionPercent: true },
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

    // Get commission percentage (default 5%)
    const commissionPercent = provider.petshopCommissionPercent ?? 5;

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

    // Build order items and calculate subtotal
    const orderItems: { productId: string; quantity: number; priceDa: number }[] = [];
    let subtotalDa = 0;

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
      subtotalDa += itemTotal;

      orderItems.push({
        productId: item.productId,
        quantity: item.quantity,
        priceDa: product.priceDa,
      });
    }

    // Calculate commission based on percentage of subtotal
    const commissionDa = Math.round(subtotalDa * commissionPercent / 100);
    const totalDa = subtotalDa + commissionDa;

    // Create order with items in a transaction
    const order = await this.prisma.$transaction(async (tx) => {
      // Create order
      const newOrder = await tx.order.create({
        data: {
          userId,
          providerId,
          subtotalDa,
          commissionDa,
          totalDa,
          status: 'PENDING',
          phone: options?.phone,
          deliveryAddress: options?.deliveryAddress,
          notes: options?.notes,
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

