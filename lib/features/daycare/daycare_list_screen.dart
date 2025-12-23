// lib/features/daycare/daycare_list_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/session_controller.dart';
import '../../core/location_provider.dart';

// Design constants - même thème que vet_details_screen
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

// Commission par défaut (fallback si non définie dans le profil du provider)
const kDefaultDaycareHourlyCommissionDa = 10;
const kDefaultDaycareDailyCommissionDa = 100;

/// Helper pour déterminer le statut d'ouverture d'une garderie
class DaycareOpenStatus {
  final bool isOpen;
  final String closingTime;
  final String? nextOpenDay;
  final String? nextOpenTime;

  DaycareOpenStatus({
    required this.isOpen,
    required this.closingTime,
    this.nextOpenDay,
    this.nextOpenTime,
  });

  static DaycareOpenStatus calculate({
    required bool is24_7,
    required String openingTime,
    required String closingTime,
    required List<dynamic> availableDays,
  }) {
    if (is24_7) {
      return DaycareOpenStatus(isOpen: true, closingTime: '24/7');
    }

    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday

    // Convertir en index de notre tableau (0 = Lundi, 6 = Dimanche)
    final dayIndex = currentWeekday - 1;

    // Parser les heures
    final openParts = openingTime.split(':');
    final closeParts = closingTime.split(':');
    final openHour = int.tryParse(openParts[0]) ?? 8;
    final openMin = int.tryParse(openParts.length > 1 ? openParts[1] : '0') ?? 0;
    final closeHour = int.tryParse(closeParts[0]) ?? 20;
    final closeMin = int.tryParse(closeParts.length > 1 ? closeParts[1] : '0') ?? 0;

    final currentMinutes = now.hour * 60 + now.minute;
    final openMinutes = openHour * 60 + openMin;
    final closeMinutes = closeHour * 60 + closeMin;

    // Vérifier si le jour actuel est disponible
    final isTodayAvailable = dayIndex < availableDays.length && availableDays[dayIndex] == true;

    // Vérifier si on est dans les heures d'ouverture
    final isWithinHours = currentMinutes >= openMinutes && currentMinutes < closeMinutes;

    if (isTodayAvailable && isWithinHours) {
      return DaycareOpenStatus(isOpen: true, closingTime: closingTime);
    }

    // Trouver le prochain jour/heure d'ouverture
    String? nextDay;
    String? nextTime;

    // Si aujourd'hui est dispo mais on n'est pas encore dans les heures
    if (isTodayAvailable && currentMinutes < openMinutes) {
      nextDay = _getDayName(dayIndex);
      nextTime = openingTime;
    } else {
      // Chercher le prochain jour disponible
      for (int i = 1; i <= 7; i++) {
        final checkIndex = (dayIndex + i) % 7;
        if (checkIndex < availableDays.length && availableDays[checkIndex] == true) {
          nextDay = _getDayName(checkIndex);
          nextTime = openingTime;
          break;
        }
      }
    }

    return DaycareOpenStatus(
      isOpen: false,
      closingTime: closingTime,
      nextOpenDay: nextDay,
      nextOpenTime: nextTime,
    );
  }

  static String _getDayName(int index) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return index < days.length ? days[index] : '';
  }
}

