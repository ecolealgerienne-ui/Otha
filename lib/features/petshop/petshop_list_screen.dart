// lib/features/petshop/petshop_list_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/location_provider.dart';

// ═══════════════════════════════════════════════════════════════
// COULEURS
// ═══════════════════════════════════════════════════════════════
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF1F2328);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

/// Provider qui charge la liste des animaleries autour du centre
final _petshopsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final center = ref.watch(currentCoordsProvider);

  final raw = await api.nearby(
    lat: center.lat,
    lng: center.lng,
    radiusKm: 40000.0,
    limit: 5000,
    status: 'approved',
  );

  final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  final petshops = rows.where((m) {
    final specialties = m['specialties'];
    if (specialties is Map) {
      final kind = (specialties['kind'] ?? '').toString().toLowerCase();
      return kind == 'petshop';
    }
    return false;
  }).toList();

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

  final mapped = petshops.map((m) {
    final id = (m['id'] ?? '').toString();
    final name = (m['displayName'] ?? m['name'] ?? 'Animalerie').toString();
    final bio = (m['bio'] ?? '').toString();
    final address = (m['address'] ?? '').toString();

    final specialties = m['specialties'] as Map?;
    final categories = <String>[];
    if (specialties != null) {
      final cats = specialties['categories'];
      if (cats is List) {
        categories.addAll(cats.map((e) => e.toString()));
      }
    }

    double? dKm = _toDouble(m['distance_km']);
    if (dKm == null) {
      final lat = _toDouble(m['lat']);
      final lng = _toDouble(m['lng']);
      dKm = _haversineKm(lat, lng);
    }

    final avatarUrl = (m['avatarUrl'] ?? m['photoUrl'] ?? '').toString();

    // Delivery options - check root level first (where backend stores them), then specialties as fallback
    // Backend stores petshop delivery settings directly on provider: p['deliveryEnabled'], p['pickupEnabled']
    final bool deliveryEnabled;
    final bool pickupEnabled;

    // Check root level first (this is where the backend stores it)
    final rootDelivery = m['deliveryEnabled'];
    final rootPickup = m['pickupEnabled'];

    if (rootDelivery != null || rootPickup != null) {
      // Use root level values
      deliveryEnabled = rootDelivery == true;
      pickupEnabled = rootPickup != false; // Default true unless explicitly false
    } else if (specialties != null) {
      // Fallback to specialties
      deliveryEnabled = specialties['deliveryEnabled'] == true;
      final pickupVal = specialties['pickupEnabled'];
      pickupEnabled = pickupVal != false;
    } else {
      // Defaults
      deliveryEnabled = false;
      pickupEnabled = true;
    }

    final deliveryFeeDa = (m['deliveryFeeDa'] as num?)?.toInt() ??
                          (m['delivery_fee_da'] as num?)?.toInt() ??
                          (specialties?['deliveryFeeDa'] as num?)?.toInt();
    final freeDeliveryAboveDa = (m['freeDeliveryAboveDa'] as num?)?.toInt() ??
                                 (m['free_delivery_above_da'] as num?)?.toInt() ??
                                 (specialties?['freeDeliveryAboveDa'] as num?)?.toInt();

    // Calculate open/close status based on current time and day
    // Simple logic: assume open 9:00-19:00 every day for now
    final now = DateTime.now();
    final hour = now.hour;
    final openingHour = (m['openingHour'] as num?)?.toInt() ?? 9;
    final closingHour = (m['closingHour'] as num?)?.toInt() ?? 19;
    final isOpen = hour >= openingHour && hour < closingHour;

    return <String, dynamic>{
      'id': id,
      'displayName': name,
      'bio': bio,
      'address': address,
      'distanceKm': dKm,
      'categories': categories,
      'avatarUrl': avatarUrl,
      'deliveryEnabled': deliveryEnabled,
      'pickupEnabled': pickupEnabled,
      'deliveryFeeDa': deliveryFeeDa,
      'freeDeliveryAboveDa': freeDeliveryAboveDa,
      'isOpen': isOpen,
      'openingHour': openingHour,
    };
  }).toList();

  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final m in mapped) {
    final id = (m['id'] as String?) ?? '';
    final key = id.isNotEmpty ? 'id:$id' : 'na:${(m['displayName'] ?? '').toString().toLowerCase()}';
    if (seen.add(key)) unique.add(m);
  }

  unique.sort((a, b) {
    final da = a['distanceKm'] as double?;
    final db = b['distanceKm'] as double?;
    if (da != null && db != null) return da.compareTo(db);
    if (da != null) return -1;
    if (db != null) return 1;
    return (a['displayName'] ?? '').toString().toLowerCase().compareTo(
        (b['displayName'] ?? '').toString().toLowerCase());
  });

  return unique;
});

class PetshopListScreen extends ConsumerStatefulWidget {
  const PetshopListScreen({super.key});

  @override
  ConsumerState<PetshopListScreen> createState() => _PetshopListScreenState();
}

