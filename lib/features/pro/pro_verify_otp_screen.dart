// lib/features/pro/pro_verify_otp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _green = Color(0xFF43AA8B);

/// Écran pour que le PRO vérifie le code OTP donné par le client
class ProVerifyOtpScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingData;

  const ProVerifyOtpScreen({
    super.key,
    required this.bookingId,
    this.bookingData,
  });

  @override
  ConsumerState<ProVerifyOtpScreen> createState() => _ProVerifyOtpScreenState();
}

class _ProVerifyOtpScreenState extends ConsumerState<ProVerifyOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _otpCode;
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Veuillez entrer les 6 chiffres du code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiProvider);
      await api.verifyBookingOtp(
        bookingId: widget.bookingId,
        otp: otp,
      );

      if (!mounted) return;

      setState(() {
        _isSuccess = true;
      });

      // Attendre un peu pour montrer le succès
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendez-vous confirmé avec succès !'),
          backgroundColor: _green,
        ),
      );

      context.pop(true); // Retourner true pour indiquer le succès
    } catch (e) {
      if (!mounted) return;

      String errorMsg = e.toString();
      // Nettoyer le message d'erreur
      if (errorMsg.contains('Exception:')) {
        errorMsg = errorMsg.replaceFirst('Exception:', '').trim();
      }
      if (errorMsg.contains('DioException')) {
        errorMsg = 'Code OTP invalide ou expiré';
      }

      setState(() {
        _errorMessage = errorMsg;
        // Vider les champs en cas d'erreur
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      // Passer au champ suivant
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Revenir au champ précédent
      _focusNodes[index - 1].requestFocus();
    }

    // Vérifier si tous les champs sont remplis
    if (_otpCode.length == 6) {
      _verifyOtp();
    }
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.bookingData?['user']?['displayName']?.toString() ??
        widget.bookingData?['clientName']?.toString() ??
        'Client';
    final serviceTitle =
        widget.bookingData?['service']?['title']?.toString() ?? 'Rendez-vous';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Vérifier le code OTP'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icône et titre
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
                      color: _isSuccess ? const Color(0xFFE8F5F0) : _coralSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _isSuccess ? Icons.check_circle : Icons.pin,
                      color: _isSuccess ? _green : _coral,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSuccess
                        ? 'Rendez-vous confirmé !'
                        : 'Entrez le code du client',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSuccess
                        ? 'La commission a été enregistrée'
                        : 'Demandez au client son code à 6 chiffres',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Info client
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                serviceTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Champs OTP
            if (!_isSuccess) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKeyPressed(index, event),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _errorMessage != null
                                  ? Colors.red
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _errorMessage != null
                                  ? Colors.red
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _coral,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Message d'erreur
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Bouton vérifier
              FilledButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: _coral,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Vérifier le code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Note explicative
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Le client peut afficher son code dans l\'application. Le code est valide pendant 10 minutes.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Bouton fermer après succès
            if (_isSuccess) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog pour vérifier l'OTP (version compacte pour usage dans l'agenda)
class ProVerifyOtpDialog extends ConsumerStatefulWidget {
  final String bookingId;
  final String? clientName;
  final String? serviceTitle;

  const ProVerifyOtpDialog({
    super.key,
    required this.bookingId,
    this.clientName,
    this.serviceTitle,
  });

  @override
  ConsumerState<ProVerifyOtpDialog> createState() => _ProVerifyOtpDialogState();
}

class _ProVerifyOtpDialogState extends ConsumerState<ProVerifyOtpDialog> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Le code doit contenir 6 chiffres';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiProvider);
      await api.verifyBookingOtp(
        bookingId: widget.bookingId,
        otp: otp,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true); // Succès
    } catch (e) {
      if (!mounted) return;

      String errorMsg = e.toString();
      if (errorMsg.contains('DioException') || errorMsg.contains('Exception:')) {
        errorMsg = 'Code invalide ou expiré';
      }

      setState(() {
        _errorMessage = errorMsg;
        _otpController.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _coralSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pin, color: _coral, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Vérifier OTP', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.clientName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Client: ${widget.clientName}',
                style: TextStyle(color: Colors.black.withOpacity(0.6)),
              ),
            ),
          TextField(
            controller: _otpController,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.grey.shade300,
                letterSpacing: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _coral, width: 2),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _verify,
          style: FilledButton.styleFrom(backgroundColor: _coral),
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Vérifier'),
        ),
      ],
    );
  }
}
