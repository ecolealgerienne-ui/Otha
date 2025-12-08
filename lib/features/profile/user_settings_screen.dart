// lib/features/profile/user_settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF2968F);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _darkBg = Color(0xFF0A0A0A);
const _darkCard = Color(0xFF1A1A1A);
const _darkBorder = Color(0xFF2A2A2A);

// Storage keys for delivery info
const _kDeliveryAddress = 'user_delivery_address';

class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});
  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  File? _avatarFile;
  String? _avatarUrl;
  Map<String, dynamic> _me = {};

  bool _loading = true;
  bool _saving = false;

  // Edit modes
  bool _editingPhone = false;
  bool _editingEmail = false;
  bool _editingAddress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool _isHttp(String? s) =>
      s != null && (s.startsWith('http://') || s.startsWith('https://'));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      _me = await api.me();

      _avatarUrl = (_me['photoUrl'] ?? _me['avatar'] ?? '') as String?;
      _phoneController.text = (_me['phone'] ?? '').toString();
      _emailController.text = (_me['email'] ?? '').toString();

      // Load delivery address from storage
      final savedAddress = await _storage.read(key: _kDeliveryAddress);
      if (savedAddress != null && savedAddress.isNotEmpty) {
        _addressController.text = savedAddress;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      setState(() => _avatarFile = file);

      final api = ref.read(apiProvider);
      final url = await api.uploadLocalFile(file, folder: 'avatar');
      await api.meUpdate(photoUrl: url);
      ref.invalidate(sessionProvider);

      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _showSnackBar('Photo mise à jour', Colors.green);
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    }
  }

  Future<void> _savePhone() async {
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Numéro de téléphone requis', Colors.orange);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).meUpdate(phone: _phoneController.text.trim());
      setState(() => _editingPhone = false);
      _showSnackBar('Téléphone mis à jour', Colors.green);
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAddress() async {
    setState(() => _saving = true);
    try {
      await _storage.write(
        key: _kDeliveryAddress,
        value: _addressController.text.trim(),
      );
      setState(() => _editingAddress = false);
      _showSnackBar('Adresse mise à jour', Colors.green);
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _logout(AppLocalizations tr) async {
    final themeMode = ref.read(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        title: Text(
          tr.logout,
          style: TextStyle(color: isDark ? Colors.white : _ink),
        ),
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
      _showSnackBar(tr.unableToLogout, Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme support
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textColor = isDark ? Colors.white : _ink;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Translations
    final locale = ref.watch(localeProvider);
    final tr = AppLocalizations(locale);

    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: _coral),
        ),
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
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _darkCard : _coralSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: _coral, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
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
                                backgroundColor: isDark ? _darkBorder : _coralSoft,
                                backgroundImage: _avatarProvider(),
                                child: _avatarProvider() == null
                                    ? const Icon(Icons.person, size: 40, color: _coral)
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
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName.isNotEmpty ? displayName : tr.myProfile,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
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
                // Section: Apparence (Theme & Language)
                _buildSectionTitle(tr.appearance, isDark: isDark),
                const SizedBox(height: 12),

                // Theme selector
                _buildAppearanceCard(
                  icon: isDark ? Icons.dark_mode : Icons.light_mode,
                  title: tr.theme,
                  subtitle: isDark ? tr.darkMode : tr.lightMode,
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                    activeColor: _coral,
                    activeTrackColor: _coral.withOpacity(0.3),
                  ),
                  isDark: isDark,
                ),

                const SizedBox(height: 12),

                // Language selector
                _buildLanguageSelector(tr, isDark),

                const SizedBox(height: 24),

                // Section: Informations personnelles
                _buildSectionTitle(tr.personalInfo, isDark: isDark),
                const SizedBox(height: 12),

                // Phone
                _buildEditableField(
                  icon: Icons.phone_outlined,
                  label: tr.phone,
                  controller: _phoneController,
                  isEditing: _editingPhone,
                  onEdit: () => setState(() => _editingPhone = true),
                  onSave: _savePhone,
                  onCancel: () {
                    _phoneController.text = (_me['phone'] ?? '').toString();
                    setState(() => _editingPhone = false);
                  },
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  hint: '0555 00 00 00',
                  isDark: isDark,
                  tr: tr,
                ),

                const SizedBox(height: 12),

                // Email (read-only info)
                _buildInfoField(
                  icon: Icons.email_outlined,
                  label: tr.email,
                  value: email,
                  helperText: tr.emailCannotBeChanged,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // Section: Livraison Petshop
                _buildSectionTitle(tr.deliveryAddress, isDark: isDark),
                const SizedBox(height: 8),
                Text(
                  tr.deliveryAddressHint,
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
                const SizedBox(height: 12),

                // Delivery address
                _buildEditableField(
                  icon: Icons.location_on_outlined,
                  label: tr.address,
                  controller: _addressController,
                  isEditing: _editingAddress,
                  onEdit: () => setState(() => _editingAddress = true),
                  onSave: _saveAddress,
                  onCancel: () async {
                    final saved = await _storage.read(key: _kDeliveryAddress);
                    _addressController.text = saved ?? '';
                    setState(() => _editingAddress = false);
                  },
                  maxLines: 2,
                  hint: tr.addressHint,
                  isDark: isDark,
                  tr: tr,
                ),

                const SizedBox(height: 24),

                // Section: Accès rapides
                _buildSectionTitle(tr.quickAccess, isDark: isDark),
                const SizedBox(height: 12),

                // Quick access buttons
                _buildQuickAccessCard(
                  icon: Icons.pets,
                  title: tr.myPets,
                  subtitle: tr.manageMyPets,
                  onTap: () => context.push('/pets/manage'),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildQuickAccessCard(
                  icon: Icons.calendar_today,
                  title: tr.myAppointments,
                  subtitle: tr.viewAllAppointments,
                  onTap: () => context.push('/me/bookings'),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildQuickAccessCard(
                  icon: Icons.support_agent,
                  title: tr.support,
                  subtitle: tr.needHelp,
                  onTap: () {
                    _showSnackBar(tr.comingSoon, Colors.grey);
                  },
                  disabled: true,
                  isDark: isDark,
                ),

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

  Widget _buildAppearanceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: _darkBorder) : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? _darkBorder : _coralSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _coral, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(AppLocalizations tr, bool isDark) {
    final currentLang = ref.watch(localeProvider);
    final currentLanguage = AppLanguage.fromCode(currentLang.languageCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: _darkBorder) : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? _darkBorder : _coralSoft,
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
                        color: isDark ? Colors.white : _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentLanguage.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
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
                            : (isDark ? _darkBorder : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDark ? _darkBorder : Colors.grey.shade200,
                              ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            lang.flag,
                            style: const TextStyle(fontSize: 20),
                          ),
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

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? hint,
    bool isDark = false,
    AppLocalizations? tr,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: _darkBorder) : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _darkBorder : _coralSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _coral, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : _ink,
                  ),
                ),
              ),
              if (!isEditing)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(foregroundColor: _coral),
                  child: Text(tr?.edit ?? 'Modifier'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isEditing) ...[
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              style: TextStyle(color: isDark ? Colors.white : _ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                filled: true,
                fillColor: isDark ? _darkBorder : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? _darkBorder : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? _darkBorder : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _coral, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : onCancel,
                  child: Text(tr?.cancel ?? 'Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: _coral,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(tr?.save ?? 'Enregistrer'),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? _darkBorder : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                controller.text.trim().isEmpty
                    ? (tr?.notProvided ?? 'Non renseigné')
                    : controller.text,
                style: TextStyle(
                  fontSize: 15,
                  color: controller.text.trim().isEmpty
                      ? Colors.grey
                      : (isDark ? Colors.white : _ink),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required IconData icon,
    required String label,
    required String value,
    String? helperText,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: _darkBorder) : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _darkBorder : _coralSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _coral, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? _darkBorder : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : _ink,
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool disabled = false,
    bool isDark = false,
  }) {
    return Material(
      color: isDark ? _darkCard : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? _darkBorder : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: disabled
                      ? (isDark ? _darkBorder : Colors.grey.shade100)
                      : (isDark ? _darkBorder : _coralSoft),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: disabled ? Colors.grey : _coral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: disabled
                            ? Colors.grey
                            : (isDark ? Colors.white : _ink),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: disabled
                    ? (isDark ? Colors.grey[700] : Colors.grey.shade300)
                    : (isDark ? Colors.grey[500] : Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
