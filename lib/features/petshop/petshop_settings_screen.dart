// lib/features/petshop/petshop_settings_screen.dart
import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';
import '../../core/locale_provider.dart';

// Colors
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _muted = Color(0xFF6B6B6B);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

class PetshopSettingsScreen extends ConsumerStatefulWidget {
  const PetshopSettingsScreen({super.key});

  @override
  ConsumerState<PetshopSettingsScreen> createState() => _PetshopSettingsScreenState();
}

class _PetshopSettingsScreenState extends ConsumerState<PetshopSettingsScreen> {
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

  // Delivery options
  bool _deliveryEnabled = false;
  bool _pickupEnabled = true;
  final _deliveryFeeDa = TextEditingController();
  final _freeDeliveryAboveDa = TextEditingController();

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
    _deliveryFeeDa.dispose();
    _freeDeliveryAboveDa.dispose();
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

    // PROVIDER (charger d'abord pour récupérer l'avatar si disponible)
    String? providerAvatarUrl;
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

      // Delivery options
      _deliveryEnabled = p['deliveryEnabled'] == true;
      _pickupEnabled = p['pickupEnabled'] != false; // default true
      final deliveryFee = p['deliveryFeeDa'];
      final freeAbove = p['freeDeliveryAboveDa'];
      _deliveryFeeDa.text = deliveryFee != null ? deliveryFee.toString() : '';
      _freeDeliveryAboveDa.text = freeAbove != null ? freeAbove.toString() : '';

