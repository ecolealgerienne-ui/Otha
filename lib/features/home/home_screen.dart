// lib/features/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// 🗺️ preview map
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;

import '../../core/session_controller.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/location_provider.dart';
// 👇 pour le bouton "Modifier" (pending)
import '../bookings/booking_confirmation_popup.dart';
import '../petshop/cart_provider.dart' show kPetshopCommissionDa;
import '../adopt/adoption_pet_creation_dialog.dart';

// ⛔️ Ne pas afficher Annuler/Modifier dans la bannière PENDING du Home
const bool kShowPendingActionsOnHome = false;

/// -------------------- Notifications (store léger) --------------------
class _Notif {
  final String id;
  final String title, body;
  final DateTime at;
  final bool read;
  final String? type;
  final Map<String, dynamic>? metadata;
  _Notif({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
    this.type,
    this.metadata,
  });
}

// Provider pour tracker si on a déjà vérifié les adoptions pendantes (une fois par session)
bool _adoptionCheckDone = false;

// Tracker si on a déjà vérifié les confirmations de bookings (une fois par session)
bool _bookingConfirmationCheckDone = false;

// Tracker si on a déjà montré la popup de restriction CETTE session (pour éviter spam au refresh)
bool _trustRestrictionShownThisSession = false;

/// Reset tous les flags de session (appelé au logout)
void resetHomeSessionFlags() {
  _adoptionCheckDone = false;
  _bookingConfirmationCheckDone = false;
  _trustRestrictionShownThisSession = false;
}

// Provider pour charger les notifications depuis le backend
final notificationsProvider = FutureProvider.autoDispose<List<_Notif>>((ref) async {
  try {
    final api = ref.read(apiProvider);
    final notifs = await api.getNotifications();

    return notifs.map((n) {
      final createdAt = DateTime.tryParse(n['createdAt']?.toString() ?? '') ?? DateTime.now();
      final metadata = n['metadata'] as Map<String, dynamic>?;
      return _Notif(
        id: n['id']?.toString() ?? '',
        title: n['title']?.toString() ?? '',
        body: n['body']?.toString() ?? '',
        at: createdAt,
        read: n['read'] == true,
        type: n['type']?.toString(),
        metadata: metadata,
      );
    }).toList();
  } catch (e) {
    return [];
  }
});

// Provider pour compter les non lues
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final api = ref.read(apiProvider);
    return await api.getUnreadNotificationsCount();
  } catch (e) {
    return 0;
  }
});

final isHostProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(sessionProvider).user ?? {};
  final email = (user['email'] ?? '').toString().toLowerCase();
  if (email.isEmpty) return false;
  final s = const FlutterSecureStorage();
  return (await s.read(key: 'is_host:$email')) == 'true';
});

/// Provider for user's pets (for home carousel)
final myPetsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.read(apiProvider);
    final pets = await api.myPets();
    return pets.map((p) => Map<String, dynamic>.from(p as Map)).toList();
  } catch (e) {
    return [];
  }
});

final avatarUrlProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(sessionProvider).user ?? {};
  final fromApi = ((user['photoUrl'] ?? user['avatar']) ?? '').toString();
  if (fromApi.startsWith('http://') || fromApi.startsWith('https://')) return fromApi;
  final email = (user['email'] ?? '').toString().toLowerCase();
  if (email.isEmpty) return null;
  final s = const FlutterSecureStorage();
  return await s.read(key: 'avatar_url:$email');
});

class NotificationsStore extends ValueNotifier<List<_Notif>> {
  static final instance = NotificationsStore._();
  NotificationsStore._() : super(const []);
  void add(String title, String body) => value = [
    _Notif(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, body: body, at: DateTime.now()),
    ...value
  ];
  void setAll(List<_Notif> notifs) => value = notifs;
  void clear() => value = const [];
}

/// Navigation au clic sur une notification
void _handleNotificationTap(BuildContext context, _Notif notif) {
  final type = notif.type;
  final metadata = notif.metadata;

  if (type == null || metadata == null) return;

  switch (type) {
    // Messages d'adoption → Ouvrir la conversation
    case 'NEW_ADOPT_MESSAGE':
      final conversationId = metadata['conversationId']?.toString();
      if (conversationId != null) {
        context.push('/adopt/chat/$conversationId');
      }
      break;

    // Demandes d'adoption (reçue/acceptée/refusée) → Ouvrir l'écran adopt (onglet chats)
    case 'ADOPT_REQUEST_RECEIVED':
    case 'ADOPT_REQUEST_ACCEPTED':
    case 'ADOPT_REQUEST_REJECTED':
      context.push('/adopt');
      break;

    // Rendez-vous confirmés/annulés → Ouvrir mes rendez-vous
    case 'BOOKING_CONFIRMED':
    case 'BOOKING_CANCELLED':
      context.push('/me/bookings');
      break;

    // Commandes expédiées/livrées → Ouvrir détails de la commande
    case 'ORDER_SHIPPED':
    case 'ORDER_DELIVERED':
      final orderId = metadata['orderId']?.toString();
      if (orderId != null) {
        context.push('/petshop/order/$orderId');
      }
      break;

    // Adoption approuvée/rejetée (admin) → Ouvrir l'écran adopt
    case 'ADOPT_POST_APPROVED':
    case 'ADOPT_POST_REJECTED':
      context.push('/adopt');
      break;

    default:
      // Type de notification inconnu, ne rien faire
      break;
  }
}

void _showNotifDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) {
      final w = MediaQuery.of(context).size.width;
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: w * .9,
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10))],
            ),
            child: ValueListenableBuilder<List<_Notif>>(
              valueListenable: NotificationsStore.instance,
              builder: (_, items, __) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      if (items.isNotEmpty)
                        TextButton(onPressed: NotificationsStore.instance.clear, child: const Text('Tout effacer')),
                    ]),
                    if (items.isEmpty)
                      const Expanded(child: Center(child: Text("Pas de notification pour l'instant")))
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = items[i];
                            return ListTile(
                              leading: const Icon(Icons.notifications),
                              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(n.body),
                              trailing: Text(
                                TimeOfDay.fromDateTime(n.at).format(context),
                                style: TextStyle(color: Colors.black.withOpacity(.5), fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.of(context).pop(); // Fermer le dialog
                                _handleNotificationTap(context, n);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: Transform.scale(scale: 0.98 + anim.value * .02, child: child)),
  );
}

/// -------------------- Top spécialistes (fetch monde, sans Alger) --------------------
final topVetsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);

  // Centre arbitraire (monde) — pas d'Alger
  const double centerLat = 0.0;
  const double centerLng = 0.0;

  final raw = await api.nearby(
    lat: centerLat,
    lng: centerLng,
    radiusKm: 40000.0, // “tout le globe”
    limit: 2000,
    offset: 0,
    status: 'approved',
  );

  String _s(v) => v?.toString() ?? '';
  double? _d(v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  final out = <Map<String, dynamic>>[];
  for (final e in raw.whereType<Map>()) {
    final m = Map<String, dynamic>.from(e);
    out.add({
      'id': _s(m['id']),
      'displayName': _s(m['displayName'] ?? m['name'] ?? 'Vétérinaire'),
      'address': _s(m['address']),
      'distanceKm': null,
      'lat': _d(m['lat']),
      'lng': _d(m['lng']),
      'specialties': m['specialties'],
    });
  }

  out.sort((a, b) => (a['displayName'] as String).toLowerCase().compareTo((b['displayName'] as String).toLowerCase()));
  return out;
});

/// -------------------- GPS (preview Home) --------------------
/// Alias vers le provider centralisé - retourne Position? pour compatibilité
final homeUserPositionStreamProvider = Provider<Position?>((ref) {
  final state = ref.watch(locationStreamProvider);
  return state.maybeWhen(
    data: (s) => s.position,
    orElse: () => null,
  );
});

/// -------------------- Prochain RDV confirmé (client) --------------------
final nextConfirmedBookingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiProvider);
  final rows = await api.myBookings(); // côté client
  final now = DateTime.now().toUtc();

  Map<String, dynamic>? best;
  DateTime? bestAt;

  for (final raw in rows) {
    final m = Map<String, dynamic>.from(raw as Map);
    final st = (m['status'] ?? '').toString().toUpperCase();
    // ✅ Seulement les RDV confirmés (les pending ont leur propre bannière)
    if (st != 'CONFIRMED') continue;

    final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
    if (iso.isEmpty) continue;

    DateTime at;
    try {
      at = DateTime.parse(iso).toUtc();
    } catch (_) {
      continue;
    }

    // ✅ Prendre en compte la durée du RDV (ne disparaît pas pile au début)
    final durationMin = (m['service']?['durationMin'] as num?)?.toInt() ?? 30;
    final endTime = at.add(Duration(minutes: durationMin));
    if (endTime.isBefore(now)) continue; // RDV complètement terminé

    if (bestAt == null || at.isBefore(bestAt)) {
      bestAt = at;
      best = m;
    }
  }
  return best;
});

