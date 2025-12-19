// lib/features/daycare/daycare_booking_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/locale_provider.dart';

// Clean color palette
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _green = Color(0xFF4CAF50);
const _greenSoft = Color(0xFFE8F5E9);

// Dark mode
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

class DaycareBookingConfirmationScreen extends ConsumerWidget {
  final Map<String, dynamic>? booking;
  final String? bookingId;
  final int totalDa;
  final String? petName;
  final DateTime? startDate;
  final DateTime? endDate;

  const DaycareBookingConfirmationScreen({
    super.key,
    this.booking,
    this.bookingId,
    this.totalDa = 0,
    this.petName,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor = isDark ? _darkCardBorder : const Color(0xFFE8E8E8);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Success animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark ? _green.withOpacity(0.15) : _greenSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _green.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 64,
                      color: _green,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  l10n.bookingSent,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  l10n.bookingSentDescription,
                  style: TextStyle(
                    fontSize: 15,
                    color: textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Booking info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      // Pet name
                      if (petName != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.pets_rounded, color: _coral, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.animalLabel,
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                  Text(
                                    petName!,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, color: borderColor),
                        ),
                      ],

                      // Dates
                      if (startDate != null) ...[
                        _InfoRow(
                          icon: Icons.login_rounded,
                          label: l10n.arrival,
                          value: '${dateFormat.format(startDate!)} ${l10n.at} ${timeFormat.format(startDate!)}',
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (endDate != null) ...[
                        _InfoRow(
                          icon: Icons.logout_rounded,
                          label: l10n.departure,
                          value: '${dateFormat.format(endDate!)} ${l10n.at} ${timeFormat.format(endDate!)}',
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: borderColor),
                      ),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.totalLabel,
                                style: TextStyle(fontSize: 14, color: textSecondary),
                              ),
                              Text(
                                l10n.commissionIncluded,
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                          Text(
                            '$totalDa DA',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _coral,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? _coral.withOpacity(0.1) : _coralSoft.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _coral.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: _coral, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.daycareWillContact,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Primary button - See my booking
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (booking != null) {
                        context.go('/daycare/booking-details', extra: booking);
                      } else {
                        context.go('/daycare/my-bookings');
                      }
                    },
                    icon: const Icon(Icons.visibility_rounded),
                    label: Text(
                      l10n.seeMyBooking,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _coral,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Secondary button - Home
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: Icon(Icons.home_rounded, color: isDark ? Colors.white70 : _coral),
                    label: Text(
                      l10n.backToHome,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : _coral,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? _darkCardBorder : _coral),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
