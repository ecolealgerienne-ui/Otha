// lib/features/daycare/daycare_settings_screen.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';
import '../../core/locale_provider.dart';

class DaycareSettingsScreen extends ConsumerStatefulWidget {
  const DaycareSettingsScreen({super.key});

  @override
  ConsumerState<DaycareSettingsScreen> createState() => _DaycareSettingsScreenState();
}

class _DaycareSettingsScreenState extends ConsumerState<DaycareSettingsScreen> {
  // Palette cyan (daycare)
  static const Color _primary = Color(0xFF00ACC1);
  static const Color _primarySoft = Color(0xFFE0F7FA);
  static const Color _primarySoftDark = Color(0xFF1A3A3D);
  static const Color _ink = Color(0xFF222222);
  static const Color _inkDark = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _mutedDark = Color(0xFFB0B0B0);
  static const Color _bgLight = Color(0xFFF7F8FA);
  static const Color _bgDark = Color(0xFF121212);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _cardDark = Color(0xFF1E1E1E);

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
  String _kind = 'daycare';
  String? _mapsUrl;

  // stats reservations
  int _countDelivered = 0;
  int _countPending = 0;
  int _countCancelled = 0;
  int _countTotal = 0;
  int _bookingCount = 0;

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

    // STATS RESERVATIONS
    try {
      final bookings = await api.myDaycareProviderBookings()
          .then((list) => list.map((b) => Map<String, dynamic>.from(b as Map)).toList());

      _bookingCount = bookings.length;

      int cDelivered = 0, cPending = 0, cCancelled = 0;
      for (final e in bookings) {
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
      _countTotal = bookings.length;
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
          .showSnackBar(SnackBar(content: Text(v ? 'Garderie visible' : 'Garderie masquee')));
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

  void _showPreviewDialog(bool isDark, AppLocalizations l10n) {
    final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final display = fullName.isEmpty ? l10n.myDaycare : fullName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _cardDark : null,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? _primarySoftDark : _primarySoft,
              backgroundImage:
                  _photoUrl.text.trim().isEmpty ? null : NetworkImage(_photoUrl.text.trim()),
              child: _photoUrl.text.trim().isEmpty
                  ? Text(display[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _primary))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(display, style: TextStyle(fontSize: 16, color: isDark ? _inkDark : _ink)),
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
                  Icon(Icons.location_on, size: 16, color: isDark ? _mutedDark : _muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_address.text.trim(), style: TextStyle(fontSize: 13, color: isDark ? _inkDark : _ink)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_bio.text.trim().isNotEmpty) ...[
              Text(
                _bio.text.trim(),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            Divider(color: isDark ? Colors.white12 : null),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_visible ? Icons.visibility : Icons.visibility_off,
                    size: 16, color: _visible ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Text(
                  _visible ? l10n.visibleToClients : l10n.notVisible,
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
              '${l10n.allBookings}: $_bookingCount',
              style: TextStyle(fontSize: 12, color: isDark ? _mutedDark : _muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          context.go('/daycare/home');
        }
      },
      child: Theme(
        data: _themed(context, isDark),
        child: Scaffold(
          backgroundColor: isDark ? _bgDark : _bgLight,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  context.go('/daycare/home');
                }
              },
            ),
            title: Text(l10n.daycareSettings),
            actions: [
              IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _headerCard(isDark, l10n),
              const SizedBox(height: 12),
              _statsRow(isDark, l10n),
              const SizedBox(height: 12),
              _businessCard(isDark, l10n),
              const SizedBox(height: 12),
              _bioCard(isDark, l10n),
              const SizedBox(height: 12),
              _languageCard(isDark, l10n),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? '...' : l10n.save),
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
        primary: _primary,
        surface: isDark ? _cardDark : _cardLight,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark ? _bgDark : _cardLight,
        foregroundColor: isDark ? _inkDark : _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? _inkDark : _ink,
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
        backgroundColor: isDark ? _primarySoftDark : _primarySoft,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: isDark ? _inkDark : _ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: _primary.withOpacity(isDark ? 0.4 : 0.3)),
      ),
      dividerTheme: theme.dividerTheme.copyWith(color: isDark ? Colors.white12 : Colors.black12),
      snackBarTheme: theme.snackBarTheme.copyWith(
        backgroundColor: isDark ? _cardDark : _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        dense: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w700, color: isDark ? _inkDark : _ink),
        subtitleTextStyle: TextStyle(color: isDark ? _mutedDark : _muted),
      ),
    );
  }

  Widget _headerCard(bool isDark, AppLocalizations l10n) {
    final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final display = fullName.isEmpty ? l10n.myDaycare : fullName;
    final initial = display.isNotEmpty ? display[0].toUpperCase() : 'G';

    return _card(
      isDark: isDark,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: isDark ? _primarySoftDark : _primarySoft,
                backgroundImage:
                    _photoUrl.text.trim().isEmpty ? null : NetworkImage(_photoUrl.text.trim()),
                child: _photoUrl.text.trim().isEmpty
                    ? Text(initial,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: _primary))
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: isDark ? _primary : _ink,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () async {
                      final ctrl = TextEditingController(text: _photoUrl.text.trim());
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? _cardDark : null,
                          title: Text(l10n.editPhoto, style: TextStyle(color: isDark ? Colors.white : null)),
                          content: TextField(
                            controller: ctrl,
                            style: TextStyle(color: isDark ? Colors.white : null),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: l10n.photoUrl,
                              labelStyle: TextStyle(color: isDark ? Colors.white60 : null),
                            ),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.cancel)),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(l10n.verify)),
                          ],
                        ),
                      );
                      if (ok == true) setState(() => _photoUrl.text = ctrl.text.trim());
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.edit, size: 14, color: Colors.white),
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
                Text(display, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? _inkDark : _ink)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(_kind.toUpperCase())),
                    Chip(
                      label: Text(_approved ? l10n.approved.toUpperCase() : l10n.pendingApproval.toUpperCase(),
                          style: TextStyle(
                              color: _approved ? Colors.white : (isDark ? _inkDark : _ink), fontWeight: FontWeight.w800)),
                      backgroundColor: _approved ? _primary : (isDark ? _primarySoftDark : _primarySoft),
                    ),
                    if (_providerId != null && _providerId!.isNotEmpty)
                      ActionChip(
                        label: Text(
                            'ID: ${_providerId!.substring(0, (_providerId!.length > 8) ? 8 : _providerId!.length)}...'),
                        onPressed: () => _copy(l10n.providerId, _providerId!),
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

  Widget _statsRow(bool isDark, AppLocalizations l10n) {
    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bookingsSummary, style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? _inkDark : _ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _pill(l10n.completedBookings, _countDelivered, Colors.green, isDark),
              _pill(l10n.pendingBookings, _countPending, Colors.orange, isDark),
              _pill(l10n.cancelledBookings, _countCancelled, Colors.red, isDark),
              _pill(l10n.total, _countTotal, _primary, isDark),
              _pill(l10n.allBookings, _bookingCount, Colors.blue, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _businessCard(bool isDark, AppLocalizations l10n) {
    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.daycareInfo, style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? _inkDark : _ink)),
          const SizedBox(height: 10),
          _kv(l10n.email, _email.text.trim().isEmpty ? '—' : _email.text.trim(), copyable: true, isDark: isDark),
          _kv(l10n.phone, _phone.text.trim().isEmpty ? '—' : _phone.text.trim(), copyable: true, isDark: isDark),
          const SizedBox(height: 6),
          _kv(l10n.address, _address.text.trim().isEmpty ? '—' : _address.text.trim(), copyable: true, isDark: isDark),
          _kv(l10n.googleMapsLink, (_mapsUrl ?? '').isEmpty ? '—' : _mapsUrl!, copyable: true, isDark: isDark),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.publicVisibility, style: TextStyle(color: isDark ? _inkDark : _ink)),
                  value: _visible,
                  onChanged: _toggleVisibility,
                ),
              ),
              const SizedBox(width: 8),
              if (_providerId != null && _providerId!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showPreviewDialog(isDark, l10n),
                  icon: const Icon(Icons.visibility),
                  label: Text(l10n.preview),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bioCard(bool isDark, AppLocalizations l10n) {
    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.description, style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? _inkDark : _ink)),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 5,
            maxLength: _bioMax,
            style: TextStyle(color: isDark ? Colors.white : null),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border:
                  const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              isDense: true,
              errorText: _errBio,
              helperText: l10n.visibleToClients,
              helperStyle: TextStyle(color: isDark ? Colors.white60 : null),
              fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
              filled: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageCard(bool isDark, AppLocalizations l10n) {
    final currentLocale = ref.watch(localeProvider);

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.language, style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? _inkDark : _ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              _languageOption('Français', 'fr', currentLocale, isDark),
              const SizedBox(width: 8),
              _languageOption('English', 'en', currentLocale, isDark),
              const SizedBox(width: 8),
              _languageOption('العربية', 'ar', currentLocale, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _languageOption(String label, String localeCode, String currentLocale, bool isDark) {
    final isSelected = currentLocale == localeCode;
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(localeProvider.notifier).setLocale(localeCode);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? _primary : (isDark ? Colors.white.withOpacity(0.05) : _primarySoft.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _primary : (isDark ? Colors.white24 : _primary.withOpacity(0.3)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : (isDark ? _inkDark : _ink),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                const Icon(Icons.check_circle, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, int value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
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
              color: isDark ? _cardDark : Colors.white,
              border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: TextStyle(color: isDark ? _mutedDark : _muted))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: TextStyle(color: isDark ? _inkDark : _ink))),
          if (copyable && v.trim().isNotEmpty && v != '—')
            IconButton(
              icon: Icon(Icons.copy, size: 18, color: isDark ? Colors.white60 : null),
              onPressed: () => _copy(k, v),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : _cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(isDark ? 0.3 : 0.2)),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x11000000), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}
