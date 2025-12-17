// lib/features/bookings/booking_details_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import 'booking_flow_screen.dart';
import 'booking_thanks_screen.dart';

class BookingDetailsScreen extends ConsumerStatefulWidget {
  const BookingDetailsScreen({super.key, required this.booking});

  final Map<String, dynamic> booking;

  @override
  ConsumerState<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  // Theme colors
  static const _coral = Color(0xFFF36C6C);
  static const _coralSoft = Color(0xFFFFEEF0);
  static const _amber = Color(0xFFFFA000);
  static const _amberSoft = Color(0xFFFFF8E1);
  static const _darkBg = Color(0xFF121212);
  static const _darkCard = Color(0xFF1E1E1E);
  static const _darkCardAlt = Color(0xFF2A2A2A);

  bool _busy = false;
  Map<String, dynamic>? _providerFull;
  bool _loadingProv = false;
  String? _resolvedProviderId;
  bool _resolvingPid = false;

  Map<String, dynamic> get _m => widget.booking;

  String? get _bookingId {
    final id = (_m['id'] ?? '').toString();
    return id.isEmpty ? null : id;
  }

  String? get _serviceId {
    final s = _m['service'];
    final sid = (s is Map)
        ? ((s['id'] ?? s['serviceId'] ?? s['service_id'] ?? '').toString())
        : ((_m['serviceId'] ?? _m['service_id'] ?? '').toString());
    return sid.isEmpty ? null : sid;
  }

  String? get _providerId {
    final p1 = (_m['providerId'] ?? _m['provider_id'] ?? '').toString();
    if (p1.isNotEmpty) return p1;

    final pMap = (_m['provider'] is Map)
        ? Map<String, dynamic>.from(_m['provider'] as Map)
        : (_m['providerProfile'] is Map)
            ? Map<String, dynamic>.from(_m['providerProfile'] as Map)
            : (_m['provider_profile'] is Map)
                ? Map<String, dynamic>.from(_m['provider_profile'] as Map)
                : null;
    final p2 = pMap == null ? '' : ((pMap['id'] ?? pMap['providerId'] ?? pMap['provider_id'] ?? '').toString());
    if (p2.isNotEmpty) return p2;

    final s = _m['service'];
    if (s is Map) {
      final p3 = ((s['providerId'] ?? s['provider_id'] ?? '').toString());
      if (p3.isNotEmpty) return p3;
    }

    return null;
  }

  String? get _effectiveProviderId => _providerId ?? _resolvedProviderId;