/// Provider qui charge la liste des garderies
final daycareProvidersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);

  // Utilise le provider GPS centralisé
  final center = ref.watch(currentCoordsProvider);

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

    // Commissions personnalisées (du profil provider)
    final hourlyCommission = m['daycareHourlyCommissionDa'] ?? kDefaultDaycareHourlyCommissionDa;
    final dailyCommission = m['daycareDailyCommissionDa'] ?? kDefaultDaycareDailyCommissionDa;

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
      'daycareHourlyCommissionDa': hourlyCommission,
      'daycareDailyCommissionDa': dailyCommission,
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
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(daycareProvidersListProvider);

    final bgColor = isDark ? _darkBg : Colors.white;
    final cardColor = isDark ? _darkCard : const Color(0xFFF7F9FB);
    final cardBorder = isDark ? _darkCardBorder : const Color(0xFFE6EDF2);
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? _darkCard : _coralSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : _coral,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pets, color: _coral, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.daycaresTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: l10n.searchDaycare,
                hintStyle: TextStyle(color: textSecondary),
                prefixIcon: Icon(Icons.search, color: textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textSecondary),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _coral, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Contenu
          Expanded(
            child: async.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: isDark ? _coral : null),
              ),
              error: (err, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: textSecondary),
                    const SizedBox(height: 16),
                    Text('Erreur: $err', style: TextStyle(color: textSecondary)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(daycareProvidersListProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                      style: FilledButton.styleFrom(backgroundColor: _coral),
                    ),
                  ],
                ),
              ),
              data: (daycares) {
                final filtered = _filterDaycares(daycares);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isEmpty ? Icons.pets : Icons.search_off,
                            size: 40,
                            color: _coral,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? l10n.noDaycareAvailable : l10n.noDaycareFound,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _DaycareCard(
                      daycare: filtered[index],
                      isDark: isDark,
                      cardColor: cardColor,
                      cardBorder: cardBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      l10n: l10n,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DaycareCard extends StatefulWidget {
  final Map<String, dynamic> daycare;
  final bool isDark;
  final Color cardColor;
  final Color cardBorder;
  final Color textPrimary;
  final Color? textSecondary;
  final AppLocalizations l10n;

  const _DaycareCard({
    required this.daycare,
    required this.isDark,
    required this.cardColor,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.l10n,
  });

  @override
  State<_DaycareCard> createState() => _DaycareCardState();
}

class _DaycareCardState extends State<_DaycareCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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

    // Commissions personnalisées du provider
    final hourlyCommission = widget.daycare['daycareHourlyCommissionDa'] ?? kDefaultDaycareHourlyCommissionDa;
    final dailyCommission = widget.daycare['daycareDailyCommissionDa'] ?? kDefaultDaycareDailyCommissionDa;

    String? priceText;
    if (hourlyRate != null) {
      final priceWithCommission = (hourlyRate as int) + (hourlyCommission as int);
      priceText = '$priceWithCommission DA${widget.l10n.perHour}';
    } else if (dailyRate != null) {
      final priceWithCommission = (dailyRate as int) + (dailyCommission as int);
      priceText = '$priceWithCommission DA${widget.l10n.perDay}';
    }

    return GestureDetector(
      onTap: () {
        final id = (widget.daycare['id'] ?? '').toString();
        if (id.isNotEmpty) {
          context.push('/explore/daycare/$id', extra: widget.daycare);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec PageView
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    // Images
                    images.isNotEmpty
                        ? PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              return Image.network(
                                images[index].toString(),
                                width: double.infinity,
                                height: 160,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholder(),
                              );
                            },
                          )
                        : _buildPlaceholder(),

                    // Badges
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Row(
                        children: [
                          if (distanceKm != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
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
                        ],
                      ),
                    ),

                    // Badge 24/7
                    if (is24_7)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _coral,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.l10n.open247,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),

                    // Indicateurs de page
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
                              width: _currentPage == index ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: _currentPage == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: widget.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Adresse
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: widget.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(fontSize: 13, color: widget.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Statut d'ouverture
                  if (!is24_7) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final availableDays = widget.daycare['availableDays'] as List<dynamic>? ?? List.filled(7, true);
                        final status = DaycareOpenStatus.calculate(
                          is24_7: is24_7,
                          openingTime: openingTime,
                          closingTime: closingTime,
                          availableDays: availableDays,
                        );

                        if (status.isOpen) {
                          return Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.l10n.openNow,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${widget.l10n.closesAt} ${status.closingTime}',
                                style: TextStyle(fontSize: 12, color: widget.textSecondary),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.l10n.closedNow,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[400],
                                ),
                              ),
                              if (status.nextOpenDay != null && status.nextOpenTime != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '• ${widget.l10n.opensAt} ${status.nextOpenDay} ${status.nextOpenTime}',
                                    style: TextStyle(fontSize: 12, color: widget.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          );
                        }
                      },
                    ),
                  ],

                  // Bio
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: TextStyle(fontSize: 13, color: widget.textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Infos (capacité + types d'animaux)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (capacity != null)
                        _buildChip(
                          Icons.pets,
                          widget.l10n.animalsCount(capacity as int),
                        ),
                      ...animalTypes.take(2).map((type) {
                        return _buildChip(Icons.pets, type.toString());
                      }),
                    ],
                  ),

                  // Prix
                  if (priceText != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.l10n.fromPrice,
                              style: TextStyle(fontSize: 11, color: widget.textSecondary),
                            ),
                            Text(
                              priceText,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _coral,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _coral,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.l10n.bookNow,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 160,
      color: widget.isDark ? _darkCard : _coralSoft,
      child: Center(
        child: Icon(
          Icons.pets,
          size: 48,
          color: _coral.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDark ? _coral.withOpacity(0.15) : _coralSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _coral),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _coral,
            ),
          ),
        ],
      ),
    );
  }
}
