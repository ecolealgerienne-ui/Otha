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
  // ÉCRAN DE SÉLECTION (THÈME CLAIR)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSelectionScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: VegeceColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo VEGECE
              const Text(
                'VEGECE',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 10,
                  color: VegeceColors.textDark,
                ),
              ),

              const SizedBox(height: 6),

              // Ligne décorative
              Container(
                width: 40,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [VegeceColors.pink, VegeceColors.pinkDark],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              Text(
                'Le bien-être de vos animaux',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                  color: VegeceColors.textGrey,
                ),
              ),

              const Spacer(flex: 3),

              // Texte d'intro
              const Text(
                'Bienvenue',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 26,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: VegeceColors.textGrey,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 36),

              // Bouton Particulier
              _VegecePrimaryButtonLight(
                label: 'Particulier',
                subtitle: 'Propriétaire d\'animaux',
                icon: Icons.person_outline,
                onPressed: () => context.push('/start/user'),
              ),

              const SizedBox(height: 14),

              // Bouton Professionnel
              _VegeceSecondaryButtonLight(
                label: 'Professionnel',
                subtitle: 'Vétérinaire, toiletteur...',
                icon: Icons.medical_services_outlined,
                onPressed: () => context.push('/start/pro'),
              ),

              const Spacer(flex: 2),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'En continuant, vous acceptez nos conditions d\'utilisation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SFPRO',
                    fontSize: 11,
                    color: VegeceColors.textGrey.withOpacity(0.6),
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
// BOUTONS
// ═══════════════════════════════════════════════════════════════

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [VegeceColors.pink, VegeceColors.pinkDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: VegeceColors.pink.withOpacity(_isPressed ? 0.15 : 0.3),
              blurRadius: _isPressed ? 8 : 16,
              offset: Offset(0, _isPressed ? 2 : 6),
            ),
          ],
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: VegeceColors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: VegeceColors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: VegeceColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: VegeceColors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: VegeceColors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _isPressed ? VegeceColors.pinkSoft : VegeceColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: VegeceColors.pink.withOpacity(_isPressed ? 0.5 : 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: VegeceColors.pinkSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: VegeceColors.pinkDark,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: VegeceColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: VegeceColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: VegeceColors.textGrey.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
