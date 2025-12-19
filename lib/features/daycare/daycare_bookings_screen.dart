import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _primary = Color(0xFF00ACC1);
const _primarySoft = Color(0xFFE0F7FA);
const _primarySoftDark = Color(0xFF1A3A3D);
const _ink = Color(0xFF222222);
const _inkDark = Color(0xFFFFFFFF);
const _bgLight = Color(0xFFF7F8FA);
const _bgDark = Color(0xFF121212);
const _cardLight = Color(0xFFFFFFFF);
const _cardDark = Color(0xFF1E1E1E);

// Commission for daycare: 100 DA per reservation
const kDaycareCommissionDa = 100;

final daycareBookingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final bookings = await api.myDaycareProviderBookings();
  return bookings.map((b) => Map<String, dynamic>.from(b as Map)).toList();
});

class DaycareBookingsScreen extends ConsumerStatefulWidget {
  const DaycareBookingsScreen({super.key});

  @override
  ConsumerState<DaycareBookingsScreen> createState() =>
      _DaycareBookingsScreenState();
}

class _DaycareBookingsScreenState extends ConsumerState<DaycareBookingsScreen> {
  String _filterStatus = 'ALL';
  String? _expandedBookingId;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final bookingsAsync = ref.watch(daycareBookingsProvider);

