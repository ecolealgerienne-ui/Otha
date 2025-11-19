// lib/features/vets/vets_list_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

/// Provider qui charge la liste des vétos autour du centre (device -> profil -> fallback)
final _vetsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);

  // ---------- 1) Centre utilisateur: DEVICE d'abord, puis PROFIL, sinon fallback ----------
  Future<({double lat, double lng})> getCenter() async {
    // a) Device (GPS/Wi-Fi) — timeouts courts pour éviter les spinners infinis
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          // Last known (ultra rapide)
          final last = await Geolocator.getLastKnownPosition().timeout(
            const Duration(milliseconds: 300),
            onTimeout: () => null,
          );
          if (last != null) {
            return (lat: last.latitude, lng: last.longitude);
          }
          // Current position (timeout court)
          try {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
            ).timeout(const Duration(seconds: 2));
            return (lat: pos.latitude, lng: pos.longitude);
          } on TimeoutException {
            // On tombera sur profil/fallback
          } catch (_) {
            // ignore et on tombe sur profil/fallback
          }
        }
      }
    } catch (_) {/* ignore */}

    // b) Profil utilisateur (fallback)
    final me = ref.read(sessionProvider).user ?? {};
    final pLat = (me['lat'] as num?)?.toDouble();
    final pLng = (me['lng'] as num?)?.toDouble();
    if (pLat != null && pLng != null && pLat != 0 && pLng != 0) {
      return (lat: pLat, lng: pLng);
    }

    // c) Fallback absolu (Alger)
    return (lat: 36.75, lng: 3.06);
  }

  final center = await getCenter();

  // ---------- 2) API: on récupère les pros depuis le backend ----------
  // Le backend:
  //  - exclut specialties.visible == false
  //  - retourne uniquement les 'vet' par défaut (status='approved')
  //  - enrichit lat/lng depuis mapsUrl si absent
  //  - calcule distance_km si un centre est fourni
  final raw = await api.nearby(
    lat: center.lat,
    lng: center.lng,
    radiusKm: 40000.0, // grand rayon pour "tout voir" (ajuste si besoin)
    limit: 5000,
    status: 'approved',
  );

  // ---------- 3) Normalisation légère côté client ----------
  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // Haversine (fallback au cas où le backend n’aurait pas mis distance_km)
  double? _haversineKm(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    const R = 6371.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat - center.lat);
    final dLng = toRad(lng - center.lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(center.lat)) * math.cos(toRad(lat)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  // Filter to only show vets (exclude petshops and daycares)
  final vetsOnly = rows.where((m) {
    final specialties = m['specialties'] as Map<String, dynamic>?;
    final kind = (specialties?['kind'] ?? '').toString().toLowerCase();
    return kind == 'vet' || kind.isEmpty; // Include if vet or no kind specified
  }).toList();

  // On prépare l'output minimum: id, displayName, bio, distanceKm
  final mapped = vetsOnly.map((m) {
    final id = (m['id'] ?? m['providerId'] ?? '').toString();
    final name = (m['displayName'] ?? m['name'] ?? 'Vétérinaire').toString();
    final bio = (m['bio'] ?? '').toString();

    // distance_km fournie par le backend si centre valide
    double? dKm = _toDouble(m['distance_km']);

    // Fallback si distance_km manquante: calcule localement avec lat/lng
    if (dKm == null) {
      final lat = _toDouble(m['lat']);
      final lng = _toDouble(m['lng']);
      dKm = _haversineKm(lat, lng);
    }

    return <String, dynamic>{
      'id': id,
      'displayName': name,
      'bio': bio,
      'distanceKm': dKm,
    };
  }).toList();

  // Dédoublonnage soft
  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final m in mapped) {
    final id = (m['id'] as String?) ?? '';
    final key = id.isNotEmpty
        ? 'id:$id'
        : 'na:${(m['displayName'] ?? '').toString().toLowerCase()}';
    if (seen.add(key)) unique.add(m);
  }

  // Tri: distance si dispo, sinon nom
  unique.sort((a, b) {
    final da = a['distanceKm'] as double?;
    final db = b['distanceKm'] as double?;
    if (da != null && db != null) return da.compareTo(db);
    if (da != null) return -1;
    if (db != null) return 1;
    final na = (a['displayName'] ?? '').toString().toLowerCase();
    final nb = (b['displayName'] ?? '').toString().toLowerCase();
    return na.compareTo(nb);
  });

  return unique;
});

class VetListScreen extends ConsumerStatefulWidget {
  const VetListScreen({super.key});
  @override
  ConsumerState<VetListScreen> createState() => _VetListScreenState();
}

class _VetListScreenState extends ConsumerState<VetListScreen> {
  @override
  void initState() {
    super.initState();
    // Réévalue à chaque ouverture (nouvelle géoloc)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(_vetsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_vetsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vétérinaires'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(_vetsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('Aucun vétérinaire trouvé.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_vetsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final m = rows[i];
                return _VetRow(
                  id: (m['id'] ?? '').toString(),
                  name: (m['displayName'] ?? 'Vétérinaire').toString(),
                  distanceKm: m['distanceKm'] as double?,
                  bio: (m['bio'] ?? '').toString(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _VetRow extends StatelessWidget {
  const _VetRow({
    required this.id,
    required this.name,
    required this.bio,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String bio;
  final double? distanceKm;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final inits = parts.take(2).map((e) => e[0]).join().toUpperCase();
    return inits.isEmpty ? 'DR' : inits;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/explore/vets/$id'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF36C6C),
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.place, size: 16, color: Colors.black45),
                          const SizedBox(width: 4),
                          Text(
                            '${distanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(color: Colors.black.withOpacity(.7)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Bio (2 lignes max)
                    if (bio.isNotEmpty)
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(.7),
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
