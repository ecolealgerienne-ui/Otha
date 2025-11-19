// src/providers/providers.service.ts
import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { Prisma, $Enums } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { MapsService } from '../maps/maps.service';

@Injectable()
export class ProvidersService {
  constructor(
    private prisma: PrismaService,
    private maps: MapsService,
  ) {}

  /* ======================= Utils ======================= */

  private isFiniteNonZero(n: any): n is number {
    return typeof n === 'number' && Number.isFinite(n) && n !== 0;
  }

  private haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const toRad = (d: number) => (d * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /** Source unique pour récupérer l’URL entrante. Priorité: dto.mapsUrl > dto.specialties.* > prevUrl.
   * Si le client envoie explicitement une string vide, on considère que c’est une demande d’effacement. */
  private getIncomingMapsUrl(dto: any, prevUrl: string | null): string | undefined {
    const top = typeof dto?.mapsUrl === 'string' ? dto.mapsUrl.trim() : undefined;
    const fromSpec = this.maps.getMapsUrlFromSpecialties(dto?.specialties);
    const aliases = [
      dto?.mapsUrl,
      dto?.specialties?.mapsUrl,
      dto?.specialties?.googleMapsUrl,
      dto?.specialties?.maps_url,
      dto?.specialties?.google_maps_url,
    ];
    const explicitClear = aliases.some((v: any) => typeof v === 'string' && v.trim() === '');
    if (explicitClear) return undefined;

    const candidate = (top ?? fromSpec ?? prevUrl ?? '').trim();
    return candidate ? this.maps.sanitizeMapsUrl(candidate) : undefined;
  }

  /** Assure visible=true si manquant + normalise mapsUrl + backfill lat/lng. */
  private async ensureGeoAndVisibility(providerId: string): Promise<void> {
    const p = await this.prisma.providerProfile.findUnique({ where: { id: providerId } });
    if (!p) return;

    let lat = typeof p.lat === 'number' ? p.lat : null;
    let lng = typeof p.lng === 'number' ? p.lng : null;
    const sp: any = { ...(p.specialties as any ?? {}) };

    if (sp.visible === undefined) sp.visible = true;

    let url: string | undefined = this.maps.getMapsUrlFromSpecialties(sp) ?? undefined;
    if (url) url = this.maps.sanitizeMapsUrl(url);

    // Étendre + parser en une fois (POI-first)
    let parsedFromUrl = false;
    if (url) {
      const res = await this.maps.expandAndParse(url, false);
      if (res?.finalUrl) url = this.maps.sanitizeMapsUrl(res.finalUrl);
      if ((!this.isFiniteNonZero(lat) || !this.isFiniteNonZero(lng)) &&
          this.isFiniteNonZero(res?.lat) && this.isFiniteNonZero(res?.lng)) {
        lat = res!.lat!; lng = res!.lng!;
        parsedFromUrl = true;
      }
    }

    // Ne centre l’URL QUE si on a obtenu des coords depuis l’URL
    if (url && parsedFromUrl && this.isFiniteNonZero(lat) && this.isFiniteNonZero(lng)) {
      url = this.maps.ensureAtCenter(url, lat!, lng!);
      url = this.maps.sanitizeMapsUrl(url);
    }

    if (url) {
      sp.mapsUrl = url;
      delete sp.maps_url;
      delete sp.googleMapsUrl;
      delete sp.google_maps_url;
    }

    const data: Prisma.ProviderProfileUpdateInput = {};
    if (this.isFiniteNonZero(lat)) data.lat = lat!;
    if (this.isFiniteNonZero(lng)) data.lng = lng!;
    data.specialties = sp as Prisma.InputJsonValue;

    await this.prisma.providerProfile.update({ where: { id: providerId }, data });
  }

  /* ======================= Nearby ======================= */

  async nearby(
    lat: number,
    lng: number,
    radiusKm = 25,
    limit = 20,
    offset = 0,
    status: 'approved' | 'pending' | 'all' = 'approved',
  ) {
    const hasCenter = this.isFiniteNonZero(lat) && this.isFiniteNonZero(lng);
    const wantAll = !Number.isFinite(radiusKm) || radiusKm <= 0;

    let whereAny: any = {};
    switch (status) {
      case 'pending':
        whereAny = { isApproved: false, rejectedAt: null };
        break;
      case 'all':
        whereAny = {};
        break;
      case 'approved':
      default:
        whereAny = { isApproved: true };
        break;
    }

    const rows = await this.prisma.providerProfile.findMany({
      where: {
        ...whereAny,
        NOT: {
          specialties: {
            path: ['visible'],
            equals: false,
          } as any,
        },
      },
      select: {
        id: true,
        displayName: true,
        address: true,
        lat: true,
        lng: true,
        specialties: true,
        bio: true,
      },
    });

    // Toujours inclure tous les types (vet, daycare, petshop) - le filtrage par type
    // doit être fait côté client, pas basé sur le status d'approbation
    const allowed = new Set(['vet', 'daycare', 'petshop']);

    const filtered = rows.filter((p) => {
      const sp: any = p.specialties ?? {};
      const kind = (sp?.kind ?? '').toString().toLowerCase();
      const hasSpecies = Array.isArray(sp?.species) && sp.species.length > 0;
      return allowed.has(kind) || hasSpecies || !kind;
    });

    const enriched = await Promise.all(
      filtered.map(async (p) => {
        let plat: number | null = typeof p.lat === 'number' ? (p.lat as number) : null;
        let plng: number | null = typeof p.lng === 'number' ? (p.lng as number) : null;

        if (!(this.isFiniteNonZero(plat) && this.isFiniteNonZero(plng))) {
          let url = this.maps.getMapsUrlFromSpecialties(p.specialties);
          if (url) {
            url = this.maps.sanitizeMapsUrl(url);
            if (this.maps.isShortGoogleMapsUrl(url)) {
              const expanded = await this.maps.expandShortGoogleMapsUrl(url);
              if (expanded) url = this.maps.sanitizeMapsUrl(expanded);
            }
            // center=false → privilégie POI
            const parsed = this.maps.parseLatLngFromGoogleUrl(url, false);
            if (parsed) {
              plat = parsed.lat;
              plng = parsed.lng;
            }
          }
        }

        const hasCoords = this.isFiniteNonZero(plat) && this.isFiniteNonZero(plng);
        const distance_km =
          hasCenter && hasCoords
            ? +this.haversineKm(lat, lng, plat as number, plng as number).toFixed(2)
            : undefined;

        return {
          id: p.id,
          displayName: p.displayName,
          address: p.address,
          lat: hasCoords ? (plat as number) : null,
          lng: hasCoords ? (plng as number) : null,
          specialties: p.specialties,
          bio: p.bio,
          ...(distance_km !== undefined ? { distance_km } : {}),
        };
      })
    );

    const pool = !wantAll && hasCenter
      ? enriched.filter((r: any) => typeof r.distance_km === 'number' && r.distance_km <= radiusKm)
      : enriched;

    pool.sort((a: any, b: any) => {
      const da = typeof a.distance_km === 'number' ? a.distance_km : undefined;
      const db = typeof b.distance_km === 'number' ? b.distance_km : undefined;
      if (da !== undefined && db !== undefined) return da - db;
      if (da !== undefined) return -1;
      if (db !== undefined) return 1;
      const na = (a.displayName ?? '').toString().toLowerCase();
      const nb = (b.displayName ?? '').toString().toLowerCase();
      return na.localeCompare(nb);
    });

    return pool.slice(offset, offset + limit);
  }

  /* =================== Provider (public) =================== */

  async providerDetails(providerId: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { id: providerId } });
    if (!prov) throw new NotFoundException('Provider not found');
    return prov;
  }

  async listServices(providerId: string) {
    const rows = await this.prisma.service.findMany({
      where: { providerId, archivedAt: null },
      orderBy: { title: 'asc' },
      select: {
        id: true,
        providerId: true,
        title: true,
        description: true,
        price: true,
        durationMin: true,
      },
    });

    return rows.map((s) => ([
      s.id,
      s.providerId,
      s.title,
      s.description ?? '',
      s.durationMin,
      s.price == null ? null : (s.price as Prisma.Decimal).toNumber(),
    ])).map(([id, providerIdX, title, description, durationMin, price]) => ({
      id, providerId: providerIdX as string, title: title as string,
      description: description as string, durationMin: durationMin as number,
      price: price as number | null,
    }));
  }

  /* =================== Provider (moi) =================== */

  async myProvider(userId: string) {
    return this.prisma.providerProfile.findUnique({ where: { userId } });
  }

