// lib/features/bookings/booking_proximity_confirmation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _green = Color(0xFF43AA8B);
const _greenSoft = Color(0xFFE8F5F0);

/// Écran de confirmation de visite affiché quand le client est proche du cabinet
class BookingProximityConfirmationScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingData;

  const BookingProximityConfirmationScreen({
    super.key,
    required this.bookingId,
    this.bookingData,
  });

  @override
  ConsumerState<BookingProximityConfirmationScreen> createState() =>
      _BookingProximityConfirmationScreenState();
}

class _BookingProximityConfirmationScreenState
    extends ConsumerState<BookingProximityConfirmationScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  // Pour l'OTP
  String? _otpCode;
  int _otpExpiresInSeconds = 0;
  Timer? _otpTimer;
  bool _showOtpSection = false;

  // Pour le rating
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _otpTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  /// Confirmation simple (juste un tap)
  Future<void> _confirmSimple() async {
    await _confirmWithMethod('SIMPLE');
  }

  /// Confirmer avec méthode spécifiée
  Future<void> _confirmWithMethod(String method) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiProvider);
      await api.clientConfirmWithMethod(
        bookingId: widget.bookingId,
        method: method,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre confirmation a été envoyée'),
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
      final result = await api.getBookingOtp(widget.bookingId);

      if (!mounted) return;

      setState(() {
        _otpCode = result['otp']?.toString();
        _otpExpiresInSeconds = (result['expiresInSeconds'] as num?)?.toInt() ?? 600;
      });

      // Démarrer le timer
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

  /// Régénérer le code OTP
  Future<void> _regenerateOtp() async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      final result = await api.generateBookingOtp(widget.bookingId);

      if (!mounted) return;

      setState(() {
        _otpCode = result['otp']?.toString();
        _otpExpiresInSeconds = (result['expiresInSeconds'] as num?)?.toInt() ?? 600;
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
    // Essayer plusieurs chemins possibles pour trouver le petId
    String? petId;

    // 1. petIds (nouveau format - liste)
    final petIds = widget.bookingData?['petIds'] as List?;
    if (petIds != null && petIds.isNotEmpty) {
      petId = petIds.first?.toString();
    }

    // 2. pet.id (format avec objet pet)
    if (petId == null) {
      final pet = widget.bookingData?['pet'] as Map<String, dynamic>?;
      petId = pet?['id']?.toString();
    }

    // 3. petId (format simple)
    if (petId == null) {
      petId = widget.bookingData?['petId']?.toString();
    }

    if (petId != null && petId.isNotEmpty) {
      context.push('/pets/$petId/qr');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun animal associé à ce rendez-vous'),
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
    final providerName =
        widget.bookingData?['provider']?['displayName']?.toString() ??
            'votre vétérinaire';
    final serviceTitle =
        widget.bookingData?['service']?['title']?.toString() ?? 'Rendez-vous';
    final scheduledAtStr = widget.bookingData?['scheduledAt']?.toString();
    DateTime? scheduledAt;
    if (scheduledAtStr != null) {
      scheduledAt = DateTime.tryParse(scheduledAtStr);
    }
    // ✅ Pas de .toLocal() - les heures sont stockées en "UTC naïf"
    final dateStr = scheduledAt != null
        ? DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(scheduledAt)
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
        title: const Text('Confirmer votre visite'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête avec icône de localisation
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
                      Icons.location_on,
                      color: _green,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Vous êtes à proximité de votre rendez-vous !',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'N\'oubliez pas de confirmer votre visite chez $providerName',
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
                        color: _coralSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: _coral),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    serviceTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section Rating
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comment s\'est passé votre rendez-vous ?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= _rating ? Icons.star : Icons.star_border,
                          color: Colors.orange,
                          size: 36,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _rating = starValue),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    enabled: !_isLoading,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Commentaire (optionnel)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Erreur
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // ✅ Code de référence (pour vets sans caméra)
            if (widget.bookingData?['referenceCode'] != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF577590).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF577590).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tag,
                            color: Color(0xFF577590),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Code de référence',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      widget.bookingData!['referenceCode'].toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF577590),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Donnez ce code au vétérinaire s\'il n\'a pas de caméra',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bouton 1: Confirmer ma visite (simple)
            _ConfirmButton(
              icon: Icons.check_circle,
              label: 'Confirmer ma visite',
              subtitle: 'Confirmation rapide en un tap',
              color: _green,
              isLoading: _isLoading,
              onPressed: _confirmSimple,
            ),

            const SizedBox(height: 12),

            // Bouton 2: Confirmer avec code OTP
            _ConfirmButton(
              icon: Icons.pin,
              label: 'Confirmer avec code OTP',
              subtitle: 'Montrez le code au vétérinaire',
              color: _coral,
              isLoading: _isLoading,
              onPressed: _showOtpCode,
            ),

            // Section OTP (affichée après clic)
            if (_showOtpSection) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _coral.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Votre code de confirmation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_otpCode != null) ...[
                      GestureDetector(
                        onTap: _copyOtp,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _coralSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _otpCode!,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 8,
                                  color: _coral,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.copy, color: _coral, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Expire dans ${_formatExpiration(_otpExpiresInSeconds)}',
                            style: TextStyle(
                              color: _otpExpiresInSeconds < 60
                                  ? Colors.red
                                  : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _regenerateOtp,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Nouveau code'),
                      ),
                    ] else if (_isLoading) ...[
                      const CircularProgressIndicator(color: _coral),
                    ] else ...[
                      const Text('Code expiré'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _regenerateOtp,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Générer un nouveau code'),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bouton 3: Scanner QR animal
            _ConfirmButton(
              icon: Icons.qr_code_scanner,
              label: 'Scanner mon QR animal',
              subtitle: 'Afficher le dossier médical au vétérinaire',
              color: const Color(0xFF577590),
              isLoading: _isLoading,
              onPressed: _goToQrScan,
            ),

            const SizedBox(height: 24),

            // Lien pour annuler
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : () => context.pop(),
                child: const Text(
                  'Plus tard',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget bouton de confirmation
class _ConfirmButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.black.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
