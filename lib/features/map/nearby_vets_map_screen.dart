// lib/features/map/nearby_vets_map_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

const _coral = Color(0xFFF36C6C);
const _coralLight = Color(0xFFFFEEF0);
const _coralDark = Color(0xFFE85555);
const _ink = Color(0xFF222222);

// ---------------- Centre utilisateur (DEVICE -> PROFIL -> fallback) ----------------
final _userCenterProvider = FutureProvider<LatLng>((ref) async {
  try {
    if (await Geolocator.isLocationServiceEnabled()) {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        final last = await Geolocator.getLastKnownPosition()
            .timeout(const Duration(milliseconds: 300), onTimeout: () => null);
        if (last != null) return LatLng(last.latitude, last.longitude);
        final cur = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 2));
        return LatLng(cur.latitude, cur.longitude);
      }
    }
  } catch (_) {}
  final me = ref.read(sessionProvider).user ?? {};
  final pLat = (me['lat'] as num?)?.toDouble();
  final pLng = (me['lng'] as num?)?.toDouble();
  if (pLat != null && pLng != null && pLat != 0 && pLng != 0) return LatLng(pLat, pLng);
  return const LatLng(36.75, 3.06);
});

// ID du provider courant (pour surligner mon marqueur)
final _myProviderIdProvider = FutureProvider<String?>((ref) async {
  final api = ref.read(apiProvider);
  final meProv = await api.myProvider();
  final id = (meProv?['id'] ?? '').toString();
  return id.isEmpty ? null : id;
});

// ---------------- Tous les pros ----------------
final allVetsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final center = await ref.watch(_userCenterProvider.future);

  final raw = await api.nearby(
    lat: center.latitude,
    lng: center.longitude,
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
    final dLat = toRad(lat - center.latitude);
    final dLng = toRad(lng - center.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(center.latitude)) * math.cos(toRad(lat)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  bool _validNum(dynamic v) => v is num && v.isFinite && v != 0;

  final out = <Map<String, dynamic>>[];
  for (final m in rows) {
    final lat = _toDouble(m['lat']);
    final lng = _toDouble(m['lng']);
    if (!_validNum(lat) || !_validNum(lng)) continue;
    m['__lat'] = lat;
    m['__lng'] = lng;
    m['__distKm'] = _toDouble(m['distance_km']) ?? _haversineKm(lat, lng);
    out.add(m);
  }
  return out;
});

// ---------------- Écran ----------------
class NearbyVetsMapScreen extends ConsumerStatefulWidget {
  const NearbyVetsMapScreen({super.key});
  @override
  ConsumerState<NearbyVetsMapScreen> createState() => _NearbyVetsMapScreenState();
}

