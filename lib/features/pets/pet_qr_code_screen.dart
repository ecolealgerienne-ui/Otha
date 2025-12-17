// lib/features/pets/pet_qr_code_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import 'pet_medical_history_screen.dart';

// Theme colors
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _green = Color(0xFF43AA8B);
const _greenSoft = Color(0xFFE8F5E9);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardAlt = Color(0xFF2A2A2A);

// Expiration time in minutes (30 minutes)
const _expirationMinutes = 30;

class PetQrCodeScreen extends ConsumerStatefulWidget {
  final String petId;
  final String? bookingId;

  const PetQrCodeScreen({super.key, required this.petId, this.bookingId});

  @override
  ConsumerState<PetQrCodeScreen> createState() => _PetQrCodeScreenState();
}

class _PetQrCodeScreenState extends ConsumerState<PetQrCodeScreen>
    with SingleTickerProviderStateMixin {
  String? _token;
  DateTime? _expiresAt;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _bookingConfirmed = false;
  int _remainingSeconds = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _generateToken();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkBookingStatus();
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_expiresAt == null) return;

    _remainingSeconds = _expiresAt!.difference(DateTime.now()).inSeconds;
    if (_remainingSeconds <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds = _expiresAt!.difference(DateTime.now()).inSeconds;
        if (_remainingSeconds <= 0) {
          _countdownTimer?.cancel();
          // Auto-regenerate when expired
          _generateToken();
        }
      });
    });
  }

  Future<void> _checkBookingStatus() async {
    if (_bookingConfirmed) return;

    try {
      final api = ref.read(apiProvider);
      final booking = await api.findActiveBookingForPet(widget.petId);

      if (booking != null && booking['status'] == 'COMPLETED') {
        setState(() => _bookingConfirmed = true);
        _pollTimer?.cancel();
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  void _showSuccessDialog() {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? _green.withOpacity(0.15) : _greenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: _green, size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.appointmentConfirmed,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'SFPRO',
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.visitRegisteredSuccess,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'SFPRO',
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/home');
              },
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.backToHome,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SFPRO',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateToken() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final result = await api.generatePetAccessToken(
        widget.petId,
        expirationMinutes: _expirationMinutes,
      );

      setState(() {
        _token = result['token']?.toString();
        final expiresStr = result['expiresAt']?.toString();
        if (expiresStr != null) {
          _expiresAt = DateTime.tryParse(expiresStr);
        } else {
          // Fallback: calculate expiry from now
          _expiresAt = DateTime.now().add(const Duration(minutes: _expirationMinutes));
        }
        _isLoading = false;
      });
      _startCountdown();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCountdown() {
    if (_remainingSeconds <= 0) return '00:00';
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progressValue {
    final totalSeconds = _expirationMinutes * 60;
    return (_remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final petAsync = ref.watch(petInfoProvider(widget.petId));
    final petName = petAsync.whenOrNull(data: (pet) => pet?['name']?.toString()) ?? 'Animal';
    final petSpecies = petAsync.whenOrNull(data: (pet) => pet?['species']?.toString());
    final petPhoto = petAsync.whenOrNull(data: (pet) => pet?['photoUrl']?.toString());

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? _darkBg : _coralSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _coral),
          ),
        ),
        title: Text(
          l10n.medicalQrCode,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            fontFamily: 'SFPRO',
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _coral))
          : _error != null
              ? _buildErrorState(isDark, l10n, textPrimary, textSecondary)
              : _buildContent(isDark, l10n, cardColor, textPrimary, textSecondary, petName, petSpecies, petPhoto),
    );
  }

  Widget _buildErrorState(bool isDark, AppLocalizations l10n, Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(isDark ? 0.15 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: Colors.red),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.error,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'SFPRO',
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'SFPRO',
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _generateToken,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    bool isDark,
    AppLocalizations l10n,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    String petName,
    String? petSpecies,
    String? petPhoto,
  ) {
    final hasPhoto = petPhoto != null && petPhoto.startsWith('http');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Pet info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pet avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                    borderRadius: BorderRadius.circular(16),
                    image: hasPhoto
                        ? DecorationImage(
                            image: NetworkImage(petPhoto!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasPhoto
                      ? null
                      : Center(
                          child: Text(
                            _getSpeciesEmoji(petSpecies),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        petName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'SFPRO',
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.medicalQrCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'SFPRO',
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.active,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SFPRO',
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // QR Code card with pulse animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _coral.withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: _coral.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _token != null
                        ? QrImageView(
                            data: _token!,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF2D2D2D),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF2D2D2D),
                            ),
                            embeddedImage: null,
                          )
                        : const SizedBox(width: 200, height: 200),
                  ),

                  const SizedBox(height: 20),

                  // Countdown timer
                  Column(
                    children: [
                      Text(
                        l10n.expiresIn,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'SFPRO',
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatCountdown(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'SFPRO',
                          color: _remainingSeconds < 60 ? Colors.red : _coral,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progressValue,
                          backgroundColor: isDark ? _darkCardAlt : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _remainingSeconds < 60 ? Colors.red : _coral,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Instructions card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : _coral.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.info_outline_rounded, color: _coral, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.instructions,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'SFPRO',
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstruction(isDark, '1', l10n.qrInstruction1, textSecondary),
                const SizedBox(height: 12),
                _buildInstruction(isDark, '2', l10n.qrInstruction2, textSecondary),
                const SizedBox(height: 12),
                _buildInstruction(isDark, '3', l10n.qrInstruction3, textSecondary),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Regenerate button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generateToken,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.generateNewCode),
              style: OutlinedButton.styleFrom(
                foregroundColor: _coral,
                side: BorderSide(color: _coral.withOpacity(0.5), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInstruction(bool isDark, String number, String text, Color textSecondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'SFPRO',
                color: _coral,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'SFPRO',
                color: textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getSpeciesEmoji(String? species) {
    switch (species?.toLowerCase()) {
      case 'dog':
        return '🐕';
      case 'cat':
        return '🐱';
      case 'bird':
        return '🐦';
      case 'rodent':
        return '🐹';
      case 'reptile':
        return '🦎';
      default:
        return '🐾';
    }
  }
}