/// -------------------- Prochain RDV pending (client) --------------------
final nextPendingBookingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiProvider);
  final rows = await api.myBookings(); // côté client
  final now = DateTime.now().toUtc();

  Map<String, dynamic>? best;
  DateTime? bestAt;

  for (final raw in rows) {
    final m = Map<String, dynamic>.from(raw as Map);
    final st = (m['status'] ?? '').toString().toUpperCase();
    if (st != 'PENDING') continue;

    final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
    if (iso.isEmpty) continue;

    DateTime at;
    try {
      at = DateTime.parse(iso).toUtc();
    } catch (_) {
      continue;
    }

    // ✅ Prendre en compte la durée du RDV
    final durationMin = (m['service']?['durationMin'] as num?)?.toInt() ?? 30;
    final endTime = at.add(Duration(minutes: durationMin));
    if (endTime.isBefore(now)) continue; // RDV terminé

    if (bestAt == null || at.isBefore(bestAt)) {
      bestAt = at;
      best = m;
    }
  }
  return best;
});

/// -------------------- Prochaine réservation garderie confirmée (client) --------------------
final nextConfirmedDaycareBookingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final rows = await api.myDaycareBookings(); // réservations garderie
    final now = DateTime.now().toUtc();

    Map<String, dynamic>? best;
    DateTime? bestAt;

    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      final st = (m['status'] ?? '').toString().toUpperCase();
      // ✅ Seulement les réservations confirmées (les pending ont leur propre bannière)
      if (st != 'CONFIRMED') continue;

      final iso = (m['startDate'] ?? '').toString(); // daycare utilise startDate au lieu de scheduledAt
      if (iso.isEmpty) continue;

      DateTime at;
      try {
        at = DateTime.parse(iso).toUtc();
      } catch (_) {
        continue;
      }

      // ✅ Pour garderie, vérifier endDate au lieu de durée
      final endIso = (m['endDate'] ?? '').toString();
      DateTime endAt;
      if (endIso.isNotEmpty) {
        try {
          endAt = DateTime.parse(endIso).toUtc().add(const Duration(hours: 23, minutes: 59));
        } catch (_) {
          endAt = at.add(const Duration(days: 1)); // Par défaut 1 jour
        }
      } else {
        endAt = at.add(const Duration(days: 1));
      }
      if (endAt.isBefore(now)) continue; // Réservation terminée

      if (bestAt == null || at.isBefore(bestAt)) {
        bestAt = at;
        best = m;
      }
    }
    return best;
  } catch (e) {
    return null; // Ignorer les erreurs si l'utilisateur n'a pas de réservations garderie
  }
});

/// -------------------- Prochaine réservation garderie pending (client) --------------------
final nextPendingDaycareBookingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final rows = await api.myDaycareBookings(); // réservations garderie
    final now = DateTime.now().toUtc();

    Map<String, dynamic>? best;
    DateTime? bestAt;

    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      final st = (m['status'] ?? '').toString().toUpperCase();
      if (st != 'PENDING') continue;

      final iso = (m['startDate'] ?? '').toString(); // daycare utilise startDate au lieu de scheduledAt
      if (iso.isEmpty) continue;

      DateTime at;
      try {
        at = DateTime.parse(iso).toUtc();
      } catch (_) {
        continue;
      }

      // ✅ Pour garderie, vérifier endDate au lieu de durée
      final endIso = (m['endDate'] ?? '').toString();
      DateTime endAt;
      if (endIso.isNotEmpty) {
        try {
          endAt = DateTime.parse(endIso).toUtc().add(const Duration(hours: 23, minutes: 59));
        } catch (_) {
          endAt = at.add(const Duration(days: 1));
        }
      } else {
        endAt = at.add(const Duration(days: 1));
      }
      if (endAt.isBefore(now)) continue; // Réservation terminée

      if (bestAt == null || at.isBefore(bestAt)) {
        bestAt = at;
        best = m;
      }
    }
    return best;
  } catch (e) {
    return null; // Ignorer les erreurs si l'utilisateur n'a pas de réservations garderie
  }
});

/// -------------------- Réservation garderie IN_PROGRESS (animal déposé, en attente récupération) --------------------
final inProgressDaycareBookingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final rows = await api.myDaycareBookings();

    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      final st = (m['status'] ?? '').toString().toUpperCase();
      // ✅ Seulement les réservations IN_PROGRESS (animal à la garderie)
      if (st == 'IN_PROGRESS') {
        return m;
      }
    }
    return null;
  } catch (e) {
    return null;
  }
});

/// -------------------- Commandes petshop en cours (client) --------------------
final activeOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final orders = await api.myClientOrders();
    // Filter for active orders (PENDING or CONFIRMED)
    return orders.where((o) {
      final status = (o['status'] ?? '').toString().toUpperCase();
      return status == 'PENDING' || status == 'CONFIRMED';
    }).toList();
  } catch (_) {
    return [];
  }
});

/// -------------------- Bootstrapping Home (charge vraies notifs) --------------------
class _HomeBootstrap extends ConsumerStatefulWidget {
  const _HomeBootstrap();
  @override
  ConsumerState<_HomeBootstrap> createState() => _HomeBootstrapState();
}

