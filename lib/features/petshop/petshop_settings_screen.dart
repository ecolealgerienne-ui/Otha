// lib/features/petshop/petshop_settings_screen.dart
import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

class PetshopSettingsScreen extends ConsumerStatefulWidget {
  const PetshopSettingsScreen({super.key});

  @override
  ConsumerState<PetshopSettingsScreen> createState() => _PetshopSettingsScreenState();
}

class _PetshopSettingsScreenState extends ConsumerState<PetshopSettingsScreen> {
  // Palette salmon (petshop)
  static const Color _primary = Color(0xFFF36C6C);
  static const Color _primarySoft = Color(0xFFFFEEF0);
  static const Color _ink = Color(0xFF222222);
  static const Color _muted = Color(0xFF6B6B6B);

  // user
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _photoUrl = TextEditingController();

  // provider
  final _address = TextEditingController();
  final _bio = TextEditingController();
  static const int _bioMax = 280;
  String? _errBio;

  // etat provider
  String? _providerId;
  bool _approved = false;
  bool _visible = true;
  String _kind = 'petshop';
  String? _mapsUrl;

  // stats commandes
  int _countDelivered = 0;
  int _countPending = 0;
  int _countCancelled = 0;
  int _countTotal = 0;
  int _productCount = 0;

  // Avatar upload
  File? _avatarFile;
  final _picker = ImagePicker();
  bool _uploadingAvatar = false;

