// lib/features/map/provider_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ProviderMapScreen extends StatelessWidget {
  final String displayName;
  final String address;
  final String mapsUrl;

  /// Coords fournies par le backend (recommandé)
  final double? lat;
  final double? lng;

  const ProviderMapScreen({
    super.key,
    required this.displayName,
    required this.address,
    required this.mapsUrl,
    this.lat,
    this.lng,
  });

  static const _fallback = LatLng(36.75, 3.06); // Alger (au cas où)

  LatLng _resolveCenter() {
    // On n’essaie plus d’extraire depuis l’URL : on fait confiance au backend.
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      return LatLng(lat!, lng!);
    }
    return _fallback;
  }

  @override
  Widget build(BuildContext context) {
    final center = _resolveCenter();
    final controller = MapController();

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: FlutterMap(
        mapController: controller,
        options: MapOptions(initialCenter: center, initialZoom: 14),
        children: [
          // ✅ CartoDB Light - Style minimaliste
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.vethome.app',
          ),
          MarkerLayer(markers: [
            Marker(
              width: 44,
              height: 44,
              point: center,
              child: const Icon(Icons.location_pin, size: 44, color: Colors.redAccent),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 12 + MediaQuery.of(context).padding.bottom,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (address.isNotEmpty) Text(address, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  // Ouvre mapsUrl si présent, sinon construit une query lat,lng
                  final uri = mapsUrl.isNotEmpty
                      ? Uri.parse(mapsUrl)
                      : Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${center.latitude},${center.longitude}',
                        );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ouvrir dans Google Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
