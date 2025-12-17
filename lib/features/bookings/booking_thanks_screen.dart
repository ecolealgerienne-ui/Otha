// lib/features/bookings/booking_thanks_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale_provider.dart';

class BookingThanksScreen extends ConsumerStatefulWidget {
  const BookingThanksScreen({super.key, required this.createdBooking});

  final Map<String, dynamic> createdBooking;

  @override
  ConsumerState<BookingThanksScreen> createState() => _BookingThanksScreenState();
}

class _BookingThanksScreenState extends ConsumerState<BookingThanksScreen>
    with TickerProviderStateMixin {
  static const _coral = Color(0xFFF36C6C);
  static const _coralSoft = Color(0xFFFFEEF0);
  static const _darkBg = Color(0xFF121212);
  static const _darkCard = Color(0xFF1E1E1E);

  late AnimationController _checkController;
  late AnimationController _pulseController;
  late AnimationController _confettiController;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Check animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // Pulse animation for the circle
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _checkController.forward();
        _confettiController.forward();
      }
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final id = (widget.createdBooking['id'] ?? '').toString();

    final bgColor = isDark ? _darkBg : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background with Vegece branding
          _buildBackground(isDark),

          // Confetti
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  progress: _confettiController.value,
                  isDark: isDark,
                ),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated check circle
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _coral,
                                        _coral.withOpacity(0.8),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _coral.withOpacity(0.4),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 60 * _checkAnimation.value,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Thank you text
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _checkAnimation.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _checkAnimation.value.clamp(0.0, 1.0))),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Text(
                            l10n.thankYou,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: _coral,
                              fontFamily: 'SFPRO',
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.bookingConfirmedTitle,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              fontFamily: 'SFPRO',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info card
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, child) {
                        final delay = (_checkAnimation.value - 0.3).clamp(0.0, 1.0) / 0.7;
                        return Opacity(
                          opacity: delay,
                          child: Transform.translate(
                            offset: Offset(0, 30 * (1 - delay)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? _darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.1) : _coralSoft,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.3)
                                  : _coral.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Pending notification icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.amber.withOpacity(0.2)
                                    : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.notifications_active_outlined,
                                color: Colors.amber.shade700,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.bookingPendingMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: textSecondary,
                                fontFamily: 'SFPRO',
                              ),
                            ),
                            if (id.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? _coral.withOpacity(0.15)
                                      : _coralSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.confirmation_number_outlined,
                                      size: 16,
                                      color: _coral,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${l10n.bookingRef} #${id.length > 8 ? id.substring(0, 8) : id}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _coral,
                                        fontFamily: 'SFPRO',
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Buttons
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, child) {
                        final delay = (_checkAnimation.value - 0.5).clamp(0.0, 1.0) / 0.5;
                        return Opacity(
                          opacity: delay,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - delay)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          // Primary button - Back to home
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                              onPressed: () => context.go('/home'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _coral,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.home_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.backToHome,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'SFPRO',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ),
                          const SizedBox(height: 12),
                          // Secondary button - View bookings
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                              onPressed: () => context.go('/bookings'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _coral,
                                side: BorderSide(
                                  color: isDark
                                      ? _coral.withOpacity(0.5)
                                      : _coral.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.viewMyBookings,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'SFPRO',
                                    ),
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _BackgroundPainter(isDark: isDark),
      ),
    );
  }
}

/// Background painter with Vegece branding
class _BackgroundPainter extends CustomPainter {
  final bool isDark;

  _BackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Gradient background
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              const Color(0xFF121212),
              const Color(0xFF1A1A1A),
            ]
          : [
              Colors.white,
              const Color(0xFFFFF8F8),
            ],
    );

    paint.shader = bgGradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw "VEGECE" watermark in background
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'VEGECE',
        style: TextStyle(
          fontSize: size.width * 0.35,
          fontWeight: FontWeight.w900,
          color: isDark
              ? Colors.white.withOpacity(0.02)
              : const Color(0xFFF36C6C).withOpacity(0.04),
          letterSpacing: 10,
          fontFamily: 'SFPRO',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Center the watermark
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      size.height * 0.15,
    );
    textPainter.paint(canvas, offset);

    // Draw decorative circles
    final circlePaint = Paint()
      ..color = isDark
          ? const Color(0xFFF36C6C).withOpacity(0.05)
          : const Color(0xFFF36C6C).withOpacity(0.03);

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      size.width * 0.3,
      circlePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.85),
      size.width * 0.25,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Confetti painter for celebration effect
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({
    required this.progress,
    required this.isDark,
  }) : particles = List.generate(30, (i) => _ConfettiParticle(i));

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final x = particle.startX * size.width;
      final y = particle.startY * size.height +
          (progress * size.height * 0.8 * particle.speed);

      if (y > size.height) continue;

      final opacity = (1 - progress).clamp(0.0, 1.0) * particle.opacity;
      paint.color = particle.color.withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * particle.rotation * math.pi * 4);

      if (particle.isCircle) {
        canvas.drawCircle(Offset.zero, particle.size, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size * 2,
            height: particle.size,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ConfettiParticle {
  final double startX;
  final double startY;
  final double speed;
  final double rotation;
  final double size;
  final double opacity;
  final Color color;
  final bool isCircle;

  _ConfettiParticle(int index)
      : startX = (math.Random(index).nextDouble()),
        startY = -0.1 - (math.Random(index + 1).nextDouble() * 0.2),
        speed = 0.3 + math.Random(index + 2).nextDouble() * 0.7,
        rotation = math.Random(index + 3).nextDouble(),
        size = 3 + math.Random(index + 4).nextDouble() * 5,
        opacity = 0.5 + math.Random(index + 5).nextDouble() * 0.5,
        color = _colors[index % _colors.length],
        isCircle = math.Random(index + 6).nextBool();

  static const _colors = [
    Color(0xFFF36C6C), // Coral
    Color(0xFFFFB74D), // Orange
    Color(0xFF81C784), // Green
    Color(0xFF64B5F6), // Blue
    Color(0xFFBA68C8), // Purple
    Color(0xFFFFD54F), // Yellow
  ];
}
