// lib/features/bookings/booking_details_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import 'booking_flow_screen.dart';
import 'booking_thanks_screen.dart'; // 👈 AJOUT

class BookingDetailsScreen extends ConsumerStatefulWidget {
  const BookingDetailsScreen({super.key, required this.booking});

  /// Le booking passé via GoRouter (state.extra)
  final Map<String, dynamic> booking;

  @override
  ConsumerState<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  bool _busy = false;

  // cache provider détaillé (pour itinéraire si besoin)
  Map<String, dynamic>? _providerFull;
  bool _loadingProv = false;

  // 🔎 Resolver d’ID provider (si le booking n’a pas l’id)
  String? _resolvedProviderId;
  bool _resolvingPid = false;

  Map<String, dynamic> get _m => widget.booking;

  String? get _bookingId {
    final id = (_m['id'] ?? '').toString();
    return id.isEmpty ? null : id;
  }

  String? get _serviceId {
    // service.id (camel) ou service_id (snake) ou top-level
    final s = _m['service'];
    final sid = (s is Map)
        ? ((s['id'] ?? s['serviceId'] ?? s['service_id'] ?? '').toString())
        : ((_m['serviceId'] ?? _m['service_id'] ?? '').toString());
    return sid.isEmpty ? null : sid;
  }

  /// Essaie un maximum d’emplacements possibles pour l’id provider
  /// - booking.providerId / provider_id
  /// - booking.provider.id / provider_profile.id
  /// - booking.service.providerId / provider_id
  String? get _providerId {
    final p1 = (_m['providerId'] ?? _m['provider_id'] ?? '').toString();
    if (p1.isNotEmpty) return p1;

    final pMap = (_m['provider'] is Map)
        ? Map<String, dynamic>.from(_m['provider'] as Map)
        : (_m['providerProfile'] is Map)
            ? Map<String, dynamic>.from(_m['providerProfile'] as Map)
            : (_m['provider_profile'] is Map)
                ? Map<String, dynamic>.from(_m['provider_profile'] as Map)
                : null;
    final p2 = pMap == null ? '' : ((pMap['id'] ?? pMap['providerId'] ?? pMap['provider_id'] ?? '').toString());
    if (p2.isNotEmpty) return p2;

    final s = _m['service'];
    if (s is Map) {
      final p3 = ((s['providerId'] ?? s['provider_id'] ?? '').toString());
      if (p3.isNotEmpty) return p3;
    }

    return null;
  }

  // ✅ Utiliser l’id natif si présent, sinon celui résolu par displayName
  String? get _effectiveProviderId => _providerId ?? _resolvedProviderId;

  // --------- Status helpers ----------
  String get _status => (_m['status'] ?? '').toString().toUpperCase();
  bool get _isPending => _status == 'PENDING';
  bool get _isConfirmed => _status == 'CONFIRMED' || _status == 'ACCEPTED';

