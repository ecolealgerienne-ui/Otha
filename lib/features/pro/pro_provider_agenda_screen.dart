// lib/features/pro/pro_provider_agenda_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import 'pro_verify_otp_screen.dart';

/// ---------- Args immuables pour le provider family ----------
class _AgendaArgs {
  final String fromIsoUtc;
  final String toIsoUtc;
  const _AgendaArgs(this.fromIsoUtc, this.toIsoUtc);

  @override
  bool operator ==(Object o) =>
      identical(this, o) ||
      o is _AgendaArgs && o.fromIsoUtc == fromIsoUtc && o.toIsoUtc == toIsoUtc;

  @override
  int get hashCode => Object.hash(fromIsoUtc, toIsoUtc);
}

/// ---------- Provider family: charge l'agenda d'une journée ----------
final _agendaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _AgendaArgs>((ref, args) async {
  final api = ref.read(apiProvider);
  final rows = await api.providerAgenda(fromIso: args.fromIsoUtc, toIso: args.toIsoUtc);
  return rows.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// ---------- Ecran Agenda Timeline ----------
class ProviderAgendaScreen extends ConsumerStatefulWidget {
  const ProviderAgendaScreen({super.key});

  @override
  ConsumerState<ProviderAgendaScreen> createState() => _ProviderAgendaScreenState();
}

class _ProviderAgendaScreenState extends ConsumerState<ProviderAgendaScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late DateTime _selectedDate;

  // Focus transmis depuis Home
  String? _focusBookingId;

  // Scroll pour timeline
  final ScrollController _scrollCtl = ScrollController();
  final Map<String, GlobalKey> _rowKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDate = DateTime.now();
    _pageController = PageController(initialPage: 500); // Centre pour swipe infini
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map) {
      final iso = extra['focusIso']?.toString();
      final bid = extra['bookingId']?.toString();
      if (iso != null && iso.isNotEmpty) {
        try {
          _selectedDate = DateTime.parse(iso);
          _focusBookingId = bid;
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDay();
    }
  }

  DateTime _dateForPage(int page) {
    final diff = page - 500;
    return DateTime.now().add(Duration(days: diff));
  }

  _AgendaArgs _argsForDate(DateTime date) {
    final fromUtc = DateTime.utc(date.year, date.month, date.day);
    final toUtc = fromUtc.add(const Duration(days: 1));
    return _AgendaArgs(fromUtc.toIso8601String(), toUtc.toIso8601String());
  }

  Future<void> _refreshDay() async {
    final args = _argsForDate(_selectedDate);
    ref.invalidate(_agendaProvider(args));
    await ref.read(_agendaProvider(args).future);
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
    _pageController.animateToPage(
      500,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousDay() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextDay() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header avec navigation
            _AgendaHeader(
              date: _selectedDate,
              onPrevious: _previousDay,
              onNext: _nextDay,
              onToday: _goToToday,
            ),

            // Timeline avec PageView pour swipe
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _selectedDate = _dateForPage(page));
                },
                itemBuilder: (context, page) {
                  final date = _dateForPage(page);
                  return _DayTimeline(
                    date: date,
                    args: _argsForDate(date),
                    scrollController: _scrollCtl,
                    focusBookingId: _focusBookingId,
                    rowKeys: _rowKeys,
                    onRefresh: _refreshDay,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- Header avec date et navigation ----------
class _AgendaHeader extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _AgendaHeader({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  bool get _isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE', 'fr_FR').format(date);
    final dayNum = DateFormat('d MMMM', 'fr_FR').format(date);
    final capitalizedDay = dayName[0].toUpperCase() + dayName.substring(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bouton retour
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              padding: const EdgeInsets.all(10),
            ),
          ),

          // Navigation jour
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, size: 28),
          ),

          // Date centrale
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              child: Column(
                children: [
                  Text(
                    capitalizedDay,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isToday ? const Color(0xFFF36C6C) : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayNum,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation jour
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 28),
          ),

          // Bouton Aujourd'hui
          TextButton.icon(
            onPressed: onToday,
            icon: Icon(
              Icons.today,
              size: 18,
              color: _isToday ? Colors.grey : const Color(0xFFF36C6C),
            ),
            label: Text(
              'Auj.',
              style: TextStyle(
                color: _isToday ? Colors.grey : const Color(0xFFF36C6C),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: _isToday ? const Color(0xFFF3F4F6) : const Color(0xFFFFEEF0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- Timeline d'une journée ----------
class _DayTimeline extends ConsumerWidget {
  final DateTime date;
  final _AgendaArgs args;
  final ScrollController scrollController;
  final String? focusBookingId;
  final Map<String, GlobalKey> rowKeys;
  final Future<void> Function() onRefresh;

  const _DayTimeline({
    required this.date,
    required this.args,
    required this.scrollController,
    required this.focusBookingId,
    required this.rowKeys,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_agendaProvider(args));

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF36C6C)),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Erreur: $e', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (items) => _buildTimeline(context, items),
    );
  }

  Widget _buildTimeline(BuildContext context, List<Map<String, dynamic>> items) {
    // Trier par heure
    final sorted = [...items];
    sorted.sort((a, b) {
      final A = DateTime.parse((a['scheduledAt'] ?? a['scheduled_at']).toString());
      final B = DateTime.parse((b['scheduledAt'] ?? b['scheduled_at']).toString());
      return A.compareTo(B);
    });

    // Grouper par heure
    final Map<int, List<Map<String, dynamic>>> byHour = {};
    for (final item in sorted) {
      final iso = (item['scheduledAt'] ?? item['scheduled_at']).toString();
      final dt = DateTime.parse(iso);
      final hour = dt.hour;
      byHour.putIfAbsent(hour, () => []).add(item);
    }

    // Heures de travail (8h - 20h)
    const startHour = 8;
    const endHour = 20;

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: const Color(0xFFF36C6C),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun rendez-vous',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Votre journée est libre',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFFF36C6C),
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: endHour - startHour,
        itemBuilder: (context, index) {
          final hour = startHour + index;
          final bookings = byHour[hour] ?? [];

          return _TimeSlot(
            hour: hour,
            bookings: bookings,
            focusBookingId: focusBookingId,
            rowKeys: rowKeys,
            onRefresh: onRefresh,
          );
        },
      ),
    );
  }
}

/// ---------- Slot horaire avec ses RDV ----------
class _TimeSlot extends StatelessWidget {
  final int hour;
  final List<Map<String, dynamic>> bookings;
  final String? focusBookingId;
  final Map<String, GlobalKey> rowKeys;
  final Future<void> Function() onRefresh;

  const _TimeSlot({
    required this.hour,
    required this.bookings,
    required this.focusBookingId,
    required this.rowKeys,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:00';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne heure
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: bookings.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
                ),
              ),
            ),
          ),

          // Ligne + contenu
          Expanded(
            child: Column(
              children: [
                if (bookings.isEmpty)
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                  )
                else
                  ...bookings.map((m) {
                    final id = (m['id'] ?? '').toString();
                    final key = rowKeys.putIfAbsent(id, () => GlobalKey());
                    final isFocus = focusBookingId == id;

                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: _BookingCard(
                        key: key,
                        m: m,
                        highlight: isFocus,
                        onRefresh: onRefresh,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- Carte RDV compacte ----------
class _BookingCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> m;
  final bool highlight;
  final Future<void> Function() onRefresh;

  const _BookingCard({
    super.key,
    required this.m,
    required this.onRefresh,
    this.highlight = false,
  });

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      final id = widget.m['id'].toString();
      await ref.read(apiProvider).providerSetStatus(bookingId: id, status: status);
      widget.m['status'] = status;
      await widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusMessage(status)),
            backgroundColor: _statusColor(status),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'CONFIRMED': return 'RDV confirmé ✓';
      case 'COMPLETED': return 'RDV terminé ✓';
      case 'CANCELLED': return 'RDV annulé';
      default: return 'Statut mis à jour';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING': return const Color(0xFFFFC857);
      case 'CONFIRMED': return const Color(0xFF43AA8B);
      case 'COMPLETED': return const Color(0xFF577590);
      case 'CANCELLED': return const Color(0xFF8D99AE);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;

    // Parse données
    final iso = (m['scheduledAt'] ?? m['scheduled_at']).toString();
    DateTime? dt;
    try { dt = DateTime.parse(iso); } catch (_) {}
    final time = dt != null ? DateFormat('HH:mm').format(dt) : '--:--';

    final status = (m['status'] ?? '').toString();
    final statusColor = _statusColor(status);

    final serviceTitle = (m['service']?['title'] ?? 'Consultation').toString();
    final priceNum = m['service']?['price'];
    final priceLabel = (priceNum is num) ? '${priceNum.round()} DA' : null;

    final displayName = (m['user']?['displayName'] ?? 'Client').toString();
    final phone = (m['user']?['phone'] ?? '').toString().trim();
    final petType = (m['pet']?['label'] ?? '').toString().trim();
    final petName = (m['pet']?['name'] ?? '').toString().trim();

    final isFirstBooking = m['user']?['isFirstBooking'] == true;
    final canShowPhone = status == 'CONFIRMED' || status == 'COMPLETED';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: widget.highlight
            ? Border.all(color: const Color(0xFF2E7DFF), width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Barre colorée latérale
            Container(
              width: 5,
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 90),
              color: statusColor,
            ),

            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1: Heure + Service + Badge nouveau
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            serviceTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFirstBooking)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 12, color: Colors.orange.shade600),
                                const SizedBox(width: 3),
                                Text(
                                  'Nouveau',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Ligne 2: Client + Animal + Prix
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              displayName,
                              if (petType.isNotEmpty) '• $petType',
                              if (petName.isNotEmpty) '($petName)',
                            ].join(' '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (priceLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              priceLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Téléphone (si confirmé/terminé)
                    if (canShowPhone && phone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Boutons d'action
                    _buildActions(status, displayName, serviceTitle),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(String status, String clientName, String serviceTitle) {
    if (status == 'COMPLETED' || status == 'CANCELLED') {
      return Row(
        children: [
          Icon(
            status == 'COMPLETED' ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: _statusColor(status),
          ),
          const SizedBox(width: 6),
          Text(
            status == 'COMPLETED' ? 'Terminé' : 'Annulé',
            style: TextStyle(
              fontSize: 13,
              color: _statusColor(status),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Bouton principal
        if (status == 'PENDING')
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : () => _setStatus('CONFIRMED'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43AA8B),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),

        if (status == 'CONFIRMED')
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : () => _setStatus('COMPLETED'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF577590),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Terminer', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),

        const SizedBox(width: 8),

        // Bouton OTP
        if (status == 'PENDING' || status == 'CONFIRMED')
          SizedBox(
            width: 48,
            child: FilledButton(
              onPressed: _busy ? null : () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => ProVerifyOtpDialog(
                    bookingId: (widget.m['id'] ?? '').toString(),
                    clientName: clientName,
                    serviceTitle: serviceTitle,
                  ),
                );
                if (result == true) await widget.onRefresh();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF36C6C),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.pin, size: 18),
            ),
          ),

        const SizedBox(width: 8),

        // Bouton Annuler
        if (status == 'PENDING' || status == 'CONFIRMED')
          SizedBox(
            width: 48,
            child: OutlinedButton(
              onPressed: _busy ? null : () => _confirmCancel(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce RDV ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _setStatus('CANCELLED');
    }
  }
}