class _NearbyVetsMapScreenState extends ConsumerState<NearbyVetsMapScreen>
    with SingleTickerProviderStateMixin {
  final _mapCtl = MapController();
  LatLng? _center;

  // Filtres
  String _selectedFilter = 'all'; // 'all', 'vet', 'daycare', 'petshop'

  // Sheet controller
  final _sheetController = DraggableScrollableController();

  // Current selected index
  int _selectedIndex = -1;

  // Scroll controller for list
  final _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = await ref.read(_userCenterProvider.future);
      if (!mounted) return;
      setState(() => _center = c);
      _mapCtl.move(c, 13);
    });

    _listScrollController.addListener(_onListScroll);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onListScroll() {
    // Calculate which card is most visible based on scroll position
    if (!_listScrollController.hasClients) return;

    final itemHeight = 130.0; // Height of each card + padding
    final offset = _listScrollController.offset;
    final newIndex = (offset / itemHeight).round();

    if (newIndex != _selectedIndex && newIndex >= 0) {
      _onCardFocused(newIndex);
    }
  }

  void _onCardFocused(int index) {
    final vetsAsync = ref.read(allVetsProvider);
    vetsAsync.whenData((rows) {
      final filtered = _getFilteredList(rows);
      if (index >= 0 && index < filtered.length) {
        setState(() => _selectedIndex = index);
        final m = filtered[index];
        final lat = (m['__lat'] as double);
        final lng = (m['__lng'] as double);
        _mapCtl.move(LatLng(lat, lng), 15);
      }
    });
  }

  String _kindOf(Map<String, dynamic> m) {
    final sp = (m['specialties'] is Map) ? Map<String, dynamic>.from(m['specialties']) : const {};
    final k = (sp['kind'] ?? m['kind'] ?? '').toString().trim().toLowerCase();
    if (k == 'vet' || k == 'veto' || k == 'vétérinaire') return 'vet';
    if (k == 'daycare' || k == 'garderie') return 'daycare';
    if (k == 'petshop' || k == 'shop') return 'petshop';
    return 'vet';
  }

  bool _explicitInvisible(Map<String, dynamic> m) {
    bool isFalse(dynamic v) {
      if (v is bool) return v == false;
      if (v is String) return v.toLowerCase() == 'false';
      return false;
    }
    if (isFalse(m['visible'])) return true;
    final sp = (m['specialties'] is Map) ? Map<String, dynamic>.from(m['specialties']) : const {};
    if (isFalse(sp['visible'])) return true;
    return false;
  }

  List<Map<String, dynamic>> _getFilteredList(List<Map<String, dynamic>> rows) {
    final filtered = <Map<String, dynamic>>[];
    for (final m in rows) {
      if (_explicitInvisible(m)) continue;
      final kind = _kindOf(m);
      if (_selectedFilter != 'all' && kind != _selectedFilter) continue;
      filtered.add(m);
    }
    filtered.sort((a, b) {
      final da = (a['__distKm'] as num?)?.toDouble() ?? double.maxFinite;
      final db = (b['__distKm'] as num?)?.toDouble() ?? double.maxFinite;
      return da.compareTo(db);
    });
    return filtered;
  }

  IconData _getKindIcon(String kind) {
    switch (kind) {
      case 'vet': return Icons.local_hospital;
      case 'daycare': return Icons.home;
      case 'petshop': return Icons.shopping_bag;
      default: return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vetsAsync = ref.watch(allVetsProvider);
    final myPidAsync = ref.watch(_myProviderIdProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: vetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (rows) {
          final filtered = _getFilteredList(rows);
          final center = _center ?? const LatLng(36.75, 3.06);
          final myPid = myPidAsync.maybeWhen(data: (v) => v, orElse: () => null);

          // Marqueurs
          final markers = <Marker>[
            // Ma position - cercle bleu pulsant
            Marker(
              width: 24, height: 24, point: center,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ];

          for (int i = 0; i < filtered.length; i++) {
            final m = filtered[i];
            final lat = ((m['__lat'] as num?)?.toDouble())!;
            final lng = ((m['__lng'] as num?)?.toDouble())!;
            final id = (m['id'] ?? '').toString();
            final isMine = (myPid != null && id == myPid);
            final isSelected = i == _selectedIndex;
            final kind = _kindOf(m);

            markers.add(
              Marker(
                width: isSelected ? 56 : 44,
                height: isSelected ? 56 : 44,
                point: LatLng(lat, lng),
                child: GestureDetector(
                  onTap: () => _onMarkerTap(i, filtered),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: _CustomMarker(
                      kind: kind,
                      isSelected: isSelected,
                      isMine: isMine,
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              // --- MAP avec style épuré ---
              FlutterMap(
                mapController: _mapCtl,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  onTap: (_, __) {
                    setState(() => _selectedIndex = -1);
                  },
                ),
                children: [
                  // CartoDB Light - Style minimaliste
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.vethome.app',
                    retinaMode: true,
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // --- TOP BAR: Retour + Filtres ---
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          // Bouton retour
                          _CircleButton(
                            icon: Icons.arrow_back,
                            onTap: () {
                              final nav = Navigator.of(context);
                              if (nav.canPop()) {
                                nav.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                          ),
                          const Spacer(),
                          // Boutons actions
                          _CircleButton(
                            icon: Icons.refresh,
                            onTap: () {
                              ref.invalidate(allVetsProvider);
                              ref.invalidate(_userCenterProvider);
                            },
                          ),
                          const SizedBox(width: 8),
                          _CircleButton(
                            icon: Icons.my_location,
                            onTap: () async {
                              final c = await ref.read(_userCenterProvider.future);
                              if (!mounted) return;
                              setState(() {
                                _center = c;
                                _selectedIndex = -1;
                              });
                              _mapCtl.move(c, 13);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filtres horizontaux
                    _FilterBar(
                      selected: _selectedFilter,
                      counts: _getCounts(rows),
                      onChanged: (v) {
                        setState(() {
                          _selectedFilter = v;
                          _selectedIndex = -1;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // --- BOTTOM SHEET DRAGGABLE ---
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.15,
                minChildSize: 0.15,
                maxChildSize: 0.65,
                snap: true,
                snapSizes: const [0.15, 0.4, 0.65],
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        // Handle bar - draggable
                        SliverToBoxAdapter(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_sheetController.size < 0.4) {
                                _sheetController.animateTo(
                                  0.4,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              } else {
                                _sheetController.animateTo(
                                  0.15,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  // Drag indicator
                                  Container(
                                    width: 48,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Info text
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.keyboard_arrow_up,
                                        color: _coral, size: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${filtered.length} établissement${filtered.length > 1 ? 's' : ''} à proximité',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Liste des providers
                        if (filtered.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Aucun établissement trouvé',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: bottomPadding + 16,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final isActive = i == _selectedIndex;
                                  return _ProviderCard(
                                    provider: filtered[i],
                                    kind: _kindOf(filtered[i]),
                                    isActive: isActive,
                                    onTap: () => _onCardTap(i, filtered, context),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, int> _getCounts(List<Map<String, dynamic>> rows) {
    int vet = 0, daycare = 0, petshop = 0;
    for (final m in rows) {
      if (_explicitInvisible(m)) continue;
      final kind = _kindOf(m);
      if (kind == 'vet') vet++;
      if (kind == 'daycare') daycare++;
      if (kind == 'petshop') petshop++;
    }
    return {'all': vet + daycare + petshop, 'vet': vet, 'daycare': daycare, 'petshop': petshop};
  }

  void _onMarkerTap(int index, List<Map<String, dynamic>> filtered) {
    setState(() => _selectedIndex = index);
    final m = filtered[index];
    final lat = m['__lat'] as double;
    final lng = m['__lng'] as double;

    // Offset pour que le marqueur soit visible au-dessus du sheet
    // On décale vers le bas de ~0.015 degrés (environ 1.5km)
    final offsetLat = lat - 0.012;
    _mapCtl.move(LatLng(offsetLat, lng), 15);

    // Expand sheet and scroll to card
    _sheetController.animateTo(
      0.4,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onCardTap(int index, List<Map<String, dynamic>> filtered, BuildContext context) {
    setState(() => _selectedIndex = index);
    final m = filtered[index];
    final lat = m['__lat'] as double;
    final lng = m['__lng'] as double;

    // Calculer l'offset basé sur la taille du sheet
    // Plus le sheet est grand, plus on décale
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * _sheetController.size;

    // Convertir les pixels en degrés (approximatif)
    // À zoom 15, 1 degré ≈ 111km, donc on calcule le ratio
    final offsetDegrees = (sheetHeight / screenHeight) * 0.025;
    final offsetLat = lat - offsetDegrees;

    _mapCtl.move(LatLng(offsetLat, lng), 15);
  }
}

// ---------------- Custom Marker ----------------
class _CustomMarker extends StatelessWidget {
  final String kind;
  final bool isSelected;
  final bool isMine;

  const _CustomMarker({
    required this.kind,
    required this.isSelected,
    required this.isMine,
  });

  IconData get _icon {
    switch (kind) {
      case 'vet': return Icons.medical_services;
      case 'daycare': return Icons.house;
      case 'petshop': return Icons.shopping_bag;
      default: return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 52.0 : 42.0;
    final iconSize = isSelected ? 24.0 : 20.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Shadow
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _coral.withOpacity(isSelected ? 0.4 : 0.2),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
        ),
        // Main circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isSelected ? _coral : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isMine ? _coralDark : _coral,
              width: isSelected ? 3 : 2,
            ),
          ),
          child: Icon(
            _icon,
            size: iconSize,
            color: isSelected ? Colors.white : _coral,
          ),
        ),
        // Mine indicator
        if (isMine)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _coralDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.star, size: 8, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ---------------- Circle Button ----------------
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: _coral, size: 22),
        ),
      ),
    );
  }
}

// ---------------- Filter Bar ----------------
class _FilterBar extends StatelessWidget {
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: 'Tous',
            count: counts['all'] ?? 0,
            icon: Icons.apps,
            isSelected: selected == 'all',
            onTap: () => onChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Vétérinaires',
            count: counts['vet'] ?? 0,
            icon: Icons.medical_services,
            isSelected: selected == 'vet',
            onTap: () => onChanged('vet'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Garderies',
            count: counts['daycare'] ?? 0,
            icon: Icons.house,
            isSelected: selected == 'daycare',
            onTap: () => onChanged('daycare'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Petshops',
            count: counts['petshop'] ?? 0,
            icon: Icons.shopping_bag,
            isSelected: selected == 'petshop',
            onTap: () => onChanged('petshop'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _coral : Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: isSelected ? 4 : 2,
      shadowColor: isSelected ? _coral.withOpacity(0.3) : Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : _coral,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : _coralLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : _coral,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Provider Card ----------------
class _ProviderCard extends ConsumerWidget {
  final Map<String, dynamic> provider;
  final String kind;
  final bool isActive;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.provider,
    required this.kind,
    required this.isActive,
    required this.onTap,
  });

  String? _photoOf(Map<String, dynamic> m) {
    final p1 = (m['photoUrl'] ?? m['avatar'])?.toString();
    if (p1 != null && p1.isNotEmpty) return p1;
    final user = (m['user'] is Map) ? Map<String, dynamic>.from(m['user']) : const {};
    final p2 = (user['photoUrl'] ?? user['avatar'])?.toString();
    return (p2 != null && p2.isNotEmpty) ? p2 : null;
  }

  String _formatDistance(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String _getKindLabel(String kind) {
    switch (kind) {
      case 'vet': return 'Vétérinaire';
      case 'daycare': return 'Garderie';
      case 'petshop': return 'Petshop';
      default: return 'Établissement';
    }
  }

  IconData _getKindIcon(String kind) {
    switch (kind) {
      case 'vet': return Icons.medical_services;
      case 'daycare': return Icons.house;
      case 'petshop': return Icons.shopping_bag;
      default: return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = _photoOf(provider);
    final name = (provider['displayName'] ?? 'Professionnel').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final address = (provider['address'] ?? '').toString();
    final distKm = (provider['__distKm'] as num?)?.toDouble();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? _coralLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? _coral : Colors.grey[200]!,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: _coral.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                height: 70,
                color: _coralLight,
                child: photo != null && photo.isNotEmpty
                    ? Image.network(
                        photo.startsWith('http://api.')
                            ? photo.replaceFirst('http://', 'https://')
                            : photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _coral,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _coral,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _coral.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getKindIcon(kind), size: 12, color: _coral),
                            const SizedBox(width: 4),
                            Text(
                              _getKindLabel(kind),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _coral,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (distKm != null)
                        Text(
                          _formatDistance(distKm),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow - Navigate to details
            GestureDetector(
              onTap: () {
                final id = (provider['id'] ?? '').toString();
                if (id.isEmpty) return;
                // Navigate based on kind
                switch (kind) {
                  case 'vet':
                    context.push('/explore/vets/$id');
                    break;
                  case 'daycare':
                    context.push('/explore/daycare/$id');
                    break;
                  case 'petshop':
                    context.push('/explore/petshop/$id');
                    break;
                  default:
                    context.push('/explore/vets/$id');
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? _coral : _coralLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: isActive ? Colors.white : _coral,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