  @override
  void initState() {
    super.initState();
    // essaie de résoudre l’ID provider si manquant (en asynchrone après 1er frame)
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryResolveProviderId());
  }

  // Normalisation simple (minuscules, accents retirés, espaces compactés)
  String _norm(String s) {
    final lower = s.toLowerCase();
    const withAccents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿ';
    const without     = 'aaaaaaceeeeiiiinooooouuuuyy';
    final map = {for (var i = 0; i < withAccents.length; i++) withAccents[i]: without[i]};
    return lower.split('').map((ch) => map[ch] ?? ch).join().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _providerName(Map<String, dynamic> p) {
    // ⚠️ Établissement (displayName) et pas prénom/nom
    final n = (p['displayName'] ?? p['name'] ?? '').toString().trim();
    return n.isEmpty ? 'Cabinet vétérinaire' : n;
  }

  String _serviceName(Map<String, dynamic> m) {
    final s = m['service'];
    if (s is Map) {
      final t = (s['title'] ?? s['name'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return 'Service';
  }

  num? _servicePrice(Map<String, dynamic> m) {
    final s = m['service'];
    if (s is Map) {
      final p = s['price'];
      if (p is num) return p;
      if (p is String) return num.tryParse(p);
    }
    return null;
  }

  Map<String, dynamic> _providerMap(Map<String, dynamic> m) {
    // Map "light" éventuellement présente dans ton booking
    final cand = m['provider'] ?? m['providerProfile'] ?? m['provider_profile'];
    if (cand is Map) return Map<String, dynamic>.from(cand);
    return <String, dynamic>{};
  }

  String? _mapsUrl(Map<String, dynamic> p) {
    final sp = p['specialties'];
    if (sp is Map) {
      final u = (sp['mapsUrl'] ?? sp['maps_url'] ?? '').toString().trim();
      if (u.startsWith('http')) return u;
    }
    final u2 = (p['mapsUrl'] ?? p['maps_url'] ?? '').toString().trim();
    return u2.startsWith('http') ? u2 : null;
  }

  (double?, double?) _coords(Map<String, dynamic> p) {
    final lat = p['lat'], lng = p['lng'];
    final dlat = (lat is num) ? lat.toDouble() : null;
    final dlng = (lng is num) ? lng.toDouble() : null;
    return (dlat, dlng);
  }

  /// 🔎 Résout providerId à partir du displayName via /nearby (comme la liste Vets)
  Future<void> _tryResolveProviderId() async {
    if (_providerId != null || _resolvedProviderId != null) return;

    // Nom d’établissement issu du booking
    final provLight = _providerMap(_m);
    final wantedName = _providerName(provLight).trim();
    if (wantedName.isEmpty) return;

    setState(() => _resolvingPid = true);
    try {
      final api = ref.read(apiProvider);

      // On récupère TOUT (radius monde autour d'Alger) — même technique que VetsList
      final all = await api.nearby(
        lat: 36.75,
        lng: 3.06,
        radiusKm: 40000.0,
        limit: 5000,
        status: 'all',
      );

      String? found;
      final wanted = _norm(wantedName);

      // 1) match exact normalisé
      for (final e in all) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final name = _norm((m['displayName'] ?? m['name'] ?? '').toString());
        if (name == wanted) {
          final id = (m['id'] ?? '').toString();
          if (id.isNotEmpty) { found = id; break; }
        }
      }

      // 2) fallback: contient() normalisé
      found ??= () {
        for (final e in all) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final name = _norm((m['displayName'] ?? m['name'] ?? '').toString());
          if (name.contains(wanted)) {
            final id = (m['id'] ?? '').toString();
            if (id.isNotEmpty) return id;
          }
        }
        return null;
      }();

      if (found != null) {
        _resolvedProviderId = found;
        if (mounted) setState(() {}); // permet d’activer le bouton
      }
    } catch (_) {
      // si non trouvé, le bouton restera désactivé
    } finally {
      if (mounted) setState(() => _resolvingPid = false);
    }
  }

  Future<Map<String, dynamic>?> _loadProviderFullIfNeeded() async {
    if (_providerFull != null) return _providerFull;
    final pid = _effectiveProviderId;
    if (pid == null) return null;
    setState(() => _loadingProv = true);
    try {
      final m = await ref.read(apiProvider).providerDetails(pid);
      _providerFull = m;
      return m;
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _loadingProv = false);
    }
  }

  // ----------------- ACTIONS -----------------

  Future<void> _openMaps() async {
    // 1) essaie avec la map "light" du booking
    Map<String, dynamic> prov = _providerMap(_m);

    // 2) si pas de mapsUrl/coords, charge les détails du provider
    String? mapsUrl = _mapsUrl(prov);
    var (lat, lng) = _coords(prov);

    if ((mapsUrl == null || mapsUrl.isEmpty) && (lat == null || lng == null)) {
      final full = await _loadProviderFullIfNeeded();
      if (full != null) {
        prov = full;
        mapsUrl = _mapsUrl(prov);
        (lat, lng) = _coords(prov);
      }
    }

    // 3) mapsUrl -> coords -> recherche nom/adresse
    try {
      if (mapsUrl != null && mapsUrl.isNotEmpty) {
        final uri = Uri.parse(mapsUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      if (lat != null && lng != null) {
        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      final name = _providerName(prov);
      final addr = (prov['address'] ?? '').toString();
      final q = Uri.encodeComponent([name, addr].where((e) => e.trim().isNotEmpty).join(' '));
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir Google Maps: $e')),
      );
    }
  }

  Future<void> _confirmCancel() async {
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
    if (ok != true || _bookingId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).setMyBookingStatus(
        bookingId: _bookingId!,
        status: 'CANCELLED',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rendez-vous annulé.')));
      // ✅ on remonte "true" pour permettre au parent d’actualiser
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ouvre le flow pour choisir un nouveau créneau.
  /// ❗️On n’annule l’ancien QUE si un nouveau RDV est effectivement créé.
  /// ❗️Après création, on affiche BookingThanksScreen puis on remonte `true` pour rafraîchir le Home.
  Future<void> _modifyBooking() async {
    final pid = _effectiveProviderId, sid = _serviceId;
    if (pid == null || sid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modification impossible (pro/service manquants).')),
      );
      return;
    }

    // 1) Ouvrir le flow (renvoie la nouvelle réservation ou null si abandon)
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingFlowScreen(providerId: pid, serviceId: sid)),
    );

    if (!mounted) return;

    // 2) L’utilisateur a quitté sans créer -> rien à faire, on ne touche pas l’ancien
    if (created is! Map || ((created['id'] ?? '').toString().isEmpty)) return;

    // 3) Annuler l’ancien RDV avant d’afficher la page Merci (pour éviter l’effet “double” sur Home)
    if (_bookingId != null) {
      setState(() => _busy = true);
      try {
        await ref.read(apiProvider).setMyBookingStatus(
          bookingId: _bookingId!,
          status: 'CANCELLED',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ancien rendez-vous annulé.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Annulation de l’ancien RDV a échoué: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    // 4) Page “Merci” (renvoie createdBooking quand on appuie sur Terminer)
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingThanksScreen(createdBooking: Map<String, dynamic>.from(created)),
      ),
    );

    if (!mounted) return;

    // 5) Fermer l’écran de détails en signalant un changement → Home pourra se rafraîchir
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final coral = const Color(0xFFF36C6C);
    final amber = const Color(0xFFFFA000);

    // lecture des infos
    final iso = (_m['scheduledAt'] ?? _m['scheduled_at'] ?? '').toString();
    DateTime? dtUtc;
    try {
      // ✅ Pas de .toLocal() - les heures sont stockées en "UTC naïf"
      dtUtc = DateTime.parse(iso);
    } catch (_) {}
    final dateStr = dtUtc != null ? DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(dtUtc) : '—';
    final timeStr = dtUtc != null ? DateFormat('HH:mm', 'fr_FR').format(dtUtc) : '—';

    final provLight = _providerMap(_m);
    final providerName = _providerName(provLight);
    final service = _serviceName(_m);
    final price = _servicePrice(_m);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du rendez-vous'),
        actions: [
          if (_loadingProv || _resolvingPid)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            // Bandeau résumé — varie selon le statut
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isPending ? Icons.hourglass_empty : Icons.event_available,
                      color: _isPending ? amber : coral,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isPending ? 'Rendez-vous en attente de confirmation' : 'Rendez-vous confirmé',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _InfoTile(
              icon: Icons.calendar_month,
              title: 'Date',
              value: dateStr,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.schedule,
              title: 'Heure',
              value: timeStr,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.apartment,
              title: 'Chez',
              value: providerName,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.medical_services_outlined,
              title: 'Service choisi',
              value: service,
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.payments_outlined,
              title: 'Montant à régler',
              value: price == null ? '—' : '${NumberFormat.decimalPattern('fr_FR').format(price)} DA',
            ),
          ],
        ),
      ),

      // Boutons actions — en PENDING : juste Annuler / Modifier ; en CONFIRMED : + Itinéraire
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -6))],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _confirmCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: coral,
                    side: BorderSide(color: coral),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: (_busy || _effectiveProviderId == null || _serviceId == null)
                      ? null
                      : _modifyBooking,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Modifier'),
                ),
              ),
              if (_isConfirmed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _openMaps,
                    style: FilledButton.styleFrom(
                      backgroundColor: coral,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Itinéraire'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline, color: Color(0xFFF36C6C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
