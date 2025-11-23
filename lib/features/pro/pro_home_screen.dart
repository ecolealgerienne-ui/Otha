import 'dart:math';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/session_controller.dart';
import '../../core/api.dart';

/// Commission fixe (doit matcher pro_services_screen)
const int kCommissionDa = 100;

/// ========================= THEME PRO (saumon) =========================
class _ProColors {
  static const ink = Color(0xFF1F2328);
  static const salmon = Color(0xFFF36C6C);
  static const salmonSoft = Color(0xFFFFE7E7);
}

ThemeData _proTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _ProColors.salmon,
      secondary: _ProColors.salmon,
      onPrimary: Colors.white,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: _ProColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const MaterialStatePropertyAll(_ProColors.salmon),
        foregroundColor: const MaterialStatePropertyAll(Colors.white),
        overlayColor:
            MaterialStatePropertyAll(_ProColors.salmon.withOpacity(.12)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const MaterialStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const MaterialStatePropertyAll(_ProColors.salmon),
        side: const MaterialStatePropertyAll(
          BorderSide(color: _ProColors.salmon, width: 1.2),
        ),
        overlayColor:
            MaterialStatePropertyAll(_ProColors.salmon.withOpacity(.08)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const MaterialStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: _ProColors.salmon),
    dividerColor: _ProColors.salmonSoft,
  );
}

/// ========================= PROVIDERS (données) =========================

/// Profil du vétérinaire connecté
final myProviderProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) => ref.read(apiProvider).myProvider(),
);

/// Prochain RDV (futur le plus proche)
final nextAppointmentProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiProvider);
  final now = DateTime.now().toUtc();
  final list = await api.providerAgenda(fromIso: now.toIso8601String());

  Map<String, dynamic>? next;
  DateTime? nextDate;
  for (final raw in list) {
    final m = Map<String, dynamic>.from(raw as Map);
    final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
    if (iso.isEmpty) continue;
    DateTime t;
    try {
      t = DateTime.parse(iso).toUtc();
    } catch (_) {
      continue;
    }
    final st = (m['status'] ?? '').toString();
    if (st != 'PENDING' && st != 'CONFIRMED') continue;
    if (t.isBefore(now)) continue;
    if (nextDate == null || t.isBefore(nextDate!)) {
      nextDate = t;
      next = m;
    }
  }
  return next;
});

/// ========================= Ledger (calculs) =========================

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

class _ProLedger {
  final String ym; // 'YYYY-MM' courant
  final int dueThis;
  final int collectedThis;
  final int netThis;
  final int arrears; // retard cumulé (mois < courant)
  const _ProLedger({
    required this.ym,
    required this.dueThis,
    required this.collectedThis,
    required this.netThis,
    required this.arrears,
  });
}

/// Historique normalisé SANS AUCUN overlay local — uniquement backend
final proLedgerProvider = FutureProvider.autoDispose<_ProLedger>((ref) async {
  final api = ref.read(apiProvider);

  final nowUtc = DateTime.now().toUtc();
  final ymNow = '${nowUtc.year}-${nowUtc.month.toString().padLeft(2, '0')}';
  final curStart = DateTime.utc(nowUtc.year, nowUtc.month, 1);

  // 1) Base: historique pro
  final hist = await api.myHistoryMonthly(months: 24);

  // 2) Index par mois (YYYY-MM)
  final Map<String, Map<String, dynamic>> byMonth = {};
  for (final raw in hist) {
    final m = Map<String, dynamic>.from(raw);
    final ym = _canonYm((m['month'] ?? '').toString());
    if (ym.length != 7) continue;

    int due = _asInt(m['dueDa']);
    if (due == 0 && m.containsKey('completed')) {
      due = _asInt(m['completed']) * kCommissionDa;
    }

    int coll = _asInt(
      m['collectedDa'] ??
          m['collectedDaScheduled'] ??
          m['collectedScheduledDa'] ??
          0,
    );
    if (due > 0 && coll > due) coll = due;

    byMonth[ym] = {'month': ym, 'dueDa': due, 'collectedDa': coll};
  }

  // 3) Override fiable serveur: /earnings/me/earnings?month=YYYY-MM
  final monthsToCheck = byMonth.values
      .where((m) => _asInt(m['dueDa']) > 0 || _asInt(m['collectedDa']) > 0)
      .map((m) => m['month'] as String)
      .toList()
    ..sort((a, b) => b.compareTo(a));

  for (final ym in monthsToCheck) {
    try {
      final e = await api.myEarnings(month: ym);
      int coll = _asInt(
        e['collectedDa'] ??
            e['collectedMonthDa'] ??
            e['paidDa'] ??
            e['totalCollectedDa'] ??
            0,
      );
      if (coll == 0) {
        final cents = _asInt(e['collectedCents'] ?? e['totalCollectedCents']);
        if (cents > 0) coll = (cents / 100).round();
      }
      if (coll < 0) coll = 0;

      final due = _asInt(byMonth[ym]?['dueDa']);
      if (due > 0 && coll > due) coll = due;
      byMonth[ym]!['collectedDa'] = coll;
    } catch (_) {
      // silencieux
    }
  }

  // 4) Agrégats
  int dueThis = 0, collThis = 0, arrears = 0;

  if (byMonth.containsKey(ymNow)) {
    dueThis = _asInt(byMonth[ymNow]!['dueDa']);
    collThis = _asInt(byMonth[ymNow]!['collectedDa']);
    if (collThis > dueThis) collThis = dueThis;
  }

  // retard cumulé avant mois courant
  for (final entry in byMonth.values) {
    final ym = entry['month'] as String;
    if (ym.length != 7) continue;
    final y = int.parse(ym.substring(0, 4));
    final m = int.parse(ym.substring(5, 7));
    final d = DateTime.utc(y, m, 1);
    if (d.isBefore(curStart)) {
      final due = _asInt(entry['dueDa']);
      final coll = _asInt(entry['collectedDa']);
      final net = due - coll;
      if (net > 0) arrears += net;
    }
  }

  final netThis = max(0, dueThis - collThis);

  return _ProLedger(
    ym: ymNow,
    dueThis: dueThis,
    collectedThis: collThis,
    netThis: netThis,
    arrears: arrears,
  );
});

