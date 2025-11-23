import 'dart:math';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

/// ========================= THEME DAYCARE (bleu cyan) =========================
class _DaycareColors {
  static const ink = Color(0xFF1F2328);
  static const primary = Color(0xFF00ACC1); // Cyan
  static const primarySoft = Color(0xFFE0F7FA);
  static const coral = Color(0xFFF36C6C);
}

ThemeData _daycareTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _DaycareColors.primary,
      secondary: _DaycareColors.primary,
      onPrimary: Colors.white,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: _DaycareColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(_DaycareColors.primary),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: WidgetStatePropertyAll(_DaycareColors.primary.withOpacity(.12)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _DaycareColors.primary),
    dividerColor: _DaycareColors.primarySoft,
  );
}

/// ========================= PROVIDERS =========================

final myDaycareProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) => ref.read(apiProvider).myProvider(),
);

final myDaycareBookingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  // Récupère les réservations via l'endpoint daycare
  final r = await api.dio.get('/daycare/provider/bookings');
  final data = r.data;
  if (data is List) {
    return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e)));
  }
  return [];
});

final pendingDaycareBookingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bookings = await ref.watch(myDaycareBookingsProvider.future);
  return bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PENDING').toList();
});

// Commission for daycare: 100 DA per reservation
const kDaycareCommissionDa = 100;

/// Ledger pour la garderie
class _DaycareLedger {
  final String ym;
  final int bookingsCount;
  final int totalRevenue;
  final int commissionDue;
  final int commissionPaid;
  final int netDue;

  const _DaycareLedger({
    required this.ym,
    required this.bookingsCount,
    required this.totalRevenue,
    required this.commissionDue,
    required this.commissionPaid,
    required this.netDue,
  });
}

final daycareLedgerProvider = FutureProvider.autoDispose<_DaycareLedger>((ref) async {
  try {
    final bookings = await ref.watch(myDaycareBookingsProvider.future);

    final now = DateTime.now();
    final ymNow = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    int bookingsThisMonth = 0;
    int revenueThisMonth = 0;

    for (final booking in bookings) {
      // Only count completed/delivered bookings
      final status = (booking['status'] ?? '').toString().toUpperCase();
      if (status != 'COMPLETED' && status != 'DELIVERED') continue;

      // Check if this booking is from this month
      final startDate = booking['startDate'];
      if (startDate == null) continue;

      final date = DateTime.tryParse(startDate.toString());
      if (date == null) continue;

      final bookingYm = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      if (bookingYm == ymNow) {
        bookingsThisMonth++;
        revenueThisMonth += _asInt(booking['totalDa'] ?? booking['total'] ?? 0);
      }
    }

    // Commission is per booking (fixed 100 DA)
    final commissionDue = bookingsThisMonth * kDaycareCommissionDa;

    return _DaycareLedger(
      ym: ymNow,
      bookingsCount: bookingsThisMonth,
      totalRevenue: revenueThisMonth,
      commissionDue: commissionDue,
      commissionPaid: 0, // TODO: Connect to backend payment tracking
      netDue: commissionDue,
    );
  } catch (_) {
    final now = DateTime.now();
    final ymNow = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _DaycareLedger(
      ym: ymNow,
      bookingsCount: 0,
      totalRevenue: 0,
      commissionDue: 0,
      commissionPaid: 0,
      netDue: 0,
    );
  }
});

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// ========================= MAIN SCREEN =========================

class DaycareHomeScreen extends ConsumerStatefulWidget {
  const DaycareHomeScreen({super.key});

  @override
  ConsumerState<DaycareHomeScreen> createState() => _DaycareHomeScreenState();
}

