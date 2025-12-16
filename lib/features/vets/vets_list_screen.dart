// lib/features/vets/vets_list_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';
import '../../core/locale_provider.dart';
import '../home/home_screen.dart' show themeProvider, AppThemeMode;

// Couleurs thème
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _darkBg = Color(0xFF0A0A0A);
const _darkCard = Color(0xFF1A1A1A);
const _darkBorder = Color(0xFF2A2A2A);

/// Provider qui charge la liste des vétos avec photos, services, disponibilités
final _vetsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);

  // ---------- 1) Centre utilisateur: DEVICE d'abord, puis PROFIL, sinon fallback ----------
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
            // Fallback
          } catch (_) {}
        }
      }
    } catch (_) {}

    final me = ref.read(sessionProvider).user ?? {};
    final pLat = (me['lat'] as num?)?.toDouble();
    final pLng = (me['lng'] as num?)?.toDouble();
    if (pLat != null && pLng != null && pLat != 0 && pLng != 0) {
      return (lat: pLat, lng: pLng);
    }

    return (lat: 36.75, lng: 3.06); // Fallback Alger
  }

  final center = await getCenter();

  // ---------- 2) API: récupère les pros ----------
  final raw = await api.nearby(
    lat: center.lat,
    lng: center.lng,
    radiusKm: 40000.0,
    limit: 5000,
    status: 'approved',
  );

  // ---------- 3) Normalisation ----------
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

  // Filtrer uniquement les vétérinaires
  final vetsOnly = rows.where((m) {
    final specialties = m['specialties'] as Map<String, dynamic>?;
    final kind = (specialties?['kind'] ?? '').toString().toLowerCase();
    return kind == 'vet' || kind.isEmpty;
  }).toList();

  final mapped = vetsOnly.map((m) {
    final id = (m['id'] ?? m['providerId'] ?? '').toString();
    final name = (m['displayName'] ?? m['name'] ?? 'Vétérinaire').toString();
    final bio = (m['bio'] ?? '').toString();
    // Le provider peut avoir avatarUrl ou photoUrl selon l'API
    final photoUrl = (m['avatarUrl'] ?? m['photoUrl'] ?? m['avatar'] ?? '').toString();

    // Services
    final services = (m['services'] as List?)?.map((s) {
      if (s is Map) return Map<String, dynamic>.from(s);
      return <String, dynamic>{};
    }).toList() ?? [];

    // Disponibilités (horaires)
    final availability = (m['availability'] as List?)?.map((a) {
      if (a is Map) return Map<String, dynamic>.from(a);
      return <String, dynamic>{};
    }).toList() ?? [];

    // Distance
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
      'photoUrl': photoUrl,
      'distanceKm': dKm,
      'services': services,
      'availability': availability,
    };
  }).toList();

  // Dédoublonnage
  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final m in mapped) {
    final id = (m['id'] as String?) ?? '';
    final key = id.isNotEmpty
        ? 'id:$id'
        : 'na:${(m['displayName'] ?? '').toString().toLowerCase()}';
    if (seen.add(key)) unique.add(m);
  }

  // Tri par distance
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(_vetsProvider);
    });
  }

  List<Map<String, dynamic>> _filterVets(List<Map<String, dynamic>> vets) {
    return vets.where((vet) {
      if (_searchQuery.isNotEmpty) {
        final name = (vet['displayName'] ?? '').toString().toLowerCase();
        final bio = (vet['bio'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !bio.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final async = ref.watch(_vetsProvider);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, l10n, isDark),

            // Liste
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _coral),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '${l10n.error}: $e',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                data: (rows) {
                  final filtered = _filterVets(rows);
                  if (filtered.isEmpty) {
                    return _buildEmptyState(l10n, isDark);
                  }
                  return RefreshIndicator(
                    color: _coral,
                    onRefresh: () async => ref.invalidate(_vetsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _VetCard(
                            vet: m,
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

  Widget _buildHeader(BuildContext context, AppLocalizations l10n, bool isDark) {
    final headerBg = isDark ? _darkCard : Colors.white;
    final textColor = isDark ? Colors.white : _ink;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey;
    final searchBg = isDark ? _darkBg : const Color(0xFFF7F8FA);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: headerBg,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton retour + titre
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: _coralSoft,
                  foregroundColor: _coral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.veterinarians,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontFamily: 'SFPRO',
                      ),
                    ),
                    Text(
                      l10n.findVetNearby,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                        fontFamily: 'SFPRO',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.invalidate(_vetsProvider),
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  backgroundColor: _coralSoft,
                  foregroundColor: _coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barre de recherche
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: l10n.searchVet,
              hintStyle: TextStyle(color: subtitleColor),
              prefixIcon: Icon(Icons.search, color: subtitleColor),
              filled: true,
              fillColor: searchBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _coral, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? Colors.white : _ink;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_hospital, size: 48, color: _coral),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noVetFound,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFamily: 'SFPRO',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty ? l10n.tryOtherTerms : l10n.noVetAvailable,
            style: TextStyle(color: subtitleColor, fontFamily: 'SFPRO'),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() => _searchQuery = ''),
              style: OutlinedButton.styleFrom(
                foregroundColor: _coral,
                side: const BorderSide(color: _coral),
              ),
              child: Text(l10n.clearSearch),
            ),
          ],
        ],
      ),
    );
  }
}

