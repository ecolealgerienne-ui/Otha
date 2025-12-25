// lib/features/petshop/petshop_shop_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
const _muted = Color(0xFF6B6B6B);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

class PetshopShopScreen extends ConsumerStatefulWidget {
  const PetshopShopScreen({super.key});

  @override
  ConsumerState<PetshopShopScreen> createState() => _PetshopShopScreenState();
}

class _PetshopShopScreenState extends ConsumerState<PetshopShopScreen> {
  // Provider info
  String? _providerId;
  bool _approved = false;
  String _kind = 'petshop';
  bool _visible = true;

  // Shop info
  final _shopName = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();
  String? _mapsUrl;
  String? _photoUrl;
  File? _avatarFile;
  bool _uploadingAvatar = false;

  // Opening hours - stored as "HH:mm-HH:mm" or null if closed
  final Map<int, bool> _daysOpen = {
    1: true, // Lundi
    2: true, // Mardi
    3: true, // Mercredi
    4: true, // Jeudi
    5: true, // Vendredi
    6: true, // Samedi
    7: false, // Dimanche
  };

  final Map<int, TimeOfDay> _openingTimes = {
    1: const TimeOfDay(hour: 9, minute: 0),
    2: const TimeOfDay(hour: 9, minute: 0),
    3: const TimeOfDay(hour: 9, minute: 0),
    4: const TimeOfDay(hour: 9, minute: 0),
    5: const TimeOfDay(hour: 9, minute: 0),
    6: const TimeOfDay(hour: 9, minute: 0),
    7: const TimeOfDay(hour: 9, minute: 0),
  };

  final Map<int, TimeOfDay> _closingTimes = {
    1: const TimeOfDay(hour: 18, minute: 0),
    2: const TimeOfDay(hour: 18, minute: 0),
    3: const TimeOfDay(hour: 18, minute: 0),
    4: const TimeOfDay(hour: 18, minute: 0),
    5: const TimeOfDay(hour: 18, minute: 0),
    6: const TimeOfDay(hour: 18, minute: 0),
    7: const TimeOfDay(hour: 18, minute: 0),
  };

  // Delivery options
  bool _deliveryEnabled = false;
  bool _pickupEnabled = true;

  bool _loading = false;
  bool _saving = false;
  bool _bootstrapped = false;

  static const int _bioMax = 280;
  String? _errBio;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _shopName.dispose();
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

  Future<void> _loadData() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    setState(() => _loading = true);

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    // USER info
    final me = ref.read(sessionProvider).user ?? {};
    final firstName = (me['firstName'] ?? '').toString();
    final lastName = (me['lastName'] ?? '').toString();
    _shopName.text = '$firstName $lastName'.trim();

    // PROVIDER info
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

      // Shop name from displayName
      final displayName = (p['displayName'] ?? '').toString();
      if (displayName.isNotEmpty) {
        _shopName.text = displayName;
      }

      // Avatar
      _photoUrl = (p['avatarUrl'] ?? p['photoUrl'] ?? me['photoUrl'] ?? '').toString();

      // Delivery options
      _deliveryEnabled = p['deliveryEnabled'] == true;
      _pickupEnabled = p['pickupEnabled'] != false;

