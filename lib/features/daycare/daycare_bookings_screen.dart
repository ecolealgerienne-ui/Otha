import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _primary = Color(0xFF00ACC1);
const _primarySoft = Color(0xFFE0F7FA);
const _ink = Color(0xFF222222);

// Commission for daycare: 100 DA per reservation
const kDaycareCommissionDa = 100;

final daycareBookingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.read(apiProvider);
    return await api.dio.get('/daycare/provider/bookings').then((r) {
      final data = r.data;
      if (data is List) return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e)));
      return [];
    });
  } catch (e) {
    return [];
  }
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
    final bookingsAsync = ref.watch(daycareBookingsProvider);

    return Theme(
      data: _themed(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('Mes réservations'),
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
                      label: 'Toutes',
                      selected: _filterStatus == 'ALL',
                      onTap: () => setState(() => _filterStatus = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'En attente',
                      selected: _filterStatus == 'PENDING',
                      onTap: () => setState(() => _filterStatus = 'PENDING'),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confirmées',
                      selected: _filterStatus == 'CONFIRMED',
                      onTap: () => setState(() => _filterStatus = 'CONFIRMED'),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Terminées',
                      selected: _filterStatus == 'COMPLETED',
                      onTap: () => setState(() => _filterStatus = 'COMPLETED'),
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Annulées',
                      selected: _filterStatus == 'CANCELLED',
                      onTap: () => setState(() => _filterStatus = 'CANCELLED'),
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            // Bookings list
            Expanded(
              child: bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
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
                    return _EmptyState(filter: _filterStatus);
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

  ThemeData _themed(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _primary,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _ink,
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
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
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
          color: selected ? chipColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [BoxShadow(color: chipColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
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
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;

    switch (filter) {
      case 'PENDING':
        message = 'Aucune réservation en attente';
        icon = Icons.hourglass_empty;
        break;
      case 'CONFIRMED':
        message = 'Aucune réservation confirmée';
        icon = Icons.thumb_up_outlined;
        break;
      case 'COMPLETED':
        message = 'Aucune réservation terminée';
        icon = Icons.check_circle_outlined;
        break;
      case 'CANCELLED':
        message = 'Aucune réservation annulée';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'Aucune réservation pour le moment';
        icon = Icons.calendar_today_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _primary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les nouvelles réservations apparaîtront ici',
            style: TextStyle(
              color: Colors.grey.shade600,
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
  final VoidCallback onToggle;
  final VoidCallback onStatusUpdate;

  const _BookingCard({
    required this.booking,
    required this.isExpanded,
    required this.onToggle,
    required this.onStatusUpdate,
  });

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (booking['id'] ?? '').toString();
    final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
    final baseTotal = _asInt(booking['totalDa'] ?? booking['total'] ?? 0);
    final startDate = booking['startDate'];
    final endDate = booking['endDate'];
    final pets = booking['pets'] as List? ?? [];
    final notes = (booking['notes'] ?? '').toString();

    // Commission: 100 DA per reservation (fixed)
    final commissionDa = kDaycareCommissionDa;

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
    final userName = (user['firstName'] ?? 'Client').toString();
    final userPhone = (user['phone'] ?? '').toString();

    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
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
                          color: statusInfo.color.withOpacity(0.1),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userName,
                              style: TextStyle(
                                color: Colors.grey.shade600,
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
                            _da(baseTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _primary,
                            ),
                          ),
                          if (commissionDa > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '+${_da(commissionDa)} com.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusInfo.color.withOpacity(0.1),
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
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                  if (start != null && end != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('dd MMM yyyy', 'fr_FR').format(start)} - ${DateFormat('dd MMM yyyy', 'fr_FR').format(end)}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.pets, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${pets.length} animal${pets.length > 1 ? 'ux' : ''}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pets
                  const Text(
                    'Animaux',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...pets.map((pet) {
                    final petData = pet is Map ? Map<String, dynamic>.from(pet) : <String, dynamic>{};
                    final petName = (petData['name'] ?? 'Animal').toString();
                    final petType = (petData['type'] ?? petData['species'] ?? '').toString();
                    final petBreed = (petData['breed'] ?? '').toString();
                    final petSize = (petData['size'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.pets, color: _primary, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  petName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (petType.isNotEmpty || petBreed.isNotEmpty || petSize.isNotEmpty)
                                  Text(
                                    [petType, petBreed, petSize].where((s) => s.isNotEmpty).join(' • '),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (userPhone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          userPhone,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Note du client',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notes,
                        style: TextStyle(
                          color: Colors.grey.shade700,
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
                              onPressed: () => _updateStatus(context, ref, id, 'CANCELLED'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Refuser'),
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
                            ),
                            icon: Icon(
                              status == 'PENDING' ? Icons.check : Icons.check_circle,
                              size: 18,
                            ),
                            label: Text(
                              status == 'PENDING' ? 'Accepter' : 'Marquer terminée',
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
      BuildContext context, WidgetRef ref, String bookingId, String newStatus) async {
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
            content: Text('Réservation ${newStatus == 'CANCELLED' ? 'refusée' : 'mise à jour'}'),
            backgroundColor: newStatus == 'CANCELLED' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo('En attente', Colors.orange, Icons.hourglass_empty);
      case 'CONFIRMED':
        return _StatusInfo('Confirmée', Colors.blue, Icons.thumb_up);
      case 'IN_PROGRESS':
        return _StatusInfo('En cours', Colors.purple, Icons.pets);
      case 'COMPLETED':
        return _StatusInfo('Terminée', Colors.green, Icons.check_circle);
      case 'CANCELLED':
        return _StatusInfo('Annulée', Colors.red, Icons.cancel);
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
