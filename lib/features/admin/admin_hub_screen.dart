// lib/features/admin/admin_hub_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';
import 'admin_shared.dart';
import 'admin_pages.dart';

class AdminHubScreen extends ConsumerStatefulWidget {
  const AdminHubScreen({super.key});
  @override
  ConsumerState<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends ConsumerState<AdminHubScreen> {
  bool _loading = true;
  String? _error;

  // Compteurs
  int? _countUsers;          // clients (role=USER)
  int? _countProsApproved;
  int? _countPending;
  int? _countRejected;
  int? _countAdoptPending;   // annonces d'adoption en attente

  // Activité / inscriptions
  int _activeNow = 0;        // pas dispo dans api.dart → 0
  int _signups30d = 0;

  // Commissions mois courant
  int _dueMonthDa = 0;
  int _collectedMonthDa = 0;

  // Courbe revenus collectés (12 mois)
  late List<_MonthPoint> _revenueSeries; // collectedDa par mois
  late List<String> _months;             // 'YYYY-MM' (12 derniers)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _months = List.generate(12, (i) {
      final d = DateTime.utc(now.year, now.month - (11 - i), 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
    _revenueSeries = _months.map((m) => _MonthPoint(m, 0)).toList();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      await api.ensureAuth();

      // Pros par statut
      final futApproved = api.listProviderApplications(status: 'approved', limit: 1000);
      final futPending  = api.listProviderApplications(status: 'pending',  limit: 1000);
      final futRejected = api.listProviderApplications(status: 'rejected', limit: 1000);

      // Clients (users) — exclusivement role=USER
      final futUsers    = api.adminListUsers(q: '', role: 'USER', limit: 1000, offset: 0);

      // Annonces d'adoption en attente
      final futAdoptPending = api.adminAdoptList(status: 'PENDING', limit: 1000);

      // Commission mois courant (agrégée côté client via /earnings admin)
      final futSummary  = api.adminCommissionSummary();

      final approved = await futApproved;
      final pending  = await futPending;
      final rejected = await futRejected;

      // Clients
      int countUsers = 0;
      int signups30d = 0;
      try {
        final users = await futUsers;
        countUsers = users.length;

        final thirtyDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 30));
        int cnt = 0;
        for (final raw in users) {
          final m = Map<String, dynamic>.from(raw as Map);
          final iso = (m['createdAt'] ?? m['created_at'] ?? '').toString();
          if (iso.isEmpty) continue;
          final dt = DateTime.tryParse(iso)?.toUtc();
          if (dt != null && dt.isAfter(thirtyDaysAgo)) cnt++;
        }
        signups30d = cnt;
      } catch (_) {
        countUsers = 0;
        signups30d = 0;
      }

      // Annonces d'adoption en attente
      int countAdoptPending = 0;
      try {
        final adoptResult = await futAdoptPending;
        final adoptPosts = adoptResult['posts'] as List? ?? [];
        countAdoptPending = adoptResult['total'] as int? ?? adoptPosts.length;
      } catch (_) {
        countAdoptPending = 0;
      }

      // Commissions mois courant
      final summary = await futSummary;
      int _getDa(String daKey, String centsKey) {
        final vDa    = summary[daKey];
        final vCents = summary[centsKey];
        if (vDa is num) return vDa.toInt();
        if (vCents is num) return (vCents / 100).round();
        if (vDa is String) return int.tryParse(vDa) ?? 0;
        if (vCents is String) return ((int.tryParse(vCents) ?? 0) / 100).round();
        return 0;
      }
      final dueMonthDa       = _getDa('totalDueMonthDa', 'totalDueMonthCents');
      final collectedMonthDa = _getDa('totalCollectedMonthDa', 'totalCollectedMonthCents');

      // Courbe revenus collectés 12 mois (somme sur pros approuvés)
      final points = {for (final m in _months) m: 0};
      final futures = <Future<void>>[];
      for (final raw in approved) {
        final p = Map<String, dynamic>.from(raw as Map);
        final pid = (p['id'] ?? '').toString();
        if (pid.isEmpty) continue;
        futures.add(() async {
          try {
            final hist = await api.adminHistoryMonthly(providerId: pid, months: 12);
            for (final e in hist) {
              final m = Map<String, dynamic>.from(e as Map);
              final ym = _canonYm((m['month'] ?? '').toString());
              final coll = _asInt(m['collectedDa']);
              if (points.containsKey(ym)) points[ym] = points[ym]! + max(0, coll);
            }
          } catch (_) {}
        }());
      }
      await Future.wait(futures);
      final series = _months.map((m) => _MonthPoint(m, points[m] ?? 0)).toList();

