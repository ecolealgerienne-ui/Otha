// lib/features/daycare/daycare_list_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

const _primary = Color(0xFF00ACC1);
const _primarySoft = Color(0xFFE0F7FA);
const _ink = Color(0xFF222222);

/// Provider qui charge la liste des garderies autour du centre
final daycareProvidersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);

  // ---------- 1) Centre utilisateur: DEVICE d'abord, puis PROFIL, sinon fallback ----------
  Future<({double lat, double lng})> getCenter() async {
    // a) Device (GPS/Wi-Fi)
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
  final raw = await api.nearby(
    lat: center.lat,
    lng: center.lng,
    radiusKm: 40000.0,
    limit: 5000,
    status: 'approved',
  );

  // ---------- 3) Normalisation légère côté client ----------
  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // Haversine (fallback au cas où le backend n'aurait pas mis distance_km)
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

  // Filter to only show daycares
  final daycaresOnly = rows.where((m) {
    final specialties = m['specialties'] as Map<String, dynamic>?;
    final kind = (specialties?['kind'] ?? '').toString().toLowerCase();
    return kind == 'daycare';
  }).toList();

  // On prépare l'output minimum: id, displayName, bio, address, distanceKm, specialties
  final mapped = daycaresOnly.map((m) {
    final id = (m['id'] ?? m['providerId'] ?? '').toString();
    final name = (m['displayName'] ?? m['name'] ?? 'Garderie').toString();
    final specs = m['specialties'] as Map<String, dynamic>?;
    final bio = (specs?['bio'] ?? m['bio'] ?? '').toString();
    final address = (m['address'] ?? '').toString();

    // Images
    final images = specs?['images'] as List?;
    final imageUrls = images?.map((e) => e.toString()).toList() ?? <String>[];

    // Capacité
    final capacity = specs?['capacity'];

    // Types d'animaux
    final animalTypes = specs?['animalTypes'] as List?;
    final types = animalTypes?.map((e) => e.toString()).toList() ?? <String>[];

    // Tarifs
    final pricing = specs?['pricing'] as Map?;
    final hourlyRate = pricing?['hourlyRate'];
    final dailyRate = pricing?['dailyRate'];

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
      'address': address,
      'distanceKm': dKm,
      'images': imageUrls,
      'capacity': capacity,
      'animalTypes': types,
      'hourlyRate': hourlyRate,
      'dailyRate': dailyRate,
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

class DaycareListScreen extends ConsumerStatefulWidget {
  const DaycareListScreen({super.key});
  @override
  ConsumerState<DaycareListScreen> createState() => _DaycareListScreenState();
}

class _DaycareListScreenState extends ConsumerState<DaycareListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Réévalue à chaque ouverture (nouvelle géoloc)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(daycareProvidersListProvider);
    });
  }

  List<Map<String, dynamic>> _filterDaycares(List<Map<String, dynamic>> daycares) {
    return daycares.where((daycare) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final name = (daycare['displayName'] ?? '').toString().toLowerCase();
        final address = (daycare['address'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !address.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(daycareProvidersListProvider);

    return Theme(
      data: _themed(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('Garderies'),
          backgroundColor: Colors.white,
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Erreur: $err')),
          data: (daycares) {
            final filtered = _filterDaycares(daycares);

            return Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher une garderie...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),

                // List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Aucune garderie disponible'
                                    : 'Aucun résultat',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(daycareProvidersListProvider);
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _DaycareCard(daycare: filtered[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  ThemeData _themed(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _primary,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _DaycareCard extends StatelessWidget {
  final Map<String, dynamic> daycare;

  const _DaycareCard({required this.daycare});

  @override
  Widget build(BuildContext context) {
    final name = (daycare['displayName'] ?? 'Garderie').toString();
    final bio = (daycare['bio'] ?? '').toString();
    final address = (daycare['address'] ?? '').toString();
    final distanceKm = daycare['distanceKm'] as double?;
    final images = daycare['images'] as List<dynamic>? ?? [];
    final firstImage = images.isNotEmpty ? images.first.toString() : null;
    final capacity = daycare['capacity'];
    final animalTypes = daycare['animalTypes'] as List<dynamic>? ?? [];
    final hourlyRate = daycare['hourlyRate'];
    final dailyRate = daycare['dailyRate'];

    String? priceText;
    if (hourlyRate != null) {
      priceText = '$hourlyRate DA/h';
    } else if (dailyRate != null) {
      priceText = '$dailyRate DA/j';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final id = (daycare['id'] ?? '').toString();
            if (id.isNotEmpty) {
              context.push('/explore/daycare/$id', extra: daycare);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: firstImage != null
                      ? Image.network(
                          firstImage,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderImage(),
                        )
                      : _placeholderImage(),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (distanceKm != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${distanceKm.toStringAsFixed(1)} km',
                          style: TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (animalTypes.isNotEmpty || priceText != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (capacity != null)
                              _chip(Icons.pets, 'Capacité: $capacity', Colors.orange),
                            if (priceText != null)
                              _chip(Icons.monetization_on, priceText, Colors.green),
                            ...animalTypes.take(2).map((t) => _chip(Icons.pets, t.toString(), _primary)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.pets, size: 32, color: _primary),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
