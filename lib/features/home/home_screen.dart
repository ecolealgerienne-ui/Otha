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
// 👇 pour le bouton "Modifier" (pending)
import '../bookings/booking_flow_screen.dart';
import '../petshop/cart_provider.dart' show kPetshopCommissionDa;

// ⛔️ Ne pas afficher Annuler/Modifier dans la bannière PENDING du Home
const bool kShowPendingActionsOnHome = false;

/// -------------------- Notifications (store léger) --------------------
class _Notif {
  final String title, body;
  final DateTime at;
  _Notif(this.title, this.body) : at = DateTime.now();
}

final isHostProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(sessionProvider).user ?? {};
  final email = (user['email'] ?? '').toString().toLowerCase();
  if (email.isEmpty) return false;
  final s = const FlutterSecureStorage();
  return (await s.read(key: 'is_host:$email')) == 'true';
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
  void add(String title, String body) => value = [_Notif(title, body), ...value];
  void clear() => value = const [];
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
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      const Expanded(child: Center(child: Text("Pas de notification pour l'instant")))
                    else
                      Expanded(
                        child: ListView.separated(
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
final homeUserPositionStreamProvider = StreamProvider<Position?>((ref) async* {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      yield null;
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      yield null;
      return;
    }

    // valeur initiale rapide si dispo
    try {
      final first = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      yield first;
    } catch (_) {}

    // stream continu
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    );
  } catch (_) {
    yield null;
  }
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
    if (st != 'CONFIRMED') continue;

    final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
    if (iso.isEmpty) continue;

    DateTime at;
    try {
      at = DateTime.parse(iso).toUtc();
    } catch (_) {
      continue;
    }
    if (at.isBefore(now)) continue;

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
    if (at.isBefore(now)) continue;

    if (bestAt == null || at.isBefore(bestAt)) {
      bestAt = at;
      best = m;
    }
  }
  return best;
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

  Future<void> _refreshAll(WidgetRef ref) async {
    // Invalide les providers pour forcer un vrai refresh
    ref.invalidate(topVetsProvider);
    ref.invalidate(nextConfirmedBookingProvider);
    ref.invalidate(nextPendingBookingProvider);
    ref.invalidate(activeOrdersProvider);
    ref.invalidate(homeUserPositionStreamProvider);
    ref.invalidate(avatarUrlProvider);
    await Future.delayed(const Duration(milliseconds: 120));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    final user = state.user ?? {};

    final role = (user['role'] as String?) ?? 'USER';
    final isPro = role == 'PRO';

    final first = (user['firstName'] as String?)?.trim();
    final last = (user['lastName'] as String?)?.trim();
    final email = (user['email'] as String?) ?? '';
    final fallback = email.isNotEmpty ? email.split('@').first : 'Utilisateur';
    final displayName = [
      if (first != null && first.isNotEmpty) first,
      if (last != null && last.isNotEmpty) last,
    ].join(' ').trim();
    final greetingName = displayName.isEmpty ? fallback : displayName;

    final avatarUrl = ref.watch(avatarUrlProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const _BottomBar(),
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ Pull-to-refresh sur la CustomScrollView
            RefreshIndicator(
              onRefresh: () => _refreshAll(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  const SliverToBoxAdapter(child: _HomeBootstrap()),
                  SliverToBoxAdapter(child: _Header(isPro: isPro, name: greetingName, avatarUrl: avatarUrl)),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  // const SliverToBoxAdapter(child: _SearchBar()),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // const SliverToBoxAdapter(child: _OscillatingCategories()),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // ▼ Prochain RDV confirmé (vert)
                  const SliverToBoxAdapter(child: _NextConfirmedBanner()),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  // ▼ Prochain RDV pending (orange) — sous le confirmé
                  const SliverToBoxAdapter(child: _NextPendingBanner()),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  // ▼ Commandes en cours (rose saumon)
                  const SliverToBoxAdapter(child: _ActiveOrdersBanner()),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  const SliverToBoxAdapter(child: _ExploreGrid()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ▼ Preview carte (tap => /maps/nearby)
                  const SliverToBoxAdapter(child: _MapPreview()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  const SliverToBoxAdapter(child: _SectionTitle('Top spécialistes')),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  const SliverToBoxAdapter(child: _TopSpecialistsList()),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ▼ Vethub en bas
                  const SliverToBoxAdapter(child: _SectionTitle('Vethub')),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  const SliverToBoxAdapter(child: _VethubRow()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

/// -------------------- Header --------------------
class _Header extends StatelessWidget {
  const _Header({required this.isPro, required this.name, this.avatarUrl});
  final bool isPro;
  final String name;
  final String? avatarUrl;

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final inits = parts.take(2).map((e) => e[0]).join().toUpperCase();
    return inits.isEmpty ? 'U' : inits;
  }

  bool _isHttp(String? s) => s != null && (s.startsWith('http://') || s.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    final coral = const Color(0xFFF36C6C);
    final subtitle = isPro ? null : "Comment va votre compagnon aujourd'hui !";
    final display = isPro ? 'Dr. $name' : name;

    final hasAvatar = _isHttp(avatarUrl);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/settings'),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFFFEEF0),
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
              child: !hasAvatar
                  ? Text(_initials(display),
                      style: TextStyle(color: Colors.pink[400], fontWeight: FontWeight.w800))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'Bienvenue, '),
                      TextSpan(text: display, style: TextStyle(fontWeight: FontWeight.w800, color: coral)),
                    ],
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.black.withOpacity(.55))),
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<List<_Notif>>(
            valueListenable: NotificationsStore.instance,
            builder: (_, items, __) => Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(onPressed: () => _showNotifDialog(context), icon: const Icon(Icons.notifications_none)),
                if (items.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
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
class _NextConfirmedBanner extends ConsumerStatefulWidget {
  const _NextConfirmedBanner({super.key});
  @override
  ConsumerState<_NextConfirmedBanner> createState() => _NextConfirmedBannerState();
}

class _NextConfirmedBannerState extends ConsumerState<_NextConfirmedBanner> {
  String _serviceName(Map<String, dynamic> m) {
    final s = m['service'];
    if (s is Map) {
      final t = (s['title'] ?? s['name'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return 'Rendez-vous';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nextConfirmedBookingProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const SizedBox.shrink();

        final iso = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
        DateTime? dtLocal;
        try {
          dtLocal = DateTime.parse(iso).toLocal();
        } catch (_) {}
        final when = dtLocal != null
            ? DateFormat('EEE d MMM • HH:mm', 'fr_FR')
                .format(dtLocal)
                .replaceFirstMapped(RegExp(r'^\w'), (x) => x.group(0)!.toUpperCase())
            : '—';

        final service = _serviceName(m);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
              onTap: () async {
                final changed = await context.push<bool>('/booking-details', extra: m);
                if (changed == true && mounted) {
                  ref.invalidate(nextConfirmedBookingProvider);
                  ref.invalidate(nextPendingBookingProvider);
                }
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E), // ✅ vert
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_available, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Prochain rendez-vous: $when — $service',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
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
    final sid = _serviceId(m);
    if (pid == null || sid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modification impossible (pro/service manquants).')),
        );
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingFlowScreen(providerId: pid, serviceId: sid)),
    );
    if (!context.mounted) return;

    ref.invalidate(nextConfirmedBookingProvider);
    ref.invalidate(nextPendingBookingProvider);
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
        DateTime? dtLocal;
        try {
          dtLocal = DateTime.parse(iso).toLocal();
        } catch (_) {}
        final when = dtLocal != null
            ? DateFormat('EEE d MMM • HH:mm', 'fr_FR')
                .format(dtLocal)
                .replaceFirstMapped(RegExp(r'^\w'), (x) => x.group(0)!.toUpperCase())
            : '—';

        final service = _serviceName(m);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA000), // ✅ orange/jaune
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hourglass_empty, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'En attente de confirmation: $when — $service',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 16),
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

class _ExploreGrid extends StatelessWidget {
  const _ExploreGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            // Vétérinaires (grand carré à gauche) → image de fond
            Expanded(
              child: _ExploreCard(
                title: 'Vétérinaires',
                onTap: () => context.push('/explore/vets'),
                big: true,
                bgAsset: 'assets/images/vet.png',
              ),
            ),
            const SizedBox(width: 12),
            // À droite: Shop (haut), Garderies (bas) → images de fond
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _ExploreCard(
                      title: 'Shop',
                      onTap: () => context.push('/explore/petshop'),
                      bgAsset: 'assets/images/shop.png',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _ExploreCard(
                      title: 'Garderies',
                      onTap: () => context.push('/explore/garderie'),
                      bgAsset: 'assets/images/care.png',
                    ),
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

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.title,
    required this.onTap,
    this.big = false,
    this.bgAsset, // image de fond (plein cadre)
    this.icon,    // fallback si pas d'image
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final bool big;
  final String? bgAsset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFF36C6C);
    const roseLight = Color(0xFFFFEEF0);

    final hasBg = bgAsset != null && bgAsset!.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: hasBg
                ? DecorationImage(
                    image: AssetImage(bgAsset!),
                    fit: BoxFit.cover,
                  )
                : null,
            gradient: hasBg
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: big ? [rose.withOpacity(.18), roseLight] : [roseLight, Colors.white],
                  ),
            boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6))],
            border: Border.all(color: const Color(0xFFFFD6DA)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (hasBg)
                  Positioned.fill(
                    child: Container(color: rose.withOpacity(0.18)), // voile pour lisibilité
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            title,
                            maxLines: 2,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: hasBg ? Colors.white : Colors.black,
                              shadows: hasBg
                                  ? const [Shadow(blurRadius: 4, color: Color(0x80000000), offset: Offset(0, 2))]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      if (!hasBg && icon != null)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(icon, size: big ? 36 : 28, color: rose),
                        ),
                    ],
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

/// -------------------- Preview Map (Home) --------------------
class _MapPreview extends ConsumerWidget {
  const _MapPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref
        .watch(homeUserPositionStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => null);

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1) Carte non interactive OU placeholder si pas de centre
              if (center == null)
                const _MapPlaceholder()
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
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vethome.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 38,
                            height: 38,
                            point: center,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF36C6C), // rose crevette
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.my_location,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // 2) Liseré rose
              IgnorePointer(
                ignoring: true,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFD6DA)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              // 3) Flou léger au-dessus de la carte
              if (center != null)
                ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // 4) Overlay cliquable (ouvre la vraie carte)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/maps/nearby'),
                ),
              ),

              // 5) Bouton "Professionnels à proximité" en haut à gauche
              Positioned(
                left: 12,
                top: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/maps/nearby'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF36C6C),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Professionnels à proximité',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Fond doux rose/blanc, sans texte
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFEEF0), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
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
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _VethubRow extends StatelessWidget {
  const _VethubRow();
  @override
  Widget build(BuildContext context) {
    final cards = [
      ('https://images.unsplash.com/photo-1543852786-1cf6624b9987?w=800', 'Trouvez votre stage', '/internships'),
      ('https://images.unsplash.com/photo-1517849845537-4d257902454a?w=800', 'Adoptez, changez une vie', '/adopt'),
    ];
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
                boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6))],
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.9), borderRadius: BorderRadius.circular(10)),
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