class _PetshopListScreenState extends ConsumerState<PetshopListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(_petshopsProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterShops(List<Map<String, dynamic>> shops) {
    return shops.where((shop) {
      if (_searchQuery.isNotEmpty) {
        final name = (shop['displayName'] ?? '').toString().toLowerCase();
        final address = (shop['address'] ?? '').toString().toLowerCase();
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
    final async = ref.watch(_petshopsProvider);

    // Theme colors
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header avec gradient
            _buildHeader(context, isDark, l10n, textPrimary, textSecondary, cardColor, borderColor),

            // Content
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: _coral),
                      const SizedBox(height: 16),
                      Text(
                        l10n.loading,
                        style: TextStyle(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.error,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          '$e',
                          style: TextStyle(color: textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(_petshopsProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Réessayer'),
                        style: FilledButton.styleFrom(backgroundColor: _coral),
                      ),
                    ],
                  ),
                ),
                data: (rows) {
                  final filtered = _filterShops(rows);
                  if (filtered.isEmpty) {
                    return _buildEmptyState(isDark, l10n, textPrimary, textSecondary);
                  }
                  return RefreshIndicator(
                    color: _coral,
                    backgroundColor: cardColor,
                    onRefresh: () async => ref.invalidate(_petshopsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _PetshopCard(
                            id: (m['id'] ?? '').toString(),
                            name: (m['displayName'] ?? 'Animalerie').toString(),
                            distanceKm: m['distanceKm'] as double?,
                            bio: (m['bio'] ?? '').toString(),
                            address: (m['address'] ?? '').toString(),
                            categories: (m['categories'] as List<String>?) ?? [],
                            avatarUrl: (m['avatarUrl'] ?? '').toString(),
                            deliveryEnabled: m['deliveryEnabled'] == true,
                            pickupEnabled: m['pickupEnabled'] != false,
                            deliveryFeeDa: m['deliveryFeeDa'] as int?,
                            freeDeliveryAboveDa: m['freeDeliveryAboveDa'] as int?,
                            isOpen: m['isOpen'] == true,
                            openingHour: m['openingHour'] as int? ?? 9,
                            isDark: isDark,
                            l10n: l10n,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color? textSecondary,
    Color cardColor,
    Color borderColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [_darkCard, _darkBg]
              : [_coralSoft, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button and title row
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _coral,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront_rounded, color: _coral, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            l10n.petshop,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.petshopDescription,
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => ref.invalidate(_petshopsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    color: _coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? _darkCardBorder : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.petshopSearchHint,
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.grey[400] : Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: isDark ? Colors.grey[400] : Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n, Color textPrimary, Color? textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, size: 56, color: _coral),
            ),
            const SizedBox(height: 28),
            Text(
              _searchQuery.isNotEmpty ? l10n.petshopNoResult : l10n.petshopNoShops,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? l10n.petshopTryOtherSearch
                  : l10n.petshopNoShopsAvailable,
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: Text(l10n.petshopClearSearch),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _coral,
                  side: const BorderSide(color: _coral, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PETSHOP CARD
// ═══════════════════════════════════════════════════════════════

class _PetshopCard extends StatelessWidget {
  const _PetshopCard({
    required this.id,
    required this.name,
    required this.bio,
    required this.address,
    required this.isDark,
    required this.l10n,
    this.distanceKm,
    this.categories = const [],
    this.avatarUrl = '',
    this.deliveryEnabled = false,
    this.pickupEnabled = true,
    this.deliveryFeeDa,
    this.freeDeliveryAboveDa,
    this.isOpen = true,
    this.openingHour = 9,
  });

  final String id;
  final String name;
  final String bio;
  final String address;
  final double? distanceKm;
  final List<String> categories;
  final String avatarUrl;
  final bool isDark;
  final bool deliveryEnabled;
  final bool pickupEnabled;
  final int? deliveryFeeDa;
  final int? freeDeliveryAboveDa;
  final bool isOpen;
  final int openingHour;
  final AppLocalizations l10n;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final inits = parts.take(2).map((e) => e[0]).join().toUpperCase();
    return inits.isEmpty ? 'PS' : inits;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade100;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push('/explore/petshop/$id'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec avatar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [_coral.withOpacity(0.15), Colors.transparent]
                        : [_coralSoft.withOpacity(0.5), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar - slightly bigger
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? _coral.withOpacity(0.3) : _coral.withOpacity(0.2),
                          width: 2,
                        ),
                        image: avatarUrl.isNotEmpty && avatarUrl.startsWith('http')
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl.isEmpty || !avatarUrl.startsWith('http')
                          ? Center(
                              child: Text(
                                _initials(name),
                                style: const TextStyle(
                                  color: _coral,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 14,
                                    color: isDark ? Colors.grey[500] : Colors.grey[400]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (distanceKm != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _coral,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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

              // Bio - moved up with less spacing
              if (bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    bio,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Delivery/Pickup badges
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (deliveryEnabled)
                      _OptionBadge(
                        icon: Icons.local_shipping_rounded,
                        label: deliveryFeeDa != null && deliveryFeeDa! > 0
                            ? '${l10n.petshopDelivery} $deliveryFeeDa DA'
                            : l10n.petshopDelivery,
                        color: Colors.blue,
                        isDark: isDark,
                        subLabel: freeDeliveryAboveDa != null
                            ? '${l10n.petshopFreeDeliveryFrom} $freeDeliveryAboveDa DA'
                            : null,
                      ),
                    if (pickupEnabled)
                      _OptionBadge(
                        icon: Icons.store_rounded,
                        label: l10n.petshopPickup,
                        color: Colors.purple,
                        isDark: isDark,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bottom action row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    // Status badge (open/closed) with opening hours
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50)
                            : (isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOpen ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOpen
                                ? l10n.petshopOpen
                                : '${l10n.petshopClosedUntil} ${openingHour}h',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOpen
                                  ? (isDark ? Colors.green[300] : Colors.green[700])
                                  : (isDark ? Colors.orange[300] : Colors.orange[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // CTA Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_coral, Color(0xFFFF8A8A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _coral.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.petshopViewProducts,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OPTION BADGE (Delivery/Pickup)
// ═══════════════════════════════════════════════════════════════

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.subLabel,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? color.withOpacity(0.8) : color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? color.withOpacity(0.9) : color.withOpacity(0.8),
                ),
              ),
              if (subLabel != null)
                Text(
                  subLabel!,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
