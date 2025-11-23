import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AvailabilityService {
  constructor(private prisma: PrismaService) {}

  // ===== Helpers internes =====
  private addMinutes(d: Date, min: number): Date {
    return new Date(d.getTime() + min * 60_000);
  }
  private overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
    return aStart < bEnd && bStart < aEnd;
  }
  private ceilToStepUtc(d: Date, stepMin: number): Date {
    const stepMs = stepMin * 60_000;
    return new Date(Math.ceil(d.getTime() / stepMs) * stepMs);
  }
  private tzParts(date: Date, timeZone: string) {
    const fmt = new Intl.DateTimeFormat('en-GB', {
      timeZone,
      hour12: false,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      weekday: 'short',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    const parts = fmt.formatToParts(date);
    const get = (t: string) => parts.find(p => p.type === t)?.value ?? '';
    return {
      year: +get('year'),
      month: +get('month'),
      day: +get('day'),
      weekdayShort: get('weekday'),
      hour: +get('hour'),
      minute: +get('minute'),
      second: +get('second'),
    };
  }
  private weekdayToNum(shortEn: string): number {
    switch (shortEn) {
      case 'Mon': return 1;
      case 'Tue': return 2;
      case 'Wed': return 3;
      case 'Thu': return 4;
      case 'Fri': return 5;
      case 'Sat': return 6;
      case 'Sun': return 7;
      default: return 1;
    }
  }
  private pad2(n: number) { return String(n).padStart(2, '0'); }

  // ================== API attendue par ProvidersController ==================

  // GET /providers/me/availability
  async getWeeklyForUser(userId: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('No provider profile for this user');

    const rows = await this.prisma.providerAvailability.findMany({
      where: { providerId: prov.id },
      orderBy: [{ weekday: 'asc' }, { startMin: 'asc' }],
      select: { id: true, weekday: true, startMin: true, endMin: true },
    });

    return { timezone: prov.timezone ?? null, entries: rows };
  }

  // POST /providers/me/availability
  async setWeeklyForUser(
    userId: string,
    entries: Array<{ weekday: number; startMin: number; endMin: number }>,
    timezone?: string,
  ) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('No provider profile for this user');

    if (!Array.isArray(entries)) {
      throw new BadRequestException('entries must be an array');
    }

    const data = [];
    for (const raw of entries) {
      const weekday = Number(raw?.weekday);
      const startMin = Number(raw?.startMin);
      const endMin = Number(raw?.endMin);
      if (![1,2,3,4,5,6,7].includes(weekday)) throw new BadRequestException('weekday must be 1..7');
      if (!Number.isFinite(startMin) || !Number.isFinite(endMin)) {
        throw new BadRequestException('startMin/endMin must be numbers');
      }
      if (startMin < 0 || endMin > 24*60 || endMin <= startMin) {
        throw new BadRequestException('invalid interval');
      }
      data.push({ providerId: prov.id, weekday, startMin, endMin });
    }

    await this.prisma.$transaction([
      this.prisma.providerAvailability.deleteMany({ where: { providerId: prov.id } }),
      ...(data.length ? [this.prisma.providerAvailability.createMany({ data })] : []),
      ...(timezone
        ? [this.prisma.providerProfile.update({ where: { id: prov.id }, data: { timezone } })]
        : []),
    ]);

    return { success: true, count: data.length, timezone: timezone ?? prov.timezone ?? null };
  }

  // POST /providers/me/time-offs
  async addTimeOffForUser(userId: string, startsAtIso: string, endsAtIso: string, reason?: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('No provider profile for this user');

    if (!startsAtIso || !endsAtIso) throw new BadRequestException('startsAt/endsAt are required');
    const startsAt = new Date(startsAtIso);
    const endsAt = new Date(endsAtIso);
    if (isNaN(startsAt.getTime()) || isNaN(endsAt.getTime())) {
      throw new BadRequestException('Invalid ISO dates');
    }
    if (endsAt <= startsAt) throw new BadRequestException('endsAt must be after startsAt');

    return this.prisma.providerTimeOff.create({
      data: { providerId: prov.id, startsAt, endsAt, reason: reason?.trim() || null },
      select: { id: true, providerId: true, startsAt: true, endsAt: true, reason: true },
    });
  }

  // GET /providers/me/time-offs
  async listTimeOffsForUser(userId: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('No provider profile for this user');

    return this.prisma.providerTimeOff.findMany({
      where: { providerId: prov.id },
      orderBy: { startsAt: 'desc' },
      select: { id: true, startsAt: true, endsAt: true, reason: true },
    });
  }

  // DELETE /providers/me/time-offs/:id
  async deleteTimeOffForUser(userId: string, id: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('No provider profile for this user');

    const res = await this.prisma.providerTimeOff.deleteMany({
      where: { id, providerId: prov.id },
    });
    if (res.count === 0) throw new NotFoundException('Time-off not found');
    return { id, deleted: true };
  }

  // ======= Slots publics (utilisés par GET /providers/:id/slots) =======

  async publicSlots(
    providerId: string,
    fromIso: string,
    toIso: string,
    stepMin = 30,
    durationMin?: number,
  ) {
    const from = new Date(fromIso);
    const to = new Date(toIso);
    if (!(from instanceof Date) || isNaN(+from) || !(to instanceof Date) || isNaN(+to) || from >= to) {
      throw new ForbiddenException('Invalid from/to');
    }

    const [prov, weekly, bookings, timeOffs] = await this.prisma.$transaction([
      this.prisma.providerProfile.findUnique({ where: { id: providerId } }),
      this.prisma.providerAvailability.findMany({
        where: { providerId },
        orderBy: [{ weekday: 'asc' }, { startMin: 'asc' }],
        select: { weekday: true, startMin: true, endMin: true },
      }),
      this.prisma.booking.findMany({
        where: {
          providerId,
          scheduledAt: { gte: from, lt: to },
          status: { in: ['PENDING', 'CONFIRMED'] },
        },
        select: { scheduledAt: true, service: { select: { durationMin: true } } },
      }),
      this.prisma.providerTimeOff.findMany({
        where: { providerId, AND: [{ startsAt: { lt: to } }, { endsAt: { gt: from } }] },
        select: { startsAt: true, endsAt: true },
        orderBy: { startsAt: 'asc' },
      }),
    ]);
    if (!prov) throw new NotFoundException('Provider not found');

    // NOTE: on reste côté serveur ; on n'impose rien au front.
    const tz = prov.timezone || 'Africa/Algiers';
    const fullDur = Math.max(stepMin, Number(durationMin || stepMin));

    const byDay = new Map<number, { startMin: number; endMin: number }[]>();
    for (const w of weekly) {
      if (!byDay.has(w.weekday)) byDay.set(w.weekday, []);
      byDay.get(w.weekday)!.push({ startMin: w.startMin, endMin: w.endMin });
    }

    const bookingIntervals = bookings.map((b) => {
      const start = new Date(b.scheduledAt);
      const end = this.addMinutes(start, Math.max(15, b.service?.durationMin ?? 30));
      return { start, end };
    });
    const timeOffIntervals = timeOffs.map((t) => ({
      start: new Date(t.startsAt),
      end: new Date(t.endsAt),
    }));

    const out: { start: string; end: string }[] = [];

    for (let slotStart = this.ceilToStepUtc(from, stepMin);
         slotStart < to;
         slotStart = this.addMinutes(slotStart, stepMin)) {
      const longEnd = this.addMinutes(slotStart, fullDur);

      if (bookingIntervals.some(b => this.overlaps(slotStart, longEnd, b.start, b.end))) continue;
      if (timeOffIntervals.some(o => this.overlaps(slotStart, longEnd, o.start, o.end))) continue;

      const p = this.tzParts(slotStart, tz);
      const wd = this.weekdayToNum(p.weekdayShort);
      const minuteOfDay = p.hour * 60 + p.minute;

      const dayDispos = byDay.get(wd) ?? [];
      const inside = dayDispos.some(d => minuteOfDay >= d.startMin && (minuteOfDay + fullDur) <= d.endMin);
      if (!inside) continue;

      out.push({ start: slotStart.toISOString(), end: longEnd.toISOString() });
    }

    return {
      providerId,
      from: from.toISOString(),
      to: to.toISOString(),
      stepMin,
      durationMin: fullDur,
      slots: out, // [{start,end}] en UTC, labels à faire côté front *si tu veux* ou via /slots-naive
    };
  }

  // Optionnel (si tu l’utilises) : /providers/:id/slots-naive
  async publicSlotsNaive(
    providerId: string,
    fromIso: string,
    toIso: string,
    stepMin = 30,
    durationMin?: number,
  ) {
    const from = new Date(fromIso);
    const to = new Date(toIso);
    if (!(from instanceof Date) || isNaN(+from) || !(to instanceof Date) || isNaN(+to) || from >= to) {
      throw new BadRequestException('Invalid from/to');
    }

    const [prov, weekly, bookings, timeOffs] = await this.prisma.$transaction([
      this.prisma.providerProfile.findUnique({ where: { id: providerId } }),
      this.prisma.providerAvailability.findMany({
        where: { providerId },
        orderBy: [{ weekday: 'asc' }, { startMin: 'asc' }],
        select: { weekday: true, startMin: true, endMin: true },
      }),
      this.prisma.booking.findMany({
        where: {
          providerId,
          scheduledAt: { gte: from, lt: to },
          status: { in: ['PENDING', 'CONFIRMED'] },
        },
        select: { scheduledAt: true, service: { select: { durationMin: true } } },
      }),
      this.prisma.providerTimeOff.findMany({
        where: { providerId, AND: [{ startsAt: { lt: to } }, { endsAt: { gt: from } }] },
        select: { startsAt: true, endsAt: true },
        orderBy: { startsAt: 'asc' },
      }),
    ]);
    if (!prov) throw new NotFoundException('Provider not found');

    const tz = prov.timezone || 'Africa/Algiers';
    const fullDur = Math.max(stepMin, Number(durationMin || stepMin));

    const byDay = new Map<number, { startMin: number; endMin: number }[]>();
    for (const w of weekly) {
      if (!byDay.has(w.weekday)) byDay.set(w.weekday, []);
      byDay.get(w.weekday)!.push({ startMin: w.startMin, endMin: w.endMin });
    }

    const bookingIntervals = bookings.map((b) => {
      const start = new Date(b.scheduledAt);
      const end = this.addMinutes(start, Math.max(15, b.service?.durationMin ?? 30));
      return { start, end };
    });
    const timeOffIntervals = timeOffs.map((t) => ({
      start: new Date(t.startsAt),
      end: new Date(t.endsAt),
    }));

    const groups = new Map<
      string,
      {
        date: string; // "YYYY-MM-DD"
        weekday: number; // 1..7
        windowStartMin?: number;
        windowEndMin?: number;
        slots: { minute: number; label: string; endLabel: string; isoUtc: string }[];
      }
    >();

    for (let slotStart = this.ceilToStepUtc(from, stepMin);
         slotStart < to;
         slotStart = this.addMinutes(slotStart, stepMin)) {
      const longEnd = this.addMinutes(slotStart, fullDur);

      if (bookingIntervals.some(b => this.overlaps(slotStart, longEnd, b.start, b.end))) continue;
      if (timeOffIntervals.some(o => this.overlaps(slotStart, longEnd, o.start, o.end))) continue;

      const p = this.tzParts(slotStart, tz);
      const wd = this.weekdayToNum(p.weekdayShort);
      const minuteOfDay = p.hour * 60 + p.minute;

      const dayDispos = byDay.get(wd) ?? [];
      const ok = dayDispos.some(d => minuteOfDay >= d.startMin && (minuteOfDay + fullDur) <= d.endMin);
      if (!ok) continue;

      const endLocal = this.tzParts(longEnd, tz);
      const dateKey = `${p.year}-${this.pad2(p.month)}-${this.pad2(p.day)}`;
      if (!groups.has(dateKey)) {
        const winStart = dayDispos.length ? Math.min(...dayDispos.map(d => d.startMin)) : undefined;
        const winEnd   = dayDispos.length ? Math.max(...dayDispos.map(d => d.endMin)) : undefined;
        groups.set(dateKey, { date: dateKey, weekday: wd, windowStartMin: winStart, windowEndMin: winEnd, slots: [] });
      }

      groups.get(dateKey)!.slots.push({
        minute: minuteOfDay,
        label: `${this.pad2(p.hour)}:${this.pad2(p.minute)}`,
        endLabel: `${this.pad2(endLocal.hour)}:${this.pad2(endLocal.minute)}`,
        isoUtc: slotStart.toISOString(),
      });
    }

    const out = Array.from(groups.values())
      .sort((a, b) => a.date.localeCompare(b.date))
      .map(g => ({ ...g, slots: g.slots.sort((a, b) => a.minute - b.minute) }));

    return { providerId, stepMin, durationMin: fullDur, days: out };
  }

  // Utilisé par BookingsController
  async isSlotFree(providerId: string, startUTC: Date, durationMin: number) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { id: providerId } });
    if (!prov) throw new NotFoundException('Provider not found');

    const tz = prov.timezone || 'Africa/Algiers';
    const endUTC = this.addMinutes(startUTC, Math.max(15, durationMin || 30));

    const offs = await this.prisma.providerTimeOff.findMany({
      where: { providerId, startsAt: { lt: endUTC }, endsAt: { gt: startUTC } },
      select: { startsAt: true, endsAt: true },
    });
    if (offs.some(o => this.overlaps(startUTC, endUTC, new Date(o.startsAt), new Date(o.endsAt)))) {
      return false;
    }

    const p = this.tzParts(startUTC, tz);
    const wd = this.weekdayToNum(p.weekdayShort);
    const minuteOfDay = p.hour * 60 + p.minute;

    const dayDispos = await this.prisma.providerAvailability.findMany({
      where: { providerId, weekday: wd },
      select: { startMin: true, endMin: true },
      orderBy: [{ startMin: 'asc' }],
    });

    const inside = dayDispos.some(d => minuteOfDay >= d.startMin && minuteOfDay + durationMin <= d.endMin);
    if (!inside) return false;

    const around = await this.prisma.booking.findMany({
      where: {
        providerId,
        status: { in: ['PENDING', 'CONFIRMED'] },
        scheduledAt: { gte: this.addMinutes(startUTC, -12*60), lte: this.addMinutes(endUTC, 12*60) },
      },
      include: { service: true },
    });

    for (const b of around) {
      const bStart = new Date(b.scheduledAt);
      const bEnd = this.addMinutes(bStart, Math.max(15, b.service?.durationMin ?? 30));
      if (this.overlaps(startUTC, endUTC, bStart, bEnd)) return false;
    }

    return true;
  }
}