class _DaycareHomeScreenState extends ConsumerState<DaycareHomeScreen> {
  @override
  Widget build(BuildContext context) {
    const bgSoft = Color(0xFFF7F8FA);

    final state = ref.watch(sessionProvider);
    final user = state.user ?? {};
    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    final fallbackUserName =
        [if (first.isNotEmpty) first, if (last.isNotEmpty) last].join(' ').trim();

    final provAsync = ref.watch(myDaycareProfileProvider);
    final daycareName = provAsync.maybeWhen(
      data: (p) {
        final dn = (p?['displayName'] ?? '').toString().trim();
        if (dn.isNotEmpty) return dn;
        return fallbackUserName.isNotEmpty ? fallbackUserName : 'Ma Garderie';
      },
      orElse: () => (fallbackUserName.isNotEmpty ? fallbackUserName : 'Ma Garderie'),
    );

    final pendingAsync = ref.watch(pendingDaycareBookingsProvider);
    final bookingsAsync = ref.watch(myDaycareBookingsProvider);
    final ledgerAsync = ref.watch(daycareLedgerProvider);

    return Theme(
      data: _daycareTheme(context),
      child: Scaffold(
        backgroundColor: bgSoft,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myDaycareProfileProvider);
              ref.invalidate(myDaycareBookingsProvider);
              ref.invalidate(pendingDaycareBookingsProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _Header(
                    daycareName: daycareName,
                    onAvatarTap: () => context.push('/daycare/settings'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // Réservations en attente (si > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: pendingAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (pending) {
                        if (pending.isEmpty) return const SizedBox.shrink();
                        return _PendingBookingsBanner(
                          bookings: pending,
                          onTap: () => context.push('/daycare/bookings'),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Actions rapides
                const SliverToBoxAdapter(child: _ActionGrid()),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Commission du mois
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ledgerAsync.when(
                      loading: () => const _CommissionCard.loading(),
                      error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                      data: (ledger) => _CommissionCard(ledger: ledger),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Statistiques rapides
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _QuickStats(bookingsAsync: bookingsAsync),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Réservations récentes
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: bookingsAsync.when(
                      loading: () => const _LoadingCard(text: 'Chargement des réservations...'),
                      error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                      data: (bookings) => _RecentBookings(bookings: bookings),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ========================= WIDGETS =========================

class _Header extends StatelessWidget {
  final String daycareName;
  final VoidCallback? onAvatarTap;
  const _Header({required this.daycareName, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_DaycareColors.primary, Color(0xFF0097A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Text(
                daycareName.isNotEmpty ? daycareName.characters.first.toUpperCase() : 'G',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _DaycareColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenue', style: TextStyle(color: Colors.white70)),
                Text(
                  daycareName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.pets, color: Colors.white, size: 26),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String text;
  const _LoadingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _PendingBookingsBanner extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final VoidCallback onTap;
  const _PendingBookingsBanner({required this.bookings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = bookings.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pending_actions, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count réservation${count > 1 ? 's' : ''} en attente',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text('Appuyez pour traiter', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Voir'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _Action('Gérer la page', Icons.edit_location, '/daycare/page', const Color(0xFF3A86FF)),
      _Action('Mes réservations', Icons.calendar_today, '/daycare/bookings', const Color(0xFFFF6D00)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.15,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _ActionCard(item: items[i]),
      ),
    );
  }
}

class _Action {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  const _Action(this.title, this.icon, this.route, this.color);
}

class _ActionCard extends StatefulWidget {
  final _Action item;
  const _ActionCard({required this.item});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward(from: Random().nextDouble() * .6);

  late final Animation<double> _scale = Tween(begin: .98, end: 1.0).animate(
    CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return ScaleTransition(
      scale: _scale,
      child: InkWell(
        onTap: () => context.push(it.route),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: it.color.withOpacity(.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: it.color.withOpacity(.16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: it.color.withOpacity(.15),
                  child: Icon(it.icon, color: it.color),
                ),
                const Spacer(),
                Text(
                  it.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> bookingsAsync;
  const _QuickStats({required this.bookingsAsync});

  @override
  Widget build(BuildContext context) {
    final bookings = bookingsAsync.value ?? [];

    final activeBookings = bookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      return status == 'CONFIRMED' || status == 'IN_PROGRESS';
    }).length;

    final completedBookings = bookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      return status == 'COMPLETED';
    }).length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aperçu rapide',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.calendar_today,
                  label: 'Réservations actives',
                  value: '$activeBookings',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.check_circle,
                  label: 'Terminées',
                  value: '$completedBookings',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.pets,
                  label: 'Total réservations',
                  value: '${bookings.length}',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.schedule,
                  label: 'En attente',
                  value: '${bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PENDING').length}',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBookings extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  const _RecentBookings({required this.bookings});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return _SectionCard(
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Aucune réservation'),
            const SizedBox(height: 8),
            Text(
              'Les réservations de vos clients apparaîtront ici',
              style: TextStyle(color: Colors.black.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Trier par date et prendre les 5 dernières
    final sorted = List<Map<String, dynamic>>.from(bookings)
      ..sort((a, b) {
        final aDate = DateTime.tryParse((a['startDate'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse((b['startDate'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final recent = sorted.take(5).toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Réservations récentes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/daycare/bookings'),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recent.map((booking) {
            final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
            final totalDa = _asInt(booking['totalDa'] ?? 0);
            final startDate = booking['startDate'];
            final endDate = booking['endDate'];
            final user = booking['user'] as Map<String, dynamic>?;
            final userName = (user?['firstName'] ?? 'Client').toString();

            DateTime? start, end;
            if (startDate != null) start = DateTime.tryParse(startDate.toString());
            if (endDate != null) end = DateTime.tryParse(endDate.toString());

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildStatusIcon(status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (start != null && end != null)
                          Text(
                            '${DateFormat('dd/MM').format(start.toLocal())} - ${DateFormat('dd/MM').format(end.toLocal())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _da(totalDa),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'PENDING':
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case 'CONFIRMED':
        icon = Icons.thumb_up;
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        icon = Icons.pets;
        color = Colors.purple;
        break;
      case 'COMPLETED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'CANCELLED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusChip(String status) {
    String label;
    Color color;

    switch (status) {
      case 'PENDING':
        label = 'En attente';
        color = Colors.orange;
        break;
      case 'CONFIRMED':
        label = 'Confirmée';
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        label = 'En cours';
        color = Colors.purple;
        break;
      case 'COMPLETED':
        label = 'Terminée';
        color = Colors.green;
        break;
      case 'CANCELLED':
        label = 'Annulée';
        color = Colors.red;
        break;
      default:
        label = status;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final _DaycareLedger? ledger;
  const _CommissionCard({required this.ledger});
  const _CommissionCard.loading() : ledger = null;

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    if (ledger == null) {
      return const _SectionCard(
        child: SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final l = ledger!;
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR')
        .format(now)
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined, color: Color(0xFFFB8C00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commission du mois',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black.withOpacity(.65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Montant à payer
          Text(
            _da(l.netDue),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.bookingsCount} réservation${l.bookingsCount > 1 ? 's' : ''} terminée${l.bookingsCount > 1 ? 's' : ''}',
            style: TextStyle(color: Colors.black.withOpacity(.6)),
          ),
          const SizedBox(height: 12),

          // Stats
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniPill(Icons.monetization_on, 'Revenus', _da(l.totalRevenue)),
              _miniPill(Icons.receipt, 'Commission', _da(l.commissionDue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _DaycareColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _DaycareColors.primary.withOpacity(.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _DaycareColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(.6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
