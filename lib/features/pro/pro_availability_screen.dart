import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

/// ——— Modèle intervalle (interne)
class _AvInterval {
  TimeOfDay start;
  TimeOfDay end;
  _AvInterval(this.start, this.end);
}

class ProAvailabilityScreen extends ConsumerStatefulWidget {
  const ProAvailabilityScreen({super.key});
  @override
  ConsumerState<ProAvailabilityScreen> createState() => _ProAvailabilityScreenState();
}

class _ProAvailabilityScreenState extends ConsumerState<ProAvailabilityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _selectedDay = 0; // 0..6 (Lun..Dim)

  // État Hebdo
  bool _loadingWeekly = true;
  bool _savingWeekly = false;

  // État Time-off
  bool _addingOff = false;
  bool _loadingOffs = true;
  final List<Map<String, dynamic>> _timeOffs = [];

  // Hebdo (rempli depuis l'API au démarrage)
  final Map<int, List<_AvInterval>> _weekly = {
    0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: [],
  };

  // Indisponibilités (form)
  DateTimeRange? _offDateRange;
  TimeOfDay _offStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _offEnd   = const TimeOfDay(hour: 23, minute: 59);
  final _offNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _fetchAndFillWeekly();
    _loadTimeOffs();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _offNote.dispose();
    super.dispose();
  }

  // ===== Helpers =====

  String _weekdayLabel(int i) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[i];
  }

  String _weekdayFullLabel(int i) {
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return days[i];
  }

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;
  TimeOfDay _fromMin(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);

  Future<void> _pickTime({
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) onPicked(t);
  }

  Future<void> _pickOffDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _offDateRange ?? DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _coral),
          ),
          child: child!,
        );
      },
    );
    if (range != null) setState(() => _offDateRange = range);
  }

  // Ne normalise qu'à l'enregistrement (tri + fusion des chevauchements)
  void _normalizeDay(int day) {
    final list = List<_AvInterval>.from(_weekly[day]!);
    list.sort((a, b) => _toMin(a.start).compareTo(_toMin(b.start)));

    final merged = <_AvInterval>[];
    for (final it in list) {
      final curStart = _toMin(it.start);
      final curEnd   = _toMin(it.end);
      if (curEnd <= curStart) continue;

      if (merged.isEmpty) {
        merged.add(_AvInterval(it.start, it.end));
      } else {
        final last = merged.last;
        final lastEnd = _toMin(last.end);
        if (curStart <= lastEnd) {
          // fusion
          final endMax = (curEnd > lastEnd) ? it.end : last.end;
          merged[merged.length - 1] = _AvInterval(last.start, endMax);
        } else {
          merged.add(_AvInterval(it.start, it.end));
        }
      }
    }
    _weekly[day] = merged;
  }

  // ===== API binding =====

  Future<void> _fetchAndFillWeekly() async {
    setState(() => _loadingWeekly = true);
    try {
      final api = ref.read(apiProvider);
      final res = await api.myWeekly(); // GET /providers/me/availability
      final entries = (res['entries'] as List?) ?? const [];

      for (var d = 0; d < 7; d++) {
        _weekly[d] = [];
      }

      for (final e in entries) {
        if (e is! Map) continue;
        final wd = (e['weekday'] is int) ? (e['weekday'] as int) : int.tryParse('${e['weekday']}') ?? 0;
        final s  = (e['startMin'] is int) ? e['startMin'] as int : int.tryParse('${e['startMin']}') ?? -1;
        final en = (e['endMin']   is int) ? e['endMin']   as int : int.tryParse('${e['endMin']}')   ?? -1;
        if (wd < 1 || wd > 7 || s < 0 || en <= s) continue;
        final dayIndex = (wd - 1) % 7;
        _weekly[dayIndex]!.add(_AvInterval(_fromMin(s), _fromMin(en)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement des disponibilités: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingWeekly = false);
    }
  }

  Future<void> _saveWeekly() async {
    // Normalise tout avant d'envoyer
    for (var d = 0; d < 7; d++) {
      _normalizeDay(d);
    }

    setState(() => _savingWeekly = true);
    try {
      final payload = <Map<String, dynamic>>[];
      _weekly.forEach((day0, list) {
        final weekday = ((day0) % 7) + 1; // 0..6 -> 1..7
        for (final it in list) {
          final s = _toMin(it.start);
          final e = _toMin(it.end);
          if (e > s) payload.add({'weekday': weekday, 'startMin': s, 'endMin': e});
        }
      });

      // IMPORTANT: n'envoie que les minutes brutes
      await ref.read(apiProvider).setWeekly(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disponibilités enregistrées ✅'), backgroundColor: Colors.green),
      );
      _fetchAndFillWeekly();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _savingWeekly = false);
    }
  }

  Future<void> _clearWeekly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider les disponibilités ?'),
        content: const Text('Tous vos créneaux hebdomadaires seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _savingWeekly = true);
    try {
      await ref.read(apiProvider).setWeekly(<Map<String, dynamic>>[]);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Disponibilités vidées ✅')));
      for (final k in _weekly.keys) {
        _weekly[k] = [];
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _savingWeekly = false);
    }
  }

  // ------- Time-offs: load + add + delete -------

  Future<void> _loadTimeOffs() async {
    setState(() => _loadingOffs = true);
    try {
      final items = await ref.read(apiProvider).myTimeOffs(); // [{id, startsAt, endsAt, reason}, ...]
      _timeOffs
        ..clear()
        ..addAll(items);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement indisponibilités: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingOffs = false);
    }
  }

  Future<void> _deleteTimeOff(String id) async {
    try {
      await ref.read(apiProvider).deleteMyTimeOff(id);
      await _loadTimeOffs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indisponibilité supprimée ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible: $e')),
      );
    }
  }

  Future<void> _addTimeOff() async {
    if (_offDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une plage de dates')),
      );
      return;
    }
    final sMin = _toMin(_offStart);
    final eMin = _toMin(_offEnd);
    if (eMin <= sMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Heure de fin doit être après le début')),
      );
      return;
    }

    setState(() => _addingOff = true);
    try {
      // ⚠️ AUCUNE conversion de fuseau : on envoie exactement ce qui est saisi (UTC "figé")
      final s = _offDateRange!.start;
      final e = _offDateRange!.end;

      final startUtc = DateTime.utc(s.year, s.month, s.day, _offStart.hour, _offStart.minute);
      final endUtc   = DateTime.utc(e.year, e.month, e.day, _offEnd.hour, _offEnd.minute);

      await ref.read(apiProvider).addTimeOff(
        startsAtIso: startUtc.toIso8601String(),
        endsAtIso: endUtc.toIso8601String(),
        reason: _offNote.text.trim().isEmpty ? null : _offNote.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Indisponibilité ajoutée ✅'), backgroundColor: Colors.green));

      setState(() {
        _offDateRange = null;
        _offStart = const TimeOfDay(hour: 0, minute: 0);
        _offEnd = const TimeOfDay(hour: 23, minute: 59);
        _offNote.clear();
      });

      await _loadTimeOffs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _addingOff = false);
    }
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Disponibilités', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: _coral,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Horaires'),
                Tab(text: 'Absences'),
              ],
            ),
          ),
        ),
        actions: [
          if (_loadingWeekly && _loadingOffs)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _coral))),
            )
          else
            IconButton(
              tooltip: 'Actualiser',
              onPressed: () {
                _fetchAndFillWeekly();
                _loadTimeOffs();
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildWeeklyTab(),
          _buildTimeOffsTab(),
        ],
      ),
    );
  }

  Widget _buildWeeklyTab() {
    return Column(
      children: [
        // Jours de la semaine
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            height: 70,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (_, i) {
                final sel = i == _selectedDay;
                final count = _weekly[i]!.length;
                final hasSlots = count > 0;

                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    width: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: sel ? _coral : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? _coral : (hasSlots ? _coral.withOpacity(0.3) : Colors.grey[300]!),
                        width: sel ? 2 : 1,
                      ),
                      boxShadow: sel ? [
                        BoxShadow(color: _coral.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                      ] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdayLabel(i),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sel ? Colors.white.withOpacity(0.2) : (hasSlots ? _coralSoft : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hasSlots ? '$count' : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : (hasSlots ? _coral : Colors.grey[400]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Contenu du jour sélectionné
        Expanded(
          child: _loadingWeekly
              ? const Center(child: CircularProgressIndicator(color: _coral))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre du jour
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _coralSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today, color: _coral, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _weekdayFullLabel(_selectedDay),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${_weekly[_selectedDay]!.length} créneau(x)',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Raccourcis rapides
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Raccourcis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _QuickChip(
                                  label: 'Matin 9h-12h',
                                  icon: Icons.wb_sunny_outlined,
                                  onTap: () {
                                    _weekly[_selectedDay]!.add(_AvInterval(
                                      const TimeOfDay(hour: 9, minute: 0),
                                      const TimeOfDay(hour: 12, minute: 0),
                                    ));
                                    _normalizeDay(_selectedDay);
                                    setState(() {});
                                  },
                                ),
                                _QuickChip(
                                  label: 'Après-midi 14h-18h',
                                  icon: Icons.wb_twilight,
                                  onTap: () {
                                    _weekly[_selectedDay]!.add(_AvInterval(
                                      const TimeOfDay(hour: 14, minute: 0),
                                      const TimeOfDay(hour: 18, minute: 0),
                                    ));
                                    _normalizeDay(_selectedDay);
                                    setState(() {});
                                  },
                                ),
                                _QuickChip(
                                  label: 'Journée 9h-18h',
                                  icon: Icons.schedule,
                                  onTap: () {
                                    _weekly[_selectedDay] = [
                                      _AvInterval(const TimeOfDay(hour: 9, minute: 0),
                                          const TimeOfDay(hour: 18, minute: 0)),
                                    ];
                                    setState(() {});
                                  },
                                ),
                                _QuickChip(
                                  label: 'Fermé',
                                  icon: Icons.block,
                                  color: Colors.grey[600],
                                  onTap: () {
                                    _weekly[_selectedDay] = [];
                                    setState(() {});
                                  },
                                ),
                                _QuickChip(
                                  label: 'Copier partout',
                                  icon: Icons.copy_all,
                                  onTap: () {
                                    final copy = _weekly[_selectedDay]!
                                        .map((e) => _AvInterval(e.start, e.end))
                                        .toList();
                                    setState(() {
                                      for (var d = 0; d < 7; d++) {
                                        if (d == _selectedDay) continue;
                                        _weekly[d] = copy
                                            .map((e) => _AvInterval(e.start, e.end))
                                            .toList();
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Reproduit sur tous les jours ✅')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Créneaux
                      Text('Créneaux', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                      const SizedBox(height: 10),

                      if (_weekly[_selectedDay]!.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.event_busy, size: 40, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('Aucun créneau', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('Utilisez les raccourcis ou ajoutez manuellement', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        )
                      else
                        ..._weekly[_selectedDay]!.asMap().entries.map((entry) {
                          final i = entry.key;
                          final interval = entry.value;
                          return _SlotCard(
                            start: interval.start,
                            end: interval.end,
                            onStartChanged: (t) {
                              interval.start = t;
                              setState(() {});
                            },
                            onEndChanged: (t) {
                              interval.end = t;
                              setState(() {});
                            },
                            onDelete: () {
                              _weekly[_selectedDay]!.removeAt(i);
                              setState(() {});
                            },
                          );
                        }),

                      const SizedBox(height: 12),

                      // Bouton ajouter
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _weekly[_selectedDay]!.add(
                              _AvInterval(
                                const TimeOfDay(hour: 9, minute: 0),
                                const TimeOfDay(hour: 12, minute: 0),
                              ),
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.add, color: _coral),
                          label: const Text('Ajouter un créneau', style: TextStyle(color: _coral)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: _coral),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // Boutons d'action
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: (_savingWeekly || _loadingWeekly) ? null : _saveWeekly,
                    style: FilledButton.styleFrom(
                      backgroundColor: _coral,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _savingWeekly
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: (_savingWeekly || _loadingWeekly) ? null : _clearWeekly,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Icon(Icons.delete_outline, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeOffsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formulaire d'ajout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _coralSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_busy, color: _coral, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Nouvelle absence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),

                const SizedBox(height: 20),

                // Plage de dates
                Text('Période', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickOffDateRange,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: Colors.grey[500], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _offDateRange == null
                                ? 'Sélectionner les dates'
                                : '${DateFormat('EEE d MMM', 'fr_FR').format(_offDateRange!.start)}  →  '
                                  '${DateFormat('EEE d MMM', 'fr_FR').format(_offDateRange!.end)}',
                            style: TextStyle(
                              color: _offDateRange == null ? Colors.grey[400] : Colors.black87,
                              fontWeight: _offDateRange == null ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Heures
                Text('Horaires', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerButton(
                        label: 'Début',
                        time: _offStart,
                        onTap: () => _pickTime(
                          initial: _offStart,
                          onPicked: (t) => setState(() => _offStart = t),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward, color: Colors.grey[400], size: 20),
                    ),
                    Expanded(
                      child: _TimePickerButton(
                        label: 'Fin',
                        time: _offEnd,
                        onTap: () => _pickTime(
                          initial: _offEnd,
                          onPicked: (t) => setState(() => _offEnd = t),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Motif
                Text('Motif (optionnel)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                const SizedBox(height: 8),
                TextField(
                  controller: _offNote,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Congés, formation, déplacement...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _coral),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),

                const SizedBox(height: 20),

                // Bouton ajouter
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addingOff ? null : _addTimeOff,
                    icon: _addingOff ? const SizedBox.shrink() : const Icon(Icons.add),
                    label: Text(_addingOff ? 'Ajout en cours...' : 'Ajouter cette absence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _coral,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Liste des absences
          Row(
            children: [
              const Text('Absences planifiées', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_loadingOffs)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _coral)),
            ],
          ),
          const SizedBox(height: 12),

          if (!_loadingOffs && _timeOffs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 40, color: Colors.green[300]),
                  const SizedBox(height: 8),
                  const Text('Aucune absence', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('Vous êtes disponible!', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            )
          else
            ...(_timeOffs.map((m) {
              final id   = (m['id'] ?? '').toString();
              final sIso = (m['startsAt'] ?? m['start'] ?? '').toString();
              final eIso = (m['endsAt']   ?? m['end']   ?? '').toString();
              final note = (m['reason'] ?? '').toString();

              DateTime? s, e;
              try { s = DateTime.parse(sIso).toLocal(); } catch (_) {}
              try { e = DateTime.parse(eIso).toLocal(); } catch (_) {}

              return _TimeOffCard(
                start: s,
                end: e,
                note: note,
                onDelete: () => _confirmDeleteTimeOff(id),
              );
            })),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTimeOff(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette absence ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) _deleteTimeOff(id);
  }
}

// ===== Widgets =====

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _QuickChip({required this.label, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? _coral).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? _coral),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? _coral)),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final TimeOfDay start;
  final TimeOfDay end;
  final ValueChanged<TimeOfDay> onStartChanged;
  final ValueChanged<TimeOfDay> onEndChanged;
  final VoidCallback onDelete;

  const _SlotCard({
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onDelete,
  });

  Future<void> _pick(BuildContext context, TimeOfDay init, ValueChanged<TimeOfDay> cb) async {
    final t = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _coral),
          ),
          child: child!,
        );
      },
    );
    if (t != null) cb(t);
  }

  @override
  Widget build(BuildContext context) {
    final invalid = (end.hour * 60 + end.minute) <= (start.hour * 60 + start.minute);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: invalid ? Colors.red[200]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _coralSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.access_time, color: _coral, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _pick(context, start, onStartChanged),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Début', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  Text(start.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          Icon(Icons.arrow_forward, color: Colors.grey[300], size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _pick(context, end, onEndChanged),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fin', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  Text(end.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          if (invalid)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.error_outline, color: Colors.red[400], size: 20),
            ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
              padding: const EdgeInsets.all(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(time.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _TimeOffCard extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final String note;
  final VoidCallback onDelete;

  const _TimeOffCard({required this.start, required this.end, required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    String fmtDate(DateTime d) => DateFormat('EEE d MMM', 'fr_FR').format(d);
    String fmtTime(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);

    String dateLabel = '';
    String timeLabel = '';

    if (start != null && end != null) {
      final sameDay = start!.year == end!.year && start!.month == end!.month && start!.day == end!.day;
      if (sameDay) {
        dateLabel = fmtDate(start!);
        timeLabel = '${fmtTime(start!)} → ${fmtTime(end!)}';
      } else {
        dateLabel = '${fmtDate(start!)} → ${fmtDate(end!)}';
        timeLabel = '${fmtTime(start!)} → ${fmtTime(end!)}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.event_busy, color: Colors.orange[400], size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(timeLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
          ),
        ],
      ),
    );
  }
}
