// lib/features/profile/user_settings_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

const _coral = Color(0xFFF36C6C);
const _softBg = Color(0xFFFFEEF0);

// Cooldowns
const _phoneCooldownDays = 30;
const _cityCooldownDays = 10;

// Storage keys
const _kPhoneNextAllowedAt = 'phone_next_allowed_at';
const _kCityNextAllowedAt = 'city_next_allowed_at';

class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});
  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _phoneFocus = FocusNode();
  final _cityFocus = FocusNode();
  double? _lat, _lng;

  final _storage = const FlutterSecureStorage();

  File? _avatarFile;
  String? _avatarUrl;

  Map<String, dynamic> _me = {};
  List<Map<String, dynamic>> _pets = [];
  List<Map<String, dynamic>> _upcoming = [];

  bool _loading = true;
  bool _saving = false;

  // cooldowns
  DateTime? _phoneNextAllowedAt;
  DateTime? _cityNextAllowedAt;

  // état d'édition
  bool _editPhone = false;
  bool _editCity = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _city.dispose();
    _phoneFocus.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  bool _isHttp(String? s) =>
      s != null && (s.startsWith('http://') || s.startsWith('https://'));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);

      // 1) Récupère les infos du user
      _me = await api.me();
      _avatarUrl = (_me['photoUrl'] ?? _me['avatar'] ?? '') as String?;
      _phone.text = (_me['phone'] ?? '').toString();
      _city.text = (_me['city'] ?? '').toString();
      _lat = (_me['lat'] is num) ? (_me['lat'] as num).toDouble() : null;
      _lng = (_me['lng'] is num) ? (_me['lng'] as num).toDouble() : null;

      // 2) Lit les cooldowns depuis le SecureStorage (namespacés par email)
      final p = await _storage.read(key: _nsKey(_kPhoneNextAllowedAt, _me));
      final c = await _storage.read(key: _nsKey(_kCityNextAllowedAt, _me));
      _phoneNextAllowedAt = _parseIsoOrNull(p);
      _cityNextAllowedAt = _parseIsoOrNull(c);

      // 3) Seeder le cooldown si valeur déjà présente mais pas de verrou local
      if (_phone.text.trim().isNotEmpty && _phoneNextAllowedAt == null) {
        _phoneNextAllowedAt = DateTime.now().add(
          const Duration(days: _phoneCooldownDays),
        );
        await _storage.write(
          key: _nsKey(_kPhoneNextAllowedAt, _me),
          value: _phoneNextAllowedAt!.toUtc().toIso8601String(),
        );
      }
      if (_city.text.trim().isNotEmpty && _cityNextAllowedAt == null) {
        _cityNextAllowedAt = DateTime.now().add(
          const Duration(days: _cityCooldownDays),
        );
        await _storage.write(
          key: _nsKey(_kCityNextAllowedAt, _me),
          value: _cityNextAllowedAt!.toUtc().toIso8601String(),
        );
      }

      // 4) Mode édition = uniquement si champ vide
      _editPhone = _phone.text.trim().isEmpty;
      _editCity = _city.text.trim().isEmpty;

      // 5) Pets + bookings (inchangé)
      final pets = await api.myPets();
      _pets = pets.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final all = await api.myBookings();
      final now = DateTime.now();
      _upcoming =
          all.map((e) => Map<String, dynamic>.from(e as Map)).where((m) {
            final s = (m['scheduledAt'] ?? m['scheduled_at'] ?? '').toString();
            DateTime? t;
            try {
              t = DateTime.parse(s);
            } catch (_) {}
            return t != null && t.isAfter(now);
          }).toList()..sort((a, b) {
            DateTime ta = DateTime.parse(
              (a['scheduledAt'] ?? a['scheduled_at']).toString(),
            );
            DateTime tb = DateTime.parse(
              (b['scheduledAt'] ?? b['scheduled_at']).toString(),
            );
            return ta.compareTo(tb);
          });
      if (_upcoming.length > 3) _upcoming = _upcoming.take(3).toList();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Namespacing des clés SecureStorage par utilisateur (évite les collisions)
  String _nsKey(String base, Map<String, dynamic> me) {
    final email = (me['email'] ?? '').toString().toLowerCase();
    return '$base:$email';
  }

  DateTime? _parseIsoOrNull(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  bool get _phoneLockedByCooldown {
    if (_phone.text.trim().isEmpty) return false; // 1re saisie autorisée
    if (_phoneNextAllowedAt == null) return false;
    return DateTime.now().isBefore(_phoneNextAllowedAt!);
  }

  bool get _cityLockedByCooldown {
    if (_city.text.trim().isEmpty) return false;
    if (_cityNextAllowedAt == null) return false;
    return DateTime.now().isBefore(_cityNextAllowedAt!);
  }

  String _cooldownLabel(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  // -------- image utils --------
  ImageProvider? _avatarProvider() {
    if (_avatarFile != null) return FileImage(_avatarFile!);
    if (_isHttp(_avatarUrl)) return NetworkImage(_avatarUrl!);
    return null;
  }

  Future<void> _pickAvatar() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (x == null) return;
      final file = File(x.path);
      setState(() => _avatarFile = file); // preview immédiat

      final api = ref.read(apiProvider);
      final url = await api.uploadLocalFile(file, folder: 'avatar');
      await api.meUpdate(photoUrl: url);

      // Invalider le sessionProvider pour rafraîchir l'avatar partout (home_screen, etc.)
      ref.invalidate(sessionProvider);

      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo mise à jour')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload avatar échoué: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);

      // valeurs "avant"
      final prevPhone = (_me['phone'] ?? '').toString();
      final prevCity = (_me['city'] ?? '').toString();

      await api.meUpdate(
        phone: (_editPhone && !_phoneLockedByCooldown)
            ? (_phone.text.trim().isEmpty ? null : _phone.text.trim())
            : null,
        city: (_editCity && !_cityLockedByCooldown)
            ? (_city.text.trim().isEmpty ? null : _city.text.trim())
            : null,
        lat: _lat,
        lng: _lng,
      );

      // Cooldowns après changement
      if (_editPhone &&
          !_phoneLockedByCooldown &&
          _phone.text.trim().isNotEmpty &&
          _phone.text.trim() != prevPhone) {
        _phoneNextAllowedAt = DateTime.now().add(
          const Duration(days: _phoneCooldownDays),
        );
        await _storage.write(
          key: _kPhoneNextAllowedAt,
          value: _phoneNextAllowedAt!.toUtc().toIso8601String(),
        );
      }
      if (_editCity &&
          !_cityLockedByCooldown &&
          _city.text.trim().isNotEmpty &&
          _city.text.trim() != prevCity) {
        _cityNextAllowedAt = DateTime.now().add(
          const Duration(days: _cityCooldownDays),
        );
        await _storage.write(
          key: _kCityNextAllowedAt,
          value: _cityNextAllowedAt!.toUtc().toIso8601String(),
        );
      }

      // On sort du mode édition
      _editPhone = false;
      _editCity = false;

      await _load(); // re-synchronise l’état
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informations sauvegardées')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d’enregistrer: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePet(String id) async {
    try {
      final ok = await ref.read(apiProvider).deletePet(id);
      if (!mounted) return;
      setState(
        () => _pets.removeWhere((p) => (p['id'] ?? '').toString() == id),
      );
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Suppression non disponible côté serveur (404). Retiré de la liste.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
    }
  }

  Future<void> _logout() async {
    try {
      await ref.read(sessionProvider.notifier).logout();
      if (!mounted) return;
      context.go('/gate');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de se déconnecter')),
      );
    }
  }

  void _onChangePhone() {
    if (_phoneLockedByCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Numéro verrouillé jusqu’au ${_cooldownLabel(_phoneNextAllowedAt)}',
          ),
        ),
      );
      return;
    }
    setState(() => _editPhone = true);
    Future.delayed(
      const Duration(milliseconds: 80),
      () => _phoneFocus.requestFocus(),
    );
  }

  void _onChangeCity() {
    if (_cityLockedByCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ville verrouillée jusqu’au ${_cooldownLabel(_cityNextAllowedAt)}',
          ),
        ),
      );
      return;
    }
    setState(() => _editCity = true);
    Future.delayed(
      const Duration(milliseconds: 80),
      () => _cityFocus.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final first = (_me['firstName'] ?? '').toString().trim();
    final last = (_me['lastName'] ?? '').toString().trim();
    final email = (_me['email'] ?? '').toString();

    final displayName = [
      first,
      last,
    ].where((e) => e.isNotEmpty).join(' ').trim();
    final headerTitle = displayName.isNotEmpty ? displayName : email;
    final showEmailUnderTitle =
        displayName.isNotEmpty; // nom au titre + email dessous

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // header grand flou
          SliverAppBar(
            pinned: false,
            expandedHeight: 240,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: _pickAvatar,
                tooltip: 'Changer la photo',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_avatarFile != null)
                      Image.file(_avatarFile!, fit: BoxFit.cover)
                    else if (_isHttp(_avatarUrl))
                      Image.network(_avatarUrl!, fit: BoxFit.cover)
                    else
                      Container(color: _softBg),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.white.withOpacity(.18)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: _softBg,
                                backgroundImage: _avatarProvider(),
                                child: _avatarProvider() == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 36,
                                        color: Colors.black45,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              headerTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _coral,
                              ),
                            ),
                            if (showEmailUnderTitle)
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.black.withOpacity(.55),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contact
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BlockTitle('Contact'),
                  const SizedBox(height: 8),

                  // Téléphone
                  Row(
                    children: [
                      Expanded(
                        child: _editPhone
                            ? _LabeledField(
                                label: 'Téléphone',
                                controller: _phone,
                                hint: 'ex: 0555 12 34 56',
                                keyboard: TextInputType.phone,
                              )
                            : _LabeledValue(
                                label: 'Téléphone',
                                value: _phone.text.trim().isEmpty
                                    ? '—'
                                    : _phone.text.trim(),
                                helper: _phoneLockedByCooldown
                                    ? 'Modifiable à partir du ${_cooldownLabel(_phoneNextAllowedAt)}'
                                    : null,
                              ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _onChangePhone,
                        style: TextButton.styleFrom(foregroundColor: _coral),
                        child: Text(
                          _editPhone
                              ? 'En saisie'
                              : _phoneLockedByCooldown
                              ? 'Verrouillé'
                              : 'Changer',
                          style: TextStyle(
                            color: _editPhone || _phoneLockedByCooldown
                                ? Colors.grey
                                : _coral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Ville
                  Row(
                    children: [
                      Expanded(
                        child: _editCity
                            ? _LabeledField(
                                label: 'Ville',
                                controller: _city,
                                hint: 'ex: Alger',
                              )
                            : _LabeledValue(
                                label: 'Ville',
                                value: _city.text.trim().isEmpty
                                    ? '—'
                                    : _city.text.trim(),
                                helper: _cityLockedByCooldown
                                    ? 'Modifiable à partir du ${_cooldownLabel(_cityNextAllowedAt)}'
                                    : null,
                              ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _onChangeCity,
                        style: TextButton.styleFrom(foregroundColor: _coral),
                        child: Text(
                          _editCity
                              ? 'En saisie'
                              : _cityLockedByCooldown
                              ? 'Verrouillé'
                              : 'Changer',
                          style: TextStyle(
                            color: _editCity || _cityLockedByCooldown
                                ? Colors.grey
                                : _coral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lat != null && _lng != null
                              ? 'Zone: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                              : 'Zone: non définie',
                          style: TextStyle(color: Colors.black.withOpacity(.7)),
                        ),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final latCtrl = TextEditingController(
                            text: _lat?.toStringAsFixed(6) ?? '',
                          );
                          final lngCtrl = TextEditingController(
                            text: _lng?.toStringAsFixed(6) ?? '',
                          );
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Définir votre zone'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: latCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Latitude',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: lngCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Longitude',
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            setState(() {
                              _lat = double.tryParse(
                                latCtrl.text.replaceAll(',', '.'),
                              );
                              _lng = double.tryParse(
                                lngCtrl.text.replaceAll(',', '.'),
                              );
                            });
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _coral,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Définir zone'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '...' : 'Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Mes animaux
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const _BlockTitle('Mes animaux'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      // simple garde côté client
                      final me = await ref
                          .read(apiProvider)
                          .me(); // throw si non loggé
                      if (me['id'] == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez vous connecter.'),
                            ),
                          );
                        }
                        return;
                      }
                      await context.push('/onboard/pet');
                      // au retour on recharge la liste (tu le fais déjà)
                      _load();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 230,
              child: _pets.isEmpty
                  ? Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un animal de compagnie'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _coral,
                          side: const BorderSide(color: _coral),
                        ),
                        onPressed: () =>
                            context.push('/onboard/pet').then((_) => _load()),
                      ),
                    )
                  : PageView.builder(
                      controller: PageController(viewportFraction: .9),
                      itemCount: _pets.length,
                      itemBuilder: (_, i) => _PetCard(
                        data: _pets[i],
                        onDelete: () async {
                          final id = (_pets[i]['id'] ?? '').toString();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Supprimer cet animal ?'),
                              content: const Text(
                                'Cette action est irréversible.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _coral,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) _deletePet(id);
                        },
                      ),
                    ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Prochains RDV
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BlockTitle('Mes prochains rendez-vous'),
                  const SizedBox(height: 8),
                  if (_upcoming.isEmpty)
                    Text(
                      'Aucun rendez-vous à venir.',
                      style: TextStyle(color: Colors.black.withOpacity(.7)),
                    )
                  else
                    ..._upcoming.map((m) => _BookingRow(m: m)),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Déconnexion (tout en bas)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _logout,
                  style: FilledButton.styleFrom(
                    backgroundColor: _coral,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Déconnexion'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- widgets ----------------

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF6F6F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value, this.helper});
  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(.55),
            ),
          ),
        ],
      ],
    );
  }
}

