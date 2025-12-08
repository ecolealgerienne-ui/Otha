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
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Délai minimum du splash screen (2 secondes)
  bool _splashMinTimeElapsed = false;

  @override
  void initState() {
    super.initState();

    // Timer pour le délai minimum du splash
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _splashMinTimeElapsed = true;
        });
      }
    });

    // Animation de glow pulsant (rose)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Animation de fade in
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Animation de scale subtle
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // ✅ Afficher le splash tant que le bootstrap n'est pas terminé OU que le délai minimum n'est pas écoulé
    if (!session.bootstrapped || !_splashMinTimeElapsed) {
      return _buildAnimatedSplash();
    }

    // ✅ Si déjà connecté, rediriger vers la bonne page selon le rôle
    if (session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final targetRoute = getHomeRouteForSession(session);
          context.go(targetRoute);
        }
      });
      return _buildAnimatedSplash();
    }

    // Écran de choix (Particulier / Professionnel) - Design CLAIR
    return _buildSelectionScreen(context);
  }

  // Splash screen sombre avec animation
  Widget _buildAnimatedSplash() {
    return Scaffold(
      backgroundColor: VegeceColors.bgDark,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_glowAnimation, _fadeAnimation, _scaleAnimation]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo VEGECE avec effet glow rose
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            VegeceColors.white,
                            Color.lerp(
                              VegeceColors.white,
                              VegeceColors.pink,
                              _glowAnimation.value * 0.3,
                            )!,
                            VegeceColors.white,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'VEGECE',
                        style: TextStyle(
                          fontFamily: 'SFPRO',
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 12,
                          color: VegeceColors.white,
                          shadows: [
                            Shadow(
                              color: VegeceColors.pink.withOpacity(_glowAnimation.value * 0.6),
                              blurRadius: 30 + (_glowAnimation.value * 20),
                            ),
                            Shadow(
                              color: VegeceColors.pinkDark.withOpacity(_glowAnimation.value * 0.4),
                              blurRadius: 60 + (_glowAnimation.value * 30),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Loading indicator avec glow rose
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.lerp(
                            VegeceColors.white.withOpacity(0.6),
                            VegeceColors.pink,
                            _glowAnimation.value,
                          )!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Écran de sélection CLAIR
  Widget _buildSelectionScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: VegeceColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Icône patte avec fond rose
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [VegeceColors.pink, VegeceColors.pinkDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: VegeceColors.pink.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pets,
                  size: 40,
                  color: VegeceColors.white,
                ),
              ),

              const SizedBox(height: 24),

              // Logo VEGECE
              const Text(
                'VEGECE',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  color: VegeceColors.textDark,
                ),
              ),

              const SizedBox(height: 8),

              // Tagline
              Text(
                'Le bien-être de vos animaux',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                  color: VegeceColors.textGrey,
                ),
              ),

              const Spacer(flex: 2),

              // Texte d'intro
              Text(
                'Bienvenue',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: VegeceColors.textDark,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choisissez votre profil pour continuer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: VegeceColors.textGrey,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              // Bouton Particulier (primaire)
              _VegecePrimaryButtonLight(
                label: 'Particulier',
                subtitle: 'Propriétaire d\'animaux',
                icon: Icons.person_outline,
                onPressed: () => context.push('/start/user'),
              ),

              const SizedBox(height: 16),

              // Bouton Professionnel (secondaire)
              _VegeceSecondaryButtonLight(
                label: 'Professionnel',
                subtitle: 'Vétérinaire, toiletteur...',
                icon: Icons.medical_services_outlined,
                onPressed: () => context.push('/start/pro'),
              ),

              const Spacer(flex: 1),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'En continuant, vous acceptez nos conditions d\'utilisation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SFPRO',
                    fontSize: 12,
                    color: VegeceColors.textGrey.withOpacity(0.7),
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

// Bouton primaire rose (thème clair)
class _VegecePrimaryButtonLight extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  const _VegecePrimaryButtonLight({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_VegecePrimaryButtonLight> createState() => _VegecePrimaryButtonLightState();
}

class _VegecePrimaryButtonLightState extends State<_VegecePrimaryButtonLight> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [VegeceColors.pink, VegeceColors.pinkDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: VegeceColors.pink.withOpacity(_isPressed ? 0.2 : 0.35),
              blurRadius: _isPressed ? 8 : 16,
              offset: Offset(0, _isPressed ? 2 : 6),
            ),
          ],
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VegeceColors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: VegeceColors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: VegeceColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: VegeceColors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: VegeceColors.white.withOpacity(0.8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// Bouton secondaire outline (thème clair)
class _VegeceSecondaryButtonLight extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  const _VegeceSecondaryButtonLight({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_VegeceSecondaryButtonLight> createState() => _VegeceSecondaryButtonLightState();
}

class _VegeceSecondaryButtonLightState extends State<_VegeceSecondaryButtonLight> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: _isPressed ? VegeceColors.pinkSoft : VegeceColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VegeceColors.pink.withOpacity(_isPressed ? 0.6 : 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VegeceColors.pinkSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: VegeceColors.pinkDark,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: VegeceColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: VegeceColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: VegeceColors.textGrey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
