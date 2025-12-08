import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/session_controller.dart';

// Couleurs Vegece
class VegeceColors {
  // Dark theme (splash)
  static const Color bgDark = Color(0xFF0B0B0B);
  // Light theme (selection)
  static const Color bgLight = Color(0xFFFCFCFC);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF6B7280);
  // Accents
  static const Color white = Color(0xFFFCFCFC);
  static const Color pink = Color(0xFFF2968F);
  static const Color pinkDark = Color(0xFFFB676D);
  static const Color pinkLight = Color(0xFFFDBDB9);
  static const Color pinkSoft = Color(0xFFFFF1F0);
}

class RoleGateScreen extends ConsumerStatefulWidget {
  const RoleGateScreen({super.key});

  @override
  ConsumerState<RoleGateScreen> createState() => _RoleGateScreenState();
}

class _RoleGateScreenState extends ConsumerState<RoleGateScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _lineController;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _lineAnimation;

  // Délai minimum du splash screen (5 secondes)
  bool _splashMinTimeElapsed = false;

  @override
  void initState() {
    super.initState();

    // Timer pour le délai minimum du splash (5 secondes)
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() {
          _splashMinTimeElapsed = true;
        });
      }
    });

    // Animation de glow pulsant subtil
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Animation de fade in élégant
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Animation de la ligne décorative
    _lineController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..forward();

    _lineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _lineController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // ✅ Afficher le splash tant que le bootstrap n'est pas terminé OU que le délai minimum n'est pas écoulé
    if (!session.bootstrapped || !_splashMinTimeElapsed) {
      return _buildPrestigeSplash();
    }

    // ✅ Si déjà connecté, rediriger vers la bonne page selon le rôle
    if (session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final targetRoute = getHomeRouteForSession(session);
          context.go(targetRoute);
        }
      });
      return _buildPrestigeSplash();
    }

    // Écran de choix (Particulier / Professionnel)
    return _buildSelectionScreen(context);
  }

  // ═══════════════════════════════════════════════════════════════
  // SPLASH SCREEN PRESTIGE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPrestigeSplash() {
    return Scaffold(
      backgroundColor: VegeceColors.bgDark,
      body: AnimatedBuilder(
        animation: Listenable.merge([_glowAnimation, _fadeAnimation, _lineAnimation]),
        builder: (context, child) {
          return Stack(
            children: [
              // Fond avec gradient subtil
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        Color.lerp(
                          VegeceColors.bgDark,
                          VegeceColors.pink.withOpacity(0.03),
                          _glowAnimation.value,
                        )!,
                        VegeceColors.bgDark,
                      ],
                    ),
                  ),
                ),
              ),

              // Contenu central
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Texte VEGECE
                      Text(
                        'VEGECE',
                        style: TextStyle(
                          fontFamily: 'SFPRO',
                          fontSize: 46,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 18,
                          color: VegeceColors.white,
                          shadows: [
                            Shadow(
                              color: VegeceColors.pink.withOpacity(_glowAnimation.value * 0.4),
                              blurRadius: 40 + (_glowAnimation.value * 20),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Ligne décorative animée
                      SizeTransition(
                        sizeFactor: _lineAnimation,
                        axis: Axis.horizontal,
                        child: Container(
                          width: 60,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                VegeceColors.pink.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tagline subtile
                      Opacity(
                        opacity: _fadeAnimation.value * 0.5,
                        child: Text(
                          'Le bien-être animal',
                          style: TextStyle(
                            fontFamily: 'SFPRO',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 4,
                            color: VegeceColors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Indicateur de chargement en bas (très discret)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          VegeceColors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ÉCRAN DE SÉLECTION MINIMALISTE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSelectionScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: VegeceColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo VEGECE minimaliste
              const Text(
                'VEGECE',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  color: VegeceColors.textDark,
                ),
              ),

              const SizedBox(height: 16),

              // Ligne décorative fine
              Container(
                width: 50,
                height: 1.5,
                color: VegeceColors.pink,
              ),

              const Spacer(flex: 4),

              // Question simple
              Text(
                'Vous êtes',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                  color: VegeceColors.textGrey,
                ),
              ),

              const SizedBox(height: 32),

              // Bouton Particulier - style épuré
              _MinimalButton(
                label: 'Particulier',
                isPrimary: true,
                onPressed: () => context.push('/start/user'),
              ),

              const SizedBox(height: 16),

              // Bouton Professionnel - style épuré
              _MinimalButton(
                label: 'Professionnel',
                isPrimary: false,
                onPressed: () => context.push('/start/pro'),
              ),

              const Spacer(flex: 3),

              // Footer discret
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Conditions d\'utilisation',
                  style: TextStyle(
                    fontFamily: 'SFPRO',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                    color: VegeceColors.textGrey.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOUTON MINIMALISTE
// ═══════════════════════════════════════════════════════════════

class _MinimalButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _MinimalButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<_MinimalButton> createState() => _MinimalButtonState();
}

class _MinimalButtonState extends State<_MinimalButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: widget.isPrimary
              ? (_isPressed ? VegeceColors.pinkDark : VegeceColors.pink)
              : (_isPressed ? const Color(0xFFF5F5F5) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: widget.isPrimary
              ? null
              : Border.all(
                  color: _isPressed
                      ? VegeceColors.textGrey.withOpacity(0.3)
                      : VegeceColors.textGrey.withOpacity(0.15),
                  width: 1,
                ),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'SFPRO',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: widget.isPrimary
                  ? VegeceColors.white
                  : VegeceColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
