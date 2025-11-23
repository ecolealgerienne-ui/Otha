// lib/features/agenda/provider_agenda_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';

/// ---------- Args immuables pour le provider family ----------
class _AgendaArgs {
  final String fromIsoUtc; // ISO UTC (inclus)
  final String toIsoUtc;   // ISO UTC (exclu)
  const _AgendaArgs(this.fromIsoUtc, this.toIsoUtc);

  @override
  bool operator ==(Object o) =>
      identical(this, o) ||
      o is _AgendaArgs && o.fromIsoUtc == fromIsoUtc && o.toIsoUtc == toIsoUtc;

  @override
  int get hashCode => Object.hash(fromIsoUtc, toIsoUtc);
}

/// ---------- Provider family: charge l’agenda d’une journée ----------
final _agendaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _AgendaArgs>((ref, args) async {
  final api = ref.read(apiProvider);
  final rows = await api.providerAgenda(fromIso: args.fromIsoUtc, toIso: args.toIsoUtc);
  return rows.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// ---------- Ecran Agenda ----------
class ProviderAgendaScreen extends ConsumerStatefulWidget {
  const ProviderAgendaScreen({super.key});

  @override
  ConsumerState<ProviderAgendaScreen> createState() => _ProviderAgendaScreenState();
}

class _ProviderAgendaScreenState extends ConsumerState<ProviderAgendaScreen>
    with WidgetsBindingObserver {
  // Base = jour affiché le plus à gauche du bandeau (UTC minuit)
  late DateTime _baseUtc;
  // Index du jour sélectionné (0..6)
  int _dayIndex = 0;

  // Focus transmis depuis Home -> { focusIso, bookingId }
  String? _focusIso;
  String? _focusBookingId;

  // Scroll + clés pour auto-scroll vers un RDV précis
  final ScrollController _listCtl = ScrollController();
  final Map<String, GlobalKey> _rowKeys = {};

  // Filtre d’état (optionnel, pour le confort)
  String _statusFilter = 'ALL'; // ALL | PENDING | CONFIRMED | COMPLETED | CANCELLED

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Par défaut: aujourd’hui (minuit UTC)
    final now = DateTime.now().toUtc();
    _baseUtc = DateTime.utc(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Récupère l’extra éventuel pour centrer sur un créneau précis
    final extra = GoRouterState.of(context).extra;
    if (extra is Map) {
      final iso = extra['focusIso']?.toString();
      final bid = extra['bookingId']?.toString();
      if (iso != null && iso.isNotEmpty) {
        _focusIso = iso;
        _focusBookingId = (bid?.isNotEmpty ?? false) ? bid : null;

        // Place la base directement sur le jour du focus
        DateTime? f;
        try {
          f = DateTime.parse(iso).toUtc();
        } catch (_) {}
        if (f != null) {
          _baseUtc = DateTime.utc(f.year, f.month, f.day);
          _dayIndex = 0; // le jour du focus = jour sélectionné
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-fetch silencieux à la reprise (ex. après annulation côté client)
      _refreshDay();
    }
  }

  _AgendaArgs _argsForSelectedDay() {
    final fromUtc = _baseUtc.add(Duration(days: _dayIndex));
    final toUtc = fromUtc.add(const Duration(days: 1));
    return _AgendaArgs(fromUtc.toIso8601String(), toUtc.toIso8601String());
  }

  Future<void> _refreshDay() async {
    final args = _argsForSelectedDay();
    // Invalide puis attend la fin du nouveau fetch
    ref.invalidate(_agendaProvider(args));
    await ref.read(_agendaProvider(args).future);
  }

  Future<void> _scrollToFocusedIfNeeded(List<Map<String, dynamic>> items) async {
    if (_focusIso == null && _focusBookingId == null) return;

    // 1) Si on a un bookingId -> scroll directement sur la ligne correspondante
    if (_focusBookingId != null) {
      final key = _rowKeys[_focusBookingId!];
      if (key != null && key.currentContext != null) {
        await Future.delayed(const Duration(milliseconds: 50));
        await Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.15,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }

    // 2) Sinon, on tente via l’ISO
    if (_focusIso != null) {
      final idx = items.indexWhere((m) {
        final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
        return iso == _focusIso;
      });
      if (idx >= 0) {
        await _listCtl.animateTo(
          (idx * 108).toDouble(), // hauteur moyenne d’une tuile
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _argsForSelectedDay();
    final async = ref.watch(_agendaProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Aujourd’hui',
            onPressed: () async {
              final now = DateTime.now().toUtc();
              setState(() {
                _baseUtc = DateTime.utc(now.year, now.month, now.day);
                _dayIndex = 0;
              });
              await _refreshDay();
            },
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),
          _DayStrip(
            baseUtc: _baseUtc,
            index: _dayIndex,
            onChanged: (i) async {
              setState(() => _dayIndex = i);
              await _refreshDay();
            },
            onPrevBase: () async {
              setState(() => _baseUtc = _baseUtc.subtract(const Duration(days: 7)));
              await _refreshDay();
            },
            onNextBase: () async {
              setState(() => _baseUtc = _baseUtc.add(const Duration(days: 7)));
              await _refreshDay();
            },
          ),
          const SizedBox(height: 6),
          _StatusFilterBar(
            value: _statusFilter,
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          const Divider(height: 1),

          // -------- Liste des rendez-vous du jour sélectionné --------
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (itemsRaw) {
                // Tri + filtre d’état
                final items = [...itemsRaw];
                items.sort((a, b) {
                  final A = DateTime.parse((a['scheduledAt'] ?? a['scheduled_at']).toString());
                  final B = DateTime.parse((b['scheduledAt'] ?? b['scheduled_at']).toString());
                  return A.compareTo(B);
                });
                final filtered = (_statusFilter == 'ALL')
                    ? items
                    : items.where((m) => (m['status'] ?? '').toString() == _statusFilter).toList();

                // Prépare les clés pour auto-scroll
                _rowKeys.clear();
                for (final m in filtered) {
                  final id = (m['id'] ?? '').toString();
                  if (id.isNotEmpty) _rowKeys[id] = GlobalKey();
                }

                // Auto-scroll si focus
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToFocusedIfNeeded(filtered);
                });

                if (filtered.isEmpty) {
                  return const Center(child: Text('Aucun rendez-vous.'));
                }

                return RefreshIndicator(
                  onRefresh: _refreshDay, // ⬅️ attend vraiment l’API
                  child: ListView.separated(
                    controller: _listCtl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final id = (m['id'] ?? '').toString();
                      final isFocus = (_focusBookingId != null && id == _focusBookingId);

                      return _BookingTile(
                        key: _rowKeys[id],
                        m: m,
                        highlight: isFocus,
                        refresh: _refreshDay, // ⬅️ passe la vraie fonction asynchrone
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- Bandeau des jours (7 jours) + flèches semaine ----------
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.baseUtc,
    required this.index,
    required this.onChanged,
    required this.onPrevBase,
    required this.onNextBase,
  });
  final DateTime baseUtc;
  final int index;
  final ValueChanged<int> onChanged;
  final Future<void> Function() onPrevBase;
  final Future<void> Function() onNextBase;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => baseUtc.add(Duration(days: i)).toLocal());

    return Row(
      children: [
        IconButton(onPressed: onPrevBase, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = days[i];
                final isSel = i == index;
                return ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('EEE', 'fr_FR').format(d), style: const TextStyle(fontSize: 12)),
                      Text(
                        DateFormat('d MMM', 'fr_FR').format(d),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  selected: isSel,
                  onSelected: (_) => onChanged(i),
                );
              },
            ),
          ),
        ),
        IconButton(onPressed: onNextBase, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

/// ---------- Barre de filtres d’état ----------
class _StatusFilterBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusFilterBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const ['ALL', 'PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED'];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final v = items[i];
          final sel = v == value;
          return ChoiceChip(
            label: Text(v),
            selected: sel,
            onSelected: (_) => onChanged(v),
          );
        },
      ),
    );
  }
}

/// ---------- Tuile RDV “timeline-like” ----------
class _BookingTile extends ConsumerStatefulWidget {
  const _BookingTile({
    super.key,
    required this.m,
    required this.refresh,
    this.highlight = false,
  });
  final Map<String, dynamic> m;
  final Future<void> Function() refresh; // ⬅️ asynchrone pour await le re-fetch
  final bool highlight;

  @override
  ConsumerState<_BookingTile> createState() => _BookingTileState();
}

class _BookingTileState extends ConsumerState<_BookingTile> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      final id = widget.m['id'].toString();

      // 1) Appel serveur
      await ref.read(apiProvider).providerSetStatus(bookingId: id, status: status);

      // 2) Update optimiste local pour feedback immédiat
      setState(() {
        widget.m['status'] = status;
      });

      // 3) Puis vrai re-fetch de la journée (attendu)
      await widget.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour: $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;

    final iso = (m['scheduledAt'] ?? m['scheduled_at']).toString();
    DateTime? dt;
    try {
      dt = DateTime.parse(iso).toUtc(); // UTC naïf : 8h UTC = 8h réel
    } catch (_) {}
    final time = dt != null ? DateFormat('HH:mm', 'fr_FR').format(dt) : '--:--';
    final dayTxt = dt != null ? DateFormat('EEE d MMM', 'fr_FR').format(dt) : '—';

    final status = (m['status'] ?? '').toString();

    // Champs renvoyés par le back : see providerAgenda()
    final serviceTitle = (m['service']?['title'] ?? 'Service').toString();
    final priceNum = m['service']?['price'];
    final priceLabel = (priceNum is num) ? '${priceNum.round()} DA' : null;

    final displayName = (m['user']?['displayName'] ?? 'Client').toString();
    final phone = (m['user']?['phone'] ?? '').toString().trim();
    final petType = (m['pet']?['label'] ?? '').toString().trim(); // “type d’animal”
    final petName = (m['pet']?['name'] ?? '').toString().trim();

    final canShowPhone = status == 'CONFIRMED' || status == 'COMPLETED';
    final hasPhone = phone.isNotEmpty;

    Color statusColor(String s) {
      switch (s) {
        case 'PENDING':
          return const Color(0xFFFFC857);
        case 'CONFIRMED':
          return const Color(0xFF43AA8B);
        case 'COMPLETED':
          return const Color(0xFF577590);
        case 'CANCELLED':
          return const Color(0xFF8D99AE);
        default:
          return Colors.grey;
      }
    }

    final sc = statusColor(status);
    final subtle = Colors.black.withOpacity(.7);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: widget.highlight ? Border.all(color: const Color(0xFF2E7DFF), width: 2) : null,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // colonne horaire
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(time, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 6),
                Text(dayTxt, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(.6))),
              ],
            ),
            const SizedBox(width: 12),

            // contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // statut + prix éventuel
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(fontWeight: FontWeight.w700, color: sc, fontSize: 12),
                        ),
                      ),
                      if (priceLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(priceLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Text(serviceTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),

                  // Ligne “Client • Animal”
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        displayName,
                        if (petType.isNotEmpty) '• $petType',
                        if (petName.isNotEmpty) '($petName)',
                      ].join(' '),
                      style: TextStyle(color: subtle),
                    ),
                  ),

                  // Téléphone — UNIQUEMENT si confirmé/terminé
                  if (canShowPhone && hasPhone) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.call_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(phone, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // actions rapides
                  Row(
                    children: [
                      if (status == 'PENDING')
                        FilledButton.tonal(
                          onPressed: _busy ? null : () => _setStatus('CONFIRMED'),
                          child: const Text('Confirmer'),
                        ),
                      if (status == 'PENDING') const SizedBox(width: 8),
                      if (status == 'CONFIRMED')
                        FilledButton.tonal(
                          onPressed: _busy ? null : () => _setStatus('COMPLETED'),
                          child: const Text('Terminer'),
                        ),
                      const Spacer(),
                      if (status == 'PENDING' || status == 'CONFIRMED')
                        TextButton(
                          onPressed: _busy ? null : () => _setStatus('CANCELLED'),
                          child: const Text('Annuler'),
                        ),
                    ],
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
