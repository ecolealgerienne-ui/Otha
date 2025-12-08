import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/session_controller.dart';

// Couleurs Vegece
class VegeceColors {
  static const Color bgPrimary = Color(0xFF0B0B0B);
  static const Color white = Color(0xFFFCFCFC);
  static const Color pink = Color(0xFFF2968F);
  static const Color pinkDark = Color(0xFFFB676D);
  static const Color pinkLight = Color(0xFFFDBDB9);
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

  @override
  void initState() {
    super.initState();

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

    // ✅ Si bootstrap pas encore terminé, afficher le splash animé
    if (!session.bootstrapped) {
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

    // Écran de choix (Particulier / Professionnel)
    return _buildSelectionScreen(context);
  }

  Widget _buildAnimatedSplash() {
    return Scaffold(
      backgroundColor: VegeceColors.bgPrimary,
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

  Widget _buildSelectionScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: VegeceColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo VEGECE
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Text(
                    'VEGECE',
                    style: TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                      color: VegeceColors.white,
                      shadows: [
                        Shadow(
                          color: VegeceColors.pink.withOpacity(_glowAnimation.value * 0.5),
                          blurRadius: 25 + (_glowAnimation.value * 15),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Tagline
              Text(
                'Le bien-être de vos animaux',
                style: TextStyle(
                  fontFamily: 'SFPRO',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: VegeceColors.white.withOpacity(0.6),
                ),
              ),

              const Spacer(flex: 3),

              // Bouton Particulier
              _VegecePrimaryButton(
                label: 'Particulier',
                onPressed: () => context.push('/start/user'),
              ),

              const SizedBox(height: 16),

              // Bouton Professionnel
              _VegeceSecondaryButton(
                label: 'Professionnel',
                onPressed: () => context.push('/start/pro'),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// Bouton primaire rose avec effet glow
class _VegecePrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _VegecePrimaryButton({required this.label, required this.onPressed});

  @override
  State<_VegecePrimaryButton> createState() => _VegecePrimaryButtonState();
}

class _VegecePrimaryButtonState extends State<_VegecePrimaryButton> {
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
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [VegeceColors.pink, VegeceColors.pinkDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: VegeceColors.pink.withOpacity(_isPressed ? 0.2 : 0.4),
              blurRadius: _isPressed ? 10 : 20,
              offset: Offset(0, _isPressed ? 2 : 8),
            ),
          ],
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'SFPRO',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: VegeceColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// Bouton secondaire outline
class _VegeceSecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _VegeceSecondaryButton({required this.label, required this.onPressed});

  @override
  State<_VegeceSecondaryButton> createState() => _VegeceSecondaryButtonState();
}

class _VegeceSecondaryButtonState extends State<_VegeceSecondaryButton> {
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
        height: 56,
        decoration: BoxDecoration(
          color: _isPressed
              ? VegeceColors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: VegeceColors.white.withOpacity(_isPressed ? 0.5 : 0.3),
            width: 1.5,
          ),
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'SFPRO',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: VegeceColors.white.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }
}
