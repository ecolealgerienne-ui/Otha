import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session_controller.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Couleurs Vegece
class _VegeceColors {
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color bgDark = Color(0xFF0A0A0A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color pink = Color(0xFFF2968F);
  static const Color pinkDark = Color(0xFFE8817A);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color pinkGlow = Color(0xFFFFC2BE);
  static const Color cardBg = Color(0xFFF9FAFB);
  static const Color cardDark = Color(0xFF1A1A1A);
  static const Color errorRed = Color(0xFFEF4444);
}

/* ========================= Helpers front ========================= */

bool _isValidHttpUrl(String s) {
  final t = s.trim();
  if (t.isEmpty) return false;
  return RegExp(r'^(https?://)', caseSensitive: false).hasMatch(t);
}

/* ========================= Écran catégories ========================= */

class ProRegisterScreen extends ConsumerStatefulWidget {
  const ProRegisterScreen({super.key});

  @override
  ConsumerState<ProRegisterScreen> createState() => _ProRegisterScreenState();
}

class _ProRegisterScreenState extends ConsumerState<ProRegisterScreen>
    with TickerProviderStateMixin {
  String? _selectedCategory;

  late AnimationController _mainController;
  late Animation<double> _headerFade;
  late Animation<double> _headerSlide;
  late Animation<double> _cardsFade;
  late Animation<double> _cardsSlide;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();

    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<double>(begin: -20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _cardsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _cardsSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) async {
    setState(() => _selectedCategory = category);

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    Widget wizard;
    switch (category) {
      case 'vet':
        wizard = const _VetWizard3Steps();
        break;
      case 'daycare':
        wizard = const _DaycareWizard3Steps();
        break;
      case 'petshop':
        wizard = const _PetshopWizard3Steps();
        break;
      default:
        return;
    }

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => wizard),
    );

    if (!mounted) return;
    setState(() => _selectedCategory = null);

