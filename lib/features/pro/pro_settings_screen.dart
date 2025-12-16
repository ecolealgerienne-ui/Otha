// lib/features/pro/pro_settings_screen.dart
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

class ProSettingsScreen extends ConsumerStatefulWidget {
  const ProSettingsScreen({super.key});

  @override
  ConsumerState<ProSettingsScreen> createState() => _ProSettingsScreenState();
}

class _ProSettingsScreenState extends ConsumerState<ProSettingsScreen> {
  // Palette saumon
  static const Color _salmon = Color(0xFFF36C6C); // primaire
  static const Color _ink = Color(0xFF222222);
  static const Color _muted = Color(0xFF6B6B6B);

  // user
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String? _photoUrl;
  File? _avatarFile;
  final _picker = ImagePicker();
  bool _uploadingPhoto = false;

  // provider
  final _address = TextEditingController();
  final _bio = TextEditingController();
  static const int _bioMax = 280;
  String? _errBio;

  // état provider
  String? _providerId;
  bool _approved = false;
  bool _visible = true; // (ré)introduit
  String _kind = 'vet';
  String? _mapsUrl;

  // services
  List<Map<String, dynamic>> _services = const [];

  // stats RDV (emoji roses)
  int _countConfirmed = 0;
  int _countPending = 0;
  int _countCancelled = 0;
  int _countTotal = 0;

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
    _lastName.text  = (me['lastName']  ?? '').toString();
    _email.text     = (me['email']     ?? '').toString();
    _phone.text     = (me['phone']     ?? '').toString();
    _photoUrl       = (me['photoUrl']  ?? me['avatar'] ?? '').toString();
    if (_photoUrl?.isEmpty == true) _photoUrl = null;

    // PROVIDER
    try {
      final raw = await api.myProvider();
      final p = _unwrap(raw) ?? {};
      _providerId = (p['id'] ?? '').toString().isEmpty ? null : (p['id'] ?? '').toString();
      _address.text = (p['address'] ?? '').toString();
      _approved = (p['isApproved'] == true);

      final specs = (p['specialties'] is Map) ? Map<String, dynamic>.from(p['specialties']) : <String, dynamic>{};
      _kind     = (specs['kind'] ?? _kind).toString();
      _visible  = (p['visible'] == true) || (specs['visible'] == true);
      _mapsUrl  = (specs['mapsUrl'] ?? p['mapsUrl'])?.toString();
      _bio.text = (p['bio'] ?? specs['bio'] ?? '').toString();
    } catch (_) {}

    // SERVICES
    try {
      final rows = await api.myServices();
      _services = rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _services = const [];
    }

    // STATS RDV (agrégation via providerAgenda)
    try {
      final now = DateTime.now().toUtc();
      final from = DateTime.utc(now.year - 1, now.month, 1);
      final rows = await api.providerAgenda(
        fromIso: from.toIso8601String(),
        toIso: now.toIso8601String(),
      );

      int cConfirmed = 0, cPending = 0, cCancelled = 0, cCompleted = 0;
      for (final e in rows) {
        final st = (e['status'] ?? '').toString().toUpperCase();
        if (st == 'CONFIRMED') cConfirmed++;
        else if (st == 'PENDING') cPending++;
        else if (st == 'CANCELLED' || st == 'CANCELED') cCancelled++;
        else if (st == 'COMPLETED') cCompleted++;
      }
      _countConfirmed = cConfirmed;
      _countPending   = cPending;
      _countCancelled = cCancelled;
      _countTotal     = cConfirmed + cPending + cCancelled + cCompleted;
    } catch (_) {
      // laisse 0 par défaut
    }

    if (mounted) setState(() {});
  }

  bool _validate() {
    final b = _bio.text.trim();
    _errBio = (b.length > _bioMax) ? 'Max $_bioMax caractères' : null;
    setState(() {});
    return _errBio == null;
  }

  /// Upload photo de profil via ImagePicker
  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 90,
      );
      if (image == null) return;

      final file = File(image.path);
      setState(() {
        _avatarFile = file;
        _uploadingPhoto = true;
      });

      final api = ref.read(apiProvider);
      final url = await api.uploadLocalFile(file, folder: 'avatar');

      // Mettre à jour le user ET le provider avec la même photo
      await api.updateMe(photoUrl: url);

      // Aussi mettre à jour le provider avec avatarUrl
      final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      final displayName = fullName.isEmpty ? _email.text.split('@').first : fullName;
      await api.upsertMyProvider(
        displayName: displayName,
        avatarUrl: url,
      );

      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo mise à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      final displayName = fullName.isEmpty ? _email.text.split('@').first : fullName;

      // Inclut 'visible' pour forcer la persistance côté back si besoin
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

