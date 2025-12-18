// lib/features/daycare/my_daycare_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

// ═══════════════════════════════════════════════════════════════
// DESIGN CONSTANTS
// ═══════════════════════════════════════════════════════════════
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _teal = Color(0xFF00ACC1);
const _green = Color(0xFF43AA8B);
const _greenSoft = Color(0xFFE8F5F0);
const _orange = Color(0xFFFF9800);
const _orangeSoft = Color(0xFFFFF3E0);
const _blue = Color(0xFF5C6BC0);
const _blueSoft = Color(0xFFE8EAF6);
const _purple = Color(0xFF7B68EE);

// Dark mode colors
const _darkBg = Color(0xFF0F0F0F);
const _darkCard = Color(0xFF1A1A1A);
const _darkCardAlt = Color(0xFF242424);

class MyDaycareBookingsScreen extends ConsumerStatefulWidget {
  const MyDaycareBookingsScreen({super.key});

  @override
  ConsumerState<MyDaycareBookingsScreen> createState() => _MyDaycareBookingsScreenState();
}

class _MyDaycareBookingsScreenState extends ConsumerState<MyDaycareBookingsScreen>
    with SingleTickerProviderStateMixin {
  Future<List<dynamic>>? _bookingsFuture;
  String _selectedFilter = 'ALL';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookings();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _loadBookings() async {
    final api = ref.read(apiProvider);
    try {
      return await api.myDaycareBookings();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? _darkCard : Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _darkCardAlt : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: textPrimary,
                ),
              ),
              onPressed: () => context.pop(),
            ),
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
                    padding: const EdgeInsets.fromLTRB(60, 16, 20, 0),
                    child: Row(
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
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.myDaycareBookings,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Filters
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.allBookings,
                      selected: _selectedFilter == 'ALL',
                      onTap: () => setState(() => _selectedFilter = 'ALL'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: l10n.pendingBookings,
                      selected: _selectedFilter == 'PENDING',
                      onTap: () => setState(() => _selectedFilter = 'PENDING'),
                      isDark: isDark,
                      color: _orange,
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: l10n.confirmedBookings,
                      selected: _selectedFilter == 'CONFIRMED',
                      onTap: () => setState(() => _selectedFilter = 'CONFIRMED'),
                      isDark: isDark,
                      color: _blue,
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: l10n.inProgressBookings,
                      selected: _selectedFilter == 'IN_PROGRESS',
                      onTap: () => setState(() => _selectedFilter = 'IN_PROGRESS'),
                      isDark: isDark,
                      color: _green,
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: l10n.completedBookings,
                      selected: _selectedFilter == 'COMPLETED',
                      onTap: () => setState(() => _selectedFilter = 'COMPLETED'),
                      isDark: isDark,
                      color: _purple,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          FutureBuilder<List<dynamic>>(
            future: _bookingsFuture,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SliverFillRemaining(
                  child: Center(
                    child: _PremiumLoader(),
                  ),
                );
              }

              if (snap.hasError) {
                return SliverFillRemaining(
                  child: _ErrorView(
                    error: snap.error.toString(),
                    onRetry: () => setState(() => _bookingsFuture = _loadBookings()),
                    isDark: isDark,
                  ),
                );
              }

              final allBookings = snap.data ?? [];
              final filtered = _selectedFilter == 'ALL'
                  ? allBookings
                  : allBookings.where((b) => b['status'] == _selectedFilter).toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyView(
                    filter: _selectedFilter,
                    l10n: l10n,
                    isDark: isDark,
                    onAddNew: () => context.push('/daycare/booking'),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, 0.1 + (index * 0.02)),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              (index * 0.08).clamp(0.0, 0.5),
                              ((index * 0.08) + 0.5).clamp(0.0, 1.0),
                              curve: Curves.easeOutCubic,
                            ),
                          )),
                          child: _PremiumBookingCard(
                            booking: filtered[index],
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

      // FAB
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_coral, Color(0xFFFF8A80)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _coral.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/daycare/booking'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            l10n.newBooking,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM BOOKING CARD
// ═══════════════════════════════════════════════════════════════
class _PremiumBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isDark;
  final AppLocalizations l10n;

  const _PremiumBookingCard({
    required this.booking,
    required this.isDark,
    required this.l10n,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return _orange;
      case 'CONFIRMED':
        return _blue;
      case 'IN_PROGRESS':
        return _green;
      case 'COMPLETED':
        return _purple;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

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
        return Icons.check_circle_rounded;
      case 'IN_PROGRESS':
        return Icons.pets_rounded;
      case 'COMPLETED':
        return Icons.done_all_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
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

    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final timeFormat = DateFormat('HH:mm');

    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : statusColor).withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [statusColor.withOpacity(0.15), statusColor.withOpacity(0.08)]
                    : [statusColor.withOpacity(0.08), statusColor.withOpacity(0.03)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider?['displayName'] ?? 'Garderie',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.pets_rounded, size: 14, color: textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${l10n.animalLabel}: ${pet?['name'] ?? l10n.notSpecified}',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Dates
                _buildDateRow(
                  Icons.login_rounded,
                  l10n.arrival,
                  dateFormat.format(startDate),
                  _teal,
                  isDark,
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: 12),
                _buildDateRow(
                  Icons.logout_rounded,
                  l10n.departure,
                  dateFormat.format(endDate),
                  _coral,
                  isDark,
                  textPrimary,
                  textSecondary,
                ),

                // Actual times
                if (actualDropOff != null) ...[
                  const SizedBox(height: 12),
                  _buildDateRow(
                    Icons.check_circle_rounded,
                    l10n.droppedAt,
                    timeFormat.format(actualDropOff),
                    _green,
                    isDark,
                    textPrimary,
                    textSecondary,
                  ),
                ],
                if (actualPickup != null) ...[
                  const SizedBox(height: 12),
                  _buildDateRow(
                    Icons.check_circle_rounded,
                    l10n.pickedUpAt,
                    timeFormat.format(actualPickup),
                    _blue,
                    isDark,
                    textPrimary,
                    textSecondary,
                  ),
                ],

                const SizedBox(height: 20),

                // Pricing
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? _darkCardAlt : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPriceColumn(
                        l10n.priceLabel,
                        '${booking['priceDa']} DA',
                        textPrimary,
                        textSecondary,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: textSecondary.withOpacity(0.2),
                      ),
                      _buildPriceColumn(
                        l10n.commissionLabel,
                        '${booking['commissionDa']} DA',
                        textPrimary,
                        textSecondary,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: textSecondary.withOpacity(0.2),
                      ),
                      _buildPriceColumn(
                        l10n.totalLabel,
                        '${booking['totalDa']} DA',
                        _coral,
                        textSecondary,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),

                // Notes
                if (booking['notes'] != null && booking['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? _blue.withOpacity(0.1) : _blueSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_rounded, size: 18, color: _blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${l10n.notesLabel}: ${booking['notes']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: textPrimary.withOpacity(0.8),
                            ),
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
    );
  }

  Widget _buildDateRow(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceColumn(
    String label,
    String value,
    Color valueColor,
    Color labelColor, {
    bool isTotal = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _coral;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [chipColor, chipColor.withOpacity(0.8)])
              : null,
          color: selected ? null : (isDark ? _darkCardAlt : Colors.grey[100]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PremiumLoader extends StatelessWidget {
  const _PremiumLoader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(_coral),
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? _darkCardAlt : _coralSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                filter == 'ALL' ? Icons.inbox_rounded : Icons.filter_list_off_rounded,
                size: 52,
                color: _coral,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              filter == 'ALL' ? l10n.noBookings : l10n.noBookingInCategory,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_coral, Color(0xFFFF8A80)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _coral.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  l10n.bookDaycare,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