    if (ok == true && mounted) {
      context.go('/pro/application/submitted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final bgColor = isDark ? _VegeceColors.bgDark : _VegeceColors.bgLight;
    final textColor = isDark ? _VegeceColors.white : _VegeceColors.textDark;
    final subtitleColor = _VegeceColors.textGrey;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: bgColor,
              ),

              // Glow rose en haut
              Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _VegeceColors.pinkGlow.withOpacity(isDark ? 0.15 : 0.3),
                        _VegeceColors.pinkGlow.withOpacity(isDark ? 0.05 : 0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: textColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Logo + Titre
                            Transform.translate(
                              offset: Offset(0, _headerSlide.value),
                              child: Opacity(
                                opacity: _headerFade.value,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'VEGECE',
                                          style: TextStyle(
                                            fontFamily: 'SFPRO',
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 6,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _VegeceColors.pink.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'PRO',
                                            style: TextStyle(
                                              fontFamily: 'SFPRO',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2,
                                              color: _VegeceColors.pink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 36,
                                      height: 1.5,
                                      color: _VegeceColors.pink,
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                      l10n.createProAccount,
                                      style: TextStyle(
                                        fontFamily: 'SFPRO',
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.chooseCategory,
                                      style: TextStyle(
                                        fontFamily: 'SFPRO',
                                        fontSize: 15,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Cards "Burger" style
                            Transform.translate(
                              offset: Offset(0, _cardsSlide.value),
                              child: Opacity(
                                opacity: _cardsFade.value,
                                child: Column(
                                  children: [
                                    _CategoryCard(
                                      icon: Icons.medical_services_outlined,
                                      label: l10n.veterinarian,
                                      description: l10n.vetDescription,
                                      isSelected: _selectedCategory == 'vet',
                                      isDark: isDark,
                                      delay: 0,
                                      onTap: () => _onCategorySelected('vet'),
                                    ),
                                    const SizedBox(height: 14),
                                    _CategoryCard(
                                      icon: Icons.pets_outlined,
                                      label: l10n.daycare,
                                      description: l10n.daycareDescription,
                                      isSelected: _selectedCategory == 'daycare',
                                      isDark: isDark,
                                      delay: 1,
                                      onTap: () => _onCategorySelected('daycare'),
                                    ),
                                    const SizedBox(height: 14),
                                    _CategoryCard(
                                      icon: Icons.storefront_outlined,
                                      label: l10n.petshop,
                                      description: l10n.petshopDescription,
                                      isSelected: _selectedCategory == 'petshop',
                                      isDark: isDark,
                                      delay: 2,
                                      onTap: () => _onCategorySelected('petshop'),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Footer
                            Opacity(
                              opacity: _cardsFade.value * 0.6,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 28),
                                child: Center(
                                  child: Text(
                                    l10n.proAccountNote,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'SFPRO',
                                      fontSize: 12,
                                      color: subtitleColor.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ========================= Category Card (Burger Style) ========================= */

class _CategoryCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final bool isDark;
  final int delay;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.isDark,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? (widget.isSelected
            ? _VegeceColors.pink.withOpacity(0.15)
            : _VegeceColors.cardDark)
        : (widget.isSelected
            ? _VegeceColors.pink.withOpacity(0.08)
            : _VegeceColors.cardBg);

    final borderColor = widget.isSelected
        ? _VegeceColors.pink
        : (widget.isDark
            ? _VegeceColors.white.withOpacity(0.08)
            : _VegeceColors.textGrey.withOpacity(0.1));

    final iconColor = widget.isSelected
        ? _VegeceColors.pink
        : (widget.isDark ? _VegeceColors.white : _VegeceColors.textDark);

    final textColor = widget.isDark ? _VegeceColors.white : _VegeceColors.textDark;
    final descColor = _VegeceColors.textGrey;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isPressed
                    ? (widget.isDark
                        ? _VegeceColors.white.withOpacity(0.05)
                        : _VegeceColors.textGrey.withOpacity(0.05))
                    : bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: _VegeceColors.pink.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Icon container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? _VegeceColors.pink.withOpacity(0.15)
                          : (widget.isDark
                              ? _VegeceColors.white.withOpacity(0.08)
                              : _VegeceColors.textGrey.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontFamily: 'SFPRO',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontFamily: 'SFPRO',
                            fontSize: 13,
                            color: descColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: widget.isSelected
                        ? _VegeceColors.pink
                        : descColor.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ========================= Step Indicator ========================= */

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final bool isDark;

  const _StepIndicator({
    required this.current,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive || isPast
                ? _VegeceColors.pink
                : (isDark
                    ? _VegeceColors.white.withOpacity(0.2)
                    : _VegeceColors.textGrey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/* ========================= Wizard VÉTÉRINAIRE ========================= */

class _VetWizard3Steps extends ConsumerStatefulWidget {
  const _VetWizard3Steps();
  @override
  ConsumerState<_VetWizard3Steps> createState() => _VetWizard3StepsState();
}

class _VetWizard3StepsState extends ConsumerState<_VetWizard3Steps> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _mapsUrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registered = false;

  File? _avnFront;
  File? _avnBack;
  File? _profilePhoto;

  final _picker = ImagePicker();

  String? _errFirst, _errLast, _errEmail, _errPass, _errPassConfirm, _errPhone, _errAddress, _errMapsUrl, _errAvn;

  bool _isValidEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) => s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _phone.dispose();
    _address.dispose();
    _mapsUrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      if (step == 0) {
        final first = _firstName.text.trim();
        final last = _lastName.text.trim();
        _errFirst = first.isEmpty ? l10n.errorFirstNameRequired : (first.length < 3 ? l10n.errorFirstNameMin : (first.length > 15 ? l10n.errorFirstNameMax : null));
        _errLast = last.isEmpty ? l10n.errorLastNameRequired : (last.length < 3 ? l10n.errorLastNameMin : (last.length > 15 ? l10n.errorLastNameMax : null));
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : l10n.errorEmailInvalid;
        _errPass = _isValidPassword(_pass.text) ? null : l10n.errorPasswordWeak;
        _errPassConfirm = _passConfirm.text.isEmpty ? l10n.errorConfirmRequired : (_passConfirm.text != _pass.text ? l10n.errorPasswordMismatch : null);
        final phone = _phone.text.trim();
        _errPhone = phone.isEmpty ? l10n.errorPhoneRequired : (!phone.startsWith('0') ? l10n.errorPhoneFormat : (phone.length < 9 || phone.length > 10 ? l10n.errorPhoneLength : null));
      } else if (step == 2) {
        _errAddress = _address.text.trim().isEmpty ? l10n.errorAddressRequired : null;
        _errMapsUrl = _isValidHttpUrl(_mapsUrl.text) ? null : l10n.errorMapsUrlRequired;
      } else if (step == 3) {
        _errAvn = (_avnFront == null || _avnBack == null) ? l10n.errorAvnRequired : null;
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPassConfirm == null && _errPhone == null;
    if (step == 2) return _errAddress == null && _errMapsUrl == null;
    if (step == 3) return _errAvn == null;
    return false;
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    if (!_validateStep(_step)) return;

    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier).registerOnly(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) {
            setState(() => _errEmail = l10n.errorEmailTaken);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(sessionProvider).error ?? l10n.error)));
          return;
        }
        _registered = true;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  Future<void> _submitFinal() async {
    final l10n = AppLocalizations.of(context);
    if (!_validateStep(3)) return;
    setState(() => _loading = true);

    try {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(true);

      final loginOk = await ref.read(sessionProvider.notifier).login(_email.text.trim(), _pass.text);
      if (!loginOk) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorConnection)));
        return;
      }

      final api = ref.read(apiProvider);

      String? photoUrl;
      if (_profilePhoto != null) {
        try {
          photoUrl = await api.uploadLocalFile(_profilePhoto!, folder: 'avatars');
        } catch (_) {}
      }

      try {
        await api.updateMe(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          photoUrl: photoUrl,
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? '');
        if (status == 409 || msg.toLowerCase().contains('phone')) {
          setState(() { _errPhone = l10n.errorPhoneTaken; _step = 1; });
          return;
        }
        rethrow;
      }

      final display = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      final displayName = display.isEmpty ? _email.text.split('@').first : display;

      String? frontUrl, backUrl;
      if (_avnFront != null) frontUrl = await api.uploadLocalFile(_avnFront!, folder: 'avn');
      if (_avnBack != null) backUrl = await api.uploadLocalFile(_avnBack!, folder: 'avn');

      await api.upsertMyProvider(
        displayName: displayName,
        address: _address.text.trim(),
        specialties: {'kind': 'vet', 'visible': true, 'mapsUrl': _mapsUrl.text.trim()},
        avnCardFront: frontUrl,
        avnCardBack: backUrl,
      );

      await ref.read(sessionProvider.notifier).refreshMe();
      await ref.read(sessionProvider.notifier).logout();
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? l10n.error);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $msg')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
      if (image == null) return;
      setState(() => _profilePhoto = File(image.path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickImage({required bool isBack}) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (image == null) return;
      setState(() {
        if (isBack) _avnBack = File(image.path); else _avnFront = File(image.path);
        _errAvn = null;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final bgColor = isDark ? _VegeceColors.bgDark : _VegeceColors.bgLight;
    final textColor = isDark ? _VegeceColors.white : _VegeceColors.textDark;
    final cardBgColor = isDark ? _VegeceColors.cardDark : _VegeceColors.cardBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_step > 0) setState(() => _step -= 1); else Navigator.pop(context);
                    },
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                  ),
                  const Spacer(),
                  _StepIndicator(current: _step, total: 4, isDark: isDark),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.veterinarian, style: TextStyle(fontFamily: 'SFPRO', fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
                    const SizedBox(height: 24),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? _VegeceColors.white.withOpacity(0.08) : _VegeceColors.textGrey.withOpacity(0.1)),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildStep(l10n, isDark, textColor),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildButton(l10n, isDark),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations l10n, bool isDark, Color textColor) {
    final inputBg = isDark ? _VegeceColors.white.withOpacity(0.05) : _VegeceColors.white;
    final inputBorder = isDark ? _VegeceColors.white.withOpacity(0.12) : _VegeceColors.textGrey.withOpacity(0.2);

    if (_step == 0) {
      return Column(key: const ValueKey('v0'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: GestureDetector(
          onTap: _pickProfilePhoto,
          child: CircleAvatar(
            radius: 45, backgroundColor: isDark ? _VegeceColors.white.withOpacity(0.1) : _VegeceColors.textGrey.withOpacity(0.1),
            backgroundImage: _profilePhoto != null ? FileImage(_profilePhoto!) : null,
            child: _profilePhoto == null ? Icon(Icons.add_a_photo, size: 26, color: _VegeceColors.textGrey) : null,
          ),
        )),
        const SizedBox(height: 20),
        _buildInput(l10n.firstName, _firstName, _errFirst, isDark, textColor, inputBg, inputBorder, maxLength: 15),
        const SizedBox(height: 16),
        _buildInput(l10n.lastName, _lastName, _errLast, isDark, textColor, inputBg, inputBorder, maxLength: 15),
      ]);
    }
    if (_step == 1) {
      return Column(key: const ValueKey('v1'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildInput(l10n.email, _email, _errEmail, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildInput(l10n.password, _pass, _errPass, isDark, textColor, inputBg, inputBorder, obscure: _obscure, helperText: l10n.passwordHelper, suffixIcon: GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _VegeceColors.textGrey, size: 20))),
        const SizedBox(height: 16),
        _buildInput(l10n.confirmPassword, _passConfirm, _errPassConfirm, isDark, textColor, inputBg, inputBorder, obscure: _obscureConfirm, suffixIcon: GestureDetector(onTap: () => setState(() => _obscureConfirm = !_obscureConfirm), child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _VegeceColors.textGrey, size: 20))),
        const SizedBox(height: 16),
        _buildInput(l10n.phone, _phone, _errPhone, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.phone, maxLength: 10),
      ]);
    }
    if (_step == 2) {
      return Column(key: const ValueKey('v2'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildInput(l10n.address, _address, _errAddress, isDark, textColor, inputBg, inputBorder),
        const SizedBox(height: 16),
        _buildInput(l10n.googleMapsUrl, _mapsUrl, _errMapsUrl, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.url, hintText: 'https://maps.google.com/...'),
      ]);
    }
    return Column(key: const ValueKey('v3'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.avnCard, style: TextStyle(fontFamily: 'SFPRO', fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 16),
      _buildImagePicker(l10n.front, _avnFront, () => _pickImage(isBack: false), () => setState(() => _avnFront = null), isDark),
      const SizedBox(height: 12),
      _buildImagePicker(l10n.back, _avnBack, () => _pickImage(isBack: true), () => setState(() => _avnBack = null), isDark),
      if (_errAvn != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_errAvn!, style: const TextStyle(color: _VegeceColors.errorRed, fontSize: 12))),
    ]);
  }

  Widget _buildInput(String label, TextEditingController controller, String? error, bool isDark, Color textColor, Color inputBg, Color inputBorder, {bool obscure = false, TextInputType? keyboardType, int? maxLength, String? helperText, String? hintText, Widget? suffixIcon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'SFPRO', fontSize: 13, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.7))),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: error != null ? _VegeceColors.errorRed.withOpacity(0.5) : inputBorder)),
        child: TextField(
          controller: controller, obscureText: obscure, keyboardType: keyboardType, maxLength: maxLength,
          style: TextStyle(fontFamily: 'SFPRO', fontSize: 15, color: textColor),
          decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), counterText: '', hintText: hintText, hintStyle: TextStyle(color: _VegeceColors.textGrey.withOpacity(0.5)), suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon) : null, suffixIconConstraints: const BoxConstraints(maxHeight: 24)),
        ),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error, style: const TextStyle(fontFamily: 'SFPRO', fontSize: 12, color: _VegeceColors.errorRed))),
      if (helperText != null && error == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(helperText, style: TextStyle(fontFamily: 'SFPRO', fontSize: 12, color: _VegeceColors.textGrey.withOpacity(0.8)))),
    ]);
  }

  Widget _buildImagePicker(String label, File? image, VoidCallback onPick, VoidCallback onRemove, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'SFPRO', fontSize: 12, fontWeight: FontWeight.w500, color: _VegeceColors.textGrey)),
      const SizedBox(height: 6),
      if (image != null)
        Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(image, height: 120, width: double.infinity, fit: BoxFit.cover)),
          Positioned(top: 6, right: 6, child: GestureDetector(onTap: onRemove, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _VegeceColors.errorRed, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close, size: 16, color: _VegeceColors.white)))),
        ])
      else
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 100, decoration: BoxDecoration(color: isDark ? _VegeceColors.white.withOpacity(0.05) : _VegeceColors.textGrey.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? _VegeceColors.white.withOpacity(0.1) : _VegeceColors.textGrey.withOpacity(0.15))),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.upload_file_outlined, size: 28, color: _VegeceColors.textGrey), const SizedBox(height: 6), Text('Upload', style: TextStyle(fontFamily: 'SFPRO', fontSize: 13, color: _VegeceColors.textGrey))])),
          ),
        ),
    ]);
  }

  Widget _buildButton(AppLocalizations l10n, bool isDark) {
    return GestureDetector(
      onTap: _loading ? null : (_step < 3 ? _next : _submitFinal),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [_VegeceColors.pink, _VegeceColors.pinkDark]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _VegeceColors.pink.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Center(child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _VegeceColors.white)) : Text(_step < 3 ? l10n.next : l10n.submit, style: const TextStyle(fontFamily: 'SFPRO', fontSize: 16, fontWeight: FontWeight.w600, color: _VegeceColors.white))),
      ),
    );
  }
}