    return Theme(
      data: _themed(context, isDark),
      child: Scaffold(
        backgroundColor: isDark ? _bgDark : _bgLight,
        appBar: AppBar(
          title: Text(l10n.myBookings),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(daycareBookingsProvider),
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.allBookings,
                      selected: _filterStatus == 'ALL',
                      onTap: () => setState(() => _filterStatus = 'ALL'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.pendingBookings,
                      selected: _filterStatus == 'PENDING',
                      onTap: () => setState(() => _filterStatus = 'PENDING'),
                      color: Colors.orange,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.confirmedBookings,
                      selected: _filterStatus == 'CONFIRMED',
                      onTap: () => setState(() => _filterStatus = 'CONFIRMED'),
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.inCare,
                      selected: _filterStatus == 'IN_PROGRESS',
                      onTap: () => setState(() => _filterStatus = 'IN_PROGRESS'),
                      color: Colors.purple,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.completedBookings,
                      selected: _filterStatus == 'COMPLETED',
                      onTap: () => setState(() => _filterStatus = 'COMPLETED'),
                      color: Colors.green,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.cancelledBookings,
                      selected: _filterStatus == 'CANCELLED',
                      onTap: () => setState(() => _filterStatus = 'CANCELLED'),
                      color: Colors.red,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // Bookings list
            Expanded(
              child: bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${l10n.error}: $e', style: TextStyle(color: isDark ? Colors.white : null))),
                data: (bookings) {
                  final filtered = _filterStatus == 'ALL'
                      ? bookings
                      : bookings.where((b) {
                          final status = (b['status'] ?? '').toString().toUpperCase();
                          return status == _filterStatus;
                        }).toList();

                  // Sort by date descending
                  filtered.sort((a, b) {
                    final aDate = DateTime.tryParse(
                            (a['startDate'] ?? a['createdAt'] ?? '').toString()) ??
                        DateTime(2000);
                    final bDate = DateTime.tryParse(
                            (b['startDate'] ?? b['createdAt'] ?? '').toString()) ??
                        DateTime(2000);
                    return bDate.compareTo(aDate);
                  });

                  if (filtered.isEmpty) {
                    return _EmptyState(filter: _filterStatus, isDark: isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(daycareBookingsProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _BookingCard(
                        booking: filtered[i],
                        isExpanded: _expandedBookingId == filtered[i]['id'],
                        isDark: isDark,
                        onToggle: () {
                          setState(() {
                            if (_expandedBookingId == filtered[i]['id']) {
                              _expandedBookingId = null;
                            } else {
                              _expandedBookingId = filtered[i]['id']?.toString();
                            }
                          });
                        },
                        onStatusUpdate: () => ref.invalidate(daycareBookingsProvider),
                      ),
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

  ThemeData _themed(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _primary,
        surface: isDark ? _cardDark : _cardLight,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark ? _bgDark : _cardLight,
        foregroundColor: isDark ? _inkDark : _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? _inkDark : _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
      dividerColor: isDark ? Colors.white12 : null,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor : (isDark ? _cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : (isDark ? Colors.white24 : Colors.grey.shade300),
          ),
          boxShadow: selected
              ? [BoxShadow(color: chipColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  final bool isDark;
  const _EmptyState({required this.filter, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String message;
    IconData icon;

    switch (filter) {
      case 'PENDING':
        message = l10n.noBookingInCategory;
        icon = Icons.hourglass_empty;
        break;
      case 'CONFIRMED':
        message = l10n.noBookingInCategory;
        icon = Icons.thumb_up_outlined;
        break;
      case 'IN_PROGRESS':
        message = l10n.noAnimalsInCare;
        icon = Icons.pets_outlined;
        break;
      case 'COMPLETED':
        message = l10n.noBookingInCategory;
        icon = Icons.check_circle_outlined;
        break;
      case 'CANCELLED':
        message = l10n.noBookingInCategory;
        icon = Icons.cancel_outlined;
        break;
      default:
        message = l10n.noBookings;
        icon = Icons.calendar_today_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? _primarySoftDark : _primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _primary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? _inkDark : _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.newBookingsWillAppear,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onStatusUpdate;

  const _BookingCard({
    required this.booking,
    required this.isExpanded,
    required this.isDark,
    required this.onToggle,
    required this.onStatusUpdate,
  });

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = (booking['id'] ?? '').toString();
    final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
    final totalDa = _asInt(booking['totalDa'] ?? booking['total'] ?? 0);
    final priceDa = _asInt(booking['priceDa'] ?? 0);
    final commissionDa = _asInt(booking['commissionDa'] ?? kDaycareCommissionDa);
    final startDate = booking['startDate'];
    final endDate = booking['endDate'];
    final pet = booking['pet'] as Map<String, dynamic>?;
    final pets = pet != null ? [pet] : [];
    final notes = (booking['notes'] ?? '').toString();

    DateTime? start, end;
    if (startDate != null) {
      try {
        start = DateTime.parse(startDate.toString());
      } catch (_) {}
    }
    if (endDate != null) {
      try {
        end = DateTime.parse(endDate.toString());
      } catch (_) {}
    }

    final user = booking['user'] as Map? ?? {};
    final userName = (user['firstName'] ?? l10n.client).toString();
    final userPhone = (user['phone'] ?? '').toString();

    final statusInfo = _getStatusInfo(status, l10n);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : _cardLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(statusInfo.icon, color: statusInfo.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${id.length > 8 ? id.substring(0, 8) : id}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? _inkDark : _ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userName,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _da(priceDa),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? _inkDark : _ink,
                            ),
                          ),
                          if (commissionDa > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '+${_da(commissionDa)} ${l10n.commissionLabel.toLowerCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            '= ${_da(totalDa)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusInfo.color.withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusInfo.label,
                              style: TextStyle(
                                color: statusInfo.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  if (start != null && end != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.white54 : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('dd MMM yyyy', 'fr_FR').format(start)} - ${DateFormat('dd MMM yyyy', 'fr_FR').format(end)}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.pets, size: 14, color: isDark ? Colors.white54 : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${pets.length} ${l10n.animal}${pets.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Divider(height: 1, color: isDark ? Colors.white12 : null),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animal
                  Text(
                    l10n.animal,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? _inkDark : _ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...pets.map((pet) {
                    final petData = pet is Map ? Map<String, dynamic>.from(pet) : <String, dynamic>{};
                    final petName = (petData['name'] ?? l10n.animal).toString();
                    final petType = (petData['type'] ?? petData['species'] ?? '').toString();
                    final petBreed = (petData['breed'] ?? '').toString();
                    final petSize = (petData['size'] ?? '').toString();
                    final petPhotoUrl = (petData['photoUrl'] ?? '').toString();

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? _primarySoftDark : _primarySoft.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primary.withOpacity(isDark ? 0.3 : 0.2)),
                      ),
                      child: Row(
                        children: [
                          // Grande image de l'animal
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: _primary.withOpacity(isDark ? 0.2 : 0.1),
                            backgroundImage: petPhotoUrl.isNotEmpty ? NetworkImage(petPhotoUrl) : null,
                            child: petPhotoUrl.isEmpty
                                ? const Icon(Icons.pets, color: _primary, size: 32)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  petName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: isDark ? _inkDark : _ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (petBreed.isNotEmpty)
                                  Text(
                                    petBreed,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (petType.isNotEmpty || petSize.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    [petType, petSize].where((s) => s.isNotEmpty).join(' • '),
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Afficher le téléphone seulement si confirmé ou après
                  if (userPhone.isNotEmpty && (status == 'CONFIRMED' || status == 'IN_PROGRESS' || status == 'COMPLETED')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: isDark ? Colors.white60 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          userPhone,
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.clientNote,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? _inkDark : _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notes,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],

                  // Action buttons
                  if (status == 'PENDING' || status == 'CONFIRMED') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (status == 'PENDING') ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateStatus(context, ref, id, 'CANCELLED', l10n),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: Text(l10n.reject),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => _updateStatus(
                              context,
                              ref,
                              id,
                              status == 'PENDING' ? 'CONFIRMED' : 'COMPLETED',
                              l10n,
                            ),
                            icon: Icon(
                              status == 'PENDING' ? Icons.check : Icons.check_circle,
                              size: 18,
                            ),
                            label: Text(
                              status == 'PENDING' ? l10n.accept : l10n.markCompleted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext context, WidgetRef ref, String bookingId, String newStatus, AppLocalizations l10n) async {
    final api = ref.read(apiProvider);

    try {
      await api.dio.patch(
        '/daycare/bookings/$bookingId/status',
        data: {'status': newStatus},
      );
      onStatusUpdate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'CANCELLED' ? l10n.bookingRejected : l10n.bookingUpdated),
            backgroundColor: newStatus == 'CANCELLED' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  _StatusInfo _getStatusInfo(String status, AppLocalizations l10n) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo(l10n.pendingBookings, Colors.orange, Icons.hourglass_empty);
      case 'CONFIRMED':
        return _StatusInfo(l10n.confirmedBookings, Colors.blue, Icons.thumb_up);
      case 'PENDING_DROP_VALIDATION':
        return _StatusInfo(l10n.dropOffToValidate, Colors.teal, Icons.login);
      case 'IN_PROGRESS':
        return _StatusInfo(l10n.inProgressBookings, Colors.purple, Icons.pets);
      case 'PENDING_PICKUP_VALIDATION':
        return _StatusInfo(l10n.pickupToValidate, Colors.indigo, Icons.logout);
      case 'COMPLETED':
        return _StatusInfo(l10n.completedBookings, Colors.green, Icons.check_circle);
      case 'CANCELLED':
        return _StatusInfo(l10n.cancelledBookings, Colors.red, Icons.cancel);
      case 'DISPUTED':
        return _StatusInfo(l10n.disputed, Colors.deepOrange, Icons.warning);
      default:
        return _StatusInfo(status, Colors.grey, Icons.help_outline);
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusInfo(this.label, this.color, this.icon);
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
