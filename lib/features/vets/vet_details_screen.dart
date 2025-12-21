import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

final _providerDetailsProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(apiProvider).providerDetails(id);
});

final _servicesProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, providerId) async {
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
  int?   _selBasePriceDa;
  int    _vetCommissionDa = 100;

  bool _booking = false;

  String _fmtDa(num v) => NumberFormat.decimalPattern('fr_FR').format(v);

  void _applySelectedService(Map<String, dynamic> svc) {
    _selTitle = (svc['title'] ?? '').toString();
    _selDesc  = (svc['description'] ?? '').toString();
    _selDurationMin = int.tryParse('${svc['durationMin'] ?? ''}') ?? 30;
    final p = svc['price'];
    // Le prix stocké EST le prix de base
    if (p is num) _selBasePriceDa = p.toInt();
    else if (p is String) _selBasePriceDa = int.tryParse(p);
  }

  // Calcul du prix total (base + commission) pour l'affichage client
  int? get _selTotalPriceDa => _selBasePriceDa != null ? _selBasePriceDa! + _vetCommissionDa : null;

  /// Popup pour les erreurs de trust (nouveau client)
  void _showTrustRestrictionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule, color: _coral, size: 32),
        ),
        title: Text(
          l10n.oneStepAtTime,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF2D2D2D),
          ),
        ),
        content: Text(
          l10n.trustRestrictionMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
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
              child: Text(l10n.understood),
            ),
          ),
        ],
      ),
    );
  }

  /// Vérifie si l'utilisateur a déjà un RDV vétérinaire en cours
  Future<Map<String, dynamic>?> _checkExistingBooking() async {
    try {
      final bookings = await ref.read(apiProvider).myBookings();
      for (final b in bookings) {
        if (b is! Map) continue;
        final status = (b['status'] ?? '').toString().toUpperCase();
        // Bloquer si un RDV est en attente ou confirmé
        if (status == 'PENDING' || status == 'CONFIRMED' || status == 'AWAITING_CONFIRMATION' || status == 'PENDING_PRO_VALIDATION') {
          return Map<String, dynamic>.from(b);
        }
      }
      return null;
    } catch (_) {
      return null; // En cas d'erreur, on laisse passer
    }
  }

  /// Affiche un dialog si l'utilisateur a déjà un RDV
  void _showExistingBookingDialog(BuildContext context, Map<String, dynamic> existing) {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final scheduledAt = existing['scheduledAt']?.toString() ?? '';
    DateTime? dt;
    try { dt = DateTime.parse(scheduledAt); } catch (_) {}
    final dateStr = dt != null
        ? DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(dt)
        : 'bientôt';

    final providerName = (existing['provider']?['displayName'] ??
                          existing['providerProfile']?['displayName'] ??
                          'un vétérinaire').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_busy, color: _coral, size: 32),
        ),
        title: Text(
          'Vous avez déjà un rendez-vous',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF2D2D2D),
          ),
        ),
        content: Text(
          'Vous avez un rendez-vous prévu $dateStr chez $providerName.\n\nVeuillez annuler ce rendez-vous avant d\'en prendre un nouveau.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Fermer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Naviguer vers les détails du RDV existant
                    context.push('/booking-details', extra: existing);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _coral,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Voir mon RDV'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedServiceId == null || _selectedSlotIso == null || _selectedPetId == null) return;

    setState(() => _booking = true);

    // Vérifier si l'utilisateur a déjà un RDV en cours
    final existingBooking = await _checkExistingBooking();
    if (existingBooking != null) {
      if (mounted) {
        setState(() => _booking = false);
        _showExistingBookingDialog(context, existingBooking);
      }
      return;
    }

    try {
      final res = await ref.read(apiProvider).createBooking(
        serviceId: _selectedServiceId!,
        scheduledAtIso: _selectedSlotIso!,
        petIds: [_selectedPetId!],
      );

      if (mounted) {
        final m = (res is Map) ? Map<String, dynamic>.from(res) : <String, dynamic>{};
        // Assurer que le service avec le prix est inclus dans les données
        final bookingData = <String, dynamic>{
          'id': (m['id'] ?? '').toString(),
          ...m,
          // Inclure les infos du service sélectionné si pas présent dans la réponse API
          if (m['service'] == null || (m['service'] is Map && m['service']['price'] == null))
            'service': {
              'id': _selectedServiceId,
              'title': _selTitle,
              'description': _selDesc,
              'durationMin': _selDurationMin,
              'price': _selTotalPriceDa, // Total = base + commission
            },
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
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : Colors.white;
    final cardColor = isDark ? _darkCard : const Color(0xFFF7F9FB);
    final cardBorder = isDark ? _darkCardBorder : const Color(0xFFE6EDF2);
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: details.when(
        loading: () => Center(child: CircularProgressIndicator(color: isDark ? _coral : null)),
        error: (e, st) => Center(child: Text('${l10n.error}: $e', style: TextStyle(color: textPrimary))),
        data: (p) {
          final name     = (p['displayName'] ?? 'Veterinaire').toString();
          final bio      = (p['bio'] ?? '').toString();
          final rating   = (p['ratingAvg'] as num?)?.toDouble() ?? 0.0;
          final count    = (p['ratingCount'] as num?)?.toInt() ?? 0;
          // Le provider peut avoir avatarUrl ou photoUrl selon l'API
          final photoUrl = (p['avatarUrl'] ?? p['photoUrl'] ?? '').toString();
          final address  = (p['address'] ?? '').toString();
          // Commission du provider (pour calculer le total client)
          final vetCommissionDa = (p['vetCommissionDa'] as num?)?.toInt() ?? 100;
          // Mettre à jour la commission d'état pour le calcul du prix total
          if (_vetCommissionDa != vetCommissionDa) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _vetCommissionDa = vetCommissionDa);
            });
          }

          return CustomScrollView(
            slivers: [
              // Header avec photo du veto
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: bgColor,
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
                                color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                                child: const Icon(Icons.local_hospital, size: 80, color: _coral),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: isDark
                                      ? [_coral.withOpacity(0.2), _darkBg]
                                      : [_coralSoft, Colors.white],
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
                      color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF2D2D2D)),
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
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: textSecondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          address,
                                          style: TextStyle(fontSize: 13, color: textSecondary),
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
                              color: isDark ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                                ),
                                Text(
                                  ' ($count)',
                                  style: TextStyle(fontSize: 12, color: textSecondary),
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
                          style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Section Services
                      _buildSectionTitle(l10n.chooseService, Icons.medical_services, isDark),
                      const SizedBox(height: 12),

                      services.when(
                        loading: () => LinearProgressIndicator(color: isDark ? _coral : null),
                        error: (e, st) => Text('${l10n.error}: $e', style: TextStyle(color: textPrimary)),
                        data: (list) {
                          if (list.isEmpty) return Text(l10n.noServiceAvailable, style: TextStyle(color: textSecondary));

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
                                // Le prix stocké EST le prix de base, on calcule le total pour le client
                                final basePriceDa = price is num ? price.toInt() : (int.tryParse('$price') ?? 0);
                                final totalPriceDa = basePriceDa + vetCommissionDa;
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
                                      color: isSel
                                          ? (isDark ? _coral.withOpacity(0.2) : _coralSoft)
                                          : cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSel ? _coral : cardBorder,
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
                                            color: isSel ? _coral : (isDark ? _darkCardBorder : Colors.grey[200]),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.vaccines,
                                            color: isSel ? Colors.white : textSecondary,
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
                                                  color: isSel ? _coral : textPrimary,
                                                ),
                                              ),
                                              if (desc.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  desc,
                                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time, size: 12, color: textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text('$dur min', style: TextStyle(fontSize: 12, color: textSecondary)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Prix (total = base + commission)
                                        Text(
                                          '${_fmtDa(totalPriceDa)} DA',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isSel ? _coral : textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),

                              const SizedBox(height: 24),

                              // Section Animal
                              _buildSectionTitle(l10n.forWhichAnimal, Icons.pets, isDark),
                              const SizedBox(height: 12),
                              _buildPetSelector(isDark, textPrimary, textSecondary, cardColor, cardBorder, l10n),

                              const SizedBox(height: 24),

                              // Section Creneaux
                              _buildSectionTitle(l10n.chooseSlot, Icons.calendar_today, isDark),
                              const SizedBox(height: 12),
                              _buildSlotsSelector(isDark, textPrimary, textSecondary, cardColor, cardBorder, l10n),
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
            color: bgColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Prix total (base + commission)
              if (_selTotalPriceDa != null)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.total, style: TextStyle(fontSize: 12, color: textSecondary)),
                      Text(
                        '${_fmtDa(_selTotalPriceDa!)} DA',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
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
                    disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _booking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          l10n.confirmBooking,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _coral, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  Widget _buildPetSelector(bool isDark, Color textPrimary, Color? textSecondary, Color cardColor, Color cardBorder, AppLocalizations l10n) {
    return Consumer(
      builder: (context, ref, _) {
        final petsAsync = ref.watch(_myPetsProvider);
        return petsAsync.when(
          loading: () => LinearProgressIndicator(color: isDark ? _coral : null),
          error: (e, st) => Text('${l10n.error}: $e', style: const TextStyle(color: Colors.red)),
          data: (pets) {
            if (pets.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.orange.shade700 : Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[isDark ? 300 : 700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.addAnimalFirst,
                        style: TextStyle(color: isDark ? Colors.orange[200] : null),
                      ),
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
                      color: isSel
                          ? (isDark ? _coral.withOpacity(0.2) : _coralSoft)
                          : cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? _coral : cardBorder,
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
                            color: isSel ? _coral : (isDark ? _darkCardBorder : Colors.grey[200]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: photoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(photoUrl, fit: BoxFit.cover),
                                )
                              : Icon(
                                  Icons.pets,
                                  color: isSel ? Colors.white : textSecondary,
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
                                color: isSel ? _coral : textPrimary,
                              ),
                            ),
                            if (species.isNotEmpty)
                              Text(
                                species,
                                style: TextStyle(fontSize: 11, color: textSecondary),
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

  Widget _buildSlotsSelector(bool isDark, Color textPrimary, Color? textSecondary, Color cardColor, Color cardBorder, AppLocalizations l10n) {
    final async = ref.watch(_naiveSlotsProvider(_SlotsArgs(widget.providerId, _selDurationMin, 14)));

    return async.when(
      loading: () => LinearProgressIndicator(color: isDark ? _coral : null),
      error: (e, st) => Text('${l10n.error}: $e', style: TextStyle(color: textPrimary)),
      data: (groups) {
        if (groups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy, color: textSecondary),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.noSlotAvailable, style: TextStyle(color: textPrimary))),
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
                        color: isSel ? _coral : cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? _coral : cardBorder,
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
                              color: isSel ? Colors.white.withOpacity(0.8) : textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isSel ? Colors.white : textPrimary,
                            ),
                          ),
                          Text(
                            month,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSel ? Colors.white.withOpacity(0.8) : textSecondary,
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
                  color: isDark ? _darkCard : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(l10n.noSlotThisDay, style: TextStyle(color: textPrimary)),
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
                        color: isSel ? _coral : (isDark ? _darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _coral : cardBorder,
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
                          color: isSel ? Colors.white : textPrimary,
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