class _VetCard extends StatelessWidget {
  const _VetCard({
    required this.vet,
    required this.isDark,
    required this.l10n,
  });

  final Map<String, dynamic> vet;
  final bool isDark;
  final AppLocalizations l10n;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final inits = parts.take(2).map((e) => e[0]).join().toUpperCase();
    return inits.isEmpty ? 'DR' : inits;
  }

  /// Vérifie si le vétérinaire est actuellement ouvert selon ses disponibilités
  ({bool isOpen, String? nextChange}) _checkAvailability() {
    final availability = (vet['availability'] as List?) ?? [];
    if (availability.isEmpty) return (isOpen: false, nextChange: null);

    final now = DateTime.now();
    final weekday = now.weekday; // 1=Lundi ... 7=Dimanche
    final currentMinutes = now.hour * 60 + now.minute;

    // Chercher les créneaux du jour actuel
    for (final slot in availability) {
      final day = slot['dayOfWeek'] as int?;
      if (day == null || day != weekday) continue;

      final startTime = slot['startTime']?.toString() ?? '';
      final endTime = slot['endTime']?.toString() ?? '';

      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      if (startParts.length >= 2 && endParts.length >= 2) {
        final startMinutes = (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
        final endMinutes = (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);

        if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
          // Ouvert - calcule l'heure de fermeture
          final closeHour = endMinutes ~/ 60;
          final closeMin = endMinutes % 60;
          return (
            isOpen: true,
            nextChange: '${closeHour.toString().padLeft(2, '0')}:${closeMin.toString().padLeft(2, '0')}'
          );
        } else if (currentMinutes < startMinutes) {
          // Fermé mais ouvre plus tard aujourd'hui
          final openHour = startMinutes ~/ 60;
          final openMin = startMinutes % 60;
          return (
            isOpen: false,
            nextChange: '${openHour.toString().padLeft(2, '0')}:${openMin.toString().padLeft(2, '0')}'
          );
        }
      }
    }

    return (isOpen: false, nextChange: null);
  }

  @override
  Widget build(BuildContext context) {
    final id = (vet['id'] ?? '').toString();
    final name = (vet['displayName'] ?? 'Vétérinaire').toString();
    final bio = (vet['bio'] ?? '').toString();
    final photoUrl = (vet['photoUrl'] ?? '').toString();
    final distanceKm = vet['distanceKm'] as double?;
    final services = (vet['services'] as List?) ?? [];
    final hasPhoto = photoUrl.startsWith('http');

    final cardBg = isDark ? _darkCard : Colors.white;
    final textColor = isDark ? Colors.white : _ink;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey.shade600;
    final borderColor = isDark ? _darkBorder : const Color(0xFFEEEEEE);

    final availStatus = _checkAvailability();

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/explore/vets/$id'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : const Color(0x08000000),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo de profil à gauche
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                  borderRadius: BorderRadius.circular(14),
                  image: hasPhoto
                      ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasPhoto
                    ? Center(
                        child: Text(
                          _initials(name),
                          style: const TextStyle(
                            color: _coral,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            fontFamily: 'SFPRO',
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Infos à droite
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + distance
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: textColor,
                              fontFamily: 'SFPRO',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me, size: 12, color: _coral),
                                const SizedBox(width: 4),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} ${l10n.kmAway}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _coral,
                                    fontFamily: 'SFPRO',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Bio courte
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        bio,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 13,
                          height: 1.3,
                          fontFamily: 'SFPRO',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Services (chips) + Statut disponibilité
                    Row(
                      children: [
                        // Services
                        if (services.isNotEmpty)
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: services.take(2).map((s) {
                                final title = (s['title'] ?? s['name'] ?? '').toString();
                                if (title.isEmpty) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      fontFamily: 'SFPRO',
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        else
                          const Spacer(),

                        // Statut disponibilité
                        if (availStatus.nextChange != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: availStatus.isOpen
                                  ? (isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50)
                                  : (isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  availStatus.isOpen ? Icons.check_circle : Icons.schedule,
                                  size: 12,
                                  color: availStatus.isOpen
                                      ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                      : (isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  availStatus.isOpen
                                      ? '${l10n.openNow} • ${l10n.closesAt} ${availStatus.nextChange}'
                                      : '${l10n.opensAt} ${availStatus.nextChange}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: availStatus.isOpen
                                        ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                        : (isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                                    fontFamily: 'SFPRO',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Bouton voir profil
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_coral, Color(0xFFF2968F)],
                          ),
                          borderRadius: BorderRadius.circular(10),
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
                              l10n.viewProfile,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                          ],
                        ),
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