  bool _loading = false;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _photoUrl.dispose();
    _address.dispose();
    _bio.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _unwrap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map && raw.containsKey('data')) {
      final d = raw['data'];
      if (d == null || (d is Map && d.isEmpty)) return null;
      return (d is Map) ? Map<String, dynamic>.from(d) : null;
    }
    if (raw is Map && raw.isEmpty) return null;
    return (raw is Map) ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> _loadAll() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    final api = ref.read(apiProvider);
    await api.ensureAuth();

    // USER (depuis le store)
    final me = ref.read(sessionProvider).user ?? {};
    _firstName.text = (me['firstName'] ?? '').toString();
    _lastName.text = (me['lastName'] ?? '').toString();
    _email.text = (me['email'] ?? '').toString();
    _phone.text = (me['phone'] ?? '').toString();
    _photoUrl.text = (me['photoUrl'] ?? me['avatar'] ?? '').toString();

    // PROVIDER
    try {
      final raw = await api.myProvider();
      final p = _unwrap(raw) ?? {};
      _providerId = (p['id'] ?? '').toString().isEmpty ? null : (p['id'] ?? '').toString();
      _address.text = (p['address'] ?? '').toString();
      _approved = (p['isApproved'] == true);

      final specs = (p['specialties'] is Map)
          ? Map<String, dynamic>.from(p['specialties'])
          : <String, dynamic>{};
      _kind = (specs['kind'] ?? _kind).toString();
      _visible = (p['visible'] == true) || (specs['visible'] == true);
      _mapsUrl = (specs['mapsUrl'] ?? p['mapsUrl'])?.toString();
      _bio.text = (p['bio'] ?? specs['bio'] ?? '').toString();
    } catch (_) {}

    // PRODUCTS
    try {
      final products = await api.myProducts();
      _productCount = products.length;
    } catch (_) {
      _productCount = 0;
    }

    // STATS COMMANDES
    try {
      final orders = await api.myPetshopOrders();

      int cDelivered = 0, cPending = 0, cCancelled = 0;
      for (final e in orders) {
        final st = (e['status'] ?? '').toString().toUpperCase();
        if (st == 'DELIVERED' || st == 'COMPLETED') {
          cDelivered++;
        } else if (st == 'PENDING') {
          cPending++;
        } else if (st == 'CANCELLED' || st == 'CANCELED') {
          cCancelled++;
        }
      }
      _countDelivered = cDelivered;
      _countPending = cPending;
      _countCancelled = cCancelled;
      _countTotal = orders.length;
    } catch (_) {
      // laisse 0 par defaut
    }

    if (mounted) setState(() {});
  }

  bool _validate() {
    final b = _bio.text.trim();
    _errBio = (b.length > _bioMax) ? 'Max $_bioMax caracteres' : null;
    setState(() {});
    return _errBio == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      await api.updateMe(
        photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim(),
      );

      final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      final displayName = fullName.isEmpty ? _email.text.split('@').first : fullName;

      await api.upsertMyProvider(
        displayName: displayName,
        address: _address.text.trim(),
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        specialties: {
          'kind': _kind,
          'visible': _visible,
          if (_mapsUrl != null && _mapsUrl!.trim().isNotEmpty) 'mapsUrl': _mapsUrl!.trim(),
        },
      );

      await ref.read(sessionProvider.notifier).refreshMe();
      await _refreshAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis a jour')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleVisibility(bool v) async {
    final old = _visible;
    setState(() => _visible = v);

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      try {
        await api.setMyVisibility(v);
      } on DioException catch (e) {
        final code = e.response?.statusCode ?? 0;
        if (code == 403) {
          final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
          final displayName = fullName.isEmpty ? _email.text.split('@').first : fullName;

          await api.upsertMyProvider(
            displayName: displayName,
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            specialties: {
              'kind': _kind,
              'visible': v,
              if ((_mapsUrl ?? '').trim().isNotEmpty) 'mapsUrl': _mapsUrl!.trim(),
            },
          );
        } else {
          rethrow;
        }
      }

      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(v ? 'Boutique visible' : 'Boutique masquee')));
    } catch (err) {
      if (!mounted) return;
      setState(() => _visible = old);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $err')));
    }
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) return;
    context.go('/gate');
  }

  void _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copie')));
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    setState(() {
      _avatarFile = File(image.path);
      _uploadingAvatar = true;
    });

    try {
      final api = ref.read(apiProvider);
      await api.ensureAuth();
      final url = await api.uploadLocalFile(_avatarFile!, folder: 'avatar');
      _photoUrl.text = url;
      _avatarFile = null;

      // Sauvegarder immédiatement
      await api.updateMe(photoUrl: url);
      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo mise à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _openPreviewPage() {
    if (_providerId == null || _providerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil non encore créé')),
      );
      return;
    }
    context.push('/petshop/store/$_providerId?preview=true');
  }

  void _showPreviewDialog() {
    final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final display = fullName.isEmpty ? 'Ma Boutique' : fullName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _primarySoft,
              backgroundImage:
                  _photoUrl.text.trim().isEmpty ? null : NetworkImage(_photoUrl.text.trim()),
              child: _photoUrl.text.trim().isEmpty
                  ? Text(display[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _primary))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(display, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_address.text.trim().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: _muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_address.text.trim(), style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_bio.text.trim().isNotEmpty) ...[
              Text(
                _bio.text.trim(),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_visible ? Icons.visibility : Icons.visibility_off,
                    size: 16, color: _visible ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Text(
                  _visible ? 'Visible par les clients' : 'Non visible',
                  style: TextStyle(
                    color: _visible ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Produits: $_productCount',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          context.go('/petshop/home');
        }
      },
      child: Theme(
        data: _themed(context),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  context.go('/petshop/home');
                }
              },
            ),
            title: const Text('Parametres boutique'),
            actions: [
              IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _headerCard(),
              const SizedBox(height: 12),
              _statsRow(),
              const SizedBox(height: 12),
              _businessCard(),
              const SizedBox(height: 12),
              _bioCard(),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? '...' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _themed(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _primary,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: _primarySoft,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: _primary.withOpacity(0.3)),
      ),
      dividerTheme: theme.dividerTheme.copyWith(color: Colors.black12),
      snackBarTheme: theme.snackBarTheme.copyWith(
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        dense: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        subtitleTextStyle: TextStyle(color: _muted),
      ),
    );
  }

  Widget _headerCard() {
    final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final display = fullName.isEmpty ? 'Ma Boutique' : fullName;
    final initial = display.isNotEmpty ? display[0].toUpperCase() : 'B';

    // Détermine l'image à afficher
    ImageProvider? avatarImage;
    if (_avatarFile != null) {
      avatarImage = FileImage(_avatarFile!);
    } else if (_photoUrl.text.trim().isNotEmpty) {
      avatarImage = NetworkImage(_photoUrl.text.trim());
    }

    return _card(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: _primarySoft,
                backgroundImage: avatarImage,
                child: _uploadingAvatar
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                      )
                    : (avatarImage == null
                        ? Text(initial,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: _primary))
                        : null),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: _ink,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(_kind.toUpperCase())),
                    Chip(
                      label: Text(_approved ? 'APPROUVE' : 'EN ATTENTE',
                          style: TextStyle(
                              color: _approved ? Colors.white : _ink, fontWeight: FontWeight.w800)),
                      backgroundColor: _approved ? _primary : _primarySoft,
                    ),
                    if (_providerId != null && _providerId!.isNotEmpty)
                      ActionChip(
                        label: Text(
                            'ID: ${_providerId!.substring(0, (_providerId!.length > 8) ? 8 : _providerId!.length)}...'),
                        onPressed: () => _copy('ID fournisseur', _providerId!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resume des commandes', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _pill('Livrees', _countDelivered, Colors.green),
              _pill('En attente', _countPending, Colors.orange),
              _pill('Annulees', _countCancelled, Colors.red),
              _pill('Total', _countTotal, _primary),
              _pill('Produits', _productCount, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _businessCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations boutique', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _kv('Email', _email.text.trim().isEmpty ? '—' : _email.text.trim(), copyable: true),
          _kv('Telephone', _phone.text.trim().isEmpty ? '—' : _phone.text.trim(), copyable: true),
          const SizedBox(height: 6),
          _kv('Adresse', _address.text.trim().isEmpty ? '—' : _address.text.trim(), copyable: true),
          _kv('Lien Google Maps', (_mapsUrl ?? '').isEmpty ? '—' : _mapsUrl!, copyable: true),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visibilite publique'),
                  value: _visible,
                  onChanged: _toggleVisibility,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_providerId != null && _providerId!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openPreviewPage,
                icon: const Icon(Icons.storefront),
                label: const Text('Voir ma boutique (aperçu client)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bioCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 5,
            maxLength: _bioMax,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border:
                  const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              isDense: true,
              errorText: _errBio,
              helperText: 'Visible par les clients',
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$value',
                style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: _muted))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
          if (copyable && v.trim().isNotEmpty && v != '—')
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copy(k, v),
              tooltip: 'Copier',
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.2)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}
