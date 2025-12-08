import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/session_controller.dart';
import '../../core/locale_provider.dart';

// Couleurs Vegece
class VegeceColors {
  static const Color bgDark = Color(0xFF0A0A0A);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF9CA3AF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color pink = Color(0xFFF2968F);
  static const Color pinkDark = Color(0xFFE8817A);
  static const Color pinkGlow = Color(0xFFFFC2BE);
}

class RoleGateScreen extends ConsumerStatefulWidget {
  const RoleGateScreen({super.key});

  @override
  ConsumerState<RoleGateScreen> createState() => _RoleGateScreenState();
}

class _RoleGateScreenState extends ConsumerState<RoleGateScreen>
    with TickerProviderStateMixin {
  // Splash animations
  late AnimationController _splashController;
  late Animation<double> _logoFade;
  late Animation<double> _logoSlide;
  late Animation<double> _lineFade;
  late Animation<double> _lineWidth;
  late Animation<double> _dotPulse;

  // Selection screen animations
  late AnimationController _selectionController;
  late Animation<double> _contentFade;
  late Animation<double> _contentSlide;
  late Animation<double> _btn1Fade;
  late Animation<double> _btn2Fade;

  bool _splashMinTimeElapsed = false;
  bool _showSelection = false;

  @override
  void initState() {
    super.initState();

    // Timer splash 5 secondes
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() => _splashMinTimeElapsed = true);
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // SPLASH ANIMATIONS
    // ═══════════════════════════════════════════════════════════════
    _splashController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..forward();

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _logoSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _lineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );

    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _dotPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // ═══════════════════════════════════════════════════════════════
    // SELECTION ANIMATIONS
    // ═══════════════════════════════════════════════════════════════
    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _btn1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _btn2Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _splashController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  void _startSelectionAnimations() {
    if (!_showSelection) {
      _showSelection = true;
      _selectionController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (!session.bootstrapped || !_splashMinTimeElapsed) {
      return _buildSplashScreen();
    }

    if (session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final targetRoute = getHomeRouteForSession(session);
          context.go(targetRoute);
        }
      });
      return _buildSplashScreen();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSelectionAnimations();
    });

    return _buildSelectionScreen(context);
  }

  // ═══════════════════════════════════════════════════════════════
  // SPLASH SCREEN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: VegeceColors.bgDark,
      body: AnimatedBuilder(
        animation: _splashController,
        builder: (context, child) {
          return Stack(
            children: [
              Container(color: VegeceColors.bgDark),
              Center(
                child: Transform.translate(
                  offset: Offset(0, _logoSlide.value),
                  child: Opacity(
                    opacity: _logoFade.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'VEGECE',
                          style: TextStyle(
                            fontFamily: 'SFPRO',
                            fontSize: 42,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 16,
                            color: VegeceColors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Opacity(
                          opacity: _lineFade.value,
                          child: Container(
                            width: 40 * _lineWidth.value,
                            height: 1,
                            color: VegeceColors.pink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _dotPulse.value,
                  child: const _LoadingDots(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ÉCRAN DE SÉLECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSelectionScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLang = ref.watch(localeProvider.notifier).currentLanguage;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    // Couleurs dynamiques selon le thème
    final bgColor = isDark ? VegeceColors.bgDark : VegeceColors.bgLight;
    final textColor = isDark ? VegeceColors.white : VegeceColors.textDark;
    final subtitleColor = isDark ? VegeceColors.textGrey : VegeceColors.textGrey;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: _selectionController,
        builder: (context, child) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: bgColor,
              ),

              // Ombre rose en bas à droite
              Positioned(
                bottom: -100,
                right: -100,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        VegeceColors.pinkGlow.withOpacity(isDark ? 0.15 : 0.25),
                        VegeceColors.pinkGlow.withOpacity(isDark ? 0.05 : 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Boutons langue et thème en haut à droite
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 20,
                child: Opacity(
                  opacity: _contentFade.value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThemeToggle(
                        isDark: isDark,
                        onToggle: () {
                          ref.read(themeProvider.notifier).toggleTheme();
                        },
                      ),
                      const SizedBox(width: 10),
                      _LanguageSelector(
                        currentLanguage: currentLang,
                        isDark: isDark,
                        onChanged: (lang) {
                          ref.read(localeProvider.notifier).setLocale(lang);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Contenu
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Logo + ligne
                      Transform.translate(
                        offset: Offset(0, _contentSlide.value),
                        child: Opacity(
                          opacity: _contentFade.value,
                          child: Column(
                            children: [
                              Text(
                                'VEGECE',
                                style: TextStyle(
                                  fontFamily: 'SFPRO',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 10,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 36,
                                height: 1,
                                color: VegeceColors.pink,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Question
                      Opacity(
                        opacity: _contentFade.value,
                        child: Text(
                          l10n.youAre,
                          style: TextStyle(
                            fontFamily: 'SFPRO',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2,
                            color: subtitleColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Bouton Particulier
                      Opacity(
                        opacity: _btn1Fade.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _btn1Fade.value)),
                          child: _SelectionButton(
                            label: l10n.individual,
                            isPrimary: true,
                            isDark: isDark,
                            onPressed: () => context.push('/start/user'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Bouton Professionnel
                      Opacity(
                        opacity: _btn2Fade.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _btn2Fade.value)),
                          child: _SelectionButton(
                            label: l10n.professional,
                            isPrimary: false,
                            isDark: isDark,
                            onPressed: () => context.push('/start/pro'),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Footer
                      Opacity(
                        opacity: _contentFade.value * 0.6,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Text(
                            l10n.termsOfUse,
                            style: TextStyle(
                              fontFamily: 'SFPRO',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: subtitleColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
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
// TOGGLE THÈME
// ═══════════════════════════════════════════════════════════════

class _ThemeToggle extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _ThemeToggle({
    required this.isDark,
    required this.onToggle,
  });

  @override
  State<_ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
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
        ? VegeceColors.white.withOpacity(0.1)
        : VegeceColors.textDark.withOpacity(0.05);
    final borderColor = widget.isDark
        ? VegeceColors.white.withOpacity(0.15)
        : VegeceColors.textGrey.withOpacity(0.15);
    final iconColor = widget.isDark ? VegeceColors.white : VegeceColors.textDark;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onToggle();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isPressed ? bgColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween(begin: 0.5, end: 1.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(widget.isDark),
                  size: 18,
                  color: iconColor,
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
// SÉLECTEUR DE LANGUE
// ═══════════════════════════════════════════════════════════════

class _LanguageSelector extends StatefulWidget {
  final AppLanguage currentLanguage;
  final bool isDark;
  final ValueChanged<AppLanguage> onChanged;

  const _LanguageSelector({
    required this.currentLanguage,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<_LanguageSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showLanguageMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu<AppLanguage>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + button.size.height + 8,
        overlay.size.width - position.dx - button.size.width,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: AppLanguage.values.map((lang) {
        final isSelected = lang == widget.currentLanguage;
        return PopupMenuItem<AppLanguage>(
          value: lang,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(
                lang.name,
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? VegeceColors.pink : VegeceColors.textDark,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: 16, color: VegeceColors.pink),
              ],
            ],
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null && selected != widget.currentLanguage) {
        widget.onChanged(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? VegeceColors.white.withOpacity(0.1)
        : VegeceColors.textGrey.withOpacity(0.08);
    final borderColor = widget.isDark
        ? VegeceColors.white.withOpacity(0.15)
        : VegeceColors.textGrey.withOpacity(0.15);
    final textColor = widget.isDark ? VegeceColors.white : VegeceColors.textDark;
    final iconColor = widget.isDark ? VegeceColors.white.withOpacity(0.7) : VegeceColors.textGrey;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        _showLanguageMenu();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isPressed ? bgColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.currentLanguage.flag,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.currentLanguage.code.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: iconColor,
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

// ═══════════════════════════════════════════════════════════════
// LOADING DOTS
// ═══════════════════════════════════════════════════════════════

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (progress < 0.5)
                ? (progress * 2)
                : (2 - progress * 2);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VegeceColors.pink.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOUTON DE SÉLECTION
// ═══════════════════════════════════════════════════════════════

class _SelectionButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final bool isDark;
  final VoidCallback onPressed;

  const _SelectionButton({
    required this.label,
    required this.isPrimary,
    required this.isDark,
    required this.onPressed,
  });

  @override
  State<_SelectionButton> createState() => _SelectionButtonState();
}

class _SelectionButtonState extends State<_SelectionButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _hoverController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _hoverController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs dynamiques pour le bouton secondaire selon le thème
    final secondaryBgColor = widget.isDark
        ? (_isPressed ? VegeceColors.white.withOpacity(0.1) : Colors.transparent)
        : (_isPressed ? const Color(0xFFFAFAFA) : VegeceColors.bgLight);
    final secondaryBorderColor = widget.isDark
        ? (_isPressed ? VegeceColors.white.withOpacity(0.25) : VegeceColors.white.withOpacity(0.15))
        : (_isPressed ? VegeceColors.textGrey.withOpacity(0.25) : VegeceColors.textGrey.withOpacity(0.12));
    final secondaryTextColor = widget.isDark ? VegeceColors.white : VegeceColors.textDark;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: widget.isPrimary
                    ? (_isPressed ? VegeceColors.pinkDark : VegeceColors.pink)
                    : secondaryBgColor,
                borderRadius: BorderRadius.circular(10),
                border: widget.isPrimary
                    ? null
                    : Border.all(color: secondaryBorderColor, width: 1),
                boxShadow: widget.isPrimary
                    ? [
                        BoxShadow(
                          color: VegeceColors.pink.withOpacity(_isPressed ? 0.15 : 0.25),
                          blurRadius: _isPressed ? 8 : 16,
                          offset: Offset(0, _isPressed ? 2 : 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'SFPRO',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: widget.isPrimary ? VegeceColors.white : secondaryTextColor,
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