// ...
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
        // Fallback: on upsert avec specialties.visible (merge backend-first)
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
        .showSnackBar(SnackBar(content: Text(v ? 'Profil visible' : 'Profil masqué')));
  } catch (err) {
    if (!mounted) return;
    setState(() => _visible = old);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $err')));
  }
}


  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) return;
    context.go('/gate'); // reset propre de la stack
  }

  void _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copié')));
  }

  @override
  Widget build(BuildContext context) {
    // Fix global “back”: si pas de pile → /pro/home
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          context.go('/pro/home');
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
                  context.go('/pro/home');
                }
              },
            ),
            title: const Text('Mon profil professionnel'),
            actions: [
              IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _headerCard(),
              const SizedBox(height: 12),
              _statsRow(), // 💗 résumé RDV
              const SizedBox(height: 12),
              _businessCard(), // contient de nouveau le switch visibilité
              const SizedBox(height: 12),
              _servicesCard(),
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

  // ===================== UI Blocks =====================

  ThemeData _themed(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _salmon,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _ink, fontWeight: FontWeight.w800, fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _salmon,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: const Color(0xFFFFEEF0),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: Color(0xFFFFD6DA)),
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
    final display = fullName.isEmpty ? 'Docteur' : fullName;
    final initial = display.isNotEmpty ? display[0].toUpperCase() : 'D';

    // Détermine l'image à afficher
    ImageProvider? avatarImage;
    if (_avatarFile != null) {
      avatarImage = FileImage(_avatarFile!);
    } else if (_photoUrl != null && _photoUrl!.startsWith('http')) {
      avatarImage = NetworkImage(_photoUrl!);
    }

    return _card(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFFFFEEF0),
                backgroundImage: avatarImage,
                child: _uploadingPhoto
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _salmon),
                      )
                    : avatarImage == null
                        ? Text(initial, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _salmon))
                        : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: _salmon,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                    borderRadius: BorderRadius.circular(16),
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
                      label: Text(_approved ? 'APPROUVÉ' : 'EN ATTENTE',
                          style: TextStyle(color: _approved ? Colors.white : _ink, fontWeight: FontWeight.w800)),
                      backgroundColor: _approved ? _salmon : const Color(0xFFFFEEF0),
                    ),
                    if (_providerId != null && _providerId!.isNotEmpty)
                      ActionChip(
                        label: Text('ID: ${_providerId!.substring(0, (_providerId!.length > 8) ? 8 : _providerId!.length)}…'),
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
    // Résumé RDV en emoji roses
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Résumé des rendez-vous', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _pill(' Confirmés', _countConfirmed),
              _pill('⏳ Pending', _countPending),
              _pill('❌ Annulés', _countCancelled),
              _pill('📅 Total', _countTotal),
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
          const Text('Informations professionnelles', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),

          _kv('Email', _email.text.trim().isEmpty ? '—' : _email.text.trim(), copyable: true),
          _kv('Téléphone', _phone.text.trim().isEmpty ? '—' : _phone.text.trim(), copyable: true),
          const SizedBox(height: 6),
          _kv('Adresse', _address.text.trim().isEmpty ? '—' : _address.text.trim(), copyable: true),
          _kv('Lien Google Maps', (_mapsUrl ?? '').isEmpty ? '—' : _mapsUrl!, copyable: true),

          const SizedBox(height: 10),
          Row(
            children: [
              // Réintroduction du switch de visibilité
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visibilité publique'),
                  value: _visible,
                  onChanged: _toggleVisibility,
                ),
              ),
              const SizedBox(width: 8),
              if (_providerId != null && _providerId!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => context.push('/explore/vets/${_providerId}'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir le profil'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _servicesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mes services', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_services.isEmpty)
            const Text('Aucun service défini.')
          else
            Column(
              children: [
                for (final s in _services.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 18, color: _ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (s['title'] ?? s['name'] ?? 'Service').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fmtPrice(s['priceDa'] ?? s['price'] ?? s['amount']),
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                if (_services.length > 5) ...[
                  const SizedBox(height: 8),
                  const Text('+ encore…', style: TextStyle(color: _muted)),
                ],
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/pro/services'),
                  icon: const Icon(Icons.tune),
                  label: const Text('Gérer mes services'),
                ),
              ),
            ],
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
          const Text('Présentation', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 5,
            maxLength: _bioMax,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              isDense: true,
              errorText: _errBio,
              helperText: 'Visible côté clients',
            ),
          ),
        ],
      ),
    );
  }

  // ===================== Small helpers =====================

  Widget _pill(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF0),
        border: Border.all(color: const Color(0xFFFFD6DA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFFFD6DA)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$value', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
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
          if (copyable && v.trim().isNotEmpty)
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
        border: Border.all(color: const Color(0xFFFFD6DA)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }

  String _fmtPrice(dynamic v) {
    if (v == null) return '—';
    final n = (v is num) ? v.toInt() : int.tryParse(v.toString());
    return n == null ? '—' : '$n DA';
  }
}
