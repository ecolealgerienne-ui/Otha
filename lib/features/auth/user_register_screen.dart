// lib/features/auth/user_register_screen.dart
// Inscription CLIENT en 3 étapes :
// 1) Nom / Prénom
// 2) Email / Mot de passe / Téléphone (register ici avec vérif email)
// 3) Photo de profil (optionnelle, "Ignorer") puis -> /onboard/pet

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

class UserRegisterScreen extends ConsumerStatefulWidget {
  const UserRegisterScreen({super.key});
  @override
  ConsumerState<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends ConsumerState<UserRegisterScreen>
    with TickerProviderStateMixin {
  // Champs
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _phone = TextEditingController();

  // UI
  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registered = false;

  // Erreurs
  String? _errFirst, _errLast, _errEmail, _errPass, _errPassConfirm, _errPhone;

  // Avatar (étape 3)
  File? _avatarFile;
  bool _uploadingAvatar = false;

  // Animations
  late AnimationController _mainController;
  late Animation<double> _headerFade;
  late Animation<double> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<double> _cardSlide;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ---- Helpers validation
  bool _isValidEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) =>
      s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));

  bool _validateStep(int step) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      if (step == 0) {
        final first = _firstName.text.trim();
        final last = _lastName.text.trim();
        if (first.isEmpty) {
          _errFirst = l10n.errorFirstNameRequired;
        } else if (first.length < 3) {
          _errFirst = l10n.errorFirstNameMin;
        } else if (first.length > 15) {
          _errFirst = l10n.errorFirstNameMax;
        } else {
          _errFirst = null;
        }
        if (last.isEmpty) {
          _errLast = l10n.errorLastNameRequired;
        } else if (last.length < 3) {
          _errLast = l10n.errorLastNameMin;
        } else if (last.length > 15) {
          _errLast = l10n.errorLastNameMax;
        } else {
          _errLast = null;
        }
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : l10n.errorEmailInvalid;
        _errPass = _isValidPassword(_pass.text) ? null : l10n.errorPasswordWeak;
        if (_passConfirm.text.isEmpty) {
          _errPassConfirm = l10n.errorConfirmRequired;
        } else if (_passConfirm.text != _pass.text) {
          _errPassConfirm = l10n.errorPasswordMismatch;
        } else {
          _errPassConfirm = null;
        }
        final phone = _phone.text.trim();
        if (phone.isEmpty) {
          _errPhone = l10n.errorPhoneRequired;
        } else if (!phone.startsWith('05') && !phone.startsWith('06') && !phone.startsWith('07')) {
          _errPhone = l10n.errorPhoneFormat;
        } else if (phone.length != 10) {
          _errPhone = l10n.errorPhoneLength;
        } else {
          _errPhone = null;
        }
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPassConfirm == null && _errPhone == null;
    return true;
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    if (!_validateStep(_step)) return;

    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier)
            .register(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) {
            setState(() { _errEmail = l10n.errorEmailTaken; });
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(sessionProvider).error ?? l10n.error)),
          );
          return;
        }
        _registered = true;
        try {
          await ref.read(apiProvider).updateMe(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phone: _phone.text.trim(),
          );
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          final msg = (e.response?.data is Map)
              ? (e.response?.data['message']?.toString() ?? '')
              : (e.message ?? '');
          if (status == 409 || msg.toLowerCase().contains('phone')) {
            setState(() { _errPhone = l10n.errorPhoneTaken; });
            return;
          }
          rethrow;
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    setState(() => _avatarFile = File(x.path));
  }

  Future<void> _finish({required bool skip}) async {
    if (skip || _avatarFile == null) {
      if (!mounted) return;
      context.go('/auth/location-permission');
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      final api = ref.read(apiProvider);
      await api.ensureAuth();
      String url = await api.uploadLocalFile(_avatarFile!, folder: 'avatar');
      await api.meUpdate(photoUrl: url);
      if (!mounted) return;
      context.go('/auth/location-permission');
    } catch (e) {
      if (!mounted) return;
      context.go('/auth/location-permission');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final api = ref.read(apiProvider);
      await api.googleAuth(
        googleId: account.id,
        email: account.email,
        firstName: account.displayName?.split(' ').first,
        lastName: account.displayName?.split(' ').skip(1).join(' '),
        photoUrl: account.photoUrl,
      );

      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      setState(() => _loading = false);

      final user = ref.read(sessionProvider).user;
      final hasFirstName = (user?['firstName']?.toString().trim().isNotEmpty) ?? false;
      final hasLastName = (user?['lastName']?.toString().trim().isNotEmpty) ?? false;
      final hasPhone = (user?['phone']?.toString().trim().isNotEmpty) ?? false;

      if (!hasFirstName || !hasLastName || !hasPhone) {
        context.go('/auth/profile-completion');
      } else {
        context.go('/auth/location-permission');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorGoogleSignIn}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    // Couleurs dynamiques
    final bgColor = isDark ? _VegeceColors.bgDark : _VegeceColors.bgLight;
    final textColor = isDark ? _VegeceColors.white : _VegeceColors.textDark;
    final subtitleColor = _VegeceColors.textGrey;
    final cardBgColor = isDark ? _VegeceColors.cardDark : _VegeceColors.cardBg;
    final cardBorderColor = isDark
        ? _VegeceColors.white.withOpacity(0.08)
        : _VegeceColors.textGrey.withOpacity(0.1);

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

              // Glow rose
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _VegeceColors.pinkGlow.withOpacity(isDark ? 0.12 : 0.25),
                        _VegeceColors.pinkGlow.withOpacity(isDark ? 0.04 : 0.08),
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
                            onPressed: () {
                              if (_step > 0) {
                                setState(() => _step -= 1);
                              } else {
                                context.pop();
                              }
                            },
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: textColor,
                              size: 20,
                            ),
                          ),
                          const Spacer(),
                          // Step indicator
                          _StepIndicator(
                            current: _step,
                            total: 3,
                            isDark: isDark,
                          ),
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
                            const SizedBox(height: 10),

                            // Titre
                            Transform.translate(
                              offset: Offset(0, _headerSlide.value),
                              child: Opacity(
                                opacity: _headerFade.value,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.createAccount,
                                      style: TextStyle(
                                        fontFamily: 'SFPRO',
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _getStepSubtitle(l10n),
                                      style: TextStyle(
                                        fontFamily: 'SFPRO',
                                        fontSize: 14,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Card formulaire
                            Transform.translate(
                              offset: Offset(0, _cardSlide.value),
                              child: Opacity(
                                opacity: _cardFade.value,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: cardBorderColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _VegeceColors.pink.withOpacity(isDark ? 0.1 : 0.06),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: _buildStep(l10n, isDark, textColor, subtitleColor),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Buttons
                            Opacity(
                              opacity: _cardFade.value,
                              child: _buildButtons(l10n, isDark, textColor),
                            ),

                            const SizedBox(height: 40),
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

  String _getStepSubtitle(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return l10n.petsDeserveBest;
      case 1:
        return l10n.emailVerificationNote;
      case 2:
        return l10n.skipPhotoNote;
      default:
        return '';
    }
  }

  Widget _buildStep(AppLocalizations l10n, bool isDark, Color textColor, Color subtitleColor) {
    final inputBgColor = isDark
        ? _VegeceColors.white.withOpacity(0.05)
        : _VegeceColors.white;
    final inputBorderColor = isDark
        ? _VegeceColors.white.withOpacity(0.12)
        : _VegeceColors.textGrey.withOpacity(0.2);

    if (_step == 0) {
      return Column(
        key: const ValueKey('step0'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: l10n.firstName,
            controller: _firstName,
            errorText: _errFirst,
            maxLength: 15,
            isDark: isDark,
            textColor: textColor,
            inputBgColor: inputBgColor,
            inputBorderColor: inputBorderColor,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: l10n.lastName,
            controller: _lastName,
            errorText: _errLast,
            maxLength: 15,
            isDark: isDark,
            textColor: textColor,
            inputBgColor: inputBgColor,
            inputBorderColor: inputBorderColor,
          ),
          const SizedBox(height: 24),
          // Séparateur
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark
                      ? _VegeceColors.white.withOpacity(0.1)
                      : _VegeceColors.textGrey.withOpacity(0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.or,
                  style: TextStyle(
                    fontFamily: 'SFPRO',
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark
                      ? _VegeceColors.white.withOpacity(0.1)
                      : _VegeceColors.textGrey.withOpacity(0.15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _GoogleButton(
            label: l10n.continueWithGoogle,
            loading: _loading,
            isDark: isDark,
            onPressed: _handleGoogleSignIn,
          ),
        ],
      );
    }

    if (_step == 1) {
      return Column(
        key: const ValueKey('step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: l10n.email,
            controller: _email,
            errorText: _errEmail,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
            textColor: textColor,
            inputBgColor: inputBgColor,
            inputBorderColor: inputBorderColor,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: l10n.password,
            controller: _pass,
            errorText: _errPass,
            obscure: _obscure,
            helperText: l10n.passwordHelper,
            isDark: isDark,
            textColor: textColor,
            inputBgColor: inputBgColor,
            inputBorderColor: inputBorderColor,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: subtitleColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: l10n.confirmPassword,
            controller: _passConfirm,
            errorText: _errPassConfirm,
            obscure: _obscureConfirm,
            isDark: isDark,
            textColor: textColor,
            inputBgColor: inputBgColor,
            inputBorderColor: inputBorderColor,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: subtitleColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: l10n.phone,
            controller: _phone,
            errorText: _errPhone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            isDark: isDark,
            textColor: textColor,
            inputBgColor: inputBgColor,
            inputBorderColor: inputBorderColor,
          ),
        ],
      );
    }

    // Étape 2 : Avatar
    return _buildAvatarStep(l10n, isDark, textColor, subtitleColor);
  }

  Widget _buildAvatarStep(AppLocalizations l10n, bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      key: const ValueKey('step2'),
      children: [
        Text(
          l10n.profilePhotoOptional,
          style: TextStyle(
            fontFamily: 'SFPRO',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? _VegeceColors.white.withOpacity(0.1)
                : _VegeceColors.textGrey.withOpacity(0.1),
            border: Border.all(
              color: _avatarFile != null
                  ? _VegeceColors.pink
                  : (isDark ? _VegeceColors.white.withOpacity(0.15) : _VegeceColors.textGrey.withOpacity(0.2)),
              width: 2,
            ),
            image: _avatarFile != null
                ? DecorationImage(
                    image: FileImage(_avatarFile!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _avatarFile == null
              ? Icon(
                  Icons.person_outline_rounded,
                  size: 48,
                  color: subtitleColor,
                )
              : null,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SecondaryButton(
              label: l10n.choosePhoto,
              icon: Icons.photo_library_outlined,
              isDark: isDark,
              onPressed: _uploadingAvatar ? null : _pickAvatar,
            ),
            if (_avatarFile != null) ...[
              const SizedBox(width: 12),
              _SecondaryButton(
                label: l10n.removePhoto,
                icon: Icons.close,
                isDark: isDark,
                isDestructive: true,
                onPressed: _uploadingAvatar ? null : () => setState(() => _avatarFile = null),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildButtons(AppLocalizations l10n, bool isDark, Color textColor) {
    if (_step < 2) {
      return _PrimaryButton(
        label: l10n.next,
        loading: _loading,
        onPressed: _next,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _SecondaryButton(
            label: l10n.skip,
            isDark: isDark,
            onPressed: _uploadingAvatar ? null : () => _finish(skip: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryButton(
            label: l10n.finish,
            loading: _uploadingAvatar,
            onPressed: () => _finish(skip: false),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    required Color textColor,
    required Color inputBgColor,
    required Color inputBorderColor,
    String? errorText,
    String? helperText,
    bool obscure = false,
    TextInputType? keyboardType,
    int? maxLength,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SFPRO',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: inputBgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? _VegeceColors.errorRed.withOpacity(0.5)
                  : inputBorderColor,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLength: maxLength,
            style: TextStyle(
              fontFamily: 'SFPRO',
              fontSize: 15,
              color: textColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              counterText: '',
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: suffixIcon,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(maxHeight: 24),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(
              fontFamily: 'SFPRO',
              fontSize: 12,
              color: _VegeceColors.errorRed,
            ),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: TextStyle(
              fontFamily: 'SFPRO',
              fontSize: 12,
              color: _VegeceColors.textGrey.withOpacity(0.8),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STEP INDICATOR
// ═══════════════════════════════════════════════════════════════

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
                : (isDark ? _VegeceColors.white.withOpacity(0.2) : _VegeceColors.textGrey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRIMARY BUTTON
// ═══════════════════════════════════════════════════════════════

class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: widget.loading ? null : (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed();
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
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isPressed
                      ? [_VegeceColors.pinkDark, _VegeceColors.pink]
                      : [_VegeceColors.pink, _VegeceColors.pinkDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _VegeceColors.pink.withOpacity(_isPressed ? 0.2 : 0.35),
                    blurRadius: _isPressed ? 8 : 20,
                    offset: Offset(0, _isPressed ? 2 : 8),
                  ),
                ],
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _VegeceColors.white,
                        ),
                      )
                    : Text(
                        widget.label,
                        style: const TextStyle(
                          fontFamily: 'SFPRO',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _VegeceColors.white,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECONDARY BUTTON
// ═══════════════════════════════════════════════════════════════

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isDark;
  final bool isDestructive;
  final VoidCallback? onPressed;

  const _SecondaryButton({
    required this.label,
    this.icon,
    required this.isDark,
    this.isDestructive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? _VegeceColors.white.withOpacity(0.08)
        : _VegeceColors.textGrey.withOpacity(0.08);
    final borderColor = isDark
        ? _VegeceColors.white.withOpacity(0.15)
        : _VegeceColors.textGrey.withOpacity(0.15);
    final textColor = isDestructive
        ? _VegeceColors.errorRed
        : (isDark ? _VegeceColors.white : _VegeceColors.textDark);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SFPRO',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GOOGLE BUTTON
// ═══════════════════════════════════════════════════════════════

class _GoogleButton extends StatefulWidget {
  final String label;
  final bool loading;
  final bool isDark;
  final VoidCallback onPressed;

  const _GoogleButton({
    required this.label,
    required this.loading,
    required this.isDark,
    required this.onPressed,
  });

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
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
        ? (_isPressed ? _VegeceColors.white.withOpacity(0.1) : Colors.transparent)
        : (_isPressed ? _VegeceColors.textGrey.withOpacity(0.08) : _VegeceColors.white);
    final borderColor = widget.isDark
        ? _VegeceColors.white.withOpacity(0.15)
        : _VegeceColors.textGrey.withOpacity(0.2);
    final textColor = widget.isDark ? _VegeceColors.white : _VegeceColors.textDark;

    return GestureDetector(
      onTapDown: widget.loading ? null : (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: widget.loading ? null : (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed();
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
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _VegeceColors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _VegeceColors.textGrey.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA4335),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.loading ? '...' : widget.label,
                    style: TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
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