  String get _status => (_m['status'] ?? '').toString().toUpperCase();
  bool get _isPending => _status == 'PENDING';
  bool get _isConfirmed => _status == 'CONFIRMED' || _status == 'ACCEPTED';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryResolveProviderId());
  }

  String _norm(String s) {
    final lower = s.toLowerCase();
    const withAccents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿ';
    const without = 'aaaaaaceeeeiiiinooooouuuuyy';
    final map = {for (var i = 0; i < withAccents.length; i++) withAccents[i]: without[i]};
    return lower.split('').map((ch) => map[ch] ?? ch).join().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _providerName(Map<String, dynamic> p) {
    final n = (p['displayName'] ?? p['name'] ?? '').toString().trim();
    return n.isEmpty ? 'Cabinet vétérinaire' : n;
  }

  String _serviceName(Map<String, dynamic> m) {
    final s = m['service'];
    if (s is Map) {
      final t = (s['title'] ?? s['name'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return 'Service';
  }

  num? _servicePrice(Map<String, dynamic> m) {
    final s = m['service'];
    if (s is Map) {
      final p = s['price'];
      if (p is num) return p;
      if (p is String) return num.tryParse(p);
    }
    return null;
  }

  Map<String, dynamic> _providerMap(Map<String, dynamic> m) {
    final cand = m['provider'] ?? m['providerProfile'] ?? m['provider_profile'];
    if (cand is Map) return Map<String, dynamic>.from(cand);
    return <String, dynamic>{};
  }

  String? _mapsUrl(Map<String, dynamic> p) {
    final sp = p['specialties'];
    if (sp is Map) {
      final u = (sp['mapsUrl'] ?? sp['maps_url'] ?? '').toString().trim();
      if (u.startsWith('http')) return u;
    }
    final u2 = (p['mapsUrl'] ?? p['maps_url'] ?? '').toString().trim();
    return u2.startsWith('http') ? u2 : null;
  }

  (double?, double?) _coords(Map<String, dynamic> p) {
    final lat = p['lat'], lng = p['lng'];
    final dlat = (lat is num) ? lat.toDouble() : null;
    final dlng = (lng is num) ? lng.toDouble() : null;
    return (dlat, dlng);
  }

  Future<void> _tryResolveProviderId() async {
    if (_providerId != null || _resolvedProviderId != null) return;

    final provLight = _providerMap(_m);
    final wantedName = _providerName(provLight).trim();
    if (wantedName.isEmpty) return;

    setState(() => _resolvingPid = true);
    try {
      final api = ref.read(apiProvider);
      final all = await api.nearby(
        lat: 36.75,
        lng: 3.06,
        radiusKm: 40000.0,
        limit: 5000,
        status: 'all',
      );

      String? found;
      final wanted = _norm(wantedName);

      for (final e in all) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final name = _norm((m['displayName'] ?? m['name'] ?? '').toString());
        if (name == wanted) {
          final id = (m['id'] ?? '').toString();
          if (id.isNotEmpty) {
            found = id;
            break;
          }
        }
      }

      found ??= () {
        for (final e in all) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final name = _norm((m['displayName'] ?? m['name'] ?? '').toString());
          if (name.contains(wanted)) {
            final id = (m['id'] ?? '').toString();
            if (id.isNotEmpty) return id;
          }
        }
        return null;
      }();

      if (found != null) {
        _resolvedProviderId = found;
        if (mounted) setState(() {});
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _resolvingPid = false);
    }
  }

  Future<Map<String, dynamic>?> _loadProviderFullIfNeeded() async {
    if (_providerFull != null) return _providerFull;
    final pid = _effectiveProviderId;
    if (pid == null) return null;
    setState(() => _loadingProv = true);
    try {
      final m = await ref.read(apiProvider).providerDetails(pid);
      _providerFull = m;
      return m;
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _loadingProv = false);
    }
  }

  Future<void> _openMaps() async {
    Map<String, dynamic> prov = _providerMap(_m);
    String? mapsUrl = _mapsUrl(prov);
    var (lat, lng) = _coords(prov);

    if ((mapsUrl == null || mapsUrl.isEmpty) && (lat == null || lng == null)) {
      final full = await _loadProviderFullIfNeeded();
      if (full != null) {
        prov = full;
        mapsUrl = _mapsUrl(prov);
        (lat, lng) = _coords(prov);
      }
    }

    try {
      if (mapsUrl != null && mapsUrl.isNotEmpty) {
        final uri = Uri.parse(mapsUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      if (lat != null && lng != null) {
        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      final name = _providerName(prov);
      final addr = (prov['address'] ?? '').toString();
      final q = Uri.encodeComponent([name, addr].where((e) => e.trim().isNotEmpty).join(' '));
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir Google Maps: $e')),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.cancelBookingTitle,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: 'SFPRO',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.cancelBookingMessage,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontFamily: 'SFPRO',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.no,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontFamily: 'SFPRO',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              l10n.yesCancel,
              style: const TextStyle(fontFamily: 'SFPRO'),
            ),
          ),
        ],
      ),
    );
    if (ok != true || _bookingId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).setMyBookingStatus(
        bookingId: _bookingId!,
        status: 'CANCELLED',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bookingCancelled)),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _modifyBooking() async {
    final l10n = AppLocalizations.of(context);
    final pid = _effectiveProviderId, sid = _serviceId;
    if (pid == null || sid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.modificationImpossible)),
      );
      return;
    }

    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingFlowScreen(providerId: pid, serviceId: sid)),
    );

    if (!mounted) return;

    if (created is! Map || ((created['id'] ?? '').toString().isEmpty)) return;

    if (_bookingId != null) {
      setState(() => _busy = true);
      try {
        await ref.read(apiProvider).setMyBookingStatus(
          bookingId: _bookingId!,
          status: 'CANCELLED',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.oldBookingCancelled)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.error}: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingThanksScreen(createdBooking: Map<String, dynamic>.from(created)),
      ),
    );

    if (!mounted) return;
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    // Colors based on theme
    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    // Parse booking data
    final iso = (_m['scheduledAt'] ?? _m['scheduled_at'] ?? '').toString();
    DateTime? dtUtc;
    try {
      dtUtc = DateTime.parse(iso);
    } catch (_) {}

    final dateStr = dtUtc != null
        ? DateFormat('EEEE d MMMM yyyy', locale == 'ar' ? 'ar' : locale == 'en' ? 'en' : 'fr_FR').format(dtUtc)
        : '—';
    final timeStr = dtUtc != null ? DateFormat('HH:mm').format(dtUtc) : '—';

    final provLight = _providerMap(_m);
    final providerName = _providerName(provLight);
    final service = _serviceName(_m);
    final price = _servicePrice(_m);

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
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: textPrimary,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.bookingDetailsTitle,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            fontFamily: 'SFPRO',
          ),
        ),
        centerTitle: true,
        actions: [
          if (_loadingProv || _resolvingPid)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _coral,
                ),
              ),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
          child: Column(
            children: [
              // Status Banner
              _buildStatusBanner(isDark, l10n, cardColor, textPrimary),
              const SizedBox(height: 20),

              // Info Cards
              _buildInfoCard(
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                icon: Icons.calendar_month_rounded,
                iconColor: _coral,
                title: l10n.dateLabel,
                value: dateStr,
              ),
              const SizedBox(height: 12),

              _buildInfoCard(
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFF6C63FF),
                title: l10n.timeLabel,
                value: timeStr,
              ),
              const SizedBox(height: 12),

              _buildInfoCard(
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFF4CAF50),
                title: l10n.locationLabel,
                value: providerName,
              ),
              const SizedBox(height: 12),

              _buildInfoCard(
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                icon: Icons.medical_services_rounded,
                iconColor: const Color(0xFF2196F3),
                title: l10n.serviceLabel,
                value: service,
              ),
              const SizedBox(height: 12),

              _buildInfoCard(
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFFFF9800),
                title: l10n.amountLabel,
                value: price == null ? '—' : '${NumberFormat.decimalPattern('fr_FR').format(price)} DA',
                isHighlighted: true,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDark, l10n, cardColor, textPrimary),
    );
  }

  Widget _buildStatusBanner(bool isDark, AppLocalizations l10n, Color cardColor, Color textPrimary) {
    final isPending = _isPending;
    final statusColor = isPending ? _amber : const Color(0xFF4CAF50);
    final statusBgColor = isDark
        ? (isPending ? _amber.withOpacity(0.15) : const Color(0xFF4CAF50).withOpacity(0.15))
        : (isPending ? _amberSoft : const Color(0xFFE8F5E9));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(isDark ? 0.1 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPending ? Icons.hourglass_empty_rounded : Icons.check_circle_rounded,
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending ? l10n.pendingConfirmation : l10n.confirmedBooking,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textPrimary,
                    fontFamily: 'SFPRO',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPending ? l10n.pendingStatusMessage : l10n.confirmedStatusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontFamily: 'SFPRO',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted
            ? Border.all(color: _coral.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    fontFamily: 'SFPRO',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isHighlighted ? 18 : 15,
                    color: isHighlighted ? _coral : textPrimary,
                    fontFamily: 'SFPRO',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, AppLocalizations l10n, Color cardColor, Color textPrimary) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Action buttons
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _confirmCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _coral,
                      side: BorderSide(color: _coral.withOpacity(0.5), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          l10n.cancel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'SFPRO',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Modify button
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: (_busy || _effectiveProviderId == null || _serviceId == null)
                        ? null
                        : _modifyBooking,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? _darkCardAlt : Colors.grey[100],
                      foregroundColor: textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: textPrimary),
                        const SizedBox(width: 6),
                        Text(
                          l10n.modify,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'SFPRO',
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Itinerary button (only for confirmed)
                if (_isConfirmed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _openMaps,
                      style: FilledButton.styleFrom(
                        backgroundColor: _coral,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            l10n.directions,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SFPRO',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