/// Carte animal: moitié photo (clip coins) / moitié infos scrollables (anti-overflow)
class _PetCard extends StatelessWidget {
  const _PetCard({required this.data, required this.onDelete});
  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? '').toString();
    final breed = (data['breed'] ?? '').toString();
    final color = (data['color'] ?? '').toString();
    final photo = (data['photoUrl'] ?? data['photo'] ?? '').toString();
    final gender = (data['gender'] ?? 'UNKNOWN').toString();
    final weightKg = (data['weightKg'] ?? data['weight'] ?? '').toString();
    final city = (data['country'] ?? '').toString(); // mappé côté back
    final kind = (data['idNumber'] ?? '').toString();
    final neutered = (data['neuteredAt'] ?? '').toString();

    Widget chip(String text, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 6)],
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 210, // PageView parent = 230, donc marge OK
        child: Row(
          children: [
            // Moitié gauche : photo bien clippée
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: photo.isNotEmpty
                    ? Image.network(photo, fit: BoxFit.cover)
                    : Container(
                        color: _softBg,
                        child: Center(
                          child: Icon(
                            gender == 'FEMALE' ? Icons.female : Icons.male,
                            size: 48,
                            color: Colors.pink[300],
                          ),
                        ),
                      ),
              ),
            ),
            // Moitié droite : infos scrollables
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '—' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (breed.isNotEmpty) breed,
                        if (color.isNotEmpty) color,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black.withOpacity(.65)),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Wrap(
                          children: [
                            if (kind.isNotEmpty)
                              chip(kind, icon: Icons.pets_outlined),
                            if (city.isNotEmpty)
                              chip(city, icon: Icons.location_on_outlined),
                            if (weightKg.isNotEmpty)
                              chip(
                                '$weightKg kg',
                                icon: Icons.monitor_weight_outlined,
                              ),
                            if (gender.isNotEmpty && gender != 'UNKNOWN')
                              chip(gender == 'MALE' ? 'Mâle' : 'Femelle'),
                            if (neutered.isNotEmpty)
                              chip(
                                neutered.split('T').first,
                                icon: Icons.content_cut,
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          onPressed: onDelete,
                          style: FilledButton.styleFrom(
                            backgroundColor: _coral,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final iso = (m['scheduledAt'] ?? m['scheduled_at']).toString();
    DateTime? dt;
    try {
      dt = DateTime.parse(iso).toLocal();
    } catch (_) {}
    final when = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} • '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '—';
    final title = (m['service']?['title'] ?? 'Rendez-vous').toString();
    final addr = (m['provider']?['address'] ?? '').toString();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: _softBg,
        child: Icon(Icons.event),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([when, if (addr.isNotEmpty) addr].join('  ·  ')),
    );
  }
}