/* ========================= Wizard GARDERIE ========================= */

class _DaycareWizard3Steps extends ConsumerStatefulWidget {
  const _DaycareWizard3Steps();
  @override
  ConsumerState<_DaycareWizard3Steps> createState() => _DaycareWizard3StepsState();
}

class _DaycareWizard3StepsState extends ConsumerState<_DaycareWizard3Steps> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _phone = TextEditingController();
  final _shopName = TextEditingController();
  final _address = TextEditingController();
  final _mapsUrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registered = false;

  final List<File> _images = [];
  final _picker = ImagePicker();

  String? _errFirst, _errLast, _errEmail, _errPass, _errPassConfirm, _errPhone, _errShop, _errAddress, _errMapsUrl, _errImages;

  bool _isValidEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) => s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _email.dispose(); _pass.dispose(); _passConfirm.dispose(); _phone.dispose(); _shopName.dispose(); _address.dispose(); _mapsUrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      if (step == 0) {
        final first = _firstName.text.trim();
        final last = _lastName.text.trim();
        _errFirst = first.isEmpty ? l10n.errorFirstNameRequired : (first.length < 3 ? l10n.errorFirstNameMin : (first.length > 15 ? l10n.errorFirstNameMax : null));
        _errLast = last.isEmpty ? l10n.errorLastNameRequired : (last.length < 3 ? l10n.errorLastNameMin : (last.length > 15 ? l10n.errorLastNameMax : null));
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : l10n.errorEmailInvalid;
        _errPass = _isValidPassword(_pass.text) ? null : l10n.errorPasswordWeak;
        _errPassConfirm = _passConfirm.text.isEmpty ? l10n.errorConfirmRequired : (_passConfirm.text != _pass.text ? l10n.errorPasswordMismatch : null);
        final phone = _phone.text.trim();
        _errPhone = phone.isEmpty ? l10n.errorPhoneRequired : (!phone.startsWith('0') ? l10n.errorPhoneFormat : (phone.length < 9 || phone.length > 10 ? l10n.errorPhoneLength : null));
      } else {
        _errShop = _shopName.text.trim().isEmpty ? l10n.errorShopNameRequired : null;
        _errAddress = _address.text.trim().isEmpty ? l10n.errorAddressRequired : null;
        _errMapsUrl = _isValidHttpUrl(_mapsUrl.text) ? null : l10n.errorMapsUrlRequired;
        _errImages = _images.isEmpty ? l10n.errorPhotoRequired : null;
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPassConfirm == null && _errPhone == null;
    return _errShop == null && _errAddress == null && _errMapsUrl == null && _errImages == null;
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) return;
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (image == null) return;
      setState(() { _images.add(File(image.path)); _errImages = null; });
    } catch (_) {}
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    if (!_validateStep(_step)) return;
    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier).registerOnly(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) { setState(() => _errEmail = l10n.errorEmailTaken); return; }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(sessionProvider).error ?? l10n.error)));
          return;
        }
        _registered = true;
      } finally { if (mounted) setState(() => _loading = false); }
    }
    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  Future<void> _submitFinal() async {
    final l10n = AppLocalizations.of(context);
    if (!_validateStep(2)) return;
    setState(() => _loading = true);
    try {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(true);
      final loginOk = await ref.read(sessionProvider.notifier).login(_email.text.trim(), _pass.text);
      if (!loginOk) { ref.read(sessionProvider.notifier).setCompletingProRegistration(false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorConnection))); return; }
      final api = ref.read(apiProvider);
      try {
        await api.updateMe(firstName: _firstName.text.trim(), lastName: _lastName.text.trim(), phone: _phone.text.trim());
      } on DioException catch (e) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        final status = e.response?.statusCode;
        final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? '');
        if (status == 409 || msg.toLowerCase().contains('phone')) { setState(() { _errPhone = l10n.errorPhoneTaken; _step = 1; }); return; }
        rethrow;
      }
      final display = _shopName.text.trim().isEmpty ? _email.text.split('@').first : _shopName.text.trim();
      final List<String> imageUrls = [];
      for (final img in _images) { imageUrls.add(await api.uploadLocalFile(img, folder: 'daycare')); }
      await api.upsertMyProvider(displayName: display, address: _address.text.trim(), specialties: {'kind': 'daycare', 'visible': true, 'mapsUrl': _mapsUrl.text.trim(), 'images': imageUrls});
      await ref.read(sessionProvider.notifier).refreshMe();
      await ref.read(sessionProvider.notifier).logout();
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? l10n.error);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $msg')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final bgColor = isDark ? _VegeceColors.bgDark : _VegeceColors.bgLight;
    final textColor = isDark ? _VegeceColors.white : _VegeceColors.textDark;
    final cardBgColor = isDark ? _VegeceColors.cardDark : _VegeceColors.cardBg;
    final inputBg = isDark ? _VegeceColors.white.withOpacity(0.05) : _VegeceColors.white;
    final inputBorder = isDark ? _VegeceColors.white.withOpacity(0.12) : _VegeceColors.textGrey.withOpacity(0.2);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(children: [
            IconButton(onPressed: () { if (_step > 0) setState(() => _step -= 1); else Navigator.pop(context); }, icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20)),
            const Spacer(), _StepIndicator(current: _step, total: 3, isDark: isDark), const Spacer(), const SizedBox(width: 48),
          ])),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.daycare, style: TextStyle(fontFamily: 'SFPRO', fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 24),
            AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? _VegeceColors.white.withOpacity(0.08) : _VegeceColors.textGrey.withOpacity(0.1))),
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _buildStepContent(l10n, isDark, textColor, inputBg, inputBorder)),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loading ? null : (_step < 2 ? _next : _submitFinal),
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(gradient: LinearGradient(colors: [_VegeceColors.pink, _VegeceColors.pinkDark]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _VegeceColors.pink.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Center(child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _VegeceColors.white)) : Text(_step < 2 ? l10n.next : l10n.submit, style: const TextStyle(fontFamily: 'SFPRO', fontSize: 16, fontWeight: FontWeight.w600, color: _VegeceColors.white))),
              ),
            ),
            const SizedBox(height: 40),
          ]))),
        ]),
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n, bool isDark, Color textColor, Color inputBg, Color inputBorder) {
    if (_step == 0) return Column(key: const ValueKey('d0'), crossAxisAlignment: CrossAxisAlignment.start, children: [_buildInput(l10n.firstName, _firstName, _errFirst, isDark, textColor, inputBg, inputBorder, maxLength: 15), const SizedBox(height: 16), _buildInput(l10n.lastName, _lastName, _errLast, isDark, textColor, inputBg, inputBorder, maxLength: 15)]);
    if (_step == 1) return Column(key: const ValueKey('d1'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildInput(l10n.email, _email, _errEmail, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.emailAddress), const SizedBox(height: 16),
      _buildInput(l10n.password, _pass, _errPass, isDark, textColor, inputBg, inputBorder, obscure: _obscure, helperText: l10n.passwordHelper, suffixIcon: GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _VegeceColors.textGrey, size: 20))), const SizedBox(height: 16),
      _buildInput(l10n.confirmPassword, _passConfirm, _errPassConfirm, isDark, textColor, inputBg, inputBorder, obscure: _obscureConfirm, suffixIcon: GestureDetector(onTap: () => setState(() => _obscureConfirm = !_obscureConfirm), child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _VegeceColors.textGrey, size: 20))), const SizedBox(height: 16),
      _buildInput(l10n.phone, _phone, _errPhone, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.phone, maxLength: 10),
    ]);
    return Column(key: const ValueKey('d2'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildInput(l10n.shopName, _shopName, _errShop, isDark, textColor, inputBg, inputBorder), const SizedBox(height: 16),
      _buildInput(l10n.address, _address, _errAddress, isDark, textColor, inputBg, inputBorder), const SizedBox(height: 16),
      _buildInput(l10n.googleMapsUrl, _mapsUrl, _errMapsUrl, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.url, hintText: 'https://maps.google.com/...'), const SizedBox(height: 16),
      Text(l10n.daycarePhotos, style: TextStyle(fontFamily: 'SFPRO', fontSize: 13, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.7))),
      const SizedBox(height: 8),
      ..._images.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(e.value, height: 100, width: double.infinity, fit: BoxFit.cover)), Positioned(top: 6, right: 6, child: GestureDetector(onTap: () => setState(() => _images.removeAt(e.key)), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _VegeceColors.errorRed, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close, size: 14, color: _VegeceColors.white))))]))),
      if (_images.length < 3) GestureDetector(onTap: _pickImage, child: Container(height: 60, decoration: BoxDecoration(color: isDark ? _VegeceColors.white.withOpacity(0.05) : _VegeceColors.textGrey.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _errImages != null ? _VegeceColors.errorRed.withOpacity(0.5) : (isDark ? _VegeceColors.white.withOpacity(0.1) : _VegeceColors.textGrey.withOpacity(0.15)))), child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate_outlined, size: 20, color: _VegeceColors.textGrey), const SizedBox(width: 8), Text(l10n.addPhoto, style: TextStyle(fontFamily: 'SFPRO', fontSize: 13, color: _VegeceColors.textGrey))])))),
      if (_errImages != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_errImages!, style: const TextStyle(fontFamily: 'SFPRO', fontSize: 12, color: _VegeceColors.errorRed))),
    ]);
  }

  Widget _buildInput(String label, TextEditingController controller, String? error, bool isDark, Color textColor, Color inputBg, Color inputBorder, {bool obscure = false, TextInputType? keyboardType, int? maxLength, String? helperText, String? hintText, Widget? suffixIcon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'SFPRO', fontSize: 13, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.7))),
      const SizedBox(height: 8),
      Container(decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: error != null ? _VegeceColors.errorRed.withOpacity(0.5) : inputBorder)),
        child: TextField(controller: controller, obscureText: obscure, keyboardType: keyboardType, maxLength: maxLength, style: TextStyle(fontFamily: 'SFPRO', fontSize: 15, color: textColor),
          decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), counterText: '', hintText: hintText, hintStyle: TextStyle(color: _VegeceColors.textGrey.withOpacity(0.5)), suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon) : null, suffixIconConstraints: const BoxConstraints(maxHeight: 24)))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error, style: const TextStyle(fontFamily: 'SFPRO', fontSize: 12, color: _VegeceColors.errorRed))),
      if (helperText != null && error == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(helperText, style: TextStyle(fontFamily: 'SFPRO', fontSize: 12, color: _VegeceColors.textGrey.withOpacity(0.8)))),
    ]);
  }
}

