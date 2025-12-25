import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';

@Injectable()
export class PatientsService {
  constructor(private prisma: PrismaService) {}

  async listPatientsForProvider(userId: string, q?: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('Provider profile not found');

    const where: Prisma.BookingWhereInput = {
      providerId: prov.id,
      // ✅ Patients visibles uniquement après RDV terminé (scan QR/OTP)
      status: 'COMPLETED',
      ...(q && q.trim()
        ? {
            user: {
              OR: [
                { firstName: { contains: q, mode: 'insensitive' } },
                { lastName:  { contains: q, mode: 'insensitive' } },
                { email:     { contains: q, mode: 'insensitive' } },
                { phone:     { contains: q, mode: 'insensitive' } },
              ],
            },
          }
        : {}),
    };

    const bookings = await this.prisma.booking.findMany({
      where,
      orderBy: { scheduledAt: 'desc' },
      include: {
        user: { select: { id: true, firstName: true, lastName: true, email: true, phone: true } },
        service: { select: { title: true, price: true } },
      },
    });

    // group by user
    const byUser = new Map<
      string,
      { user: any; bookings: Array<{ id: string; scheduledAt: Date; status: string; service: any }> }
    >();

    for (const b of bookings) {
      if (!byUser.has(b.userId)) byUser.set(b.userId, { user: b.user, bookings: [] });
      byUser.get(b.userId)!.bookings.push({
        id: b.id,
        scheduledAt: b.scheduledAt,
        status: b.status,
        service: b.service,
      });
    }

    // pets par propriétaire
    const ownerIds = Array.from(byUser.keys());
    const pets = await this.prisma.pet.findMany({
      where: { ownerId: { in: ownerIds } },
      select: { id: true, ownerId: true, name: true, idNumber: true },
      orderBy: { updatedAt: 'desc' },
    });
    const petsByOwner = new Map<string, Array<any>>();
    for (const p of pets) {
      if (!petsByOwner.has(p.ownerId)) petsByOwner.set(p.ownerId, []);
      petsByOwner.get(p.ownerId)!.push({ id: p.id, name: p.name, label: p.idNumber });
    }

    const result = [];
    for (const [uid, data] of byUser) {
      const list = data.bookings; // déjà triée desc
      result.push({
        user: data.user,
        lastSeenAt: list.length ? list[0].scheduledAt : null,
        bookingsCount: list.length,
        pets: petsByOwner.get(uid) ?? [],
        bookings: list,
      });
    }

    // tri lisible
    result.sort((a, b) => {
      const an = `${a.user?.firstName ?? ''} ${a.user?.lastName ?? ''}`.trim().toLowerCase();
      const bn = `${b.user?.firstName ?? ''} ${b.user?.lastName ?? ''}`.trim().toLowerCase();
      if (an && bn && an !== bn) return an.localeCompare(bn);
      return (b.lastSeenAt?.valueOf() ?? 0) - (a.lastSeenAt?.valueOf() ?? 0);
    });

    return result;
  }
}
