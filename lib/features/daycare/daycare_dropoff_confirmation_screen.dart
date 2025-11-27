// lib/features/daycare/daycare_dropoff_confirmation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _green = Color(0xFF22C55E);
const _greenSoft = Color(0xFFE8F5E9);
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

/// Écran de confirmation du dépôt d'animal en garderie
class DaycareDropOffConfirmationScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingData;
  final double? lat;
  final double? lng;

  const DaycareDropOffConfirmationScreen({
    super.key,
    required this.bookingId,
    this.bookingData,
    this.lat,
    this.lng,
  });

  @override
  ConsumerState<DaycareDropOffConfirmationScreen> createState() =>
      _DaycareDropOffConfirmationScreenState();
}

class _DaycareDropOffConfirmationScreenState
    extends ConsumerState<DaycareDropOffConfirmationScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  // Pour l'OTP
  String? _otpCode;
  int _otpExpiresInSeconds = 0;
  Timer? _otpTimer;
  bool _showOtpSection = false;

  @override
  void initState() {
    super.initState();
    // Notifier le pro que le client est à proximité
    _notifyNearby();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  /// Notifier le pro que le client est à proximité
  Future<void> _notifyNearby() async {
    try {
      final api = ref.read(apiProvider);
      await api.notifyDaycareClientNearby(
        widget.bookingId,
        lat: widget.lat,
        lng: widget.lng,
      );
    } catch (e) {
      // Ignorer les erreurs silencieusement
    }
  }

  /// Confirmer le dépôt de l'animal
  Future<void> _confirmDropOff() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiProvider);
      await api.clientConfirmDaycareDropOff(
        widget.bookingId,
        method: 'PROXIMITY',
        lat: widget.lat,
        lng: widget.lng,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépôt confirmé ! La garderie va valider.'),
          backgroundColor: _green,
        ),
      );

      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Afficher le code OTP
  Future<void> _showOtpCode() async {
    setState(() {
      _showOtpSection = true;
      _isLoading = true;
    });

    try {
      final api = ref.read(apiProvider);
      // D'abord confirmer le dépôt pour générer l'OTP
      await api.clientConfirmDaycareDropOff(
        widget.bookingId,
        method: 'OTP',
        lat: widget.lat,
        lng: widget.lng,
      );

      // Ensuite récupérer l'OTP
      final result = await api.getDaycareDropOtp(widget.bookingId);

      if (!mounted) return;

      setState(() {
        _otpCode = result['otp']?.toString();
        final expiresAt = result['expiresAt']?.toString();
        if (expiresAt != null) {
          final expires = DateTime.tryParse(expiresAt);
          if (expires != null) {
            _otpExpiresInSeconds = expires.difference(DateTime.now()).inSeconds;
            if (_otpExpiresInSeconds < 0) _otpExpiresInSeconds = 0;
          }
        } else {
          _otpExpiresInSeconds = 600; // 10 minutes par défaut
        }
      });

      _startOtpTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _otpExpiresInSeconds--;
        if (_otpExpiresInSeconds <= 0) {
          timer.cancel();
          _otpCode = null;
        }
      });
    });
  }

  /// Copier le code OTP
  void _copyOtp() {
    if (_otpCode == null) return;
    Clipboard.setData(ClipboardData(text: _otpCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié !')),
    );
  }

  /// Aller au scan QR
  void _goToQrScan() {
    // Naviguer vers l'écran de QR code de l'animal
    final pet = widget.bookingData?['pet'] as Map<String, dynamic>?;
    final petId = pet?['id']?.toString() ?? widget.bookingData?['petId']?.toString();

    if (petId != null && petId.isNotEmpty) {
      context.push('/pets/$petId/qr');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun animal associé à cette réservation'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatExpiration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final providerName = widget.bookingData?['provider']?['displayName']?.toString() ?? 'la garderie';
    final pet = widget.bookingData?['pet'] as Map<String, dynamic>?;
    final petName = pet?['name']?.toString() ?? 'Votre animal';
    final startDateStr = widget.bookingData?['startDate']?.toString();
    DateTime? startDate;
    if (startDateStr != null) {
      startDate = DateTime.tryParse(startDateStr);
    }
    final dateStr = startDate != null
        ? DateFormat('EEEE d MMMM', 'fr_FR').format(startDate)
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Confirmer le dépôt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête avec icône
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _greenSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.pets,
                      color: _green,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Déposer $petName',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous êtes à proximité de $providerName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _greenSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: _green),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section OTP (si activée)
            if (_showOtpSection) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _green.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Code de vérification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Montrez ce code à la garderie',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_otpCode != null) ...[
                      GestureDetector(
                        onTap: _copyOtp,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _greenSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _otpCode!,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 8,
                                  color: _green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.copy, color: _green),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Expire dans ${_formatExpiration(_otpExpiresInSeconds)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _otpExpiresInSeconds < 60 ? _coral : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (_isLoading) ...[
                      const CircularProgressIndicator(color: _green),
                    ] else ...[
                      const Text(
                        'Code expiré',
                        style: TextStyle(color: _coral, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Message d'erreur
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _coralSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: _coral),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: _coral),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Boutons d'action
            const Text(
              'Choisissez une méthode de confirmation :',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Bouton Scanner QR
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _goToQrScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner le QR code de l\'animal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Bouton Afficher OTP
            if (!_showOtpSection)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _showOtpCode,
                icon: const Icon(Icons.pin),
                label: const Text('Obtenir un code de vérification'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Bouton principal de confirmation
            FilledButton.icon(
              onPressed: _isLoading ? null : _confirmDropOff,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(_isLoading ? 'Confirmation...' : 'Confirmer le dépôt'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La garderie recevra une notification et devra valider le dépôt de votre animal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
