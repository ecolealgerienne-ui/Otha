// lib/features/daycare/my_daycare_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Clean color palette - coral only
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

// Dark mode
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

class MyDaycareBookingsScreen extends ConsumerStatefulWidget {
  const MyDaycareBookingsScreen({super.key});

  @override
  ConsumerState<MyDaycareBookingsScreen> createState() =>
      _MyDaycareBookingsScreenState();
}

class _MyDaycareBookingsScreenState
    extends ConsumerState<MyDaycareBookingsScreen> {
  Future<List<dynamic>>? _bookingsFuture;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookings();
  }

  Future<List<dynamic>> _loadBookings() async {
    final api = ref.read(apiProvider);
    return await api.myDaycareBookings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor = isDark ? _darkCardBorder : const Color(0xFFE8E8E8);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

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
              child: const Icon(Icons.pets_rounded, color: _coral, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.myDaycareBookings,
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
      body: Column(
        children: [
          // Filters
          Container(
            color: cardColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: l10n.allBookings,
                    selected: _selectedFilter == 'ALL',
                    onTap: () => setState(() => _selectedFilter = 'ALL'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.pendingBookings,
                    selected: _selectedFilter == 'PENDING',
                    onTap: () => setState(() => _selectedFilter = 'PENDING'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.confirmedBookings,
                    selected: _selectedFilter == 'CONFIRMED',
                    onTap: () => setState(() => _selectedFilter = 'CONFIRMED'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.inProgressBookings,
                    selected: _selectedFilter == 'IN_PROGRESS',
                    onTap: () => setState(() => _selectedFilter = 'IN_PROGRESS'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.completedBookings,
                    selected: _selectedFilter == 'COMPLETED',
                    onTap: () => setState(() => _selectedFilter = 'COMPLETED'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: borderColor),

          // Content
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _bookingsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: _coral),
                  );
                }

                if (snap.hasError) {
                  return _ErrorView(
                    error: snap.error.toString(),
                    onRetry: () => setState(() => _bookingsFuture = _loadBookings()),
                    isDark: isDark,
                    l10n: l10n,
                  );
                }

                final allBookings = snap.data ?? [];
                final filtered = _selectedFilter == 'ALL'
                    ? allBookings
                    : allBookings.where((b) => b['status'] == _selectedFilter).toList();

                if (filtered.isEmpty) {
                  return _EmptyView(
                    filter: _selectedFilter,
                    l10n: l10n,
                    isDark: isDark,
                    onAddNew: () => context.push('/daycare/booking'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    return _BookingCard(
                      booking: filtered[index],
                      isDark: isDark,
                      l10n: l10n,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/daycare/booking'),
        backgroundColor: _coral,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n.newBooking,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// BOOKING CARD
// ───────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isDark;
  final AppLocalizations l10n;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _BookingCard({
    required this.booking,
    required this.isDark,
    required this.l10n,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return l10n.pendingBookings;
      case 'CONFIRMED':
        return l10n.confirmedBookings;
      case 'IN_PROGRESS':
        return l10n.inProgressBookings;
      case 'COMPLETED':
        return l10n.completedBookings;
      case 'CANCELLED':
        return l10n.cancelledBookings;
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty_rounded;
      case 'CONFIRMED':
        return Icons.check_circle_outline_rounded;
      case 'IN_PROGRESS':
        return Icons.pets_rounded;
      case 'COMPLETED':
        return Icons.done_all_rounded;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = booking['pet'] as Map<String, dynamic>?;
    final provider = booking['provider'] as Map<String, dynamic>?;
    final status = booking['status'] as String;
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final actualDropOff = booking['actualDropOff'] != null
        ? DateTime.parse(booking['actualDropOff']).toLocal()
        : null;
    final actualPickup = booking['actualPickup'] != null
        ? DateTime.parse(booking['actualPickup']).toLocal()
        : null;

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _coralSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getStatusIcon(status), color: _coral, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider?['displayName'] ?? l10n.daycareTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.pets_rounded, size: 14, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            pet?['name'] ?? l10n.notSpecified,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _coral,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: borderColor),

          // Dates section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DateRow(
                  icon: Icons.login_rounded,
                  label: l10n.arrival,
                  value: dateFormat.format(startDate),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 10),
                _DateRow(
                  icon: Icons.logout_rounded,
                  label: l10n.departure,
                  value: dateFormat.format(endDate),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                if (actualDropOff != null) ...[
                  const SizedBox(height: 10),
                  _DateRow(
                    icon: Icons.check_rounded,
                    label: l10n.droppedAt,
                    value: timeFormat.format(actualDropOff),
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    highlight: true,
                  ),
                ],
                if (actualPickup != null) ...[
                  const SizedBox(height: 10),
                  _DateRow(
                    icon: Icons.check_rounded,
                    label: l10n.pickedUpAt,
                    value: timeFormat.format(actualPickup),
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    highlight: true,
                  ),
                ],
              ],
            ),
          ),

          Container(height: 1, color: borderColor),

          // Pricing
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _PriceItem(
                    label: l10n.priceLabel,
                    value: '${booking['priceDa']} DA',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: borderColor,
                ),
                Expanded(
                  child: _PriceItem(
                    label: l10n.commissionLabel,
                    value: '${booking['commissionDa']} DA',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: borderColor,
                ),
                Expanded(
                  child: _PriceItem(
                    label: l10n.totalLabel,
                    value: '${booking['totalDa']} DA',
                    textPrimary: _coral,
                    textSecondary: textSecondary,
                    isTotal: true,
                  ),
                ),
              ],
            ),
          ),

          // Notes
          if (booking['notes'] != null && booking['notes'].toString().isNotEmpty) ...[
            Container(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note_outlined, size: 16, color: textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking['notes'].toString(),
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final bool highlight;

  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: highlight ? _coralSoft : textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: highlight ? _coral : textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceItem extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final bool isTotal;

  const _PriceItem({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _coral : (isDark ? _darkCardBorder : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: selected ? null : Border.all(
            color: isDark ? _darkCardBorder : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String filter;
  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback onAddNew;

  const _EmptyView({
    required this.filter,
    required this.l10n,
    required this.isDark,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white70 : Colors.grey[600];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? _darkCardBorder : _coralSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                filter == 'ALL' ? Icons.inbox_outlined : Icons.filter_list_off_rounded,
                size: 48,
                color: _coral,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              filter == 'ALL' ? l10n.noBookings : l10n.noBookingInCategory,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                l10n.bookDaycare,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final bool isDark;
  final AppLocalizations l10n;

  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.isDark,
    required this.l10n,
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
                color: _coralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: _coral,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: _coral),
              label: Text(
                l10n.retry,
                style: const TextStyle(color: _coral),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _coral),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
