// lib/features/auth/start_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/api.dart';
import '../../core/session_controller.dart';
import '../../core/locale_provider.dart';

enum StartVariant { user, pro }

// Couleurs Vegece - Thème Clair
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
}

class StartScreen extends ConsumerStatefulWidget {
  final StartVariant variant;
  const StartScreen({super.key, required this.variant});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen>
    with TickerProviderStateMixin {
  bool _loading = false;

  // Animations
  late AnimationController _mainController;
  late Animation<double> _logoFade;
  late Animation<double> _logoSlide;
  late Animation<double> _titleFade;
  late Animation<double> _titleSlide;
  late Animation<double> _cardFade;
  late Animation<double> _cardSlide;
  late Animation<double> _btn1Fade;
  late Animation<double> _btn2Fade;
  late Animation<double> _footerFade;

  String get _loginQuery => widget.variant == StartVariant.user ? 'user' : 'pro';

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..forward();

    // Logo animations
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _logoSlide = Tween<double>(begin: -20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    // Title animations
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // Card animations
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Button animations
    _btn1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );
    _btn2Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
      ),
    );

    // Footer animation
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);

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

      final user = ref.read(sessionProvider).user;
      final hasFirstName = (user?['firstName']?.toString().trim().isNotEmpty) ?? false;
      final hasLastName = (user?['lastName']?.toString().trim().isNotEmpty) ?? false;
      final hasPhone = (user?['phone']?.toString().trim().isNotEmpty) ?? false;

      if (!hasFirstName || !hasLastName || !hasPhone) {
        context.go('/auth/profile-completion');
      } else {
        context.go('/home');
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
    final isUser = widget.variant == StartVariant.user;

    // Thème dynamique
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    // Couleurs dynamiques selon le thème
    final bgColor = isDark ? _VegeceColors.bgDark : _VegeceColors.bgLight;
    final textColor = isDark ? _VegeceColors.white : _VegeceColors.textDark;
    final subtitleColor = isDark ? _VegeceColors.textGrey : _VegeceColors.textGrey;
    final cardBgColor = isDark ? const Color(0xFF1A1A1A) : _VegeceColors.cardBg;
    final cardBorderColor = isDark
        ? _VegeceColors.white.withOpacity(0.08)
        : _VegeceColors.textGrey.withOpacity(0.1);

    final title = isUser ? l10n.takeCareOfCompanion : l10n.welcomeToVegece;
    final subtitle = isUser ? l10n.petsDeserveBest : l10n.yourCareMakesDifference;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Fond avec transition
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: bgColor,
              ),

              // Glow rose en haut à droite
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _VegeceColors.pinkGlow.withOpacity(isDark ? 0.15 : 0.3),
                        _VegeceColors.pinkGlow.withOpacity(isDark ? 0.05 : 0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Glow rose en bas à gauche
              Positioned(
                bottom: -120,
                left: -80,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),

                      // Logo VEGECE
                      Transform.translate(
                        offset: Offset(0, _logoSlide.value),
                        child: Opacity(
                          opacity: _logoFade.value,
                          child: Column(
                            children: [
                              Text(
                                'VEGECE',
                                style: TextStyle(
                                  fontFamily: 'SFPRO',
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 14,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 40,
                                height: 1.5,
                                color: _VegeceColors.pink,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Titre + sous-titre
                      Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: Opacity(
                          opacity: _titleFade.value,
                          child: Column(
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'SFPRO',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'SFPRO',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Card avec boutons
                      Transform.translate(
                        offset: Offset(0, _cardSlide.value),
                        child: Opacity(
                          opacity: _cardFade.value,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: cardBorderColor,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _VegeceColors.pink.withOpacity(isDark ? 0.15 : 0.08),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Bouton Se connecter
                                Opacity(
                                  opacity: _btn1Fade.value,
                                  child: _AnimatedButton(
                                    label: l10n.login,
                                    isPrimary: true,
                                    onPressed: () {
                                      context.push('/auth/login?as=$_loginQuery');
                                    },
                                  ),
                                ),

                                if (isUser) ...[
                                  const SizedBox(height: 16),

                                  // Séparateur OU
                                  Opacity(
                                    opacity: _btn2Fade.value,
                                    child: Row(
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
                                  ),

                                  const SizedBox(height: 16),

                                  // Bouton Google
                                  Opacity(
                                    opacity: _btn2Fade.value,
                                    child: _GoogleButton(
                                      label: l10n.signInWithGoogle,
                                      loading: _loading,
                                      isDark: isDark,
                                      onPressed: _handleGoogleSignIn,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 20),

                                // Lien inscription
                                Opacity(
                                  opacity: _footerFade.value,
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
                                        onTap: () {
                                          if (isUser) {
                                            context.pushNamed('registerUser');
                                          } else {
                                            context.pushNamed('registerPro');
                                          }
                                        },
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
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOUTON ANIMÉ PRINCIPAL
// ═══════════════════════════════════════════════════════════════

class _AnimatedButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _AnimatedButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
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
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
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
                child: Text(
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
// BOUTON GOOGLE - THÈME DYNAMIQUE
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
    // Couleurs dynamiques selon le thème
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
                border: Border.all(
                  color: borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google icon
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
