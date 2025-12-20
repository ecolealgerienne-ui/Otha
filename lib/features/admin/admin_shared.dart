import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminColors {
  static const salmon = Color(0xFFF36C6C);
  static const salmonSoft = Color(0xFFFFE7E7);
  static const ink = Colors.black87;
}

/// Commission par défaut (fallback si non définie dans le profil du provider)
const int kDefaultCommissionDa = 100; // DA par RDV COMPLETED

// ===== Format =====
String formatDa(int value) {
  final nf = NumberFormat.decimalPattern('fr_FR');
  return '${nf.format(value)} DA';
}

// ===== Périodes (mois courant, en UTC) =====
({DateTime from, DateTime to}) currentMonthUtc() {
  final now = DateTime.now().toUtc();
  final from = DateTime.utc(now.year, now.month, 1);
  final to = (now.month == 12)
      ? DateTime.utc(now.year + 1, 1, 1)
      : DateTime.utc(now.year, now.month + 1, 1);
  return (from: from, to: to);
}

// ===== Cartes / Maps =====
String? staticMapUrl(double? lat, double? lng, {int w = 900, int h = 360, int z = 16}) {
  if (lat == null || lng == null || lat == 0 || lng == 0) return null;
  final ll = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  final base = 'https://staticmap.openstreetmap.de/staticmap.php';
  final cb = DateTime.now().millisecondsSinceEpoch;
  return '$base?center=$ll&zoom=$z&size=${w}x$h&maptype=mapnik&markers=$ll,red-pushpin&cb=$cb';
}

String sanitizeMaps(String u) {
  final raw = u.trim();
  if (raw.isEmpty) return '';
  final withScheme =
      RegExp(r'^(https?://)', caseSensitive: false).hasMatch(raw) ? raw : 'https://$raw';
  Uri uri;
  try {
    uri = Uri.parse(withScheme);
  } catch (_) {
    return raw;
  }
  const banned = {
    'ts',
    'entry',
    'g_ep',
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'hl',
    'ved',
    'source',
    'opi',
    'sca_esv'
  };
  final qp = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((k, _) => banned.contains(k));
  var path = uri.path.replaceAll(RegExp(r'/+'), '/');
  final hasImportant =
      RegExp(r'/data=![^/?#]*(?:!3d|!4d|:0x|ChI)', caseSensitive: false).hasMatch(path);
  if (!hasImportant) path = path.replaceAll(RegExp(r'/data=![^/?#]*'), '');
  final clean = uri.replace(queryParameters: qp, path: path);
  return clean.toString().replaceAll(RegExp(r'[?#]$'), '');
}

({double? lat, double? lng}) extractLatLngFromUrl(String url) {
  final s = url.trim();
  if (s.isEmpty) return (lat: null, lng: null);
  final dec = Uri.decodeFull(s);

  final at =
      RegExp(r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)').allMatches(dec).toList();
  if (at.isNotEmpty) {
    final m = at.last;
    final lat = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    final lng = double.tryParse(m.group(2)!.replaceAll(',', '.'));
    if (lat != null && lng != null) return (lat: lat, lng: lng);
  }

  final m34 =
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)', caseSensitive: false)
          .firstMatch(dec);
  if (m34 != null) {
    final lat = double.tryParse(m34.group(1)!.replaceAll(',', '.'));
    final lng = double.tryParse(m34.group(2)!.replaceAll(',', '.'));
    return (lat: lat, lng: lng);
  }
  final m43 =
      RegExp(r'!4d(-?\d+(?:\.\d+)?)!3d(-?\d+(?:\.\d+)?)', caseSensitive: false)
          .firstMatch(dec);
  if (m43 != null) {
    final lat = double.tryParse(m43.group(2)!.replaceAll(',', '.'));
    final lng = double.tryParse(m43.group(1)!.replaceAll(',', '.'));
    return (lat: lat, lng: lng);
  }
  return (lat: null, lng: null);
}

// ===== UI partagées =====
class StatsRow extends StatelessWidget {
  final List<Widget> items;
  const StatsRow({super.key, required this.items});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: items[0]),
        const SizedBox(width: 12),
        Expanded(child: items[1]),
      ]);
}

class StatBox extends StatelessWidget {
  final String label;
  final int? value;
  final IconData icon;
  final int? badge;
  final VoidCallback? onTap;
  const StatBox(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.badge,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.salmon.withOpacity(.25)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6))
            ],
          ),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: AdminColors.salmonSoft,
                child: Icon(icon, color: AdminColors.salmon)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.black.withOpacity(.65), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${value ?? '—'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18)),
                ])),
            if (badge != null && badge! > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AdminColors.salmon,
                    borderRadius: BorderRadius.circular(999)),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
          ]),
        ),
      ),
    );
  }
}

class StatBoxMoneyDa extends StatelessWidget {
  final String label;
  final int dueDa;
  final int collectedDa;
  final VoidCallback? onTap;
  const StatBoxMoneyDa(
      {super.key,
      required this.label,
      required this.dueDa,
      required this.collectedDa,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.salmon.withOpacity(.25)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 6))
            ],
          ),
          child: Row(children: [
            const CircleAvatar(
                backgroundColor: Color(0xFFEAF6EA),
                child: Icon(Icons.payments, color: Colors.green)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.black.withOpacity(.65), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${formatDa(dueDa)} à percevoir',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('${formatDa(collectedDa)} collectés',
                      style: TextStyle(
                          color: Colors.black.withOpacity(.6), fontSize: 12)),
                ])),
          ]),
        ),
      ),
    );
  }
}

class MoneyCardDa extends StatelessWidget {
  final String title;
  final int amountDa;
  final Color color;
  final IconData icon;
  const MoneyCardDa(
      {super.key,
      required this.title,
      required this.amountDa,
      required this.color,
      required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(children: [
        CircleAvatar(backgroundColor: Colors.white, child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(formatDa(amountDa),
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ])),
      ]),
    );
  }
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const QuickAction({super.key, required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.salmon.withOpacity(.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AdminColors.salmon),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class MapPreviewCard extends StatelessWidget {
  final String? url;
  const MapPreviewCard({super.key, required this.url});
  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12)),
        child: const Text('Prévisualisation indisponible — coordonnées manquantes'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url!,
          key: ValueKey(url),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (c, child, prog) => prog == null
              ? child
              : Container(
                  color: Colors.black.withOpacity(0.04),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (c, err, st) => Container(
            color: Colors.black.withOpacity(0.04),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            child: const Text('Impossible de charger la carte'),
          ),
        ),
      ),
    );
  }
}

// ===== Feuille appel =====
Future<void> showCallSheet(BuildContext context, String? phone, {String? name}) async {
  final p = (phone ?? '').trim();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name == null || name.isEmpty ? 'Téléphone' : 'Téléphone — $name',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.call, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.isEmpty ? '—' : p,
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Copier',
                  onPressed: p.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: p));
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Numéro copié')));
                        },
                  icon: const Icon(Icons.copy),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer')),
            ),
          ],
        ),
      ),
    ),
  );
}