      // Récupérer l'avatar du provider si disponible
      providerAvatarUrl = (p['avatarUrl'] ?? p['photoUrl'] ?? '').toString();
    } catch (_) {}

    // Charger l'avatar: priorité au provider, puis utilisateur
    _photoUrl.text = providerAvatarUrl?.isNotEmpty == true
        ? providerAvatarUrl!
        : (me['photoUrl'] ?? me['avatar'] ?? '').toString();

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

      // Save delivery options
      await _saveDeliveryOptions();

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

  Future<void> _saveDeliveryOptions() async {
    if (_providerId == null || _providerId!.isEmpty) return;

    final api = ref.read(apiProvider);
    try {
      final deliveryFee = int.tryParse(_deliveryFeeDa.text.trim());
      final freeAbove = int.tryParse(_freeDeliveryAboveDa.text.trim());

      await api.updateDeliveryOptions(
        deliveryEnabled: _deliveryEnabled,
        pickupEnabled: _pickupEnabled,
        deliveryFeeDa: deliveryFee,
        freeDeliveryAboveDa: freeAbove,
      );
    } catch (e) {
      debugPrint('Error saving delivery options: $e');
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

      // Sauvegarder au niveau utilisateur
      await api.updateMe(photoUrl: url);
      await ref.read(sessionProvider.notifier).refreshMe();

      // Sauvegarder aussi au niveau provider si on a un provider
      if (_providerId != null && _providerId!.isNotEmpty) {
        final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
        final displayName = fullName.isEmpty ? _email.text.split('@').first : fullName;

        await api.upsertMyProvider(
          displayName: displayName,
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          avatarUrl: url,
          specialties: {
            'kind': _kind,
            'visible': _visible,
            if (_mapsUrl != null && _mapsUrl!.isNotEmpty) 'mapsUrl': _mapsUrl!,
          },
        );
      }

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

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;

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
        data: _themed(context, isDark),
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            foregroundColor: textPrimary,
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
              _headerCard(isDark),
              const SizedBox(height: 12),
              _statsRow(isDark),
              const SizedBox(height: 12),
              _businessCard(isDark),
              const SizedBox(height: 12),
              _deliveryCard(isDark),
              const SizedBox(height: 12),
              _bioCard(isDark),
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

  ThemeData _themed(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _coral,
        surface: isDark ? _darkCard : Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark ? _darkCard : Colors.white,
        foregroundColor: isDark ? Colors.white : _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _coral,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: isDark ? _coral.withOpacity(0.15) : _coralSoft,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : _ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: _coral.withOpacity(0.3)),
      ),
      dividerTheme: theme.dividerTheme.copyWith(color: isDark ? _darkCardBorder : Colors.black12),
      snackBarTheme: theme.snackBarTheme.copyWith(
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        dense: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : _ink),
        subtitleTextStyle: TextStyle(color: isDark ? Colors.grey[400] : _muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _coral;
          return isDark ? Colors.grey[600] : Colors.grey[400];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _coral.withOpacity(0.5);
          return isDark ? Colors.grey[800] : Colors.grey[300];
        }),
      ),
    );
  }

  Widget _headerCard(bool isDark) {
    final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final display = fullName.isEmpty ? 'Ma Boutique' : fullName;
    final initial = display.isNotEmpty ? display[0].toUpperCase() : 'B';

    final textPrimary = isDark ? Colors.white : _ink;

    // Détermine l'image à afficher
    ImageProvider? avatarImage;
    if (_avatarFile != null) {
      avatarImage = FileImage(_avatarFile!);
    } else if (_photoUrl.text.trim().isNotEmpty) {
      avatarImage = NetworkImage(_photoUrl.text.trim());
    }

    return _card(
      isDark: isDark,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                backgroundImage: avatarImage,
                child: _uploadingAvatar
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _coral),
                      )
                    : (avatarImage == null
                        ? Text(initial,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: _coral))
                        : null),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: isDark ? _darkCardBorder : _ink,
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
                Text(display, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(_kind.toUpperCase())),
                    Chip(
                      label: Text(_approved ? 'APPROUVE' : 'EN ATTENTE',
                          style: TextStyle(
                              color: _approved ? Colors.white : (isDark ? Colors.white : _ink), fontWeight: FontWeight.w800)),
                      backgroundColor: _approved ? _coral : (isDark ? _coral.withOpacity(0.15) : _coralSoft),
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

  Widget _statsRow(bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resume des commandes', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : _ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _pill('Livrees', _countDelivered, Colors.green, isDark),
              _pill('En attente', _countPending, Colors.orange, isDark),
              _pill('Annulees', _countCancelled, Colors.red, isDark),
              _pill('Total', _countTotal, _coral, isDark),
              _pill('Produits', _productCount, Colors.blue, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _businessCard(bool isDark) {
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : _muted;

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations boutique', style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary)),
          const SizedBox(height: 10),
          _kv('Email', _email.text.trim().isEmpty ? '—' : _email.text.trim(), copyable: true, isDark: isDark),
          _kv('Telephone', _phone.text.trim().isEmpty ? '—' : _phone.text.trim(), copyable: true, isDark: isDark),
          const SizedBox(height: 6),
          _kv('Adresse', _address.text.trim().isEmpty ? '—' : _address.text.trim(), copyable: true, isDark: isDark),
          _kv('Lien Google Maps', (_mapsUrl ?? '').isEmpty ? '—' : _mapsUrl!, copyable: true, isDark: isDark),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Visibilite publique', style: TextStyle(color: textPrimary)),
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
                  foregroundColor: _coral,
                  side: const BorderSide(color: _coral),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _deliveryCard(bool isDark) {
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : _muted;

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_shipping, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Options de livraison', style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary)),
                    const SizedBox(height: 2),
                    Text('Configurez comment les clients recoivent leurs commandes',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pickup option
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? (_pickupEnabled ? Colors.purple.withOpacity(0.15) : _darkCardBorder)
                  : (_pickupEnabled ? Colors.purple.shade50 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pickupEnabled ? Colors.purple.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.store_rounded, color: _pickupEnabled ? Colors.purple : Colors.grey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Retrait en boutique',
                        style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                      Text('Les clients viennent chercher leur commande',
                        style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: _pickupEnabled,
                  onChanged: (v) => setState(() => _pickupEnabled = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Delivery option
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? (_deliveryEnabled ? Colors.blue.withOpacity(0.15) : _darkCardBorder)
                  : (_deliveryEnabled ? Colors.blue.shade50 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _deliveryEnabled ? Colors.blue.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: _deliveryEnabled ? Colors.blue : Colors.grey, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Livraison a domicile',
                            style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                          Text('Vous livrez les commandes aux clients',
                            style: TextStyle(fontSize: 12, color: textSecondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _deliveryEnabled,
                      onChanged: (v) => setState(() => _deliveryEnabled = v),
                    ),
                  ],
                ),
                if (_deliveryEnabled) ...[
                  const SizedBox(height: 12),
                  Divider(color: isDark ? _darkCardBorder : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  // Delivery fee
                  TextField(
                    controller: _deliveryFeeDa,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Frais de livraison (DA)',
                      labelStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(Icons.payments_outlined, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: isDark ? _darkCardBorder : Colors.white,
                      hintText: 'Ex: 300',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  // Free delivery threshold
                  TextField(
                    controller: _freeDeliveryAboveDa,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Livraison gratuite a partir de (DA)',
                      labelStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(Icons.card_giftcard, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                      filled: true,
                      fillColor: isDark ? _darkCardBorder : Colors.white,
                      hintText: 'Ex: 5000 (laisser vide pour desactiver)',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Laissez le seuil vide pour ne pas offrir de livraison gratuite',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Warning if neither is enabled
          if (!_pickupEnabled && !_deliveryEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Activez au moins une option pour que les clients puissent commander',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bioCard(bool isDark) {
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : _muted;

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 5,
            maxLength: _bioMax,
            style: TextStyle(color: textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: const BorderSide(color: _coral),
              ),
              filled: true,
              fillColor: isDark ? _darkCardBorder : Colors.white,
              isDense: true,
              errorText: _errBio,
              helperText: 'Visible par les clients',
              helperStyle: TextStyle(color: textSecondary),
              counterStyle: TextStyle(color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, int value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
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
              color: isDark ? _darkCard : Colors.white,
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

  Widget _kv(String k, String v, {bool copyable = false, required bool isDark}) {
    final textSecondary = isDark ? Colors.grey[400] : _muted;
    final textPrimary = isDark ? Colors.white : _ink;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: TextStyle(color: textSecondary))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: TextStyle(color: textPrimary))),
          if (copyable && v.trim().isNotEmpty && v != '—')
            IconButton(
              icon: Icon(Icons.copy, size: 18, color: textSecondary),
              onPressed: () => _copy(k, v),
              tooltip: 'Copier',
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : _coral.withOpacity(0.2)),
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}
