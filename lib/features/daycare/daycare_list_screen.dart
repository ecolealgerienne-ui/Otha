// lib/features/daycare/daycare_list_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/session_controller.dart';

// ═══════════════════════════════════════════════════════════════
// DESIGN CONSTANTS
// ═══════════════════════════════════════════════════════════════
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _teal = Color(0xFF00ACC1);
const _tealSoft = Color(0xFFE0F7FA);
const _green = Color(0xFF43AA8B);
const _greenSoft = Color(0xFFE8F5F0);
const _purple = Color(0xFF7B68EE);
const _purpleSoft = Color(0xFFF0EDFF);

// Dark mode colors
const _darkBg = Color(0xFF0F0F0F);
const _darkCard = Color(0xFF1A1A1A);
const _darkCardAlt = Color(0xFF242424);
const _darkBorder = Color(0xFF2A2A2A);

// Commission cachée ajoutée au prix affiché
const kDaycareCommissionDa = 100;

/// Provider qui charge la liste des garderies autour du centre
final daycareProvidersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);

  Future<({double lat, double lng})> getCenter() async {
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

    final me = ref.read(sessionProvider).user ?? {};
    final pLat = (me['lat'] as num?)?.toDouble();
    final pLng = (me['lng'] as num?)?.toDouble();
    if (pLat != null && pLng != null && pLat != 0 && pLng != 0) {
      return (lat: pLat, lng: pLng);
    }

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
    final availableDays = availability?['availableDays'] as List? ?? List.filled(7, true);

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
      'availableDays': availableDays,
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

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════
class DaycareListScreen extends ConsumerStatefulWidget {
  const DaycareListScreen({super.key});
  @override
  ConsumerState<DaycareListScreen> createState() => _DaycareListScreenState();
}

class _DaycareListScreenState extends ConsumerState<DaycareListScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(daycareProvidersListProvider);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(daycareProvidersListProvider);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar avec effet glassmorphism
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? _darkCard : Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [_darkCard, _darkCardAlt]
                        : [Colors.white, const Color(0xFFFAF9FF)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_coral, Color(0xFFFF8A80)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _coral.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.pets_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              l10n.daycaresTitle,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search bar avec glassmorphism
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : Colors.black).withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n.searchDaycare,
                      hintStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(Icons.search_rounded, color: _coral),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: textSecondary),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? _darkCardAlt : Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
            ),
          ),

          // Content
          async.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: _PremiumLoader(),
              ),
            ),
            error: (err, st) => SliverFillRemaining(
              child: _ErrorView(
                error: err.toString(),
                onRetry: () => ref.invalidate(daycareProvidersListProvider),
                isDark: isDark,
              ),
            ),
            data: (daycares) {
              final filtered = _filterDaycares(daycares);

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyView(
                    searchQuery: _searchQuery,
                    l10n: l10n,
                    isDark: isDark,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, 0.1 + (index * 0.02)),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              (index * 0.1).clamp(0.0, 0.5),
                              ((index * 0.1) + 0.5).clamp(0.0, 1.0),
                              curve: Curves.easeOutCubic,
                            ),
                          )),
                          child: _PremiumDaycareCard(
                            daycare: filtered[index],
                            isDark: isDark,
                            l10n: l10n,
                          ),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM DAYCARE CARD
// ═══════════════════════════════════════════════════════════════
class _PremiumDaycareCard extends StatefulWidget {
  final Map<String, dynamic> daycare;
  final bool isDark;
  final AppLocalizations l10n;

  const _PremiumDaycareCard({
    required this.daycare,
    required this.isDark,
    required this.l10n,
  });

  @override
  State<_PremiumDaycareCard> createState() => _PremiumDaycareCardState();
}

class _PremiumDaycareCardState extends State<_PremiumDaycareCard> {
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

    final cardColor = widget.isDark ? _darkCard : Colors.white;
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = widget.isDark ? Colors.white60 : Colors.black54;

    String? priceText;
    if (hourlyRate != null) {
      final priceWithCommission = (hourlyRate as int) + kDaycareCommissionDa;
      priceText = '${widget.l10n.fromPrice} $priceWithCommission DA${widget.l10n.perHour}';
    } else if (dailyRate != null) {
      final priceWithCommission = (dailyRate as int) + kDaycareCommissionDa;
      priceText = '${widget.l10n.fromPrice} $priceWithCommission DA${widget.l10n.perDay}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (widget.isDark ? Colors.black : _coral).withOpacity(widget.isDark ? 0.3 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            final id = (widget.daycare['id'] ?? '').toString();
            if (id.isNotEmpty) {
              context.push('/explore/daycare/$id', extra: widget.daycare);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image gallery avec effet parallaxe
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 200,
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
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                );
                              },
                            )
                          : _buildPlaceholder(),

                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Distance badge
                      if (distanceKm != null)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${distanceKm.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 24/7 badge
                      if (is24_7)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_green, Color(0xFF66BB6A)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _green.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.l10n.open247,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),

                      // Image indicators
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentImageIndex == index ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
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

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom et horaires
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.place_rounded, size: 16, color: textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(fontSize: 13, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Horaires si pas 24/7
                    if (!is24_7) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.isDark ? _teal.withOpacity(0.15) : _tealSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 16, color: _teal),
                            const SizedBox(width: 8),
                            Text(
                              widget.l10n.openFromTo(openingTime, closingTime),
                              style: TextStyle(
                                fontSize: 13,
                                color: _teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        bio,
                        style: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Info chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (capacity != null)
                          _InfoChip(
                            icon: Icons.pets_rounded,
                            label: widget.l10n.animalsCount(capacity as int),
                            color: _purple,
                            isDark: widget.isDark,
                          ),
                        ...animalTypes.take(3).map((type) {
                          return _InfoChip(
                            icon: _getAnimalIcon(type.toString()),
                            label: type.toString(),
                            color: _coral,
                            isDark: widget.isDark,
                          );
                        }),
                      ],
                    ),

                    if (priceText != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.isDark
                                ? [_coral.withOpacity(0.15), _coral.withOpacity(0.08)]
                                : [_coralSoft, _coralSoft.withOpacity(0.5)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              priceText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _coral,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _coral,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDark
              ? [_darkCardAlt, _darkCard]
              : [_coralSoft, const Color(0xFFFFF5F5)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets_rounded,
              size: 48,
              color: _coral.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              widget.l10n.noImageAvailable,
              style: TextStyle(
                color: _coral.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAnimalIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('chien') || lower.contains('dog')) return Icons.pets;
    if (lower.contains('chat') || lower.contains('cat')) return Icons.pets;
    if (lower.contains('oiseau') || lower.contains('bird')) return Icons.flutter_dash;
    return Icons.pets;
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
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

class _PremiumLoader extends StatefulWidget {
  const _PremiumLoader();

  @override
  State<_PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<_PremiumLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _coral.withOpacity(0),
                      _coral,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chargement...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String searchQuery;
  final AppLocalizations l10n;
  final bool isDark;

  const _EmptyView({
    required this.searchQuery,
    required this.l10n,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white70 : Colors.grey[600];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? _darkCardAlt : _coralSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              searchQuery.isEmpty ? Icons.pets_rounded : Icons.search_off_rounded,
              size: 48,
              color: _coral,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            searchQuery.isEmpty ? l10n.noDaycareAvailable : l10n.noDaycareFound,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final bool isDark;

  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur: $error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