class _HomeBootstrapState extends ConsumerState<_HomeBootstrap> {
  final _storage = const FlutterSecureStorage();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_done) return;
    _done = true;

    try {
      final api = ref.read(apiProvider);
      final bookings = await api.myBookings();
      final seenCsv = (await _storage.read(key: 'seen_confirms')) ?? '';
      final seen = seenCsv.isEmpty ? <String>{} : seenCsv.split(',').toSet();

      for (final raw in bookings) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m['id'] ?? '').toString();
        final status = (m['status'] ?? '').toString();
        final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
        if (id.isEmpty || iso.isEmpty) continue;

        DateTime? when;
        try {
          when = DateTime.parse(iso);
        } catch (_) {}

        final future = when == null ? false : when.isAfter(DateTime.now());
        if (status == 'CONFIRMED' && future && !seen.contains(id)) {
          NotificationsStore.instance.add('Rendez-vous confirmé', 'Votre rendez-vous est confirmé.');
          seen.add(id);
        }
      }
      await _storage.write(key: 'seen_confirms', value: seen.join(','));
    } catch (_) {
      // silence
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// ====================================================================
///                                 HOME
/// ====================================================================
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _loadNotifications(WidgetRef ref) async {
    try {
      final notifs = await ref.read(notificationsProvider.future);
      NotificationsStore.instance.setAll(notifs);
    } catch (e) {
      // Ignorer les erreurs de chargement des notifications
    }
  }

  Future<void> _checkPendingAdoptions(BuildContext context, WidgetRef ref) async {
    // Ne vérifier qu'une seule fois par session
    if (_adoptionCheckDone) return;
    _adoptionCheckDone = true;

    try {
      await checkAndShowAdoptionDialog(context, ref);
    } catch (e) {
      // Ignorer les erreurs silencieusement
    }
  }

  Future<void> _checkPendingBookingConfirmations(BuildContext context, WidgetRef ref) async {
    // Ne vérifier qu'une seule fois par session
    if (_bookingConfirmationCheckDone) return;
    _bookingConfirmationCheckDone = true;

    try {
      final bookings = await ref.read(awaitingConfirmationBookingsProvider.future);

      // S'il y a au moins un booking en attente, afficher le popup pour le premier
      if (bookings.isNotEmpty && context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => BookingConfirmationPopup(
            booking: bookings.first,
            onDismiss: () {
              // Rafraîchir la liste après confirmation
              ref.invalidate(awaitingConfirmationBookingsProvider);
            },
          ),
        );
      }
    } catch (e) {
      // Ignorer les erreurs silencieusement
    }
  }

  /// Verifie si l'utilisateur est restreint et affiche un popup avec le timer
  Future<void> _checkTrustRestriction(BuildContext context, WidgetRef ref) async {
    // Eviter le spam si deja montre cette session (refresh, etc.)
    if (_trustRestrictionShownThisSession) return;
    _trustRestrictionShownThisSession = true; // Marquer IMMEDIATEMENT pour eviter double appel

    try {
      final api = ref.read(apiProvider);
      final trustInfo = await api.checkUserCanBook();

      final trustStatus = (trustInfo['trustStatus'] ?? '').toString().toUpperCase();
      final restrictedUntilRaw = trustInfo['restrictedUntil'];

      // Parser restrictedUntil (peut etre String ISO ou deja un DateTime serialise)
      DateTime? restrictedUntil;
      if (restrictedUntilRaw is String && restrictedUntilRaw.isNotEmpty) {
        restrictedUntil = DateTime.tryParse(restrictedUntilRaw);
      } else if (restrictedUntilRaw is DateTime) {
        restrictedUntil = restrictedUntilRaw;
      }

      debugPrint('[TRUST] Status: $trustStatus, RestrictedUntil: $restrictedUntil');

      if (trustStatus == 'RESTRICTED' && restrictedUntil != null && restrictedUntil.isAfter(DateTime.now()) && context.mounted) {
        // Calculer le temps restant
        final remaining = restrictedUntil.difference(DateTime.now());
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        final minutes = remaining.inMinutes % 60;

        String timerText;
        if (days > 0) {
          timerText = '$days jour${days > 1 ? 's' : ''} et $hours heure${hours > 1 ? 's' : ''}';
        } else if (hours > 0) {
          timerText = '$hours heure${hours > 1 ? 's' : ''} et $minutes minute${minutes > 1 ? 's' : ''}';
        } else {
          timerText = '$minutes minute${minutes > 1 ? 's' : ''}';
        }

        await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 36),
              ),
              title: const Text(
                'Compte restreint',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Vous n\'etes pas venu a votre dernier rendez-vous.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.red.shade400, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          timerText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Veuillez patienter avant de pouvoir reprendre un rendez-vous.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                  ),
                ],
              ),
              actions: [
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('J\'ai compris'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // TODO: Naviguer vers la page de contact support
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Le support sera bientot disponible.')),
                        );
                      },
                      child: Text(
                        'Contacter le support',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
      }
    } catch (e) {
      debugPrint('[TRUST] Error checking trust status: $e');
    }
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    // Invalide les providers pour forcer un vrai refresh
    ref.invalidate(topVetsProvider);
    ref.invalidate(nextConfirmedBookingProvider);
    ref.invalidate(nextPendingBookingProvider);
    ref.invalidate(nextConfirmedDaycareBookingProvider);
    ref.invalidate(nextPendingDaycareBookingProvider);
    ref.invalidate(activeOrdersProvider);
    ref.invalidate(locationStreamProvider);
    ref.invalidate(avatarUrlProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
    await Future.delayed(const Duration(milliseconds: 120));
    // Recharger les notifications après invalidation
    _loadNotifications(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    final user = state.user ?? {};

    final role = (user['role'] as String?) ?? 'USER';
    final isPro = role == 'PRO';

    final first = (user['firstName'] as String?)?.trim();
    final email = (user['email'] as String?) ?? '';
    final fallback = email.isNotEmpty ? email.split('@').first : 'Utilisateur';
    // Affiche uniquement le prénom dans le header
    final greetingName = (first != null && first.isNotEmpty) ? first : fallback;

    final avatarUrl = ref.watch(avatarUrlProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );

    // Charger les notifications et vérifier les adoptions pendantes au premier affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications(ref);
      if (!isPro) {
        _checkTrustRestriction(context, ref); // ✅ Verifier si l'utilisateur est restreint
        _checkPendingAdoptions(context, ref);
        _checkPendingBookingConfirmations(context, ref);
        // ✅ Rafraîchir les bookings à chaque affichage du home pour détecter les confirmations
        ref.invalidate(nextConfirmedBookingProvider);
        ref.invalidate(nextPendingBookingProvider);
      }
    });

    // Theme support
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      // bottomNavigationBar: const _BottomBar(), // Caché temporairement
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ Pull-to-refresh sur la CustomScrollView
            RefreshIndicator(
              color: const Color(0xFFF2968F),
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              onRefresh: () => _refreshAll(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  const SliverToBoxAdapter(child: _HomeBootstrap()),

                  // ▼ Header avec animation d'entrée
                  SliverToBoxAdapter(
                    child: _FadeSlideIn(
                      delay: const Duration(milliseconds: 0),
                      child: _Header(
                        isPro: isPro,
                        name: greetingName,
                        avatarUrl: avatarUrl,
                        trustStatus: (user['trustStatus'] as String?) ?? 'NEW',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ▼ Mes Compagnons carousel (only for non-pro users)
                  if (!isPro)
                    SliverToBoxAdapter(
                      child: _FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: const _MyPetsCarousel(),
                      ),
                    ),
                  if (!isPro) const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ▼ Banners de RDV/réservations (avec animations staggered)
                  SliverToBoxAdapter(
                    child: _FadeSlideIn(
                      delay: const Duration(milliseconds: 180),
                      child: const _NextConfirmedBanner(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _FadeSlideIn(
                      delay: const Duration(milliseconds: 220),
                      child: const _NextPendingBanner(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _NextConfirmedDaycareBookingBanner()),
                  const SliverToBoxAdapter(child: _NextPendingDaycareBookingBanner()),
                  const SliverToBoxAdapter(child: _InProgressDaycareBookingBanner()),
                  const SliverToBoxAdapter(child: _ActiveOrdersBanner()),

                  // ▼ Services carousel avec animation
                  SliverToBoxAdapter(
                    child: _FadeSlideIn(
                      delay: const Duration(milliseconds: 280),
                      child: const _ExploreGrid(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ▼ Preview carte avec animation
                  SliverToBoxAdapter(
                    child: _FadeSlideIn(
                      delay: const Duration(milliseconds: 350),
                      child: const _MapPreview(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ▼ Section Adoption & Carrière stylée
                  SliverToBoxAdapter(
                    child: _FadeSlideIn(
                      delay: const Duration(milliseconds: 420),
                      child: _AdoptBoostSection(isDark: isDark),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),

            _HostFabOverlay(),
          ],
        ),
      ),
    );
  }
}

/// -------------------- Staggered Animation Wrapper --------------------
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.offset = const Offset(0, 20),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _slide.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// -------------------- Header --------------------
class _Header extends StatelessWidget {
  const _Header({required this.isPro, required this.name, this.avatarUrl, this.trustStatus, this.isDark = false});
  final bool isPro;
  final String name;
  final String? avatarUrl;
  final String? trustStatus;
  final bool isDark;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final inits = parts.take(2).map((e) => e[0]).join().toUpperCase();
    return inits.isEmpty ? 'U' : inits;
  }

  bool _isHttp(String? s) => s != null && (s.startsWith('http://') || s.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const coral = Color(0xFFF2968F);
    const coralDark = Color(0xFFF36C6C);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.45);
    final avatarBg = isDark ? const Color(0xFF2A1A1C) : const Color(0xFFFFEEF0);
    final subtitle = isPro ? null : l10n.howIsYourCompanion;
    final display = isPro ? 'Dr. $name' : name;

    final hasAvatar = _isHttp(avatarUrl);

    // Greeting based on time of day
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : (hour < 18 ? 'Bon après-midi' : 'Bonsoir');

    // Design épuré sans fond de card
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Avatar simple avec ring coral subtil
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: coral, width: 2),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: avatarBg,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
                child: !hasAvatar
                    ? Text(_initials(display),
                        style: const TextStyle(color: coral, fontWeight: FontWeight.w700, fontSize: 14))
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Greeting + name sur une ligne
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'SFPRO',
                      color: textColor,
                    ),
                    children: [
                      TextSpan(
                        text: '$greeting, ',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: subtitleColor,
                        ),
                      ),
                      TextSpan(
                        text: display,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontFamily: 'SFPRO',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Badge vérifié (plus discret)
          if (trustStatus == 'VERIFIED') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: coral.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified, size: 16, color: coral),
            ),
          ],
          // Notification button minimal
          Consumer(
            builder: (_, ref, __) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider).maybeWhen(
                data: (count) => count,
                orElse: () => 0,
              );

              return GestureDetector(
                onTap: () => _showNotifDialog(context),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 24,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: coral,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// -------------------- (optionnel) Barre de recherche --------------------
class _SearchBar extends StatelessWidget {
  const _SearchBar();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          hintText: 'Rechercher',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF6F6F6),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        onTap: () {},
      ),
    );
  }
}

/// -------------------- Catégories (oscillation) [désactivé] --------------------
class _OscillatingCategories extends StatefulWidget {
  const _OscillatingCategories();
  @override
  State<_OscillatingCategories> createState() => _OscillatingCategoriesState();
}

class _OscillatingCategoriesState extends State<_OscillatingCategories> {
  late final ScrollController _ctl;
  Timer? _tick;
  bool _paused = false;
  Timer? _resumeTimer;
  int _dir = 1;
  static const _STEP = 1.0;
  static const _PERIOD = Duration(milliseconds: 20);

  final _cats = const [
    ('Vet', Icons.pets, '/explore/vets'),
    ('Toilettage', Icons.content_cut, '/explore/toilettage'), // fixed icon
    ('Garderie', Icons.child_care, '/explore/garderie'),
    ('Promenade', Icons.directions_walk, null),
    ('Nutrition', Icons.local_dining, null),
    ('Vaccins', Icons.vaccines, null),
  ];

  @override
  void initState() {
    super.initState();
    _ctl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _resumeTimer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _start() {
    _tick?.cancel();
    _tick = Timer.periodic(_PERIOD, (_) {
      if (!mounted || _paused || !_ctl.hasClients) return;
      final max = _ctl.position.maxScrollExtent;
      if (max <= 0) return;
      var next = _ctl.offset + (_dir * _STEP);
      if (next <= 0) {
        next = 0;
        _dir = 1;
      } else if (next >= max) {
        next = max;
        _dir = -1;
      }
      _ctl.jumpTo(next);
    });
  }

  void _pauseFor([Duration d = const Duration(seconds: 2)]) {
    _paused = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(d, () => _paused = false);
  }

  @override
  Widget build(BuildContext context) {
    const chipColor = Color(0xFFF7E5E5);
    return SizedBox(
      height: 46,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          _pauseFor();
          return false;
        },
        child: ListView.builder(
          controller: _ctl,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _cats.length,
          itemBuilder: (_, i) {
            final (label, icon, route) = _cats[i];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _pauseFor(const Duration(seconds: 3)),
                onTap: () {
                  _pauseFor(const Duration(seconds: 3));
                  if (route != null) context.push(route);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Icon(icon, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// -------------------- Bandeau RDV confirmé (tap => page détails) --------------------
/// Affiche aussi un bouton "Confirmer ma présence" si le client est à proximité
/// Vérifie la proximité automatiquement toutes les 30 secondes
class _NextConfirmedBanner extends ConsumerStatefulWidget {
  const _NextConfirmedBanner({super.key});
  @override
  ConsumerState<_NextConfirmedBanner> createState() => _NextConfirmedBannerState();
}

class _NextConfirmedBannerState extends ConsumerState<_NextConfirmedBanner> {
  bool _isNearby = false;
  bool _checkingProximity = false;
  double? _distanceMeters;
  Timer? _proximityTimer;
  Map<String, dynamic>? _lastBooking;
  Position? _lastPosition;
  bool _locationPermissionDenied = false;
  bool _locationServiceDisabled = false;

  @override
  void initState() {
    super.initState();
    // Timer qui vérifie la proximité et rafraîchit les données toutes les 30 secondes
    _proximityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        // ✅ Rafraîchir les données de booking pour détecter les changements de statut
        ref.invalidate(nextConfirmedBookingProvider);

        if (_lastBooking != null && !_locationPermissionDenied) {
          _checkProximity(_lastBooking!, forceRefresh: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    super.dispose();
  }

  String _serviceName(Map<String, dynamic> m) {
    final s = m['service'];
    if (s is Map) {
      final t = (s['title'] ?? s['name'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return 'Rendez-vous';
  }

  /// Ouvre les paramètres de l'application pour activer la localisation
  Future<void> _openLocationSettings() async {
    final opened = await Geolocator.openAppSettings();
    if (opened && mounted) {
      // Réessayer après retour des paramètres
      setState(() {
        _locationPermissionDenied = false;
        _locationServiceDisabled = false;
      });
      if (_lastBooking != null) {
        _checkProximity(_lastBooking!, forceRefresh: true);
      }
    }
  }

  /// Ouvre les paramètres système de localisation
  Future<void> _openSystemLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (opened && mounted) {
      setState(() {
        _locationServiceDisabled = false;
      });
      if (_lastBooking != null) {
        _checkProximity(_lastBooking!, forceRefresh: true);
      }
    }
  }

  /// Vérifie si l'utilisateur est à proximité du cabinet (< 500m)
  Future<void> _checkProximity(Map<String, dynamic> booking, {bool forceRefresh = false}) async {
    if (_checkingProximity) return;

    // Vérifier si le RDV est dans les prochaines 2h ou commencé depuis moins de 1h
    final iso = (booking['scheduledAt'] ?? booking['scheduled_at'] ?? '').toString();
    if (iso.isEmpty) return;

    DateTime? scheduledAt;
    try {
      // ✅ Pas de .toLocal() - les heures sont stockées en "UTC naïf" (9h = 09:00Z)
      scheduledAt = DateTime.parse(iso);
    } catch (_) {
      return;
    }

    final now = DateTime.now().toUtc(); // Comparer en UTC
    final diff = scheduledAt.difference(now);
    // Afficher le bouton confirmer si: RDV dans les 2h OU commencé depuis moins de 1h
    if (diff.inHours > 2 || diff.inHours < -1) return;

    // Récupérer les coordonnées du provider
    final provider = booking['provider'] as Map<String, dynamic>?;
    final providerProfile = booking['providerProfile'] as Map<String, dynamic>?;
    final effectiveProvider = provider ?? providerProfile;

    if (effectiveProvider == null) return;

    final provLat = (effectiveProvider['lat'] as num?)?.toDouble();
    final provLng = (effectiveProvider['lng'] as num?)?.toDouble();

    if (provLat == null || provLng == null) return;

    setState(() => _checkingProximity = true);

    try {
      // Vérifier si le service de localisation est activé
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationServiceDisabled = true;
            _checkingProximity = false;
          });
        }
        return;
      }

      // Vérifier la permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Demander la permission
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationPermissionDenied = true;
            _checkingProximity = false;
          });
        }
        return;
      }

      // Permission accordée, récupérer la position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      _lastPosition = position;

      // Sync avec le backend (throttled automatiquement)
      final bookingId = (booking['id'] ?? '').toString();
      if (bookingId.isNotEmpty) {
        syncLocationToBackend(
          api: ref.read(apiProvider),
          lat: position.latitude,
          lng: position.longitude,
          vetBookingId: bookingId,
        );
      }

      final distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        provLat, provLng,
      );

      final wasNearby = _isNearby;
      final isNowNearby = distance <= 500;

      if (mounted) {
        setState(() {
          _distanceMeters = distance;
          _isNearby = isNowNearby;
          _locationPermissionDenied = false;
          _locationServiceDisabled = false;
        });

        // Notification push intégrée via le backend sync
        if (!wasNearby && isNowNearby) {
          debugPrint('[GPS] Client est maintenant à proximité du vétérinaire');
        }
      }
    } catch (e) {
      // Ignorer les erreurs de géolocalisation
    } finally {
      if (mounted) {
        setState(() => _checkingProximity = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nextConfirmedBookingProvider);
    final userPos = ref.watch(homeUserPositionStreamProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const SizedBox.shrink();

        // Sauvegarder le booking pour les vérifications périodiques
        _lastBooking = m;

        // Vérifier la proximité si on a la position de l'utilisateur
        // Ou si la position a changé significativement
        final posChanged = userPos != null && _lastPosition != null &&
            Geolocator.distanceBetween(
              userPos.latitude, userPos.longitude,
              _lastPosition!.latitude, _lastPosition!.longitude,
            ) > 50; // Plus de 50m de différence

        if (userPos != null && !_checkingProximity && (_distanceMeters == null || posChanged)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkProximity(m);
          });
        }

        final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
        DateTime? dtUtc;
        try {
          // ✅ Pas de .toLocal() - les heures sont stockées en "UTC naïf" (9h = 09:00Z)
          dtUtc = DateTime.parse(iso);
        } catch (_) {}
        final when = dtUtc != null
            ? DateFormat('EEE d MMM • HH:mm', 'fr_FR')
                .format(dtUtc)
                .replaceFirstMapped(RegExp(r'^\w'), (x) => x.group(0)!.toUpperCase())
            : '—';

        final service = _serviceName(m);

        // Vérifier si le RDV est proche dans le temps (2h avant, 1h après)
        final now = DateTime.now().toUtc(); // Comparer en UTC
        final isTimeClose = dtUtc != null &&
            dtUtc.difference(now).inHours <= 2 &&
            dtUtc.difference(now).inHours >= -1;

        // ✅ NOUVEAU: Vérifier si c'est l'heure exacte du RDV (15min avant à 30min après)
        // Permet d'afficher le bouton "Confirmer" même sans géoloc
        final isAppointmentTimeNow = dtUtc != null &&
            now.isAfter(dtUtc.subtract(const Duration(minutes: 15))) &&
            now.isBefore(dtUtc.add(const Duration(minutes: 30)));

        // Theme support
        final themeMode = ref.watch(themeProvider);
        final isDark = themeMode == AppThemeMode.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A2E1A), const Color(0xFF1A1A1A)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFF1F8F1)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(isDark ? 0.15 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ligne principale (cliquable vers détails)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final changed = await context.push<bool>('/booking-details', extra: m);
                    if (changed == true && mounted) {
                      ref.invalidate(nextConfirmedBookingProvider);
                      ref.invalidate(nextPendingBookingProvider);
                    }
                  },
                  child: Row(
                    children: [
                      // Icon with gradient + medical badge to distinguish vet
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.event_available, color: Colors.white, size: 22),
                          ),
                          // Medical badge to distinguish vet
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                              ),
                              child: const Icon(Icons.medical_services, color: Color(0xFF22C55E), size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rendez-vous confirmé',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF22C55E),
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$when',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            Text(
                              service,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Bouton "Confirmer ma présence" si à proximité
                if (_isNearby && isTimeClose) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF43AA8B), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vous êtes à proximité !',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E7D32),
                                  fontSize: 13,
                                ),
                              ),
                              if (_distanceMeters != null)
                                Text(
                                  '${_distanceMeters!.round()} m du cabinet',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () {
                      context.push('/booking/${m['id']}/confirm', extra: m);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmer ma présence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF36C6C),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ] else if (isTimeClose && !_isNearby && _distanceMeters != null) ...[
                  // Si pas à proximité mais RDV proche, afficher la distance
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Distance: ${(_distanceMeters! / 1000).toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ] else if (isTimeClose && _locationServiceDisabled) ...[
                  // Service de localisation désactivé
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_off, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Localisation désactivée',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activez la localisation pour détecter automatiquement votre arrivée au cabinet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openSystemLocationSettings,
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Activer'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade700,
                                  side: BorderSide(color: Colors.orange.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => context.push('/booking/${m['id']}/confirm', extra: m),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF36C6C),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Confirmer', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (isTimeClose && _locationPermissionDenied) ...[
                  // Permission refusée
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_disabled, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Permission localisation refusée',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Autorisez la localisation pour détecter automatiquement votre arrivée. Sinon, confirmez manuellement.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openLocationSettings,
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Paramètres'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => context.push('/booking/${m['id']}/confirm', extra: m),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF36C6C),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Confirmer', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (isAppointmentTimeNow && _distanceMeters == null) ...[
                  // ✅ C'est l'heure du RDV mais pas de géoloc - afficher directement le bouton
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFFE65100), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'C\'est l\'heure de votre rendez-vous !',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE65100),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => context.push('/booking/${m['id']}/confirm', extra: m),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmer ma présence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF36C6C),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ] else if (isTimeClose && _distanceMeters == null) ...[
                  // Pas de géolocalisation disponible - afficher le bouton quand même
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Activez la localisation pour une confirmation automatique',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => context.push('/booking/${m['id']}/confirm', extra: m),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmer ma présence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF36C6C),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------- Bandeau RDV pending (actions Annuler/Modifier, pas d’itinéraire) --------------------
class _NextPendingBanner extends ConsumerStatefulWidget {
  const _NextPendingBanner({super.key});
  @override
  ConsumerState<_NextPendingBanner> createState() => _NextPendingBannerState();
}

class _NextPendingBannerState extends ConsumerState<_NextPendingBanner> {
  String _serviceName(Map<String, dynamic> m) {
    final s = m['service'];
    if (s is Map) {
      final t = (s['title'] ?? s['name'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return 'Rendez-vous';
  }

  String? _serviceId(Map<String, dynamic> m) {
    final s = m['service'];
    final sid = (s is Map)
        ? ((s['id'] ?? s['serviceId'] ?? s['service_id'] ?? '').toString())
        : ((m['serviceId'] ?? m['service_id'] ?? '').toString());
    return sid.isEmpty ? null : sid;
  }

  String? _providerId(Map<String, dynamic> m) {
    final p1 = (m['providerId'] ?? m['provider_id'] ?? '').toString();
    if (p1.isNotEmpty) return p1;

    final pMap = (m['provider'] is Map)
        ? Map<String, dynamic>.from(m['provider'] as Map)
        : (m['providerProfile'] is Map)
            ? Map<String, dynamic>.from(m['providerProfile'] as Map)
            : (m['provider_profile'] is Map)
                ? Map<String, dynamic>.from(m['provider_profile'] as Map)
                : null;
    final p2 = pMap == null ? '' : ((pMap['id'] ?? pMap['providerId'] ?? pMap['provider_id'] ?? '').toString());
    if (p2.isNotEmpty) return p2;

    final s = m['service'];
    if (s is Map) {
      final p3 = ((s['providerId'] ?? s['provider_id'] ?? '').toString());
      if (p3.isNotEmpty) return p3;
    }
    return null;
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le rendez-vous ?'),
        content: const Text('Cette action est irréversible. Confirmez-vous l’annulation ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF36C6C)),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiProvider).setMyBookingStatus(bookingId: id, status: 'CANCELLED');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rendez-vous annulé.')));
      }
      ref.invalidate(nextConfirmedBookingProvider);
      ref.invalidate(nextPendingBookingProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _modify(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
    final pid = _providerId(m);
    if (pid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modification impossible (pro manquant).')),
        );
      }
      return;
    }

    // Naviguer vers la page du vétérinaire pour reprendre un nouveau RDV
    GoRouter.of(context).push('/explore/vets/$pid');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nextPendingBookingProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const SizedBox.shrink();

        final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
        DateTime? dtUtc;
        try {
          // ✅ Pas de .toLocal() - les heures sont stockées en "UTC naïf"
          dtUtc = DateTime.parse(iso);
        } catch (_) {}
        final when = dtUtc != null
            ? DateFormat('EEE d MMM • HH:mm', 'fr_FR')
                .format(dtUtc)
                .replaceFirstMapped(RegExp(r'^\w'), (x) => x.group(0)!.toUpperCase())
            : '—';

        final service = _serviceName(m);

        // Theme support
        final themeMode = ref.watch(themeProvider);
        final isDark = themeMode == AppThemeMode.dark;
        final l10n = AppLocalizations.of(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF2E2A1A), const Color(0xFF1A1A1A)]
                    : [const Color(0xFFFFF8E1), const Color(0xFFFFFBF0)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFA000).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA000).withOpacity(isDark ? 0.15 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne principale similaire au confirmé
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final changed = await context.push<bool>('/booking-details', extra: m);
                    if (changed == true && mounted) {
                      ref.invalidate(nextConfirmedBookingProvider);
                      ref.invalidate(nextPendingBookingProvider);
                    }
                  },
                  child: Row(
                    children: [
                      // Icon with gradient + medical badge to distinguish vet
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFA000), Color(0xFFE65100)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFA000).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.hourglass_empty, color: Colors.white, size: 22),
                          ),
                          // Medical badge to distinguish vet
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFFA000), width: 1.5),
                              ),
                              child: const Icon(Icons.medical_services, color: Color(0xFFFFA000), size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.pendingConfirmation,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFFA000),
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              when,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            Text(
                              service,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 👇 Conserve le code des boutons mais ne l’affiche pas sur Home
                if (kShowPendingActionsOnHome)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _cancel(context, ref, m),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF36C6C),
                            side: const BorderSide(color: Color(0xFFF36C6C)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _modify(context, ref, m),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Modifier'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------- Bandeau garderie confirmée avec détection de proximité --------------------
class _NextConfirmedDaycareBookingBanner extends ConsumerStatefulWidget {
  const _NextConfirmedDaycareBookingBanner({super.key});
  @override
  ConsumerState<_NextConfirmedDaycareBookingBanner> createState() => _NextConfirmedDaycareBookingBannerState();
}

class _NextConfirmedDaycareBookingBannerState extends ConsumerState<_NextConfirmedDaycareBookingBanner> {
  bool _isNearby = false;
  bool _checkingProximity = false;
  bool _hasNotifiedPro = false; // Pour éviter de notifier plusieurs fois
  double? _distanceMeters;
  Timer? _proximityTimer;
  Map<String, dynamic>? _lastBooking;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    // Timer qui vérifie la proximité toutes les 30 secondes
    _proximityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(nextConfirmedDaycareBookingProvider);
        if (_lastBooking != null) {
          _checkProximity(_lastBooking!);
        }
      }
    });
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    super.dispose();
  }

  String _petName(Map<String, dynamic> m) {
    final pet = m['pet'];
    if (pet is Map) {
      final name = (pet['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Votre animal';
  }

  /// Vérifie si l'utilisateur est à proximité de la garderie (< 500m)
  Future<void> _checkProximity(Map<String, dynamic> booking) async {
    if (_checkingProximity) return;

    // Vérifier si c'est le jour du dépôt
    final iso = (booking['startDate'] ?? '').toString();
    if (iso.isEmpty) return;

    DateTime? startDate;
    try {
      startDate = DateTime.parse(iso);
    } catch (_) {
      return;
    }

    final now = DateTime.now().toUtc();
    final diff = startDate.difference(now);
    // Afficher le bouton confirmer si: RDV dans les 2h OU commencé depuis moins de 2h
    if (diff.inHours > 2 || diff.inHours < -2) return;

    // Récupérer les coordonnées du provider
    final provider = booking['provider'] as Map<String, dynamic>?;
    if (provider == null) return;

    final provLat = (provider['lat'] as num?)?.toDouble();
    final provLng = (provider['lng'] as num?)?.toDouble();

    if (provLat == null || provLng == null) return;

    setState(() => _checkingProximity = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastPosition = pos;

      // Sync avec le backend (throttled automatiquement)
      final bookingId = (booking['id'] ?? '').toString();
      if (bookingId.isNotEmpty) {
        syncLocationToBackend(
          api: ref.read(apiProvider),
          lat: pos.latitude,
          lng: pos.longitude,
          daycareBookingId: bookingId,
        );
      }

      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, provLat, provLng);
      final isNearby = distance < 500; // Moins de 500m

      if (mounted) {
        setState(() {
          _distanceMeters = distance;
          _isNearby = isNearby;
        });

        // ✅ Notifier automatiquement le pro quand le client est à proximité
        if (isNearby && !_hasNotifiedPro) {
          _notifyProOfProximity(booking, pos.latitude, pos.longitude);
        }
      }
    } catch (e) {
      // Ignorer les erreurs de géolocalisation
    } finally {
      if (mounted) {
        setState(() => _checkingProximity = false);
      }
    }
  }

  /// Notifie le pro que le client est à proximité (appelé automatiquement)
  Future<void> _notifyProOfProximity(Map<String, dynamic> booking, double lat, double lng) async {
    final id = (booking['id'] ?? '').toString();
    if (id.isEmpty) return;

    try {
      final api = ref.read(apiProvider);
      await api.notifyDaycareClientNearby(id, lat: lat, lng: lng);
      if (mounted) {
        setState(() => _hasNotifiedPro = true);
      }
    } catch (e) {
      // Ignorer les erreurs silencieusement
    }
  }

  void _goToDropOffConfirmation(BuildContext context, Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) return;

    context.push('/daycare/dropoff-confirmation/$id', extra: {
      'booking': m,
      'lat': _lastPosition?.latitude,
      'lng': _lastPosition?.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nextConfirmedDaycareBookingProvider);
    final userPos = ref.watch(homeUserPositionStreamProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const SizedBox.shrink();

        _lastBooking = m;

        // Vérifier la proximité si position disponible
        if (userPos != null && !_checkingProximity && _distanceMeters == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkProximity(m);
          });
        }

        final iso = (m['startDate'] ?? '').toString();
        DateTime? dtUtc;
        try {
          dtUtc = DateTime.parse(iso);
        } catch (_) {}
        final when = dtUtc != null
            ? DateFormat('EEE d MMM • HH:mm', 'fr_FR')
                .format(dtUtc)
                .replaceFirstMapped(RegExp(r'^\w'), (x) => x.group(0)!.toUpperCase())
            : '—';

        final petName = _petName(m);

        // Vérifier si c'est le jour du dépôt
        final now = DateTime.now().toUtc();
        final isTimeClose = dtUtc != null &&
            dtUtc.difference(now).inHours <= 2 &&
            dtUtc.difference(now).inHours >= -2;

        // Theme support
        final themeMode = ref.watch(themeProvider);
        final isDark = themeMode == AppThemeMode.dark;
        final l10n = AppLocalizations.of(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A2E1A), const Color(0xFF1A1A1A)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFF1F8F1)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(isDark ? 0.15 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final changed = await context.push<bool>('/daycare/booking-details', extra: m);
                    if (changed == true) {
                      ref.invalidate(nextConfirmedDaycareBookingProvider);
                      ref.invalidate(nextPendingDaycareBookingProvider);
                    }
                  },
                  child: Row(
                    children: [
                      // Icon with gradient + paw badge to distinguish daycare
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.event_available, color: Colors.white, size: 22),
                          ),
                          // Paw badge to distinguish daycare
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                              ),
                              child: const Icon(Icons.pets, color: Color(0xFF22C55E), size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.confirmedDaycare,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF22C55E),
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              when,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            Text(
                              petName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Bouton "Confirmer le dépôt" si c'est le jour du dépôt
                if (_isNearby && isTimeClose) ...[
                  // Avec géoloc et à proximité
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF22C55E)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF22C55E), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vous êtes à ${_distanceMeters?.toInt() ?? '?'}m de la garderie',
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _goToDropOffConfirmation(context, m),
                            icon: const Icon(Icons.pets, size: 18),
                            label: const Text('Confirmer le dépôt de l\'animal'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isTimeClose && !_isNearby && _distanceMeters != null) ...[
                  // Géoloc OK mais pas encore à proximité
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Distance: ${(_distanceMeters! / 1000).toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _goToDropOffConfirmation(context, m),
                      icon: const Icon(Icons.pets, size: 18),
                      label: const Text('Confirmer le dépôt de l\'animal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else if (isTimeClose && _distanceMeters == null) ...[
                  // Pas de géoloc - afficher le bouton quand même
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Activez la localisation pour une confirmation automatique',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _goToDropOffConfirmation(context, m),
                      icon: const Icon(Icons.pets, size: 18),
                      label: const Text('Confirmer le dépôt de l\'animal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------- Bandeau réservation garderie pending --------------------
class _NextPendingDaycareBookingBanner extends ConsumerStatefulWidget {
  const _NextPendingDaycareBookingBanner({super.key});
  @override
  ConsumerState<_NextPendingDaycareBookingBanner> createState() => _NextPendingDaycareBookingBannerState();
}

class _NextPendingDaycareBookingBannerState extends ConsumerState<_NextPendingDaycareBookingBanner> {
  static const _coral = Color(0xFFF36C6C);
  static const _amber = Color(0xFFFFA000);
  static const _darkCard = Color(0xFF1E1E1E);

  String _petName(Map<String, dynamic> m, AppLocalizations l10n) {
    final pet = m['pet'];
    if (pet is Map) {
      final name = (pet['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return l10n.yourPet;
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) return;

    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.cancelBookingTitle,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: 'SFPRO',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.cancelBookingMessage,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontFamily: 'SFPRO',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.no,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontFamily: 'SFPRO',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.yesCancel, style: const TextStyle(fontFamily: 'SFPRO')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiProvider).cancelDaycareBooking(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.bookingCancelledSuccess),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      ref.invalidate(nextConfirmedDaycareBookingProvider);
      ref.invalidate(nextPendingDaycareBookingProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(nextPendingDaycareBookingProvider);

    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const SizedBox.shrink();

        final iso = (m['startDate'] ?? '').toString();
        DateTime? dtUtc;
        try {
          dtUtc = DateTime.parse(iso);
        } catch (_) {}
        final when = dtUtc != null
            ? DateFormat('EEE d MMM • HH:mm', locale == 'ar' ? 'ar' : locale == 'en' ? 'en' : 'fr_FR')
                .format(dtUtc)
                .replaceFirstMapped(RegExp(r'^\w'), (x) => x.group(0)!.toUpperCase())
            : '—';

        final petName = _petName(m, l10n);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF2E2A1A), const Color(0xFF1A1A1A)]
                    : [const Color(0xFFFFF8E1), const Color(0xFFFFFBF0)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _amber.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: _amber.withOpacity(isDark ? 0.15 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final changed = await context.push<bool>('/daycare/booking-details', extra: m);
                    if (changed == true && mounted) {
                      ref.invalidate(nextConfirmedDaycareBookingProvider);
                      ref.invalidate(nextPendingDaycareBookingProvider);
                    }
                  },
                  child: Row(
                    children: [
                      // Icon with gradient + paw badge
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFA000), Color(0xFFE65100)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _amber.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.hourglass_empty, color: Colors.white, size: 22),
                          ),
                          // Paw badge to distinguish daycare
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _amber, width: 1.5),
                              ),
                              child: const Icon(Icons.pets, color: Color(0xFFFFA000), size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  l10n.pendingDaycare,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFFA000),
                                    fontFamily: 'SFPRO',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              when,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            Text(
                              petName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bouton Annuler
                if (kShowPendingActionsOnHome)
                  OutlinedButton(
                    onPressed: () => _cancel(context, ref, m),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _coral,
                      side: const BorderSide(color: _coral),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.cancel, style: const TextStyle(fontFamily: 'SFPRO')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------- Bandeau réservation garderie IN_PROGRESS (animal déposé) --------------------
class _InProgressDaycareBookingBanner extends ConsumerStatefulWidget {
  const _InProgressDaycareBookingBanner({super.key});
  @override
  ConsumerState<_InProgressDaycareBookingBanner> createState() => _InProgressDaycareBookingBannerState();
}

class _InProgressDaycareBookingBannerState extends ConsumerState<_InProgressDaycareBookingBanner> {
  bool _isNearby = false;
  bool _checkingProximity = false;
  bool _hasNotifiedPro = false; // Pour éviter de notifier plusieurs fois
  double? _distanceMeters;
  Timer? _proximityTimer;
  Map<String, dynamic>? _lastBooking;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    // Timer qui vérifie la proximité toutes les 30 secondes
    _proximityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(inProgressDaycareBookingProvider);
        if (_lastBooking != null) {
          _checkProximity(_lastBooking!);
        }
      }
    });
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    super.dispose();
  }

  String _petName(Map<String, dynamic> m) {
    final pet = m['pet'];
    if (pet is Map) {
      final name = (pet['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Votre animal';
  }

  /// Vérifie si l'utilisateur est à proximité de la garderie (< 500m)
  Future<void> _checkProximity(Map<String, dynamic> booking) async {
    if (_checkingProximity) return;

    // Récupérer les coordonnées du provider
    final provider = booking['provider'] as Map<String, dynamic>?;
    if (provider == null) return;

    final provLat = (provider['lat'] as num?)?.toDouble();
    final provLng = (provider['lng'] as num?)?.toDouble();

    if (provLat == null || provLng == null) return;

    setState(() => _checkingProximity = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastPosition = pos;

      // Sync avec le backend (throttled automatiquement)
      final bookingId = (booking['id'] ?? '').toString();
      if (bookingId.isNotEmpty) {
        syncLocationToBackend(
          api: ref.read(apiProvider),
          lat: pos.latitude,
          lng: pos.longitude,
          daycareBookingId: bookingId,
        );
      }

      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, provLat, provLng);
      final isNearby = distance < 500; // Moins de 500m

      if (mounted) {
        setState(() {
          _distanceMeters = distance;
          _isNearby = isNearby;
        });

        // ✅ Notifier automatiquement le pro quand le client est à proximité pour le retrait
        if (isNearby && !_hasNotifiedPro) {
          _notifyProOfProximity(booking, pos.latitude, pos.longitude);
        }
      }
    } catch (e) {
      // Ignorer les erreurs de géolocalisation
    } finally {
      if (mounted) {
        setState(() => _checkingProximity = false);
      }
    }
  }

  /// Notifie le pro que le client est à proximité pour le retrait (appelé automatiquement)
  Future<void> _notifyProOfProximity(Map<String, dynamic> booking, double lat, double lng) async {
    final id = (booking['id'] ?? '').toString();
    if (id.isEmpty) return;

    try {
      final api = ref.read(apiProvider);
      await api.notifyDaycareClientNearby(id, lat: lat, lng: lng);
      if (mounted) {
        setState(() => _hasNotifiedPro = true);
      }
    } catch (e) {
      // Ignorer les erreurs silencieusement
    }
  }

  void _goToPickupConfirmation(BuildContext context, Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) return;

    context.push('/daycare/pickup-confirmation/$id', extra: {
      'booking': m,
      'lat': _lastPosition?.latitude,
      'lng': _lastPosition?.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inProgressDaycareBookingProvider);
    final userPos = ref.watch(homeUserPositionStreamProvider);
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    // Couleurs selon le thème
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const SizedBox.shrink();

        _lastBooking = m;

        // Vérifier la proximité si position disponible
        if (userPos != null && !_checkingProximity && _distanceMeters == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkProximity(m);
          });
        }

        final petName = _petName(m);

        // Calculer le temps depuis le dépôt
        final dropIso = (m['clientDropConfirmedAt'] ?? m['startDate'] ?? '').toString();
        DateTime? dropAt;
        try {
          dropAt = DateTime.parse(dropIso);
        } catch (_) {}

        String sinceText = '';
        if (dropAt != null) {
          final diff = DateTime.now().toUtc().difference(dropAt);
          if (diff.inHours > 0) {
            sinceText = ' (${l10n.sinceHours} ${diff.inHours}h)';
          } else if (diff.inMinutes > 0) {
            sinceText = ' (${l10n.sinceHours} ${diff.inMinutes}min)';
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
              border: isDark ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final changed = await context.push<bool>('/daycare/booking-details', extra: m);
                    if (changed == true) {
                      ref.invalidate(inProgressDaycareBookingProvider);
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6), // bleu pour IN_PROGRESS
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pets, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$petName ${l10n.petAtDaycare}$sinceText',
                              style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.readyToPickup,
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 16, color: iconColor),
                    ],
                  ),
                ),

                // ✅ Bouton "Confirmer le retrait" - toujours disponible pour IN_PROGRESS
                if (_isNearby) ...[
                  // À proximité - bouton vert
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF22C55E).withOpacity(0.15) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF22C55E)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF22C55E), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.youAreXmFromDaycare('${_distanceMeters?.toInt() ?? '?'}m'),
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _goToPickupConfirmation(context, m),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: Text(l10n.confirmAnimalPickup),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!_isNearby && _distanceMeters != null) ...[
                  // Géoloc OK mais pas encore à proximité
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        l10n.distanceKm((_distanceMeters! / 1000).toStringAsFixed(1)),
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _goToPickupConfirmation(context, m),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: Text(l10n.confirmAnimalPickup),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  // Pas de géoloc - afficher le bouton quand même
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: iconColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.enableLocationForAutoConfirm,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _goToPickupConfirmation(context, m),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: Text(l10n.confirmAnimalPickup),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------- Bandeau Commandes en cours (rose saumon) --------------------
class _ActiveOrdersBanner extends ConsumerWidget {
  const _ActiveOrdersBanner({super.key});

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeOrdersProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (orders) {
        if (orders.isEmpty) return const SizedBox.shrink();

        // Show all active orders stacked
        return Column(
          children: orders.map((order) {
            final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
            final baseTotalDa = _asInt(order['totalDa'] ?? 0);
            final orderId = (order['id'] ?? '').toString();
            final provider = order['provider'] as Map<String, dynamic>?;
            final shopName = provider?['displayName'] ?? 'Animalerie';
            final items = (order['items'] as List?) ?? [];
            final itemCount = items.length;

            // Calculate total item quantity for commission
            int totalItemQty = 0;
            for (final item in items) {
              totalItemQty += _asInt(item['quantity'] ?? 1);
            }

            // Add commission per item
            final commissionDa = totalItemQty * kPetshopCommissionDa;
            final totalDa = baseTotalDa + commissionDa;

            final isPending = status == 'PENDING';
            final statusText = isPending ? 'En attente' : 'Confirmee';
            final statusColor = isPending ? const Color(0xFFFFA000) : const Color(0xFF22C55E);
            final statusIcon = isPending ? Icons.hourglass_empty : Icons.thumb_up;

            return Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/petshop/order/$orderId'),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF36C6C), // rose saumon
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_bag, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commande $shopName',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  '$statusText • $itemCount article${itemCount > 1 ? 's' : ''} • $totalDa DA',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// -------------------- Services Carousel (Auto-slide) --------------------
class _ExploreGrid extends ConsumerStatefulWidget {
  const _ExploreGrid({super.key});

  @override
  ConsumerState<_ExploreGrid> createState() => _ExploreGridState();
}

class _ExploreGridState extends ConsumerState<_ExploreGrid> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentPage = 0;
  bool _isPaused = false;

  // Données des services (routes inchangées)
  static const _services = [
    ('veterinarians', Icons.medical_services_outlined, 'assets/images/vet.png', '/explore/vets'),
    ('shop', Icons.storefront_outlined, 'assets/images/shop.png', '/explore/petshop'),
    ('daycares', Icons.pets_outlined, 'assets/images/care.png', '/explore/garderie'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isPaused) return;
      final nextPage = (_currentPage + 1) % _services.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseAutoSlide() {
    _isPaused = true;
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isPaused = false);
    });
  }

  String _getLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'veterinarians': return l10n.veterinarians;
      case 'shop': return l10n.shop;
      case 'daycares': return l10n.daycares;
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    const pink = Color(0xFFF2968F);
    const pinkGlow = Color(0xFFFFC2BE);
    final bgCard = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFFFD6DA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carousel (sans titre, plus grand, moins arrondi)
        SizedBox(
          height: 140,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _pauseAutoSlide();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final (labelKey, icon, asset, route) = _services[index];
                final label = _getLabel(labelKey, l10n);

                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_pageController.position.haveDimensions) {
                      final page = _pageController.page ?? _currentPage.toDouble();
                      scale = (1 - (page - index).abs() * 0.1).clamp(0.9, 1.0);
                    }

                    return Transform.scale(
                      scale: scale,
                      child: GestureDetector(
                        onTap: () => context.push(route),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : pink.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            image: DecorationImage(
                              image: AssetImage(asset),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(isDark ? 0.4 : 0.25),
                                BlendMode.darken,
                              ),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(isDark ? 0.7 : 0.5),
                                    ],
                                  ),
                                ),
                              ),

                              // Content - texte à gauche, logo à droite, explorer en bas
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Ligne du haut: Titre à gauche, icône à droite
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Titre à gauche
                                        Text(
                                          label,
                                          style: const TextStyle(
                                            fontFamily: 'SFPRO',
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 8,
                                                color: Color(0x80000000),
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        // Icône à droite
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: pink.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: pinkGlow.withOpacity(0.5),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Icon(icon, color: Colors.white, size: 22),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    // Explorer en bas à droite
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                l10n.explore,
                                                style: TextStyle(
                                                  fontFamily: 'SFPRO',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white.withOpacity(0.95),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 12,
                                                color: Colors.white.withOpacity(0.95),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_services.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? pink : (isDark ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// -------------------- Mes animaux (carnet de santé) --------------------
class _MyPetsButton extends ConsumerWidget {
  const _MyPetsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    const coral = Color(0xFFF2968F);
    final coralSoft = isDark ? const Color(0xFF2A1A1C) : const Color(0xFFFFEEF0);
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFFFD6DA);
    final textColor = isDark ? Colors.white : const Color(0xFF222222);
    final subtitleColor = isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/pets'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0F000000),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: coralSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pets, color: coral, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.myAnimals,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'SFPRO',
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.healthRecordQr,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'SFPRO',
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// -------------------- Mes Compagnons Carousel (épuré) --------------------
class _MyPetsCarousel extends ConsumerWidget {
  const _MyPetsCarousel({super.key});

  void _showAddPetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: Color(0xFFF2968F), size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ajoutez votre compagnon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'SFPRO',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Créez le profil de votre animal pour accéder à son carnet de santé et gérer ses rendez-vous.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'SFPRO',
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.push('/pets/add');
                  // Refresh au retour
                  ref.invalidate(myPetsProvider);
                  PaintingBinding.instance.imageCache.clear();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF2968F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Ajouter mon animal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Plus tard',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final petsAsync = ref.watch(myPetsProvider);

    const coral = Color(0xFFF2968F);
    const coralDark = Color(0xFFF36C6C);

    return petsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pets) {
        // Si pas d'animaux, afficher une card d'invitation
        if (pets.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GestureDetector(
              onTap: () => _showAddPetDialog(context, ref),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: isDark
                        ? [const Color(0xFF2A1A1C), const Color(0xFF1A1A1A)]
                        : [const Color(0xFFFFF5F5), const Color(0xFFFFEEF0)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: coral.withOpacity(0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: coral.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: coral, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajoutez votre premier compagnon',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'SFPRO',
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Créer son carnet de santé',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'SFPRO',
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [coral, coralDark],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.pets, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Carousel horizontal avec PageView pour les animaux
        return SizedBox(
          height: 90,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.92),
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final pet = pets[index];
              final name = (pet['name'] ?? 'Mon animal').toString();
              final species = (pet['species'] ?? '').toString();
              final photoUrl = (pet['photoUrl'] ?? pet['photo_url'] ?? '').toString();
              final hasPhoto = photoUrl.startsWith('http');

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () async {
                    await context.push('/pets');
                    // Refresh les données au retour + vider le cache image
                    ref.invalidate(myPetsProvider);
                    PaintingBinding.instance.imageCache.clear();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Photo ou placeholder
                          if (hasPhoto)
                            Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFEEF0),
                                child: const Center(
                                  child: Icon(Icons.pets, color: coral, size: 40),
                                ),
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [const Color(0xFF2A1A1C), const Color(0xFF1A1010)]
                                      : [const Color(0xFFFFEEF0), const Color(0xFFFFD6DA)],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.pets,
                                  color: coral.withOpacity(0.5),
                                  size: 50,
                                ),
                              ),
                            ),

                          // Gradient sombre de gauche à droite
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: const [0.0, 0.8],
                              ),
                            ),
                          ),

                          // Label "Mes animaux" en haut - RTL aware
                          PositionedDirectional(
                            top: 10,
                            start: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF36C6C).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.pets,
                                    color: Color(0xFFF36C6C),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppLocalizations.of(context).myAnimals,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'SFPRO',
                                      color: Color(0xFFF36C6C),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Contenu: nom + bouton patte
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Spacer(),
                                // Infos à droite
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'SFPRO',
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black45,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (species.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          species,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'SFPRO',
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                // Bouton patte
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [coral, coralDark],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: coral.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.pets, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),

                          // Indicateur de page (dots) si plusieurs animaux
                          if (pets.length > 1)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(pets.length, (i) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: i == index ? 16 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == index
                                          ? coral
                                          : Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// -------------------- Preview Map (Home) --------------------
class _MapPreview extends ConsumerWidget {
  const _MapPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final pos = ref.watch(homeUserPositionStreamProvider);

    // Fallback éventuel: position du profil si enregistrée
    final me = ref.watch(sessionProvider).user ?? {};
    final profLat = (me['lat'] as num?)?.toDouble();
    final profLng = (me['lng'] as num?)?.toDouble();
    final LatLng? profileCenter = (profLat != null &&
            profLng != null &&
            profLat != 0 &&
            profLng != 0)
        ? LatLng(profLat, profLng)
        : null;

    final LatLng? center =
        pos != null ? LatLng(pos.latitude, pos.longitude) : profileCenter;

    final borderColor = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFFFD6DA);

    // Map tile URL based on theme
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    const coral = Color(0xFFF2968F);
    const coralDark = Color(0xFFF36C6C);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: coral.withOpacity(isDark ? 0.15 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1) Carte non interactive OU placeholder si pas de centre
                if (center == null)
                  _MapPlaceholder(isDark: isDark)
                else
                  IgnorePointer(
                    ignoring: true,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 12,
                        interactionOptions:
                            const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        // ✅ Utiliser CartoDB (theme clair ou sombre)
                        TileLayer(
                          urlTemplate: tileUrl,
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.vethome.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 44,
                              height: 44,
                              point: center,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [coral, coralDark],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: coral.withOpacity(0.5),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.my_location,
                                      size: 20, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // 2) Liseré rose premium
                IgnorePointer(
                  ignoring: true,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: coral.withOpacity(0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),

                // 3) Flou léger au-dessus de la carte
                if (center != null)
                  ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                // 4) Overlay cliquable (ouvre la vraie carte)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.push('/maps/nearby'),
                  ),
                ),

                // 5) Bouton "Professionnels à proximité" avec design premium
                Positioned(
                  left: 14,
                  top: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/maps/nearby'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [coral, coralDark],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: coral.withOpacity(0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              l10n.nearbyProfessionals,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'SFPRO',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({this.isDark = false});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // ✅ Fond neutre avec icone de localisation
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Chargement de la carte...',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[500],
                fontSize: 12,
                fontFamily: 'SFPRO',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x11F36C6C)
      ..strokeWidth = 1;

    const step = 18.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// -------------------- Vethub --------------------
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing, this.isDark = false});
  final String text;
  final Widget? trailing;
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'SFPRO',
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// -------------------- Section Adoption & Carrière stylée --------------------
class _AdoptBoostSection extends StatelessWidget {
  final bool isDark;
  const _AdoptBoostSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Card Adoption
          Expanded(
            child: _AdoptBoostCard(
              isDark: isDark,
              title: l10n.adopt,
              subtitle: l10n.changeALife,
              icon: Icons.favorite_rounded,
              gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
              route: '/adopt',
              emoji: '🐾',
            ),
          ),
          const SizedBox(width: 12),
          // Card Carrière
          Expanded(
            child: _AdoptBoostCard(
              isDark: isDark,
              title: l10n.boost,
              subtitle: l10n.yourCareer,
              icon: Icons.rocket_launch_rounded,
              gradient: const [Color(0xFF6B5BFF), Color(0xFF8B7FFF)],
              route: '/internships',
              emoji: '🚀',
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptBoostCard extends StatefulWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String route;
  final String emoji;

  const _AdoptBoostCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.route,
    required this.emoji,
  });

  @override
  State<_AdoptBoostCard> createState() => _AdoptBoostCardState();
}

class _AdoptBoostCardState extends State<_AdoptBoostCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        context.push(widget.route);
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient[0].withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Emoji décoratif en arrière-plan
              Positioned(
                right: -10,
                bottom: -10,
                child: Text(
                  widget.emoji,
                  style: TextStyle(
                    fontSize: 70,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône avec cercle
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    // Titre
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'SFPRO',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Sous-titre
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontFamily: 'SFPRO',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Flèche en haut à droite
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VethubRow extends ConsumerWidget {
  const _VethubRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final cards = [
      ('https://images.unsplash.com/photo-1517849845537-4d257902454a?w=800', l10n.adoptChangeLife, '/adopt'),
      ('https://images.unsplash.com/photo-1543852786-1cf6624b9987?w=800', l10n.boostCareer, '/internships'),
    ];

    final labelBg = isDark ? const Color(0xFF1A1A1A).withOpacity(0.9) : Colors.white.withOpacity(0.9);
    final labelColor = isDark ? Colors.white : Colors.black87;

    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final (img, title, route) = cards[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(route),
            child: Ink(
              width: 240,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(img),
                  fit: BoxFit.cover,
                  colorFilter: isDark
                      ? ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken)
                      : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x11000000),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: labelBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'SFPRO',
                      color: labelColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// -------------------- Top spécialistes --------------------
class _TopSpecialistsList extends ConsumerWidget {
  const _TopSpecialistsList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topVetsProvider);
    return SizedBox(
      height: 140,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('Aucun vétérinaire trouvé.'));
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final m = items[i];
              final id = (m['id'] ?? '').toString();
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/explore/vets/$id'),
                child: _DoctorCard(m: m),
              );
            },
          );
        },
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.m});
  final Map<String, dynamic> m;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final inits = parts.take(2).map((e) => e[0]).join().toUpperCase();
    return inits.isEmpty ? 'DR' : inits;
  }

  @override
  Widget build(BuildContext context) {
    final name = (m['displayName'] ?? m['name'] ?? 'Vétérinaire').toString();
    final address = (m['address'] ?? '').toString();
    final dist = m['distanceKm'];

    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFFEEF0),
            child: Text(_initials(name), style: TextStyle(color: Colors.pink[400], fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(address.isEmpty ? '—' : address,
              style: TextStyle(color: Colors.black.withOpacity(.55), fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          if (dist is num)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.place, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${(dist as num).toStringAsFixed(1)} km', style: TextStyle(color: Colors.black.withOpacity(.7))),
              ],
            ),
        ],
      ),
    );
  }
}

/// -------------------- Bouton “Hébergeur” --------------------
class _HostFabOverlay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const coral = Color(0xFFF36C6C);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final asyncIsHost = ref.watch(isHostProvider);
    final isHost = asyncIsHost.maybeWhen(data: (v) => v, orElse: () => false);

    if (!isHost) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      bottom: 90 + bottomInset,
      child: SizedBox(
        height: 46,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: coral,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          onPressed: () => context.push('/explore/garderie'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_work_outlined, size: 18),
              SizedBox(width: 8),
              Text('Heb'),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------- Bottom bar --------------------
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    const barColor = Colors.white;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 78 + bottomInset,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: const BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -4))],
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: InkWell(
              onTap: () => context.go('/home'),
              customBorder: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: barColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: Center(child: Image.asset('assets/images/patte.png', width: 30, height: 30)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
