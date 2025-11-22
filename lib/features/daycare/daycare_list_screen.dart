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

// Commission cachée ajoutée au prix affiché
const kDaycareCommissionDa = 100;

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
          final last = await Geolocator.getLastKnownPosition().timeout(
            const Duration(milliseconds: 300),
            onTimeout: () => null,
          );
          if (last != null) {
            return (lat: last.latitude, lng: last.longitude);
          }
          try {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
            ).timeout(const Duration(seconds: 2));
            return (lat: pos.latitude, lng: pos.longitude);
          } on TimeoutException {
            // continue
          } catch (_) {
            // continue
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

  final raw = await api.nearby(
    lat: center.lat,
    lng: center.lng,
    radiusKm: 40000.0,
    limit: 5000,
    status: 'approved',
  );

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

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

  final mapped = daycaresOnly.map((m) {
    final id = (m['id'] ?? m['providerId'] ?? '').toString();
    final name = (m['displayName'] ?? m['name'] ?? 'Garderie').toString();
    final specs = m['specialties'] as Map<String, dynamic>?;
    final bio = (specs?['bio'] ?? m['bio'] ?? '').toString();
    final address = (m['address'] ?? '').toString();

    final images = specs?['images'] as List?;
    final imageUrls = images?.map((e) => e.toString()).toList() ?? <String>[];

    final capacity = specs?['capacity'];

    final animalTypes = specs?['animalTypes'] as List?;
    final types = animalTypes?.map((e) => e.toString()).toList() ?? <String>[];

    final pricing = specs?['pricing'] as Map?;
    final hourlyRate = pricing?['hourlyRate'];
    final dailyRate = pricing?['dailyRate'];

    final availability = specs?['availability'] as Map?;
    final is24_7 = availability?['is24_7'] == true;
    final openingTime = availability?['openingTime']?.toString() ?? '08:00';
    final closingTime = availability?['closingTime']?.toString() ?? '20:00';

    double? dKm = _toDouble(m['distance_km']);
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
      'is24_7': is24_7,
      'openingTime': openingTime,
      'closingTime': closingTime,
    };
  }).toList();

  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final m in mapped) {
    final id = (m['id'] as String?) ?? '';
    final key = id.isNotEmpty
        ? 'id:$id'
        : 'na:${(m['displayName'] ?? '').toString().toLowerCase()}';
    if (seen.add(key)) unique.add(m);
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(daycareProvidersListProvider);
    });
  }

  List<Map<String, dynamic>> _filterDaycares(List<Map<String, dynamic>> daycares) {
    return daycares.where((daycare) {
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

                // List - Style Booking.com
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _BookingComStyleCard(daycare: filtered[i]),
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

class _BookingComStyleCard extends StatefulWidget {
  final Map<String, dynamic> daycare;

  const _BookingComStyleCard({required this.daycare});

  @override
  State<_BookingComStyleCard> createState() => _BookingComStyleCardState();
}

class _BookingComStyleCardState extends State<_BookingComStyleCard> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.daycare['displayName'] ?? 'Garderie').toString();
    final bio = (widget.daycare['bio'] ?? '').toString();
    final address = (widget.daycare['address'] ?? '').toString();
    final distanceKm = widget.daycare['distanceKm'] as double?;
    final images = widget.daycare['images'] as List<dynamic>? ?? [];
    final capacity = widget.daycare['capacity'];
    final animalTypes = widget.daycare['animalTypes'] as List<dynamic>? ?? [];
    final hourlyRate = widget.daycare['hourlyRate'];
    final dailyRate = widget.daycare['dailyRate'];
    final is24_7 = widget.daycare['is24_7'] == true;
    final openingTime = widget.daycare['openingTime']?.toString() ?? '08:00';
    final closingTime = widget.daycare['closingTime']?.toString() ?? '20:00';

    // Simuler places restantes (dans un vrai système, ça viendrait du backend)
    final remainingSpots = capacity != null ? (capacity as int) - ((capacity as int) ~/ 3) : null;

    String? priceText;
    if (hourlyRate != null) {
      final priceWithCommission = (hourlyRate as int) + kDaycareCommissionDa;
      priceText = 'À partir de $priceWithCommission DA/heure';
    } else if (dailyRate != null) {
      final priceWithCommission = (dailyRate as int) + kDaycareCommissionDa;
      priceText = 'À partir de $priceWithCommission DA/jour';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final id = (widget.daycare['id'] ?? '').toString();
            if (id.isNotEmpty) {
              context.push('/explore/daycare/$id', extra: widget.daycare);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grande image avec slider (style Booking.com)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      // Images
                      images.isNotEmpty
                          ? PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() => _currentImageIndex = index);
                              },
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                return Image.network(
                                  images[index].toString(),
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _placeholderImage(),
                                );
                              },
                            )
                          : _placeholderImage(),

                      // Distance badge (top left)
                      if (distanceKm != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Image indicators (bottom center)
                      if (images.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Contenu
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom de la garderie
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Horaires
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: _primary),
                        const SizedBox(width: 6),
                        Text(
                          is24_7 ? 'Ouvert 24h/24 - 7j/7' : 'Ouvert $openingTime - $closingTime',
                          style: TextStyle(
                            fontSize: 13,
                            color: _primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        bio,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Capacité et places restantes
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (capacity != null)
                          _infoBadge(
                            Icons.pets,
                            'Capacité: $capacity',
                            Colors.orange,
                          ),
                        if (remainingSpots != null && remainingSpots > 0)
                          _infoBadge(
                            Icons.check_circle,
                            '$remainingSpots places restantes',
                            Colors.green,
                          ),
                        if (remainingSpots != null && remainingSpots <= 0)
                          _infoBadge(
                            Icons.warning,
                            'Complet',
                            Colors.red,
                          ),
                      ],
                    ),

                    if (animalTypes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: animalTypes.take(4).map((type) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primarySoft,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              type.toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    if (priceText != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            priceText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: _primary),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: _primarySoft,
      ),
      child: const Center(
        child: Icon(Icons.pets, size: 64, color: _primary),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