      setState(() {
        _countUsers        = countUsers;
        _countProsApproved = approved.length;
        _countPending      = pending.length;
        _countRejected     = rejected.length;
        _countAdoptPending = countAdoptPending;

        _activeNow  = 0; // pas d'endpoint dans api.dart
        _signups30d = signups30d;

        _dueMonthDa       = dueMonthDa;
        _collectedMonthDa = collectedMonthDa;

        _revenueSeries = series;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final role = (user?['role'] as String?) ?? 'USER';
    if (role != 'ADMIN') {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Accès refusé (ADMIN requis)'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Revenir')),
          ]),
        ),
      );
    }

    final theme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: AdminColors.salmon,
        secondary: AdminColors.salmon,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AdminColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: const Color(0xFFFFE7E7),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AdminColors.salmon),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin — Hub'),
          actions: [
            IconButton(tooltip: 'Rafraîchir', icon: const Icon(Icons.refresh), onPressed: _load),
            IconButton(
              tooltip: 'Déconnexion', icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(sessionProvider.notifier).logout();
                if (!mounted) return;
                context.go('/auth/login?as=pro');
              },
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        // Ligne 1 — Clients + Pros
                        StatsRow(items: [
                          StatBox(
                            label: 'Clients',
                            value: _countUsers,
                            icon: Icons.group,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                            ),
                          ),
                          StatBox(
                            label: 'Pros approuvés',
                            value: _countProsApproved,
                            icon: Icons.verified,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminProsApprovedPage()),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // Ligne 2 — En attente/rejetés + Commissions mois
                        StatsRow(items: [
                          StatBox(
                            label: 'En attente / Rejetés',
                            value: ((_countPending ?? 0) + (_countRejected ?? 0)),
                            icon: Icons.rule,
                            badge: (_countPending ?? 0) > 0 ? (_countPending ?? 0) : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminApplicationsPage()),
                            ),
                          ),
                          StatBoxMoneyDa(
                            label: 'Commissions du mois',
                            dueDa: _dueMonthDa,
                            collectedDa: _collectedMonthDa,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminCommissionsPage()),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // Ligne 3 — Adoptions en attente
                        if (_countAdoptPending != null && _countAdoptPending! > 0)
                          Column(
                            children: [
                              StatsRow(items: [
                                StatBox(
                                  label: 'Adoptions à modérer',
                                  value: _countAdoptPending,
                                  icon: Icons.pets,
                                  badge: _countAdoptPending,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AdminAdoptPostsPage()),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 12),
                            ],
                          ),

                        const SizedBox(height: 8),

                        // Statistiques globales
                        const Text('Statistiques globales',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),

                        // Connectés / Inscriptions 30j
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStatCard(
                                icon: Icons.wifi, color: Colors.teal,
                                title: 'Connectés',
                                value: _activeNow.toString(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStatCard(
                                icon: Icons.person_add_alt_1, color: Colors.indigo,
                                title: 'Inscriptions 30j',
                                value: _signups30d.toString(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Courbe revenus collectés (12 mois)
                        _RevenueCard(series: _revenueSeries),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ========================= UI Bits =========================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  const _MiniStatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black.withOpacity(.7))),
            ),
            const SizedBox(width: 10),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final List<_MonthPoint> series; // 12 points, ordonnés
  const _RevenueCard({required this.series});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    final total = series.fold<int>(0, (s, p) => s + p.valueDa);
    final last = series.isNotEmpty ? series.last.valueDa : 0;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenus collectés — 12 mois',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text('Total: ${_da(total)}',
                      style: TextStyle(color: Colors.black.withOpacity(.7))),
                ),
                Text('Dernier mois: ${_da(last)}',
                    style: TextStyle(color: Colors.black.withOpacity(.7))),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: _LineChart(series: series),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<_MonthPoint> series;
  const _LineChart({required this.series});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LineChartPainter(series));
}

class _LineChartPainter extends CustomPainter {
  final List<_MonthPoint> series;
  _LineChartPainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final bg = Paint()..color = const Color(0xFFFFE7E7);
    final line = Paint()
      ..color = const Color(0xFFF36C6C)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = const Color(0xFFF36C6C).withOpacity(.12)
      ..style = PaintingStyle.fill;

    final maxVal = series.map((e) => e.valueDa).fold<int>(0, max);
    final minVal = 0;
    final dx = size.width / (series.length - 1).clamp(1, 999);
    final dy = (maxVal == minVal) ? 0 : size.height / (maxVal - minVal);

    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(r, bg);

    final p = Path();
    final pf = Path();

    for (int i = 0; i < series.length; i++) {
      final x = dx * i;
      final value = series[i].valueDa.toDouble();
      final y = size.height - (value - minVal) * dy;
      if (i == 0) {
        p.moveTo(x, y);
        pf.moveTo(x, size.height);
        pf.lineTo(x, y);
      } else {
        p.lineTo(x, y);
        pf.lineTo(x, y);
      }
    }
    pf.lineTo(size.width, size.height);
    pf.close();

    canvas.drawPath(pf, fill);
    canvas.drawPath(p, line);

    final dot = Paint()..color = const Color(0xFFF36C6C);
    for (int i = 0; i < series.length; i++) {
      final x = dx * i;
      final value = series[i].valueDa.toDouble();
      final y = size.height - (value - minVal) * dy;
      canvas.drawCircle(Offset(x, y), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) {
    if (old.series.length != series.length) return true;
    for (int i = 0; i < series.length; i++) {
      if (old.series[i].valueDa != series[i].valueDa) return true;
    }
    return false;
  }
}

// ========================= Helpers =========================

class _MonthPoint {
  final String ym; // 'YYYY-MM'
  final int valueDa;
  const _MonthPoint(this.ym, this.valueDa);
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _canonYm(String s) {
  final t = s.replaceAll('/', '-').trim();
  final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(t) ??
      RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(t);
  if (m == null) return t;
  final y = m.group(1)!;
  final mo = int.parse(m.group(2)!);
  return '$y-${mo.toString().padLeft(2, '0')}';
}