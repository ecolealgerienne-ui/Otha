// lib/features/pro/patients_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';

/// ---------- Helpers: noms / étiquettes ----------

String humanName(Map<String, dynamic>? u) {
  if (u == null) return 'Client';
  // 1) displayName si présent
  String name = (u['displayName'] ?? '').toString().trim();
  if (name.isEmpty) {
    // 2) first/last
    final f = (u['firstName'] ?? '').toString().trim();
    final l = (u['lastName'] ?? '').toString().trim();
    name = [f, l].where((s) => s.isNotEmpty).join(' ').trim();
  }
  if (name.isEmpty) name = (u['email'] ?? '').toString().trim();
  return name.isEmpty ? 'Client' : name;
}

String petLabel(Map<String, dynamic>? p) {
  if (p == null) return '';
  final kind = (p['idNumber'] ?? p['label'] ?? p['animalType'] ?? '').toString().trim();
  final name = (p['name'] ?? '').toString().trim();
  if (kind.isNotEmpty && name.isNotEmpty) return '$kind ($name)';
  return name.isNotEmpty ? name : kind;
}

bool _isVisibleStatus(String s) {
  // On ne montre les patients qu'à partir de CONFIRMED (ou terminés)
  switch (s.toUpperCase()) {
    case 'CONFIRMED':
    case 'COMPLETED':
      return true;
    default:
      return false;
  }
}

/// ---------- Source: tous les bookings du pro (fenêtre ouverte) ----------
final _allBookingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final rows = await api.providerAgenda(); // GET /bookings/provider/me
  return rows
      .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

/// ---------- Modèle agrégé par patient ----------
class _PatientRow {
  final String keyId;        // userId si dispo, sinon email
  final String name;         // calculé via displayName || first/last || email
  final String phone;        // dernier phone connu
  final String lastPet;      // étiquette du dernier animal vu (ex: "Chien (Moka)")
  final int visits;          // nb de RDV (CONFIRMED/COMPLETED)
  final DateTime? lastAt;    // dernière visite

  const _PatientRow({
    required this.keyId,
    required this.name,
    required this.phone,
    required this.lastPet,
    required this.visits,
    required this.lastAt,
  });
}

