// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/session_controller.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../adopt/adoption_pet_creation_dialog.dart';

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

class AuthLoginScreen extends ConsumerStatefulWidget {
  final String asRole;
  const AuthLoginScreen({super.key, required this.asRole});

  @override
  ConsumerState<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends ConsumerState<AuthLoginScreen>
    with TickerProviderStateMixin {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  final _idFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _loading = false;
  bool _obscure = true;

  String? _errId;
  String? _errPass;
  String? _authError;

  // Animations
  late AnimationController _mainController;
  late Animation<double> _headerFade;
  late Animation<double> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<double> _cardSlide;

  static const bool _DEV_AUTO_REGISTER_ON_401 = false;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    // Prefill de test
    if (widget.asRole == 'pro') {
      _id.text = 'pro1@vethome.local';
    } else {
      _id.text = 'user1@vethome.local';
    }
    _pass.text = 'pass1234';
  }

  @override
  void dispose() {
    _mainController.dispose();
    _id.dispose();
    _pass.dispose();
    _idFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    return re.hasMatch(s.trim());
  }

  bool _isValidPhoneLike(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.length >= 8 && digits.length <= 16;
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _errId = null;
      _errPass = null;

      final id = _id.text.trim();
      if (id.isEmpty || (!_isValidEmail(id) && !_isValidPhoneLike(id))) {
        _errId = l10n.errorInvalidEmail;
      }
      if (_pass.text.isEmpty) {
        _errPass = l10n.errorPasswordRequired;
      }
    });
    return _errId == null && _errPass == null;
  }

  Future<bool> _tryLogin(String email, String pass) async {
    return await ref.read(sessionProvider.notifier).login(email, pass);
  }

  Map<String, dynamic>? _unwrapProvider(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map && raw.containsKey('data')) {
      final d = raw['data'];
      if (d == null) return null;
      if (d is Map && d.isEmpty) return null;
      return (d is Map) ? Map<String, dynamic>.from(d) : null;
    }
    if (raw is Map && raw.isEmpty) return null;
    return (raw is Map) ? Map<String, dynamic>.from(raw) : null;
  }

  bool _isRejected(Map<String, dynamic>? prov) {
    if (prov == null) return false;
    final v = prov['rejectedAt'];
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    return true;
  }

  String _providerKind(Map<String, dynamic>? prov) {
    if (prov == null) return '';
    final s = prov['specialties'];
    if (s is Map) {
      final k = s['kind'];
      if (k is String) return k.toLowerCase();
    }
    return '';
  }

  Future<Map<String, dynamic>?> _safeMyProvider() async {
    final api = ref.read(apiProvider);
    await api.ensureAuth();
    try {
      final raw = await api.myProvider();
      return _unwrapProvider(raw);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _showDetectedProDialogAndRedirect() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.proAccountDetected),
        content: Text(l10n.proAccountMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sessionProvider.notifier).logout();
              if (!mounted) return;
              context.go('/auth/login?as=pro');
            },
            child: Text(l10n.goToPro),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetectedClientDialogAndRedirect() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clientAccountDetected),
        content: Text(l10n.clientAccountMessage),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sessionProvider.notifier).logout();
              if (!mounted) return;
              context.go('/auth/login?as=user');
            },
            child: Text(l10n.goToIndividual),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              context.pushNamed('registerPro');
            },
            child: Text(l10n.createProAccount),
          ),
        ],
      ),
    );
  }

  Future<void> _incorrectAndLogout() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() => _authError = l10n.errorIncorrectCredentials);
    await ref.read(sessionProvider.notifier).logout();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_validate()) {
      return;
    }

    setState(() {
      _authError = null;
      _loading = true;
    });

    final typed = _id.text.trim();
    final pass = _pass.text;

    var ok = await _tryLogin(typed, pass);

    if (!ok) {
      final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
      final was401 = err.contains('401') || err.contains('unauthorized') || err.contains('invalid');

      if (was401 && _isValidEmail(typed)) {
        final lower = typed.toLowerCase();
        if (lower != typed) {
          ok = await _tryLogin(lower, pass);
        }
      }

      if (!ok && was401 && _DEV_AUTO_REGISTER_ON_401) {
        final regOk = await ref.read(sessionProvider.notifier).register(typed, pass);
        if (regOk) ok = await _tryLogin(typed, pass);
      }
    }

    if (!mounted) return;

    if (ok) {
      await ref.read(sessionProvider.notifier).refreshMe();
    }

    setState(() => _loading = false);

    if (!ok) {
      setState(() => _authError = l10n.errorIncorrectCredentials);
      return;
    }

    // ---------- ROUTAGE ----------
    final me = ref.read(sessionProvider).user;
    final role = ((me?['role'] as String?) ?? 'USER').toUpperCase();

    if (role == 'ADMIN') {
      context.go('/admin/dashboard');
      return;
    }

    if (widget.asRole == 'pro') {
      Map<String, dynamic>? prov;
      try {
        prov = await _safeMyProvider();
      } on DioException catch (e) {
        final msg = (e.response?.data is Map)
            ? (e.response?.data['message']?.toString() ?? e.message ?? l10n.error)
            : (e.message ?? l10n.error);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      if (prov == null) {
        await _showDetectedClientDialogAndRedirect();
        return;
      }

      if (_isRejected(prov)) {
        if (!mounted) return;
        context.go('/pro/application/rejected');
        return;
      }

      final status = (prov['status'] ?? prov['state'] ?? '').toString().toUpperCase();
      final isApproved = (prov['isApproved'] == true) ||
          (prov['approved'] == true) ||
          (status == 'APPROVED');

      if (isApproved) {
        final kind = _providerKind(prov);
        final String target = switch (kind) {
          'daycare' => '/daycare/home',
          'petshop' => '/petshop/home',
          _ => '/pro/home',
        };
        if (!mounted) return;
        context.go(target);
      } else {
        if (!mounted) return;
        context.go('/pro/application/submitted');
      }
      return;
    }

    // Flux particulier
    if (widget.asRole == 'user') {
      try {
        final prov = await _safeMyProvider();
        if (prov != null) {
          if (_isRejected(prov)) {
            await _incorrectAndLogout();
            return;
          }
          await _showDetectedProDialogAndRedirect();
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      context.go('/home');

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkPendingAdoptions();
        }
      });
      return;
    }

    // fallback
    if (role == 'PRO') {
      context.go('/pro/home');
    } else {
      context.go('/home');
    }
  }

  Future<void> _checkPendingAdoptions() async {
    try {
      await checkAndShowAdoptionDialog(context, ref);
    } catch (e) {
      // Ignorer les erreurs silencieusement
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _authError = null;
      _loading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

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

      final me = ref.read(sessionProvider).user;
      final role = ((me?['role'] as String?) ?? 'USER').toUpperCase();

      if (role == 'ADMIN') {
        context.go('/admin/dashboard');
        return;
      }

      if (widget.asRole == 'pro') {
        Map<String, dynamic>? prov;
        try {
          prov = await _safeMyProvider();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorProfileRetrieval)),
          );
          return;
        }

        if (prov == null) {
          await _showDetectedClientDialogAndRedirect();
          return;
        }

        if (_isRejected(prov)) {
          if (!mounted) return;
          context.go('/pro/application/rejected');
          return;
        }

        final status = (prov['status'] ?? prov['state'] ?? '').toString().toUpperCase();
        final isApproved = (prov['isApproved'] == true) ||
            (prov['approved'] == true) ||
            (status == 'APPROVED');

        if (isApproved) {
          final kind = _providerKind(prov);
          final String target = switch (kind) {
            'daycare' => '/daycare/home',
            'petshop' => '/petshop/home',
            _ => '/pro/home',
          };
          if (!mounted) return;
          context.go(target);
        } else {
          if (!mounted) return;
          context.go('/pro/application/submitted');
        }
        return;
      }

      // Flux particulier
      if (widget.asRole == 'user') {
        try {
          final prov = await _safeMyProvider();
          if (prov != null) {
            if (_isRejected(prov)) {
              await _incorrectAndLogout();
              return;
            }
            await _showDetectedProDialogAndRedirect();
            return;
          }
        } catch (_) {}
        if (!mounted) return;

        final hasFirstName = me?['firstName']?.toString().trim().isNotEmpty ?? false;
        final hasLastName = me?['lastName']?.toString().trim().isNotEmpty ?? false;
        final hasPhone = me?['phone']?.toString().trim().isNotEmpty ?? false;

        if (!hasFirstName || !hasLastName || !hasPhone) {
          context.go('/auth/profile-completion');
          return;
        }

        context.go('/home');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _checkPendingAdoptions();
          }
        });
        return;
      }

      // fallback
      if (role == 'PRO') {
        context.go('/pro/home');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _authError = '${l10n.errorGoogleSignIn}: ${e.toString()}';
      });
    }
  }

  void _goToRegister() {
    if (widget.asRole == 'pro') {
      context.pushNamed('registerPro');
    } else {
      context.pushNamed('registerUser');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isUser = widget.asRole == 'user';

    // Thème dynamique
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
    final inputBgColor = isDark
        ? _VegeceColors.white.withOpacity(0.05)
        : _VegeceColors.white;
    final inputBorderColor = isDark
        ? _VegeceColors.white.withOpacity(0.12)
        : _VegeceColors.textGrey.withOpacity(0.2);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Fond
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: bgColor,
              ),

              // Glow rose en haut à droite
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

              // Contenu
              SafeArea(
                child: Column(
                  children: [
                    // Header avec bouton retour
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Titre
                            Transform.translate(
                              offset: Offset(0, _headerSlide.value),
                              child: Opacity(
                                opacity: _headerFade.value,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.login,
                                      style: TextStyle(
                                        fontFamily: 'SFPRO',
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isUser
                                          ? l10n.petsDeserveBest
                                          : l10n.yourCareMakesDifference,
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Email/Phone field
                                      _buildInputField(
                                        label: l10n.emailOrPhone,
                                        controller: _id,
                                        focusNode: _idFocus,
                                        errorText: _errId,
                                        keyboardType: TextInputType.emailAddress,
                                        isDark: isDark,
                                        textColor: textColor,
                                        inputBgColor: inputBgColor,
                                        inputBorderColor: inputBorderColor,
                                        onChanged: (_) => setState(() => _authError = null),
                                      ),

                                      const SizedBox(height: 20),

                                      // Password field
                                      _buildInputField(
                                        label: l10n.password,
                                        controller: _pass,
                                        focusNode: _passFocus,
                                        errorText: _errPass,
                                        obscure: _obscure,
                                        isDark: isDark,
                                        textColor: textColor,
                                        inputBgColor: inputBgColor,
                                        inputBorderColor: inputBorderColor,
                                        onChanged: (_) => setState(() => _authError = null),
                                        suffixIcon: GestureDetector(
                                          onTap: () => setState(() => _obscure = !_obscure),
                                          child: Icon(
                                            _obscure
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: subtitleColor,
                                            size: 20,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Forgot password
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () => context.push('/auth/forgot?as=${widget.asRole}'),
                                          child: Text(
                                            l10n.forgotPassword,
                                            style: const TextStyle(
                                              fontFamily: 'SFPRO',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: _VegeceColors.pink,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Error message
                                      if (_authError != null) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _VegeceColors.errorRed.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.error_outline_rounded,
                                                color: _VegeceColors.errorRed,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _authError!,
                                                  style: const TextStyle(
                                                    fontFamily: 'SFPRO',
                                                    fontSize: 13,
                                                    color: _VegeceColors.errorRed,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 24),

                                      // Login button
                                      _PrimaryButton(
                                        label: l10n.confirm,
                                        loading: _loading,
                                        onPressed: _submit,
                                      ),

                                      // Google Sign-In pour users uniquement
                                      if (isUser) ...[
                                        const SizedBox(height: 20),

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

                                        // Google button
                                        _GoogleButton(
                                          label: l10n.continueWithGoogle,
                                          loading: _loading,
                                          isDark: isDark,
                                          onPressed: _handleGoogleSignIn,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Signup link
                            Opacity(
                              opacity: _cardFade.value,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${l10n.noAccount} ',
                                      style: TextStyle(
                                        fontFamily: 'SFPRO',
                                        fontSize: 14,
                                        color: subtitleColor,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _goToRegister,
                                      child: Text(
                                        l10n.signUp,
                                        style: const TextStyle(
                                          fontFamily: 'SFPRO',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _VegeceColors.pink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isDark,
    required Color textColor,
    required Color inputBgColor,
    required Color inputBorderColor,
    String? errorText,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
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
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: TextStyle(
              fontFamily: 'SFPRO',
              fontSize: 15,
              color: textColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOUTON PRINCIPAL
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
// BOUTON GOOGLE
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