/* ========================= Wizard ANIMALERIE ========================= */

class _PetshopWizard3Steps extends ConsumerStatefulWidget {
  const _PetshopWizard3Steps();
  @override
  ConsumerState<_PetshopWizard3Steps> createState() => _PetshopWizard3StepsState();
}

class _PetshopWizard3StepsState extends ConsumerState<_PetshopWizard3Steps> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _phone = TextEditingController();
  final _shopName = TextEditingController();
  final _address = TextEditingController();
  final _mapsUrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registered = false;

  String? _errFirst, _errLast, _errEmail, _errPass, _errPassConfirm, _errPhone, _errShop, _errAddress, _errMapsUrl;

  bool _isValidEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) => s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _email.dispose(); _pass.dispose(); _passConfirm.dispose(); _phone.dispose(); _shopName.dispose(); _address.dispose(); _mapsUrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      if (step == 0) {
        final first = _firstName.text.trim();
        final last = _lastName.text.trim();
        _errFirst = first.isEmpty ? l10n.errorFirstNameRequired : (first.length < 3 ? l10n.errorFirstNameMin : (first.length > 15 ? l10n.errorFirstNameMax : null));
        _errLast = last.isEmpty ? l10n.errorLastNameRequired : (last.length < 3 ? l10n.errorLastNameMin : (last.length > 15 ? l10n.errorLastNameMax : null));
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : l10n.errorEmailInvalid;
        _errPass = _isValidPassword(_pass.text) ? null : l10n.errorPasswordWeak;
        _errPassConfirm = _passConfirm.text.isEmpty ? l10n.errorConfirmRequired : (_passConfirm.text != _pass.text ? l10n.errorPasswordMismatch : null);
        final phone = _phone.text.trim();
        _errPhone = phone.isEmpty ? l10n.errorPhoneRequired : (!phone.startsWith('0') ? l10n.errorPhoneFormat : (phone.length < 9 || phone.length > 10 ? l10n.errorPhoneLength : null));
      } else {
        _errShop = _shopName.text.trim().isEmpty ? l10n.errorShopNameRequired : null;
        _errAddress = _address.text.trim().isEmpty ? l10n.errorAddressRequired : null;
        _errMapsUrl = _isValidHttpUrl(_mapsUrl.text) ? null : l10n.errorMapsUrlRequired;
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPassConfirm == null && _errPhone == null;
    return _errShop == null && _errAddress == null && _errMapsUrl == null;
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    if (!_validateStep(_step)) return;
    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier).registerOnly(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) { setState(() => _errEmail = l10n.errorEmailTaken); return; }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(sessionProvider).error ?? l10n.error)));
          return;
        }
        _registered = true;
      } finally { if (mounted) setState(() => _loading = false); }
    }
    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  Future<void> _submitFinal() async {
    final l10n = AppLocalizations.of(context);
    if (!_validateStep(2)) return;
    setState(() => _loading = true);
    try {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(true);
      final loginOk = await ref.read(sessionProvider.notifier).login(_email.text.trim(), _pass.text);
      if (!loginOk) { ref.read(sessionProvider.notifier).setCompletingProRegistration(false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorConnection))); return; }
      final api = ref.read(apiProvider);
      try {
        await api.updateMe(firstName: _firstName.text.trim(), lastName: _lastName.text.trim(), phone: _phone.text.trim());
      } on DioException catch (e) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        final status = e.response?.statusCode;
        final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? '');
        if (status == 409 || msg.toLowerCase().contains('phone')) { setState(() { _errPhone = l10n.errorPhoneTaken; _step = 1; }); return; }
        rethrow;
      }
      final display = _shopName.text.trim().isEmpty ? _email.text.split('@').first : _shopName.text.trim();
      await api.upsertMyProvider(displayName: display, address: _address.text.trim(), specialties: {'kind': 'petshop', 'visible': true, 'mapsUrl': _mapsUrl.text.trim()});
      await ref.read(sessionProvider.notifier).refreshMe();
      await ref.read(sessionProvider.notifier).logout();
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? l10n.error);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $msg')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final bgColor = isDark ? _VegeceColors.bgDark : _VegeceColors.bgLight;
    final textColor = isDark ? _VegeceColors.white : _VegeceColors.textDark;
    final cardBgColor = isDark ? _VegeceColors.cardDark : _VegeceColors.cardBg;
    final inputBg = isDark ? _VegeceColors.white.withOpacity(0.05) : _VegeceColors.white;
    final inputBorder = isDark ? _VegeceColors.white.withOpacity(0.12) : _VegeceColors.textGrey.withOpacity(0.2);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(children: [
            IconButton(onPressed: () { if (_step > 0) setState(() => _step -= 1); else Navigator.pop(context); }, icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20)),
            const Spacer(), _StepIndicator(current: _step, total: 3, isDark: isDark), const Spacer(), const SizedBox(width: 48),
          ])),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.petshop, style: TextStyle(fontFamily: 'SFPRO', fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 24),
            AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? _VegeceColors.white.withOpacity(0.08) : _VegeceColors.textGrey.withOpacity(0.1))),
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _buildStepContent(l10n, isDark, textColor, inputBg, inputBorder)),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loading ? null : (_step < 2 ? _next : _submitFinal),
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(gradient: LinearGradient(colors: [_VegeceColors.pink, _VegeceColors.pinkDark]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _VegeceColors.pink.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Center(child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _VegeceColors.white)) : Text(_step < 2 ? l10n.next : l10n.submit, style: const TextStyle(fontFamily: 'SFPRO', fontSize: 16, fontWeight: FontWeight.w600, color: _VegeceColors.white))),
              ),
            ),
            const SizedBox(height: 40),
          ]))),
        ]),
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n, bool isDark, Color textColor, Color inputBg, Color inputBorder) {
    if (_step == 0) return Column(key: const ValueKey('p0'), crossAxisAlignment: CrossAxisAlignment.start, children: [_buildInput(l10n.firstName, _firstName, _errFirst, isDark, textColor, inputBg, inputBorder, maxLength: 15), const SizedBox(height: 16), _buildInput(l10n.lastName, _lastName, _errLast, isDark, textColor, inputBg, inputBorder, maxLength: 15)]);
    if (_step == 1) return Column(key: const ValueKey('p1'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildInput(l10n.email, _email, _errEmail, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.emailAddress), const SizedBox(height: 16),
      _buildInput(l10n.password, _pass, _errPass, isDark, textColor, inputBg, inputBorder, obscure: _obscure, helperText: l10n.passwordHelper, suffixIcon: GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _VegeceColors.textGrey, size: 20))), const SizedBox(height: 16),
      _buildInput(l10n.confirmPassword, _passConfirm, _errPassConfirm, isDark, textColor, inputBg, inputBorder, obscure: _obscureConfirm, suffixIcon: GestureDetector(onTap: () => setState(() => _obscureConfirm = !_obscureConfirm), child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _VegeceColors.textGrey, size: 20))), const SizedBox(height: 16),
      _buildInput(l10n.phone, _phone, _errPhone, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.phone, maxLength: 10),
    ]);
    return Column(key: const ValueKey('p2'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildInput(l10n.shopName, _shopName, _errShop, isDark, textColor, inputBg, inputBorder), const SizedBox(height: 16),
      _buildInput(l10n.address, _address, _errAddress, isDark, textColor, inputBg, inputBorder), const SizedBox(height: 16),
      _buildInput(l10n.googleMapsUrl, _mapsUrl, _errMapsUrl, isDark, textColor, inputBg, inputBorder, keyboardType: TextInputType.url, hintText: 'https://maps.google.com/...'),
    ]);
  }

  Widget _buildInput(String label, TextEditingController controller, String? error, bool isDark, Color textColor, Color inputBg, Color inputBorder, {bool obscure = false, TextInputType? keyboardType, int? maxLength, String? helperText, String? hintText, Widget? suffixIcon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'SFPRO', fontSize: 13, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.7))),
      const SizedBox(height: 8),
      Container(decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: error != null ? _VegeceColors.errorRed.withOpacity(0.5) : inputBorder)),
        child: TextField(controller: controller, obscureText: obscure, keyboardType: keyboardType, maxLength: maxLength, style: TextStyle(fontFamily: 'SFPRO', fontSize: 15, color: textColor),
          decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), counterText: '', hintText: hintText, hintStyle: TextStyle(color: _VegeceColors.textGrey.withOpacity(0.5)), suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon) : null, suffixIconConstraints: const BoxConstraints(maxHeight: 24)))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error, style: const TextStyle(fontFamily: 'SFPRO', fontSize: 12, color: _VegeceColors.errorRed))),
      if (helperText != null && error == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(helperText, style: TextStyle(fontFamily: 'SFPRO', fontSize: 12, color: _VegeceColors.textGrey.withOpacity(0.8)))),
    ]);
  }
}