/// ---------- Agrégation: bookings -> patients ----------
final patientsProvider =
    FutureProvider.autoDispose<List<_PatientRow>>((ref) async {
  final list = await ref.watch(_allBookingsProvider.future);

  final Map<String, _PatientRow> acc = {};

  for (final m in list) {
    final status = (m['status'] ?? '').toString().toUpperCase();
    if (!_isVisibleStatus(status)) continue; // on ignore PENDING, etc.

    final u = (m['user'] is Map)
        ? Map<String, dynamic>.from(m['user'] as Map)
        : <String, dynamic>{};

    final userId =
        (u['id'] ?? m['userId'] ?? u['email'] ?? '').toString().trim();
    if (userId.isEmpty) continue;

    final name = humanName(u);
    final phone = (u['phone'] ?? '').toString().trim();

    // Date du RDV
    DateTime? when;
    final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
    try {
      when = DateTime.parse(iso).toUtc();
    } catch (_) {}

    // Etiquette animal pour ce RDV
    final pet = (m['pet'] is Map)
        ? Map<String, dynamic>.from(m['pet'] as Map)
        : <String, dynamic>{};
    final lastPetThis = petLabel(pet);

    final prev = acc[userId];
    if (prev == null) {
      acc[userId] = _PatientRow(
        keyId: userId,
        name: name,
        phone: phone,
        lastPet: lastPetThis,
        visits: 1,
        lastAt: when,
      );
    } else {
      final newer =
          (prev.lastAt == null || (when != null && when.isAfter(prev.lastAt!)))
              ? when
              : prev.lastAt;
      // si visite plus récente -> on met à jour le dernier animal
      final lastPet =
          (newer == when && lastPetThis.isNotEmpty) ? lastPetThis : prev.lastPet;

      acc[userId] = _PatientRow(
        keyId: userId,
        name: prev.name.isNotEmpty ? prev.name : name,
        phone: prev.phone.isNotEmpty ? prev.phone : phone,
        lastPet: lastPet,
        visits: prev.visits + 1,
        lastAt: newer,
      );
    }
  }

  final rows = acc.values.toList()
    ..sort((a, b) {
      // tri par dernière visite desc, puis nom
      if (a.lastAt != null && b.lastAt != null) {
        final c = b.lastAt!.compareTo(a.lastAt!);
        if (c != 0) return c;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  return rows;
});

/// ---------- UI ----------
class ProPatientsScreen extends ConsumerStatefulWidget {
  const ProPatientsScreen({super.key});

  @override
  ConsumerState<ProPatientsScreen> createState() => _ProPatientsScreenState();
}

class _ProPatientsScreenState extends ConsumerState<ProPatientsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Recharger',
            onPressed: () {
              ref.invalidate(_allBookingsProvider);
              ref.invalidate(patientsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, téléphone, animal)…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (rows) {
                final q = _search.text.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? rows
                    : rows.where((r) {
                        final hay =
                            '${r.name} ${r.phone} ${r.lastPet}'.toLowerCase();
                        return hay.contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Aucun patient.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _PatientTile(row: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientTile extends ConsumerWidget {
  const _PatientTile({required this.row});
  final _PatientRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastTxt = row.lastAt == null
        ? '—'
        : DateFormat('EEE d MMM yyyy', 'fr_FR').format(row.lastAt!.toUtc()); // UTC naïf : 8h UTC = 8h réel

    final subtitleParts = <String>[
      if (row.lastPet.isNotEmpty) row.lastPet,
      if (row.phone.isNotEmpty) row.phone,
      'Dernière visite: $lastTxt',
      '${row.visits} ${row.visits > 1 ? "visites" : "visite"}',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6))
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          child:
              Text(row.name.isNotEmpty ? row.name.characters.first.toUpperCase() : '?'),
        ),
        title: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: FilledButton.tonal(
          onPressed: () => _showHistory(context, ref, row.keyId, row.name),
          child: const Text('Historique'),
        ),
        onTap: () => _showHistory(context, ref, row.keyId, row.name),
      ),
    );
  }

  Future<void> _showHistory(
      BuildContext context, WidgetRef ref, String userKey, String name) async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _PatientHistorySheet(userKey: userKey, title: name),
    );
  }
}

class _PatientHistorySheet extends ConsumerWidget {
  const _PatientHistorySheet({required this.userKey, required this.title});
  final String userKey;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAll = ref.watch(_allBookingsProvider);
    return asyncAll.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Erreur: $e'),
      ),
      data: (all) {
        // Bookings du patient (confirmés/terminés), plus récents d'abord
        final items = all
            .where((m) {
              final u = (m['user'] is Map)
                  ? Map<String, dynamic>.from(m['user'] as Map)
                  : <String, dynamic>{};
              final id = (u['id'] ?? m['userId'] ?? u['email'] ?? '')
                  .toString()
                  .trim();
              if (id != userKey) return false;
              final st = (m['status'] ?? '').toString().toUpperCase();
              return _isVisibleStatus(st);
            })
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
          ..sort((a, b) {
            final A = DateTime.tryParse(
                    (a['scheduledAt'] ?? a['scheduled_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final B = DateTime.tryParse(
                    (b['scheduledAt'] ?? b['scheduled_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return B.compareTo(A);
          });

        final nf = NumberFormat.decimalPattern('fr_FR');

        Widget rowFor(Map<String, dynamic> m) {
          final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
          DateTime? dt;
          try {
            dt = DateTime.parse(iso).toUtc(); // UTC naïf : 8h UTC = 8h réel
          } catch (_) {}
          final when =
              dt != null ? DateFormat('dd/MM/yyyy • HH:mm', 'fr_FR').format(dt) : '—';

          final service = (m['service']?['title'] ?? 'Service').toString();

          // prix robuste (num / string)
          num? price;
          final p = m['service']?['price'];
          if (p is num) {
            price = p;
          } else if (p is String) {
            price = num.tryParse(p);
          }
          final priceTxt = price != null ? '${nf.format(price)} DA' : '—';

          final petTxt = petLabel(
              (m['pet'] is Map) ? Map<String, dynamic>.from(m['pet'] as Map) : null);

          final status = (m['status'] ?? '').toString();

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_note),
            title: Text(service, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              when,
              if (petTxt.isNotEmpty) petTxt,
              if (status.isNotEmpty) status,
            ].join(' • ')),
            trailing:
                Text(priceTxt, style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              final id = (m['id'] ?? '').toString();
              if (id.isEmpty) return;
              // Ouvre l’occurrence dans l’agenda
              GoRouter.of(context).go('/pro/agenda', extra: {
                'focusIso': iso,
                'bookingId': id,
              });
            },
          );
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, ctl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Text('Historique — $title',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text('Aucun rendez-vous pour ce patient.'))
                      : ListView.separated(
                          controller: ctl,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => rowFor(items[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