      // Parse opening hours from specialties
      final hours = specs['openingHours'];
      if (hours is Map) {
        for (int day = 1; day <= 7; day++) {
          final dayStr = day.toString();
          if (hours.containsKey(dayStr)) {
            final dayHours = hours[dayStr];
            if (dayHours == null || dayHours == 'closed') {
              _daysOpen[day] = false;
            } else if (dayHours is String && dayHours.contains('-')) {
              _daysOpen[day] = true;
              final parts = dayHours.split('-');
              if (parts.length == 2) {
                _openingTimes[day] = _parseTime(parts[0]) ?? const TimeOfDay(hour: 9, minute: 0);
                _closingTimes[day] = _parseTime(parts[1]) ?? const TimeOfDay(hour: 18, minute: 0);
              }
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.trim().split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _validate() {
    final b = _bio.text.trim();
    _errBio = (b.length > _bioMax) ? 'Max $_bioMax caractères' : null;
    setState(() {});
    return _errBio == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      // Build opening hours map
      final Map<String, dynamic> openingHours = {};
      for (int day = 1; day <= 7; day++) {
        if (_daysOpen[day] == true) {
          openingHours[day.toString()] =
              '${_formatTime(_openingTimes[day]!)}-${_formatTime(_closingTimes[day]!)}';
        } else {
          openingHours[day.toString()] = 'closed';
        }
      }

      await api.upsertMyProvider(
        displayName: _shopName.text.trim(),
        address: _address.text.trim(),
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        avatarUrl: _photoUrl,
        specialties: {
          'kind': _kind,
          'visible': _visible,
          'openingHours': openingHours,
          if (_mapsUrl != null && _mapsUrl!.trim().isNotEmpty) 'mapsUrl': _mapsUrl!.trim(),
        },
      );

      // Save delivery options
      await api.updateDeliveryOptions(
        deliveryEnabled: _deliveryEnabled,
        pickupEnabled: _pickupEnabled,
      );

      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      final tr = AppLocalizations(ref.read(localeProvider));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.profileUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
      _photoUrl = url;
      _avatarFile = null;

      if (!mounted) return;
      final tr = AppLocalizations(ref.read(localeProvider));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.photoUpdated)),
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

  Future<void> _selectTime(int day, bool isOpening) async {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final currentTime = isOpening ? _openingTimes[day]! : _closingTimes[day]!;

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _coral,
              onPrimary: Colors.white,
              surface: isDark ? _darkCard : Colors.white,
              onSurface: isDark ? Colors.white : _ink,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark ? _darkCard : Colors.white,
              hourMinuteColor: isDark ? _darkCardBorder : _coralSoft,
              hourMinuteTextColor: isDark ? Colors.white : _ink,
              dialBackgroundColor: isDark ? _darkCardBorder : _coralSoft,
              dialHandColor: _coral,
              dialTextColor: isDark ? Colors.white : _ink,
              entryModeIconColor: _coral,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTimes[day] = picked;
        } else {
          _closingTimes[day] = picked;
        }
      });
    }
  }

  String _getDayName(int day, AppLocalizations tr) {
    switch (day) {
      case 1: return tr.monday;
      case 2: return tr.tuesday;
      case 3: return tr.wednesday;
      case 4: return tr.thursday;
      case 5: return tr.friday;
      case 6: return tr.saturday;
      case 7: return tr.sunday;
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : _muted;

    final locale = ref.watch(localeProvider);
    final tr = AppLocalizations(locale);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigateBack();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          foregroundColor: textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBack,
          ),
          title: Text(tr.shopManagement, style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _coral),
                ),
              )
            else
              TextButton(
                onPressed: _save,
                child: Text(tr.save, style: const TextStyle(color: _coral, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _coral))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Shop header with avatar
                  _buildHeaderCard(isDark, tr),
                  const SizedBox(height: 16),

                  // Shop info
                  _buildInfoCard(isDark, tr, textPrimary, textSecondary),
                  const SizedBox(height: 16),

                  // Opening hours
                  _buildOpeningHoursCard(isDark, tr, textPrimary, textSecondary),
                  const SizedBox(height: 16),

                  // Delivery options
                  _buildDeliveryCard(isDark, tr, textPrimary, textSecondary),
                  const SizedBox(height: 16),

                  // Description
                  _buildDescriptionCard(isDark, tr, textPrimary, textSecondary),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _saving ? '...' : tr.save,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _navigateBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go('/petshop/home');
    }
  }

  Widget _buildHeaderCard(bool isDark, AppLocalizations tr) {
    final initial = _shopName.text.isNotEmpty ? _shopName.text[0].toUpperCase() : 'B';

    ImageProvider? avatarImage;
    if (_avatarFile != null) {
      avatarImage = FileImage(_avatarFile!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_photoUrl!);
    }

    return _card(
      isDark: isDark,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 40,
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
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _coral))
                        : null),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: isDark ? _darkCardBorder : _ink,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopName.text.isEmpty ? tr.myShop : _shopName.text,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _approved ? _coral : (isDark ? _coral.withOpacity(0.15) : _coralSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _approved ? tr.approved : tr.pending,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _approved ? Colors.white : (isDark ? Colors.white : _coral),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PETSHOP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : _coral,
                        ),
                      ),
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

  Widget _buildInfoCard(bool isDark, AppLocalizations tr, Color textPrimary, Color? textSecondary) {
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
                  color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront, color: _coral, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                tr.shopInfo,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Shop name
          Text(tr.shopName, style: TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _shopName,
            style: TextStyle(color: textPrimary),
            decoration: _inputDecoration(isDark, tr.shopNameHint),
          ),
          const SizedBox(height: 16),

          // Address
          Text(tr.address, style: TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _address,
            style: TextStyle(color: textPrimary),
            decoration: _inputDecoration(isDark, tr.addressHint),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningHoursCard(bool isDark, AppLocalizations tr, Color textPrimary, Color? textSecondary) {
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
                  color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.access_time, color: Colors.green.shade600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.openingHours,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr.openingHoursHint,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days list
          ...List.generate(7, (index) {
            final day = index + 1;
            final isOpen = _daysOpen[day] ?? false;
            final dayName = _getDayName(day, tr);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? (isOpen ? Colors.green.withOpacity(0.1) : _darkCardBorder)
                    : (isOpen ? Colors.green.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOpen ? Colors.green.withOpacity(0.3) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  // Day toggle
                  GestureDetector(
                    onTap: () => setState(() => _daysOpen[day] = !isOpen),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.green : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOpen ? Icons.check : Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Day name
                  SizedBox(
                    width: 80,
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isOpen ? textPrimary : (isDark ? Colors.grey[500] : Colors.grey),
                      ),
                    ),
                  ),

                  // Times or closed label
                  Expanded(
                    child: isOpen
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _timeButton(
                                time: _openingTimes[day]!,
                                onTap: () => _selectTime(day, true),
                                isDark: isDark,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('-', style: TextStyle(color: textSecondary)),
                              ),
                              _timeButton(
                                time: _closingTimes[day]!,
                                onTap: () => _selectTime(day, false),
                                isDark: isDark,
                              ),
                            ],
                          )
                        : Text(
                            tr.closed,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _timeButton({
    required TimeOfDay time,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? _darkCard : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? _darkCardBorder : Colors.grey.shade300),
        ),
        child: Text(
          _formatTime(time),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(bool isDark, AppLocalizations tr, Color textPrimary, Color? textSecondary) {
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
                child: const Icon(Icons.local_shipping, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.deliveryOptions,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr.deliveryOptionsHint,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pickup option
          _deliveryOption(
            icon: Icons.store_rounded,
            title: tr.pickupInStore,
            subtitle: tr.pickupInStoreHint,
            enabled: _pickupEnabled,
            onChanged: (v) => setState(() => _pickupEnabled = v),
            color: Colors.purple,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),

          // Delivery option
          _deliveryOption(
            icon: Icons.local_shipping_rounded,
            title: tr.homeDelivery,
            subtitle: tr.homeDeliveryHint,
            enabled: _deliveryEnabled,
            onChanged: (v) => setState(() => _deliveryEnabled = v),
            color: Colors.blue,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
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
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr.deliveryWarning,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
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

  Widget _deliveryOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    required Color color,
    required bool isDark,
    required Color textPrimary,
    Color? textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? (enabled ? color.withOpacity(0.15) : _darkCardBorder)
            : (enabled ? color.withOpacity(0.08) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? color.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: enabled ? color : Colors.grey, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary)),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(bool isDark, AppLocalizations tr, Color textPrimary, Color? textSecondary) {
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
                  color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description, color: Colors.orange.shade600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.description,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr.descriptionHint,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 5,
            maxLength: _bioMax,
            style: TextStyle(color: textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr.descriptionPlaceholder,
              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
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
                borderSide: const BorderSide(color: _coral),
              ),
              filled: true,
              fillColor: isDark ? _darkCardBorder : Colors.white,
              errorText: _errBio,
              counterStyle: TextStyle(color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
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
        borderSide: const BorderSide(color: _coral),
      ),
      filled: true,
      fillColor: isDark ? _darkCardBorder : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _card({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : _coral.withOpacity(0.15)),
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}
