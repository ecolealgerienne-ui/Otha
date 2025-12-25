// lib/features/petshop/petshop_settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';
import '../../core/locale_provider.dart';

// Colors
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

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
  Map<String, dynamic> _me = {};
  String? _providerId;
  String? _avatarUrl;
  File? _avatarFile;
  bool _uploadingAvatar = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      await api.ensureAuth();
      _me = ref.read(sessionProvider).user ?? {};

      // Load provider info
      try {
        final raw = await api.myProvider();
        Map<String, dynamic> p = {};
        if (raw is Map<String, dynamic>) {
          if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
            p = raw['data'] as Map<String, dynamic>;
          } else {
            p = raw;
          }
        }
        _providerId = (p['id'] ?? '').toString().isEmpty ? null : (p['id'] ?? '').toString();
        _avatarUrl = (p['avatarUrl'] ?? p['photoUrl'] ?? _me['photoUrl'] ?? '').toString();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    setState(() {
      _avatarFile = File(image.path);
      _uploadingAvatar = true;
    });

    try {
      final api = ref.read(apiProvider);
      await api.ensureAuth();
      final url = await api.uploadLocalFile(_avatarFile!, folder: 'avatar');
      _avatarUrl = url;
      _avatarFile = null;

      // Save to user and provider
      await api.updateMe(photoUrl: url);
      if (_providerId != null && _providerId!.isNotEmpty) {
        final firstName = (_me['firstName'] ?? '').toString();
        final lastName = (_me['lastName'] ?? '').toString();
        final displayName = '$firstName $lastName'.trim();
        await api.upsertMyProvider(
          displayName: displayName.isEmpty ? 'Ma boutique' : displayName,
          avatarUrl: url,
        );
      }
      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      final tr = AppLocalizations(ref.read(localeProvider));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.photoUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout(AppLocalizations tr) async {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        title: Text(tr.logout, style: TextStyle(color: isDark ? Colors.white : _ink)),
        content: Text(
          tr.confirmLogoutMessage,
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: Text(tr.logout),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(sessionProvider.notifier).logout();
      if (!mounted) return;
      context.go('/gate');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.unableToLogout)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final locale = ref.watch(localeProvider);
    final tr = AppLocalizations(locale);

    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: _coral)),
      );
    }

    final firstName = (_me['firstName'] ?? '').toString().trim();
    final lastName = (_me['lastName'] ?? '').toString().trim();
    final email = (_me['email'] ?? '').toString();
    final displayName = [firstName, lastName].where((e) => e.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            backgroundColor: cardColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _darkCardBorder : _coralSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: _coral, size: 20),
              ),
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  context.go('/petshop/home');
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [_darkCard, _darkBg]
                        : [_coralSoft, Colors.white],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar with edit button
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: cardColor,
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: isDark ? _darkCardBorder : _coralSoft,
                                backgroundImage: _avatarFile != null
                                    ? FileImage(_avatarFile!)
                                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                        ? NetworkImage(_avatarUrl!) as ImageProvider
                                        : null),
                                child: _uploadingAvatar
                                    ? const CircularProgressIndicator(color: _coral, strokeWidth: 2)
                                    : (_avatarUrl == null || _avatarUrl!.isEmpty)
                                        ? const Icon(Icons.storefront, size: 40, color: _coral)
                                        : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _coral,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardColor, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName.isNotEmpty ? displayName : tr.myShop,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section: Apparence
                _buildSectionTitle(tr.appearance, isDark: isDark),
                const SizedBox(height: 12),

                // Theme selector
                _buildCard(
                  isDark: isDark,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? _darkCardBorder : _coralSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: _coral,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.theme,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              isDark ? tr.darkMode : tr.lightMode,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isDark,
                        onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                        activeColor: _coral,
                        activeTrackColor: _coral.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Language selector
                _buildLanguageSelector(tr, isDark, textPrimary, textSecondary),

                const SizedBox(height: 32),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(
                      tr.logout,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isDark = false}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : _ink,
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: _darkCardBorder) : null,
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildLanguageSelector(AppLocalizations tr, bool isDark, Color textPrimary, Color? textSecondary) {
    final currentLang = ref.watch(localeProvider);
    final currentLanguage = AppLanguage.fromCode(currentLang.languageCode);

    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? _darkCardBorder : _coralSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.language, color: _coral, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.language,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      currentLanguage.name,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: AppLanguage.values.map((lang) {
              final isSelected = lang == currentLanguage;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: lang == AppLanguage.values.first ? 0 : 4,
                    right: lang == AppLanguage.values.last ? 0 : 4,
                  ),
                  child: GestureDetector(
                    onTap: () => ref.read(localeProvider.notifier).setLocale(lang),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _coral
                            : (isDark ? _darkCardBorder : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(color: isDark ? _darkCardBorder : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(lang.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            lang.code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
