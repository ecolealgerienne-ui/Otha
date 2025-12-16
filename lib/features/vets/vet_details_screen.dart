import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

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
  final res = await ref.read(apiProvider).providerSlotsNaive(
        providerId: args.providerId,
        durationMin: args.durationMin,
        days: args.days,
        stepMin: args.durationMin,
      );

  final days = (res['days'] as List? ?? const []);
  const jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
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
      'date': dateStr,
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
  String? _selectedPetId;
  int _selectedDayIndex = 0;

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

  /// Popup pour les erreurs de trust (nouveau client)
  void _showTrustRestrictionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: _coralSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule, color: _coral, size: 32),
        ),
        title: const Text(
          'Une etape a la fois',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'En tant que nouveau client, vous devez d\'abord honorer votre rendez-vous en cours avant d\'en reserver un autre.\n\nCela nous aide a garantir un service de qualite pour tous.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('J\'ai compris'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedServiceId == null || _selectedSlotIso == null || _selectedPetId == null) return;

    setState(() => _booking = true);
    try {
      final res = await ref.read(apiProvider).createBooking(
        serviceId: _selectedServiceId!,
        scheduledAtIso: _selectedSlotIso!,
        petIds: [_selectedPetId!],
      );

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
        final errorMsg = e.toString();
        // Detecter les erreurs de trust (403, nouveau client, etc.)
        if (errorMsg.contains('403') ||
            errorMsg.contains('nouveau client') ||
            errorMsg.contains('honorer') ||
            errorMsg.contains('restreint') ||
            errorMsg.contains('Forbidden')) {
          _showTrustRestrictionDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: _coral),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details  = ref.watch(_providerDetailsProvider(widget.providerId));
    final services = ref.watch(_servicesProvider(widget.providerId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur: $e')),
        data: (p) {
          final name     = (p['displayName'] ?? 'Veterinaire').toString();
          final bio      = (p['bio'] ?? '').toString();
          final rating   = (p['ratingAvg'] as num?)?.toDouble() ?? 0.0;
          final count    = (p['ratingCount'] as num?)?.toInt() ?? 0;
          // Le provider peut avoir avatarUrl ou photoUrl selon l'API
          final photoUrl = (p['avatarUrl'] ?? p['photoUrl'] ?? '').toString();
          final address  = (p['address'] ?? '').toString();

          return CustomScrollView(
            slivers: [
              // Header avec photo du veto
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo du veterinaire ou placeholder
                      photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: _coralSoft,
                                child: const Icon(Icons.local_hospital, size: 80, color: _coral),
                              ),
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [_coralSoft, Colors.white],
                                ),
                              ),
                              child: const Icon(Icons.local_hospital, size: 80, color: _coral),
                            ),
                      // Gradient pour lisibilite
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Color(0xFF2D2D2D)),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Contenu
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom et rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          address,
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Badge rating
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  ' ($count)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Bio
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          bio,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Section Services
                      _buildSectionTitle('Choisir un service', Icons.medical_services),
                      const SizedBox(height: 12),

                      services.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, st) => Text('Erreur: $e'),
                        data: (list) {
                          if (list.isEmpty) return const Text('Aucun service disponible.');

                          _selectedServiceId ??= (list.first)['id'].toString();
                          final cur = list.firstWhere(
                            (m) => (m['id'] ?? '').toString() == _selectedServiceId,
                            orElse: () => list.first,
                          );
                          _applySelectedService(cur);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Services cards
                              ...list.map((svc) {
                                final id    = (svc['id'] ?? '').toString();
                                final title = (svc['title'] ?? '').toString();
                                final desc  = (svc['description'] ?? '').toString();
                                final dur   = int.tryParse('${svc['durationMin'] ?? ''}') ?? 30;
                                final price = svc['price'];
                                final priceDa = price is num ? price.toInt() : (int.tryParse('$price') ?? 0);
                                final isSel = id == _selectedServiceId;

                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedServiceId = id;
                                    _selectedSlotIso = null;
                                    _applySelectedService(svc);
                                  }),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSel ? _coralSoft : const Color(0xFFF7F9FB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSel ? _coral : const Color(0xFFE6EDF2),
                                        width: isSel ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Icone
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isSel ? _coral : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.vaccines,
                                            color: isSel ? Colors.white : Colors.grey[500],
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSel ? _coral : const Color(0xFF2D2D2D),
                                                ),
                                              ),
                                              if (desc.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  desc,
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                                                  const SizedBox(width: 4),
                                                  Text('$dur min', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Prix
                                        Text(
                                          '${_fmtDa(priceDa)} DA',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isSel ? _coral : const Color(0xFF2D2D2D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),

                              const SizedBox(height: 24),

                              // Section Animal
                              _buildSectionTitle('Pour quel animal ?', Icons.pets),
                              const SizedBox(height: 12),
                              _buildPetSelector(),

                              const SizedBox(height: 24),

                              // Section Creneaux
                              _buildSectionTitle('Choisir un creneau', Icons.calendar_today),
                              const SizedBox(height: 12),
                              _buildSlotsSelector(),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Bouton de reservation fixe
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Prix total
              if (_selPriceDa != null)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                        '${_fmtDa(_selPriceDa!)} DA',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              // Bouton
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: (_selectedServiceId != null &&
                              _selectedSlotIso != null &&
                              _selectedPetId != null &&
                              !_booking)
                      ? _confirmBooking
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _coral,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _booking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Confirmer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _coralSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _coral, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  Widget _buildPetSelector() {
    return Consumer(
      builder: (context, ref, _) {
        final petsAsync = ref.watch(_myPetsProvider);
        return petsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, st) => Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
          data: (pets) {
            if (pets.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Vous devez d\'abord ajouter un animal dans votre profil.'),
                    ),
                  ],
                ),
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: pets.map((pet) {
                final id = (pet['id'] ?? '').toString();
                final name = (pet['name'] ?? 'Animal').toString();
                final photoUrl = (pet['photoUrl'] ?? '').toString();
                final species = (pet['species'] ?? '').toString();
                final isSel = id == _selectedPetId;

                return GestureDetector(
                  onTap: () => setState(() => _selectedPetId = id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel ? _coralSoft : const Color(0xFFF7F9FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? _coral : const Color(0xFFE6EDF2),
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Photo animal
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSel ? _coral : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: photoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(photoUrl, fit: BoxFit.cover),
                                )
                              : Icon(
                                  Icons.pets,
                                  color: isSel ? Colors.white : Colors.grey[500],
                                  size: 18,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSel ? _coral : const Color(0xFF2D2D2D),
                              ),
                            ),
                            if (species.isNotEmpty)
                              Text(
                                species,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                        if (isSel) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, color: _coral, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildSlotsSelector() {
    final async = ref.watch(_naiveSlotsProvider(_SlotsArgs(widget.providerId, _selDurationMin, 14)));

    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => Text('Erreur: $e'),
      data: (groups) {
        if (groups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy, color: Colors.grey[500]),
                const SizedBox(width: 12),
                const Expanded(child: Text('Aucun creneau disponible sur 14 jours.')),
              ],
            ),
          );
        }

        if (_selectedDayIndex >= groups.length) _selectedDayIndex = 0;
        final slotsForDay = (groups[_selectedDayIndex]['slots'] as List).cast<Map>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Jours horizontaux
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final day = groups[i]['day'].toString();
                  final parts = day.split(' ');
                  final weekday = parts.isNotEmpty ? parts[0] : '';
                  final dayNum = parts.length > 1 ? parts[1] : '';
                  final month = parts.length > 2 ? parts[2] : '';
                  final isSel = i == _selectedDayIndex;

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedDayIndex = i;
                      _selectedSlotIso = null;
                    }),
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSel ? _coral : const Color(0xFFF7F9FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? _coral : const Color(0xFFE6EDF2),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekday.replaceAll('.', ''),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white.withOpacity(0.8) : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isSel ? Colors.white : const Color(0xFF2D2D2D),
                            ),
                          ),
                          Text(
                            month,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSel ? Colors.white.withOpacity(0.8) : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Heures disponibles
            if (slotsForDay.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Aucun creneau ce jour.'),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: slotsForDay.map((s) {
                  final iso = (s['isoUtc'] ?? '').toString();
                  final t   = (s['time']   ?? '').toString();
                  final isSel = iso == _selectedSlotIso;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlotIso = iso),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? _coral : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _coral : const Color(0xFFE6EDF2),
                        ),
                        boxShadow: isSel
                            ? [BoxShadow(color: _coral.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : const Color(0xFF2D2D2D),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }
}