async upsertMyProvider(userId: string, dto: any) {
  const { displayName, bio, address, specialties, timezone } = dto ?? {};
  if (!displayName || String(displayName).trim().length === 0) {
    throw new ForbiddenException('displayName is required');
  }

  const existing = await this.prisma.providerProfile.findUnique({ where: { userId } });

  const prevUrlRaw = existing ? this.maps.getMapsUrlFromSpecialties(existing.specialties) : null;
  const prevUrl = prevUrlRaw ? this.maps.sanitizeMapsUrl(prevUrlRaw) : null;

  const clientGaveCoords = this.isFiniteNonZero(dto?.lat) && this.isFiniteNonZero(dto?.lng);

  // détection d’effacement explicite
  const aliases = [
    dto?.mapsUrl,
    dto?.specialties?.mapsUrl,
    dto?.specialties?.googleMapsUrl,
    dto?.specialties?.maps_url,
    dto?.specialties?.google_maps_url,
  ];
  const explicitClear = aliases.some((v: any) => typeof v === 'string' && v.trim() === '');

  let lat: number | null = clientGaveCoords
    ? Number(dto.lat)
    : (this.isFiniteNonZero(existing?.lat) ? existing!.lat! : null);
  let lng: number | null = clientGaveCoords
    ? Number(dto.lng)
    : (this.isFiniteNonZero(existing?.lng) ? existing!.lng! : null);

  // URL entrante unifiée (sauf si clear explicite)
  let mapsUrl = explicitClear ? undefined : this.getIncomingMapsUrl(dto, prevUrl);

  // --- NOUVEAU: on tente expansion + parsing en une fois
  let gotFromUrl = false; // drapeau "coords fraîches depuis l'URL"
  if (mapsUrl) {
    const expanded = await this.maps.expandAndParse(mapsUrl, false);
    if (expanded?.finalUrl) {
      mapsUrl = this.maps.sanitizeMapsUrl(expanded.finalUrl);
    }
    if (!clientGaveCoords) {
      if (this.isFiniteNonZero(expanded?.lat)) { lat = expanded!.lat!; gotFromUrl = true; }
      if (this.isFiniteNonZero(expanded?.lng)) { lng = expanded!.lng!; gotFromUrl = gotFromUrl || true; }
    }
  }

  // specialties normalisé — ne réinjecte jamais l’ancien lien si clear ou nouveau présent
  let normalized: Record<string, any> | undefined = undefined;

  if (explicitClear) {
    const base = { ...(existing?.specialties as any ?? {}) };
    delete base.mapsUrl;
    delete base.maps_url;
    delete base.googleMapsUrl;
    delete base.google_maps_url;
    if (!base.kind) base.kind = 'vet';
    normalized = base;
  } else if (specialties && typeof specialties === 'object') {
    const tmp = { ...(specialties as Record<string, any>) };
    const effectiveUrl = this.maps.getMapsUrlFromSpecialties(tmp) ?? mapsUrl ?? undefined;

    if (effectiveUrl) {
      let finalUrl = this.maps.sanitizeMapsUrl(effectiveUrl);
      // IMPORTANT: on ne centre que si coords viennent du client ou de l’URL
      if ((clientGaveCoords || gotFromUrl) && this.isFiniteNonZero(lat) && this.isFiniteNonZero(lng)) {
        // centre uniquement si c’est déjà une longue URL google maps
        if (/^https?:\/\/[^/]*google\.[^/]+\/maps\//i.test(finalUrl)) {
          finalUrl = this.maps.ensureAtCenter(finalUrl, lat!, lng!);
        }
      }
      tmp.mapsUrl = this.maps.sanitizeMapsUrl(finalUrl);
    } else {
      delete (tmp as any).mapsUrl;
      delete (tmp as any).maps_url;
      delete (tmp as any).googleMapsUrl;
      delete (tmp as any).google_maps_url;
    }
    if (!tmp.kind) tmp.kind = 'vet';
    normalized = tmp;
  } else if (mapsUrl) {
    let finalUrl = this.maps.sanitizeMapsUrl(mapsUrl);
    if ((clientGaveCoords || gotFromUrl) && this.isFiniteNonZero(lat) && this.isFiniteNonZero(lng)) {
      if (/^https?:\/\/[^/]*google\.[^/]+\/maps\//i.test(finalUrl)) {
        finalUrl = this.maps.ensureAtCenter(finalUrl, lat!, lng!);
      }
    }
    normalized = { kind: 'vet', mapsUrl: this.maps.sanitizeMapsUrl(finalUrl) };
  }

  if (existing) {
    const data: Prisma.ProviderProfileUpdateInput = {
      displayName,
      bio: bio ?? existing.bio,
      address: address ?? existing.address,
      timezone: timezone ?? existing.timezone,
    };
    if (this.isFiniteNonZero(lat)) data.lat = lat!;
    if (this.isFiniteNonZero(lng)) data.lng = lng!;
    if (normalized) data.specialties = normalized as Prisma.InputJsonValue;

    return this.prisma.providerProfile.update({ where: { userId }, data });
  }

  const createData: Prisma.ProviderProfileCreateInput = {
    user: { connect: { id: userId } },
    displayName,
    bio: bio ?? null,
    address: address ?? null,
    timezone: timezone ?? null,
  };
  if (this.isFiniteNonZero(lat)) createData.lat = lat!;
  if (this.isFiniteNonZero(lng)) createData.lng = lng!;
  if (normalized) createData.specialties = normalized as Prisma.InputJsonValue;

  return this.prisma.providerProfile.create({ data: createData });
}


  /* =================== Services (moi) =================== */

  private async requireMyProvider(userId: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('No provider profile for this user');
    return prov;
  }

  async myServices(userId: string) {
    const prov = await this.requireMyProvider(userId);
    const rows = await this.prisma.service.findMany({
      where: { providerId: prov.id, archivedAt: null },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        providerId: true,
        title: true,
        description: true,
        price: true,
        durationMin: true,
        archivedAt: true,
        createdAt: true,
      },
    });

    return rows.map((s) => ({
      ...s,
      price: s.price == null ? null : (s.price as Prisma.Decimal).toNumber(),
    }));
  }

  async createMyService(userId: string, dto: any) {
    const prov = await this.requireMyProvider(userId);

    const title = String(dto?.title ?? '').trim();
    const durationMin = Number(dto?.durationMin);
    const priceNum = dto?.price !== undefined && dto?.price !== null ? Number(dto.price) : 0;

    if (!title) throw new ForbiddenException('title is required');
    if (!Number.isFinite(durationMin) || durationMin < 15) {
      throw new ForbiddenException('durationMin must be >= 15');
    }
    if (!Number.isFinite(priceNum) || priceNum < 0) {
      throw new ForbiddenException('price must be a positive number');
    }

    const data: Prisma.ServiceUncheckedCreateInput = {
      providerId: prov.id,
      title,
      durationMin,
      price: new Prisma.Decimal(priceNum),
      description: dto?.description ?? null,
    };

    return this.prisma.service.create({ data });
  }

  async updateMyService(userId: string, serviceId: string, dto: any) {
    const prov = await this.requireMyProvider(userId);

    const found = await this.prisma.service.findFirst({
      where: { id: serviceId, providerId: prov.id },
    });
    if (!found) throw new NotFoundException('Service not found');

    const data: Prisma.ServiceUncheckedUpdateInput = {};
    if (dto?.title !== undefined) data.title = String(dto.title).trim();
    if (dto?.durationMin !== undefined) {
      const d = Number(dto.durationMin);
      if (!Number.isFinite(d) || d < 15) throw new ForbiddenException('durationMin must be >= 15');
      data.durationMin = d;
    }
    if (dto?.price !== undefined) {
      const p = Number(dto.price);
      if (!Number.isFinite(p) || p < 0) throw new ForbiddenException('price must be a positive number');
      data.price = new Prisma.Decimal(p);
    }
    if (dto?.description !== undefined) {
      const s = String(dto.description).trim();
      data.description = s.length ? s : null;
    }

    return this.prisma.service.update({ where: { id: serviceId }, data });
  }

  async deleteMyService(userId: string, serviceId: string) {
    const prov = await this.requireMyProvider(userId);
    const res = await this.prisma.service.updateMany({
      where: { id: serviceId, providerId: prov.id },
      data: { archivedAt: new Date() },
    });
    if (res.count === 0) throw new NotFoundException('Service introuvable ou non autorisé');
    return { id: serviceId, archivedAt: new Date() };
  }

  /* =================== Admin =================== */

  async listApplications(
    status: 'pending' | 'approved' | 'rejected' | 'all' = 'pending',
    limit = 50,
    offset = 0,
  ) {
    let where: any = {};
    switch (status) {
      case 'pending':
        where = { isApproved: false, rejectedAt: null };
        break;
      case 'approved':
        where = { isApproved: true };
        break;
      case 'rejected':
        where = { rejectedAt: { not: null } };
        break;
      case 'all':
      default:
        where = {};
    }

    return this.prisma.providerProfile.findMany({
      where,
      orderBy: { appliedAt: 'asc' },
      take: limit,
      skip: offset,
      select: {
        id: true,
        userId: true,
        displayName: true,
        address: true,
        isApproved: true,
        appliedAt: true,
        rejectedAt: true,
        rejectionReason: true,
        specialties: true,
        user: {
          select: {
            id: true,
            email: true,
            role: true,
            firstName: true,
            lastName: true,
            phone: true,
          },
        },
      },
    });
  }

  async approveProvider(providerId: string) {
    const prov = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      select: { id: true, userId: true },
    });
    if (!prov) throw new NotFoundException('Provider not found');

    const { provider, user } = await this.prisma.$transaction(async (tx) => {
      const provider = await tx.providerProfile.update({
        where: { id: providerId },
        data: { isApproved: true, rejectedAt: null, rejectionReason: null },
      });
      const user = await tx.user.update({
        where: { id: prov.userId },
        data: { role: $Enums.Role.PRO },
      });
      return { provider, user };
    });

    await this.ensureGeoAndVisibility(providerId);

    return {
      provider,
      user: { id: user.id, email: user.email, role: user.role },
    };
  }

  async rejectProvider(providerId: string, reason?: string) {
    const exists = await this.prisma.providerProfile.findUnique({
      where: { id: providerId },
      select: { id: true },
    });
    if (!exists) throw new NotFoundException('Provider not found');

    const updated = await this.prisma.providerProfile.update({
      where: { id: providerId },
      data: {
        isApproved: false,
        rejectedAt: new Date(),
        rejectionReason: reason ?? 'Votre demande a été refusée.',
      },
      select: { id: true, isApproved: true, rejectedAt: true, rejectionReason: true },
    });

    return { success: true, provider: updated };
  }

  /** Backfill admin : étend maps.app.goo.gl → parse coords → met à jour lat/lng + mapsUrl */
  async backfillLatLngAndExpandShortUrls(limit = 500) {
    const candidates = await this.prisma.providerProfile.findMany({
      where: {
        OR: [
          { lat: null },
          { lng: null },
          { lat: 0 },
          { lng: 0 },
          { specialties: { path: ['mapsUrl'], string_contains: 'maps.app.goo.gl' } as any },
          { specialties: { path: ['mapsUrl'], string_contains: 'goo.gle'        } as any },
          { specialties: { path: ['mapsUrl'], string_contains: 'g.page'         } as any },
          { specialties: { path: ['mapsUrl'], string_contains: 'goo.gl'         } as any },
        ],
      },
      take: limit,
    });

    let updated = 0;

    for (const p of candidates) {
      const prevUrl = this.maps.getMapsUrlFromSpecialties(p.specialties);
      let mapsUrl: string | undefined = prevUrl ?? undefined;
      if (mapsUrl) mapsUrl = this.maps.sanitizeMapsUrl(mapsUrl);

      if (mapsUrl && this.maps.isShortGoogleMapsUrl(mapsUrl)) {
        const expanded = await this.maps.expandShortGoogleMapsUrl(mapsUrl);
        if (expanded) mapsUrl = this.maps.sanitizeMapsUrl(expanded);
      }

      let lat: number | undefined = p.lat ?? undefined;
      let lng: number | undefined = p.lng ?? undefined;

      if (mapsUrl) {
        // POI-first
        const parsed = this.maps.parseLatLngFromGoogleUrl(mapsUrl, false);
        if (parsed) {
          lat = parsed.lat;
          lng = parsed.lng;

          if (this.isFiniteNonZero(lat) && this.isFiniteNonZero(lng)) {
            mapsUrl = this.maps.ensureAtCenter(mapsUrl, lat!, lng!);
            mapsUrl = this.maps.sanitizeMapsUrl(mapsUrl);
          }
        }
      }

      const data: Prisma.ProviderProfileUpdateInput = {};
      if (this.isFiniteNonZero(lat)) data.lat = lat!;
      if (this.isFiniteNonZero(lng)) data.lng = lng!;
      if (mapsUrl && mapsUrl !== prevUrl) {
        const merged = { ...(p.specialties as any ?? {}), mapsUrl };
        data.specialties = merged as Prisma.InputJsonValue;
      }

      if (Object.keys(data).length > 0) {
        await this.prisma.providerProfile.update({ where: { id: p.id }, data });
        updated++;
      }
    }

    return { scanned: candidates.length, updated };
  }

  async reapplyMyProvider(userId: string) {
    const prov = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!prov) throw new NotFoundException('No provider profile to re-apply');

    return this.prisma.providerProfile.update({
      where: { id: prov.id },
      data: {
        isApproved: false,
        rejectedAt: null,
        rejectionReason: null,
        appliedAt: new Date(),
      },
      select: { id: true, isApproved: true, appliedAt: true, rejectedAt: true, rejectionReason: true },
    });
  }
}
