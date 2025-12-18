// lib/features/daycare/daycare_booking_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Clean color palette
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _green = Color(0xFF4CAF50);
const _orange = Color(0xFFFF9800);
const _blue = Color(0xFF2196F3);

// Dark mode
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

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
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor = isDark ? _darkCardBorder : const Color(0xFFE8E8E8);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    final booking = widget.booking;
    final pet = booking['pet'] as Map<String, dynamic>?;
    final provider = booking['provider'] as Map<String, dynamic>?;
    final providerUser = provider?['user'] as Map<String, dynamic>?;
    final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final priceDa = booking['priceDa'] ?? 0;
    final commissionDa = booking['commissionDa'] ?? 100;
    final totalDa = booking['totalDa'] ?? (priceDa + commissionDa);
    final notes = booking['notes']?.toString();

    final actualDropOff = booking['actualDropOff'] != null
        ? DateTime.parse(booking['actualDropOff']).toLocal()
        : null;
    final actualPickup = booking['actualPickup'] != null
        ? DateTime.parse(booking['actualPickup']).toLocal()
        : null;

    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    final canCancel = status == 'PENDING' || status == 'CONFIRMED';
    final statusInfo = _getStatusInfo(status, l10n);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _coralSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: _coral, size: 18),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.daycareBookingDetails,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusInfo.color.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusInfo.color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusInfo.icon, color: statusInfo.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusInfo.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: statusInfo.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusInfo.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pet section
            _buildSection(
              title: l10n.animalLabel,
              icon: Icons.pets_rounded,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              isDark: isDark,
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? _darkCardBorder : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: pet?['photoUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              pet!['photoUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.pets_rounded,
                                color: textSecondary,
                                size: 28,
                              ),
                            ),
                          )
                        : Icon(Icons.pets_rounded, color: textSecondary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet?['name'] ?? l10n.notSpecified,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            pet?['species'],
                            pet?['breed'],
                            if (pet?['age'] != null) '${pet!['age']} ans',
                          ].where((e) => e != null).join(' • '),
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Daycare section
            _buildSection(
              title: l10n.daycare,
              icon: Icons.home_work_rounded,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider?['displayName'] ?? l10n.notSpecified,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  if (provider?['address'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            provider!['address'],
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (providerUser?['phone'] != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _callPhone(providerUser!['phone']),
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: Text(providerUser!['phone']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _coral,
                          side: const BorderSide(color: _coral),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dates section
            _buildSection(
              title: l10n.datesLabel,
              icon: Icons.calendar_today_rounded,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              isDark: isDark,
              child: Column(
                children: [
                  _DateRow(
                    icon: Icons.login_rounded,
                    label: l10n.plannedArrival,
                    value: '${dateFormat.format(startDate)} ${l10n.at} ${timeFormat.format(startDate)}',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 12),
                  _DateRow(
                    icon: Icons.logout_rounded,
                    label: l10n.plannedDeparture,
                    value: '${dateFormat.format(endDate)} ${l10n.at} ${timeFormat.format(endDate)}',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  if (actualDropOff != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: borderColor),
                    ),
                    _DateRow(
                      icon: Icons.check_circle_rounded,
                      label: l10n.droppedAt,
                      value: '${dateFormat.format(actualDropOff)} ${l10n.at} ${timeFormat.format(actualDropOff)}',
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      highlight: true,
                      highlightColor: _green,
                    ),
                  ],
                  if (actualPickup != null) ...[
                    const SizedBox(height: 12),
                    _DateRow(
                      icon: Icons.check_circle_rounded,
                      label: l10n.pickedUpAt,
                      value: '${dateFormat.format(actualPickup)} ${l10n.at} ${timeFormat.format(actualPickup)}',
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      highlight: true,
                      highlightColor: _blue,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Price section
            _buildSection(
              title: l10n.pricing,
              icon: Icons.payments_rounded,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              isDark: isDark,
              child: Column(
                children: [
                  _PriceRow(
                    label: l10n.priceLabel,
                    value: '$priceDa DA',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 8),
                  _PriceRow(
                    label: l10n.commissionLabel,
                    value: '$commissionDa DA',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: borderColor),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.totalLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '$totalDa DA',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _coral,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(
                title: l10n.notesLabel,
                icon: Icons.note_alt_outlined,
                cardColor: cardColor,
                borderColor: borderColor,
                textPrimary: textPrimary,
                isDark: isDark,
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Cancel button
            if (canCancel)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelBooking,
                  icon: _cancelling
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red.shade400,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(l10n.cancelBooking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _coral),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(String status, AppLocalizations l10n) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo(
          label: l10n.pendingBookings,
          description: l10n.pendingDescription,
          icon: Icons.hourglass_empty_rounded,
          color: _orange,
        );
      case 'CONFIRMED':
        return _StatusInfo(
          label: l10n.confirmedBookings,
          description: l10n.confirmedDescription,
          icon: Icons.check_circle_outline_rounded,
          color: _blue,
        );
      case 'IN_PROGRESS':
        return _StatusInfo(
          label: l10n.inProgressBookings,
          description: l10n.inProgressDescription,
          icon: Icons.pets_rounded,
          color: _green,
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

  Future<void> _cancelBooking() async {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_rounded, color: Colors.red, size: 32),
        ),
        title: Text(
          l10n.cancelBookingConfirm,
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          l10n.cancelBookingMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.yesCancel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);

    try {
      final api = ref.read(apiProvider);
      await api.cancelDaycareBooking(widget.booking['id']);

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
      if (mounted) {
        setState(() => _cancelling = false);
      }
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

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final bool highlight;
  final Color? highlightColor;

  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    this.highlight = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? (highlightColor ?? _coral) : textSecondary;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: highlight ? highlightColor : textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _PriceRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}