/// Détails RDV complétés sur une fenêtre (pour “Générées avec ses rendez-vous” — Mois)
final completedBookingsForRangeProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String fromIso, String toIso})>(
        (ref, range) async {
  final api = ref.read(apiProvider);
  final list =
      await api.providerAgenda(fromIso: range.fromIso, toIso: range.toIso);

  final out = <Map<String, dynamic>>[];
  for (final raw in list) {
    final m = Map<String, dynamic>.from(raw as Map);
    if ((m['status'] ?? '').toString() != 'COMPLETED') continue;

    final svc = Map<String, dynamic>.from((m['service'] ?? const {}) as Map);
    final price = _asInt(svc['price'] ?? svc['priceCents']);
    final title = (svc['title'] ?? 'Service').toString();

    final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
    out.add({
      'scheduledAt': iso,
      'serviceTitle': title,
      'totalPriceDa': price,
    });
  }
  out.sort((a, b) {
    final A = DateTime.tryParse((a['scheduledAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final B = DateTime.tryParse((b['scheduledAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return B.compareTo(A);
  });
  return out;
});

/// “Tout le temps” — liste complète (pas de total global).
final completedBookingsAllTimeProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final from = DateTime.utc(2019, 1, 1).toIso8601String();
  final to = DateTime.now().toUtc().toIso8601String();
  final list = await api.providerAgenda(fromIso: from, toIso: to);
  final out = <Map<String, dynamic>>[];
  for (final raw in list) {
    final m = Map<String, dynamic>.from(raw as Map);
    if ((m['status'] ?? '').toString() != 'COMPLETED') continue;
    final svc = Map<String, dynamic>.from((m['service'] ?? const {}) as Map);
    final price = _asInt(svc['price'] ?? svc['priceCents']);
    final title = (svc['title'] ?? 'Service').toString();
    final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
    out.add({
      'scheduledAt': iso,
      'serviceTitle': title,
      'totalPriceDa': price,
    });
  }
  out.sort((a, b) {
    final A = DateTime.tryParse((a['scheduledAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final B = DateTime.tryParse((b['scheduledAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return B.compareTo(A);
  });
  return out;
});

/// ========================= UI =========================

class ProHomeScreen extends ConsumerStatefulWidget {
  const ProHomeScreen({super.key});
  @override
  ConsumerState<ProHomeScreen> createState() => _ProHomeScreenState();
}

class _ProHomeScreenState extends ConsumerState<ProHomeScreen> {
  /// "ALL" = tout le temps ; sinon "YYYY-MM"
  late String _scope;
  late List<String> _months;

  @override
  void initState() {
    super.initState();
    _scope = 'ALL';
    final now = DateTime.now().toUtc();
    _months = List.generate(36, (i) {
      final d = DateTime.utc(now.year, now.month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  (String fromIso, String toIso)? _boundsForScopeMonth() {
    if (_scope == 'ALL') return null;
    final y = int.parse(_scope.substring(0, 4));
    final m = int.parse(_scope.substring(5, 7));
    final from = DateTime.utc(y, m, 1);
    final to = (m == 12) ? DateTime.utc(y + 1, 1, 1) : DateTime.utc(y, m + 1, 1);
    return (from.toIso8601String(), to.toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    const bgSoft = Color(0xFFF7F8FA);

    final state = ref.watch(sessionProvider);
    final user = state.user ?? {};
    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    final fallbackUserName =
        [if (first.isNotEmpty) first, if (last.isNotEmpty) last].join(' ').trim();

    final provAsync = ref.watch(myProviderProfileProvider);
    final doctorName = provAsync.maybeWhen(
      data: (p) {
        final dn = (p?['displayName'] ?? '').toString().trim();
        if (dn.isNotEmpty) return dn;
        if (fallbackUserName.isNotEmpty) return fallbackUserName;
        return 'Docteur';
      },
      orElse: () =>
          (fallbackUserName.isNotEmpty ? fallbackUserName : 'Docteur'),
    );

    final nextAsync = ref.watch(nextAppointmentProvider);
    final ledgerAsync = ref.watch(proLedgerProvider);

    final monthBounds = _boundsForScopeMonth();
    final monthBookingsAsync = (monthBounds == null)
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(completedBookingsForRangeProvider((
            fromIso: monthBounds.$1,
            toIso: monthBounds.$2,
          )));

    final allTimeAsync = (_scope == 'ALL')
        ? ref.watch(completedBookingsAllTimeProvider)
        : const AsyncValue.data(<Map<String, dynamic>>[]);

    return Theme(
      data: _proTheme(context),
      child: Scaffold(
        backgroundColor: bgSoft,
        appBar: null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myProviderProfileProvider);
              ref.invalidate(nextAppointmentProvider);
              ref.invalidate(proLedgerProvider);

              if (monthBounds != null) {
                ref.invalidate(completedBookingsForRangeProvider((
                  fromIso: monthBounds.$1,
                  toIso: monthBounds.$2,
                )));
              }
              if (_scope == 'ALL') {
                ref.invalidate(completedBookingsAllTimeProvider);
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    doctorName: doctorName,
                    onAvatarTap: () => context.push('/pro/settings'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // ------- Prochain rendez-vous -------
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: nextAsync.when(
                      loading: () => const _LoadingCard(
                        text: 'Chargement du prochain rendez-vous...',
                      ),
                      error: (e, _) => _SectionCard(
                        child: Text('Erreur: $e'),
                      ),
                      data: (next) => _NextAppointment(next: next),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ------- Actions -------
                const SliverToBoxAdapter(child: _ActionGrid()),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ------- À payer (fin du mois) + retard + bouton Payer -------
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ledgerAsync.when(
                      loading: () => const _CommissionDueCard.loading(),
                      error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                      data: (l) => _CommissionDueCard(
                        ledger: l,
                        scope: _scope == 'ALL' ? null : _scope,
                        onPay: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Paiement: logique à implémenter'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // ------- Sélecteur de période -------
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionCard(
                      child: Row(
                        children: [
                          const Text('Période',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _scope,
                            items: <DropdownMenuItem<String>>[
                              const DropdownMenuItem(
                                  value: 'ALL', child: Text('Tout le temps')),
                              ..._months.map((m) => DropdownMenuItem(
                                  value: m, child: Text(m))),
                            ],
                            onChanged: (v) => setState(() {
                              _scope = v ?? 'ALL';
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ------- Générées avec ses rendez-vous -------
                if (_scope == 'ALL')
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: allTimeAsync.when(
                        loading: () => const _SectionCard(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                        error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                        data: (rows) => _GeneratedWithBookings(
                          ym: 'Tout le temps',
                          rows: rows,
                          showTotals: false,
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: monthBookingsAsync.when(
                        loading: () => const _SectionCard(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                        error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                        data: (rows) => _GeneratedWithBookings(
                          ym: _scope,
                          rows: rows,
                          showTotals: true,
                        ),
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

/// Header saumon
class _Header extends StatelessWidget {
  final String doctorName;
  final VoidCallback? onAvatarTap;
  const _Header({required this.doctorName, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ProColors.salmon, Color(0xFFFF9D9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
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
                doctorName.isNotEmpty
                    ? doctorName.characters.first.toUpperCase()
                    : 'D',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                  'Dr $doctorName',
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
          const Icon(Icons.handshake, color: Colors.white, size: 26),
        ],
      ),
    );
  }
}

/// Carte section générique
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
          BoxShadow(
              color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

/// Carte de chargement compacte
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
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prochain RDV
class _NextAppointment extends StatelessWidget {
  final Map<String, dynamic>? next;
  const _NextAppointment({this.next});

  @override
  Widget build(BuildContext context) {
    if (next == null) {
      return const _SectionCard(
        child: _EmptyRow(
          icon: Icons.access_time,
          label: 'Aucun rendez-vous à venir',
        ),
      );
    }

    final iso = next!['scheduledAt']?.toString() ?? '';
    DateTime? dt;
    try {
      dt = DateTime.parse(iso).toLocal();
    } catch (_) {}
    final when = dt != null
        ? DateFormat('EEEE d MMMM • HH:mm', 'fr_FR')
            .format(dt)
            .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase())
        : '—';
    final service = next!['service']?['title']?.toString() ?? 'Service';
    final client = (() {
      final u = Map<String, dynamic>.from(next!['user'] ?? const {});
      final dn = (u['displayName'] ?? '').toString().trim();
      return dn.isNotEmpty ? dn : 'Client';
    })();

    final bookingId = (next!['id'] ?? '').toString();

    return _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _ProColors.salmonSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event, color: _ProColors.salmon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$when\n$service • $client',
              style: const TextStyle(height: 1.3),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              context.push('/pro/agenda',
                  extra: {'focusIso': iso, 'bookingId': bookingId});
            },
            label: const Text('Voir'),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Ligne “vide” standard
class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Grid Actions
class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _Action('Agenda', Icons.calendar_month, '/pro/agenda',
          const Color(0xFF1F7A8C)),
      _Action('Disponibilités', Icons.schedule, '/pro/availability',
          const Color(0xFF7B2CBF)),
      _Action('Services & Tarifs', Icons.medical_services, '/pro/services',
          const Color(0xFF3A86FF)),
      _Action('Scanner patient', Icons.qr_code_scanner, '/vet/scan',
          const Color(0xFFFF6D00)),
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

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte « À payer (fin du mois) » + bouton Payer
class _CommissionDueCard extends StatelessWidget {
  final _ProLedger? ledger;
  final String? scope; // null => affiche le mois courant; sinon 'YYYY-MM'
  final VoidCallback? onPay;
  const _CommissionDueCard({required this.ledger, this.scope, this.onPay});
  const _CommissionDueCard.loading()
      : ledger = null,
        scope = null,
        onPay = null;

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
    final monthLabel = (scope == null)
        ? DateFormat('MMMM yyyy', 'fr_FR')
            .format(now)
            .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase())
        : scope!;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
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
                child:
                    const Icon(Icons.payments_outlined, color: Color(0xFFFB8C00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'À payer (fin du mois)',
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
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.lock),
                label: const Text('Payer'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Montant principal (À payer = net courant + retard)
          Text(
            _da(l.netThis + l.arrears),
            textAlign: TextAlign.start,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          // Générées / Payé — MOIS COURANT uniquement
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniPill(Icons.summarize, 'Générées', _da(l.dueThis)),
              _miniPill(Icons.task_alt, 'Payé', _da(l.collectedThis)),
            ],
          ),
          const SizedBox(height: 10),

          // Retard cumulé
          if (l.arrears > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _ProColors.salmonSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _ProColors.salmon.withOpacity(.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: _ProColors.salmon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Retard cumulé: ${_da(l.arrears)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _ProColors.salmonSoft),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _ProColors.salmon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.black.withOpacity(.70)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// “Générées avec ses rendez-vous”
class _GeneratedWithBookings extends StatelessWidget {
  final String ym; // 'YYYY-MM' ou 'Tout le temps'
  final List<Map<String, dynamic>> rows;
  final bool showTotals; // false quand 'Tout le temps'
  const _GeneratedWithBookings({
    required this.ym,
    required this.rows,
    required this.showTotals,
  });

  String _da(num v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    final totalClient =
        rows.fold<int>(0, (sum, e) => sum + _asInt(e['totalPriceDa'] ?? 0));
    final totalCommission = rows.length * kCommissionDa;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Générées avec ses rendez-vous — $ym',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const _EmptyRow(
              icon: Icons.event_busy,
              label: 'Aucun rendez-vous complété',
            )
          else
            ...[
              ...rows.take(20).map((e) {
                final title = (e['serviceTitle'] ?? 'Service').toString();
                final price = _asInt(e['totalPriceDa'] ?? 0);
                final whenIso = (e['scheduledAt'] ?? '').toString();
                final when = DateTime.tryParse(whenIso)?.toLocal();
                final label = when == null
                    ? title
                    : '${DateFormat('dd/MM • HH:mm').format(when)} — $title';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_da(price)),
                    ],
                  ),
                );
              }),
              if (rows.length > 20)
                Text(
                  '+${rows.length - 20} autres…',
                  style: TextStyle(color: Colors.black.withOpacity(.6)),
                ),
              if (showTotals) ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _totChip(
                        icon: Icons.payments_outlined,
                        label: 'Total client',
                        value: _da(totalClient),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _totChip(
                        icon: Icons.receipt_long,
                        label: 'Commission (due)',
                        value: _da(totalCommission),
                      ),
                    ),
                  ],
                ),
              ],
            ],
        ],
      ),
    );
  }

  Widget _totChip(
      {required IconData icon,
      required String label,
      required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ProColors.salmonSoft),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _ProColors.salmon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.black.withOpacity(.70)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
