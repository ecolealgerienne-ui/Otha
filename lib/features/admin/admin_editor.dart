import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'admin_shared.dart';

enum ProviderEditorMode { pending, rejected, approved }

Future<void> showProviderEditor(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> p, {
  required ProviderEditorMode mode,
}) async {
  final provId = (p['id'] ?? '').toString();
  final name0 = (p['displayName'] ?? '').toString();
  final addr0 = (p['address'] ?? '').toString();
  final approved = (p['isApproved'] == true);
  final rejectedAt = (p['rejectedAt'] ?? '').toString();
  final sp0 = Map<String, dynamic>.from((p['specialties'] ?? const {}) as Map);
  final user = Map<String, dynamic>.from((p['user'] ?? const {}) as Map);
  final email = (user['email'] ?? '').toString();
  final phone = (user['phone'] ?? '').toString();
  final firstName = (user['firstName'] ?? '').toString();
  final lastName = (user['lastName'] ?? '').toString();

  final lat0 = (p['lat'] as num?)?.toDouble();
  final lng0 = (p['lng'] as num?)?.toDouble();
  final maps0 = (sp0['mapsUrl'] ?? '').toString();

  final avnCardFront = (p['avnCardFront'] ?? '').toString();
  final avnCardBack = (p['avnCardBack'] ?? '').toString();

  final nameCtrl = TextEditingController(text: name0);
  final addrCtrl = TextEditingController(text: addr0);
  final mapsCtrl = TextEditingController(text: maps0);
  final latCtrl = TextEditingController(text: lat0 == null ? '' : lat0.toStringAsFixed(6));
  final lngCtrl = TextEditingController(text: lng0 == null ? '' : lng0.toStringAsFixed(6));

  String? errMaps, errLat, errLng, errName;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (ctx, scroll) => StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> save() async {
              final name = nameCtrl.text.trim();
              final maps = mapsCtrl.text.trim();
              final mapsOk = maps.isEmpty || RegExp(r'^(https?://)', caseSensitive: false).hasMatch(maps);
              final lat = double.tryParse(latCtrl.text.replaceAll(',', '.'));
              final lng = double.tryParse(lngCtrl.text.replaceAll(',', '.'));
              setLocal(() {
                errName = name.isEmpty ? 'Nom requis' : null;
                errMaps = mapsOk ? null : 'URL invalide';
                errLat = (lat == null) ? 'Latitude invalide' : null;
                errLng = (lng == null) ? 'Longitude invalide' : null;
              });
              if (errName != null || !mapsOk || lat == null || lng == null) return;

              try {
                await ref.read(apiProvider).adminUpdateProvider(
                      provId,
                      displayName: name,
                      address: addrCtrl.text.trim(),
                      lat: lat,
                      lng: lng,
                      mapsUrl: maps,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modifications enregistrées')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            }

            Widget label(String s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(s, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13)),
            );

            return SafeArea(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 24, backgroundColor: AdminColors.salmonSoft,
                      child: Text((name0.isEmpty ? email : name0).substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AdminColors.ink)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name0.isEmpty ? '(Sans nom)' : name0,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    IconButton(tooltip: 'Appeler', icon: const Icon(Icons.call),
                      onPressed: () => showCallSheet(context, phone, name: name0.isEmpty ? email : name0)),
                  ]),
                  const SizedBox(height: 14), const Divider(),

                  // Informations utilisateur
                  if (firstName.isNotEmpty || lastName.isNotEmpty) ...[
                    label('Prénom & Nom'),
                    Text('${firstName.isEmpty ? '-' : firstName} ${lastName.isEmpty ? '-' : lastName}',
                      style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                  ],
                  label('Email'),
                  Text(email.isEmpty ? '-' : email, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 8),
                  label('Téléphone'),
                  Text(phone.isEmpty ? '-' : phone, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 14), const Divider(),

                  label('Nom à afficher'),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(isDense: true, errorText: errName,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 10),
                  label('Adresse postale'),
                  TextField(
                    controller: addrCtrl,
                    decoration: InputDecoration(isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),

                  const SizedBox(height: 14), const Divider(),

                  label('Lien Google Maps (PC, court ou long)'),
                  TextField(
                    controller: mapsCtrl, keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      isDense: true, errorText: errMaps,
                      hintText: 'https://www.google.com/maps/place/... ou https://maps.app.goo.gl/…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Nettoyer', icon: const Icon(Icons.link),
                          onPressed: () => setLocal(() => mapsCtrl.text = sanitizeMaps(mapsCtrl.text))),
                        IconButton(tooltip: 'Extraire coords', icon: const Icon(Icons.my_location), onPressed: () {
                          final e = extractLatLngFromUrl(mapsCtrl.text);
                          if (e.lat != null && e.lng != null) {
                            setLocal(() {
                              latCtrl.text = e.lat!.toStringAsFixed(6);
                              lngCtrl.text = e.lng!.toStringAsFixed(6);
                              errLat = null; errLng = null;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Aucune coordonnée trouvée dans l’URL')));
                          }
                        }),
                        IconButton(tooltip: 'Copier', icon: const Icon(Icons.copy), onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: mapsCtrl.text.trim()));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
                          }
                        }),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      label('Latitude'),
                      TextField(
                        controller: latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
                        decoration: InputDecoration(isDense: true, errorText: errLat,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        onChanged: (_) => setLocal(() {}),
                      ),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      label('Longitude'),
                      TextField(
                        controller: lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
                        decoration: InputDecoration(isDense: true, errorText: errLng,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        onChanged: (_) => setLocal(() {}),
                      ),
                    ])),
                  ]),

                  const SizedBox(height: 12),

                  // Cartes AVN (recto-verso)
                  if (avnCardFront.isNotEmpty || avnCardBack.isNotEmpty) ...[
                    const Divider(),
                    label('Documents AVN (Attestation Vétérinaire Nationale)'),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (avnCardFront.isNotEmpty)
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Recto', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showZoomableImage(context, avnCardFront, 'Carte AVN - Recto'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Image.network(avnCardFront, height: 180, width: double.infinity, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 180, color: Colors.grey[200],
                                      child: const Center(child: Icon(Icons.error_outline, color: Colors.red)),
                                    ),
                                  ),
                                  // Icône zoom pour indiquer que c'est cliquable
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ])),
                      if (avnCardFront.isNotEmpty && avnCardBack.isNotEmpty) const SizedBox(width: 12),
                      if (avnCardBack.isNotEmpty)
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Verso', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showZoomableImage(context, avnCardBack, 'Carte AVN - Verso'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Image.network(avnCardBack, height: 180, width: double.infinity, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 180, color: Colors.grey[200],
                                      child: const Center(child: Icon(Icons.error_outline, color: Colors.red)),
                                    ),
                                  ),
                                  // Icône zoom pour indiquer que c'est cliquable
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ])),
                    ]),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save, color: AdminColors.salmon),
                        label: const Text('Enregistrer', style: TextStyle(color: AdminColors.salmon)),
                        onPressed: () async { await save(); setLocal(() {}); },
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AdminColors.salmon)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!approved && rejectedAt.isEmpty && mode == ProviderEditorMode.pending)
                      Expanded(child: FilledButton.icon(
                        icon: const Icon(Icons.verified), label: const Text('Approuver'),
                        onPressed: () async {
                          await save();
                          if (context.mounted) Navigator.pop(context);
                          await ref.read(apiProvider).approveProvider(provId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approuvé ✅')));
                          }
                        },
                      ))
                    else if (mode == ProviderEditorMode.rejected && !approved)
                      Expanded(child: FilledButton.icon(
                        icon: const Icon(Icons.refresh), label: const Text('Ré-approuver'),
                        onPressed: () async {
                          if (context.mounted) Navigator.pop(context);
                          await ref.read(apiProvider).approveProvider(provId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ré-approuvé ✅')));
                          }
                        },
                      ))
                    else
                      Expanded(child: OutlinedButton.icon(
                        icon: const Icon(Icons.block, color: Colors.red),
                        label: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          if (context.mounted) Navigator.pop(context);
                          await ref.read(apiProvider).rejectProvider(provId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejeté ❌')));
                          }
                        },
                      )),
                  ]),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

/// Affiche une image en plein écran avec zoom
void _showZoomableImage(BuildContext context, String imageUrl, String title) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Image zoomable avec InteractiveViewer
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.error_outline, color: Colors.red, size: 48),
                ),
              ),
            ),
          ),
          // Bouton fermer en haut à droite
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
          // Titre en haut à gauche
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
