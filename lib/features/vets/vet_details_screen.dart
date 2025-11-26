import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

final _providerDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(apiProvider).providerDetails(id);
});

final _servicesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, providerId) async {
  final list = await ref.read(apiProvider).listServices(providerId);
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _myPetsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final list = await ref.read(apiProvider).myPets();
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

@immutable
class _SlotsArgs {
  final String providerId;
  final int durationMin;
  final int days;
  const _SlotsArgs(this.providerId, this.durationMin, this.days);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SlotsArgs &&
          other.providerId == providerId &&
          other.durationMin == durationMin &&
          other.days == days;

  @override
  int get hashCode => Object.hash(providerId, durationMin, days);
}

/// On demande au back des slots « naïfs » déjà prêts (labels HH:mm sans TZ côté app)
final _naiveSlotsProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, _SlotsArgs>((ref, args) async {
  // ❌ Supprimé ref.keepAlive() pour rafraîchir les créneaux après chaque booking
  final res = await ref.read(apiProvider).providerSlotsNaive(
        providerId: args.providerId,
        durationMin: args.durationMin,
        days: args.days,
        stepMin: args.durationMin, // 👈 interval = durée du service
      );

  final days = (res['days'] as List? ?? const []);
  // Normalise en [{ day, slots:[{isoUtc, time, end}] }]
  const jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.']; // 1..7
  const mois  = ['janv.','févr.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
  String dayLabel(String yyyymmdd, int weekday1to7) {
    final mm = int.parse(yyyymmdd.substring(5,7));
    final dd = int.parse(yyyymmdd.substring(8,10));
    final j  = (weekday1to7 >= 1 && weekday1to7 <= 7) ? jours[weekday1to7 - 1] : '';
    return '$j $dd ${mois[mm - 1]}';
  }

  final out = <Map<String, dynamic>>[];
  for (final g in days) {
    if (g is! Map) continue;
    final m = Map<String, dynamic>.from(g);
    final dateStr = (m['date'] ?? '').toString();
    final weekday = int.tryParse('${m['weekday'] ?? ''}') ?? 1;
    final slots   = (m['slots'] as List? ?? const []);
    if (slots.isEmpty) continue;

    out.add({
      'day': dayLabel(dateStr, weekday),
      'slots': slots.map((s) {
        final x = Map<String, dynamic>.from(s as Map);
        return {
          'isoUtc': (x['isoUtc']   ?? '').toString(),
          'time'  : (x['label']    ?? '').toString(),
          'end'   : (x['endLabel'] ?? '').toString(),
        };
      }).toList(),
    });
  }
  return out;
});

class VetDetailsScreen extends ConsumerStatefulWidget {
  final String providerId;
  const VetDetailsScreen({super.key, required this.providerId});

  @override
  ConsumerState<VetDetailsScreen> createState() => _VetDetailsScreenState();
}

class _VetDetailsScreenState extends ConsumerState<VetDetailsScreen> {
  String? _selectedServiceId;
  String? _selectedSlotIso;
  String? _selectedPetId; // Animal sélectionné

  // Infos du service sélectionné (affichées dans l'UI)
  String _selTitle = '';
  String _selDesc  = '';
  int    _selDurationMin = 30;
  int?   _selPriceDa;

  bool _booking = false;

  String _fmtDa(num v) => NumberFormat.decimalPattern('fr_FR').format(v);

  void _applySelectedService(Map<String, dynamic> svc) {
    _selTitle = (svc['title'] ?? '').toString();
    _selDesc  = (svc['description'] ?? '').toString();
    _selDurationMin = int.tryParse('${svc['durationMin'] ?? ''}') ?? 30;
    final p = svc['price'];
    if (p is num) _selPriceDa = p.toInt();
    else if (p is String) _selPriceDa = int.tryParse(p);
  }

  @override
  Widget build(BuildContext context) {
    final details  = ref.watch(_providerDetailsProvider(widget.providerId));
    final services = ref.watch(_servicesProvider(widget.providerId));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Profil vétérinaire'),
        surfaceTintColor: Colors.transparent,
      ),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur: $e')),
        data: (p) {
          final name   = (p['displayName'] ?? 'Vétérinaire').toString();
          final bio    = (p['bio'] ?? '').toString();
          final rating = (p['ratingAvg'] as num?)?.toDouble() ?? 0.0;
          final count  = (p['ratingCount'] as num?)?.toInt() ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/dog_preview.png',
                  height: 190, width: double.infinity, fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(1)),
                Text('  ($count avis)', style: TextStyle(color: Colors.black.withOpacity(.6))),
              ]),
              const SizedBox(height: 10),
              Text(
                bio.isEmpty ? 'Pas de description.' : bio,
                style: TextStyle(color: Colors.black.withOpacity(.75)),
              ),
              const SizedBox(height: 18),

              const Text('Services', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              services.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Erreur services: $e'),
                data: (list) {
                  if (list.isEmpty) return const Text('Aucun service.');
                  // init sélection
                  _selectedServiceId ??= (list.first)['id'].toString();
                  final cur = list.firstWhere(
                    (m) => (m['id'] ?? '').toString() == _selectedServiceId,
                    orElse: () => list.first,
                  );
                  _applySelectedService(cur);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SERVICES — horizontal slider
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: list.map((svc) {
                            final id    = (svc['id'] ?? '').toString();
                            final title = (svc['title'] ?? '').toString();
                            final isSel = id == _selectedServiceId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ChoiceChip(
                                label: Text(title),
                                selected: isSel,
                                onSelected: (_) => setState(() {
                                  _selectedServiceId = id;
                                  _selectedSlotIso   = null;
                                  _applySelectedService(svc);
                                }),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Description du service
                      if (_selDesc.trim().isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE6EDF2)),
                          ),
                          child: Text(_selDesc.trim()),
                        ),
                      const SizedBox(height: 16),

                      // SÉLECTION D'ANIMAL
                      Row(
                        children: [
                          const Text('Pour quel animal ?', style: TextStyle(fontWeight: FontWeight.w700)),
                          if (_selectedPetId == null) ...[
                            const SizedBox(width: 8),
                            const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final petsAsync = ref.watch(_myPetsProvider);
                          return petsAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, st) => Text('Erreur: $e', style: TextStyle(color: Colors.red)),
                            data: (pets) {
                              if (pets.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: const Text('Vous devez d\'abord ajouter un animal dans votre profil.'),
                                );
                              }
                              // ❌ NE PLUS auto-sélectionner : l'utilisateur DOIT choisir explicitement
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: pets.map((pet) {
                                    final id = (pet['id'] ?? '').toString();
                                    final name = (pet['name'] ?? 'Animal').toString();
                                    final photoUrl = (pet['photoUrl'] ?? '').toString();
                                    final isSel = id == _selectedPetId;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: FilterChip(
                                        avatar: photoUrl.isNotEmpty
                                            ? CircleAvatar(backgroundImage: NetworkImage(photoUrl))
                                            : const Icon(Icons.pets, size: 18),
                                        label: Text(name),
                                        selected: isSel,
                                        onSelected: (_) => setState(() => _selectedPetId = id),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      const Text('Créneaux disponibles', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),

                      // SLOTS — 2 lignes horizontales (jours + heures)
                      _SlotsPickerNaive(
                        providerId: widget.providerId,
                        durationMin: _selDurationMin,
                        selectedIso: _selectedSlotIso,
                        onSelect: (iso) => setState(()=> _selectedSlotIso = iso),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(
            onPressed: (_selectedServiceId != null && _selectedSlotIso != null && _selectedPetId != null && !_booking)
                ? () async {
                    setState(()=> _booking = true);
                    try {
                      final res = await ref.read(apiProvider).createBooking(
                        serviceId: _selectedServiceId!,
                        scheduledAtIso: _selectedSlotIso!,
                        petIds: [_selectedPetId!], // Envoyer l'animal sélectionné
                      );

                      // ✅ Naviguer vers l'écran de remerciement via GoRouter
                      if (mounted) {
                        final m = (res is Map) ? Map<String, dynamic>.from(res) : <String, dynamic>{};
                        final bookingData = <String, dynamic>{
                          'id': (m['id'] ?? '').toString(),
                          ...m,
                        };

                        context.go('/booking/thanks', extra: bookingData);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(()=> _booking = false);
                    }
                  }
                : null,
            child: Text(
              _booking
                ? '...'
                : (_selPriceDa != null ? 'Réserver — ${_fmtDa(_selPriceDa!)} DA' : 'Réserver'),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2 lignes horizontales :
/// 1) Jours (chips scrollables)
/// 2) Heures du jour sélectionné (chips scrollables)
class _SlotsPickerNaive extends ConsumerStatefulWidget {
  final String providerId;
  final int durationMin;
  final void Function(String iso) onSelect;
  final String? selectedIso;
  const _SlotsPickerNaive({
    required this.providerId,
    required this.durationMin,
    required this.onSelect,
    this.selectedIso,
    super.key,
  });

  @override
  ConsumerState<_SlotsPickerNaive> createState() => _SlotsPickerNaiveState();
}

class _SlotsPickerNaiveState extends ConsumerState<_SlotsPickerNaive> {
  int _dayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_naiveSlotsProvider(_SlotsArgs(widget.providerId, widget.durationMin, 14)));

    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => Text('Erreur slots: $e'),
      data: (groups) {
        if (groups.isEmpty) return const Text('Pas de créneaux sur 14 jours.');
        if (_dayIndex >= groups.length) _dayIndex = 0;

        final dayLabels = groups.map((g) => (g['day'] ?? '').toString()).toList();
        final slotsForDay = (groups[_dayIndex]['slots'] as List).cast<Map>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : JOURS (horizontal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < dayLabels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(dayLabels[i]),
                        selected: i == _dayIndex,
                        onSelected: (_) => setState(() {
                          _dayIndex = i;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Ligne 2 : HEURES du jour sélectionné (horizontal)
            if (slotsForDay.isEmpty)
              const Text('Aucun créneau ce jour.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: slotsForDay.map<Widget>((s) {
                    final iso = (s['isoUtc'] ?? '').toString();
                    final t   = (s['time']   ?? '').toString();
                    final e   = (s['end']    ?? '').toString();
                    final label = e.isNotEmpty ? '$t–$e' : t;
                    final sel = iso == widget.selectedIso;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: sel,
                        onSelected: (_) => widget.onSelect(iso),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}
