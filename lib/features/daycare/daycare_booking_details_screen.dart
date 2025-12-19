// lib/features/daycare/daycare_booking_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

class DaycareBookingDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;

  const DaycareBookingDetailsScreen({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<DaycareBookingDetailsScreen> createState() => _DaycareBookingDetailsScreenState();
}

class _DaycareBookingDetailsScreenState extends ConsumerState<DaycareBookingDetailsScreen> {
  // Theme colors
  static const _coral = Color(0xFFF36C6C);
  static const _coralSoft = Color(0xFFFFEEF0);
  static const _amber = Color(0xFFFFA000);
  static const _amberSoft = Color(0xFFFFF8E1);
  static const _green = Color(0xFF4CAF50);
  static const _blue = Color(0xFF2196F3);
  static const _darkBg = Color(0xFF121212);
  static const _darkCard = Color(0xFF1E1E1E);
  static const _darkCardAlt = Color(0xFF2A2A2A);

  bool _busy = false;

  Map<String, dynamic> get _m => widget.booking;

  String get _status => (_m['status'] ?? 'PENDING').toString().toUpperCase();
  bool get _isPending => _status == 'PENDING';
  bool get _isConfirmed => _status == 'CONFIRMED';
  bool get _canCancel => _isPending || _isConfirmed;

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
    final pet = _m['pet'] as Map<String, dynamic>?;
    final provider = _m['provider'] as Map<String, dynamic>?;
    final providerUser = provider?['user'] as Map<String, dynamic>?;

    // Les dates sont stockées en heure locale naïve (sans timezone), ne pas appeler toLocal()
    final startDate = DateTime.parse(_m['startDate']);
    final endDate = DateTime.parse(_m['endDate']);
    final totalDa = _m['totalDa'] ?? ((_m['priceDa'] ?? 0) + (_m['commissionDa'] ?? 100));

    final dateFormat = DateFormat('EEEE d MMMM yyyy', locale == 'ar' ? 'ar' : locale == 'en' ? 'en' : 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    final providerName = provider?['displayName'] ?? l10n.daycare;
    final petName = pet?['name'] ?? l10n.notSpecified;
    final phone = providerUser?['phone'] ?? provider?['phone'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: Scaffold(
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
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Text(
            l10n.daycareBookingDetails,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              fontFamily: 'SFPRO',
            ),
          ),
          centerTitle: true,
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
                  icon: Icons.pets_rounded,
                  iconColor: _coral,
                  title: l10n.animalLabel,
                  value: petName,
                ),
                const SizedBox(height: 12),

                _buildInfoCard(
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.home_work_rounded,
                  iconColor: const Color(0xFF6C63FF),
                  title: l10n.daycare,
                  value: providerName,
                ),
                const SizedBox(height: 12),

                _buildInfoCard(
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.login_rounded,
                  iconColor: _green,
                  title: l10n.plannedArrival,
                  value: '${dateFormat.format(startDate)}\n${timeFormat.format(startDate)}',
                ),
                const SizedBox(height: 12),

                _buildInfoCard(
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.logout_rounded,
                  iconColor: _blue,
                  title: l10n.plannedDeparture,
                  value: '${dateFormat.format(endDate)}\n${timeFormat.format(endDate)}',
                ),
                const SizedBox(height: 12),

                _buildInfoCard(
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  icon: Icons.payments_rounded,
                  iconColor: const Color(0xFFFF9800),
                  title: l10n.totalLabel,
                  value: '${NumberFormat.decimalPattern('fr_FR').format(totalDa)} DA',
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(isDark, l10n, cardColor, textPrimary, phone, provider),
      ),
    );
  }

  Widget _buildStatusBanner(bool isDark, AppLocalizations l10n, Color cardColor, Color textPrimary) {
    final statusInfo = _getStatusInfo(_status, l10n);
    final statusColor = statusInfo.color;
    final statusBgColor = isDark
        ? statusColor.withOpacity(0.15)
        : statusColor.withOpacity(0.1);

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
              statusInfo.icon,
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
                  statusInfo.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textPrimary,
                    fontFamily: 'SFPRO',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusInfo.description,
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

  Widget _buildBottomBar(bool isDark, AppLocalizations l10n, Color cardColor, Color textPrimary, String? phone, Map<String, dynamic>? provider) {
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
                // Cancel button (only when PENDING or CONFIRMED)
                if (_canCancel)
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

                // Itinerary button (only when CONFIRMED)
                if (_isConfirmed) ...[
                  if (_canCancel) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _openMaps(provider),
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

                // Call button (when not confirmed but has phone)
                if (!_isConfirmed && phone != null && phone.isNotEmpty) ...[
                  if (_canCancel) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _callPhone(phone),
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
                          const Icon(Icons.phone_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            l10n.call,
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

                // If no actions available, show back to home button
                if (!_canCancel && !_isConfirmed && (phone == null || phone.isEmpty))
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.go('/home'),
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
                          const Icon(Icons.home_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            l10n.backToHome,
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMaps(Map<String, dynamic>? provider) async {
    if (provider == null) return;

    try {
      // Try mapsUrl first
      final specialties = provider['specialties'];
      String? mapsUrl;
      if (specialties is Map) {
        mapsUrl = (specialties['mapsUrl'] ?? specialties['maps_url'] ?? '').toString().trim();
      }
      mapsUrl ??= (provider['mapsUrl'] ?? provider['maps_url'] ?? '').toString().trim();

      if (mapsUrl.isNotEmpty && mapsUrl.startsWith('http')) {
        final uri = Uri.parse(mapsUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // Try lat/lng
      final lat = provider['lat'];
      final lng = provider['lng'];
      if (lat is num && lng is num) {
        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // Fallback to address search
      final name = provider['displayName'] ?? '';
      final addr = provider['address'] ?? '';
      final q = Uri.encodeComponent([name, addr].where((e) => e.toString().trim().isNotEmpty).join(' '));
      if (q.isNotEmpty) {
        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir Google Maps: $e')),
      );
    }
  }

  _StatusInfo _getStatusInfo(String status, AppLocalizations l10n) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo(
          label: l10n.pendingConfirmation,
          description: l10n.pendingDescription,
          icon: Icons.hourglass_empty_rounded,
          color: _amber,
        );
      case 'CONFIRMED':
        return _StatusInfo(
          label: l10n.confirmedBooking,
          description: l10n.confirmedDescription,
          icon: Icons.check_circle_rounded,
          color: _green,
        );
      case 'IN_PROGRESS':
        return _StatusInfo(
          label: l10n.inProgressBookings,
          description: l10n.inProgressDescription,
          icon: Icons.pets_rounded,
          color: _blue,
        );
      case 'COMPLETED':
        return _StatusInfo(
          label: l10n.completedBookings,
          description: l10n.completedDescription,
          icon: Icons.done_all_rounded,
          color: Colors.grey,
        );
      case 'CANCELLED':
        return _StatusInfo(
          label: l10n.cancelledBookings,
          description: l10n.cancelledDescription,
          icon: Icons.cancel_outlined,
          color: Colors.red,
        );
      default:
        return _StatusInfo(
          label: status,
          description: '',
          icon: Icons.info_outline_rounded,
          color: Colors.grey,
        );
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).cancelDaycareBooking(_m['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.bookingCancelledSuccess),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatusInfo {
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  _StatusInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}
