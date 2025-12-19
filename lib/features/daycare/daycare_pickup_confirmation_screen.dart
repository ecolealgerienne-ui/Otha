// lib/features/daycare/daycare_pickup_confirmation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _green = Color(0xFF22C55E);
const _greenSoft = Color(0xFFE8F5E9);
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _orange = Color(0xFFF59E0B);
const _orangeSoft = Color(0xFFFEF3C7);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkBorder = Color(0xFF2A2A2A);

/// Écran de confirmation du retrait d'animal en garderie
class DaycarePickupConfirmationScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingData;
  final double? lat;
  final double? lng;

  const DaycarePickupConfirmationScreen({
    super.key,
    required this.bookingId,
    this.bookingData,
    this.lat,
    this.lng,
  });

  @override
  ConsumerState<DaycarePickupConfirmationScreen> createState() =>
      _DaycarePickupConfirmationScreenState();
}

class _DaycarePickupConfirmationScreenState
    extends ConsumerState<DaycarePickupConfirmationScreen> {
  bool _isLoading = false;
  bool _isLoadingLateFee = true;
  String? _errorMessage;

  // Frais de retard
  int? _lateFeeDa;
  double? _lateFeeHours;
  int? _hourlyRate;

  // Pour l'OTP
  String? _otpCode;
  int _otpExpiresInSeconds = 0;
  Timer? _otpTimer;
  Timer? _statusCheckTimer;
  bool _showOtpSection = false;
  bool _isValidated = false;

  @override
  void initState() {
    super.initState();
    _loadLateFee();
    _notifyNearby();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkBookingStatus();
    });
  }

  Future<void> _checkBookingStatus() async {
    try {
      final api = ref.read(apiProvider);
      final booking = await api.getDaycareBooking(widget.bookingId);
      final status = (booking['status'] ?? '').toString().toUpperCase();

      if (!mounted) return;

      if (status == 'COMPLETED') {
        _statusCheckTimer?.cancel();
        _otpTimer?.cancel();
        setState(() => _isValidated = true);

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _showSuccessAndGoHome();
        }
      }
    } catch (e) {
      // Ignorer les erreurs de polling silencieusement
    }
  }

  void _showSuccessAndGoHome() {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? _green.withOpacity(0.15) : _greenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: _green,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.pickupConfirmedTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.animalPickedUpSuccess,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.returnToHome,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _loadLateFee() async {
    try {
      final api = ref.read(apiProvider);
      final result = await api.calculateDaycareLateFee(widget.bookingId);

      if (!mounted) return;

      setState(() {
        _lateFeeDa = (result['lateFeeDa'] as num?)?.toInt();
        _lateFeeHours = (result['lateFeeHours'] as num?)?.toDouble();
        _hourlyRate = (result['hourlyRate'] as num?)?.toInt();
        _isLoadingLateFee = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLateFee = false;
      });
    }
  }

  Future<void> _confirmPickup() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiProvider);
      await api.clientConfirmDaycarePickupWithLateFee(
        widget.bookingId,
        method: 'PROXIMITY',
        lat: widget.lat,
        lng: widget.lng,
      );

      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pickupConfirmedSnack),
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

  Future<void> _showOtpCode() async {
    setState(() {
      _showOtpSection = true;
      _isLoading = true;
    });

    try {
      final api = ref.read(apiProvider);
      await api.clientConfirmDaycarePickupWithLateFee(
        widget.bookingId,
        method: 'OTP',
        lat: widget.lat,
        lng: widget.lng,
      );

      final result = await api.getDaycarePickupOtp(widget.bookingId);

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
          _otpExpiresInSeconds = 600;
        }
      });

      _startOtpTimer();
      _startStatusPolling();
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

  void _copyOtp() {
    if (_otpCode == null) return;
    Clipboard.setData(ClipboardData(text: _otpCode!));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.codeCopied)),
    );
  }

  void _goToQrScan() {
    final pet = widget.bookingData?['pet'] as Map<String, dynamic>?;
    final petId = pet?['id']?.toString() ?? widget.bookingData?['petId']?.toString();

    if (petId != null && petId.isNotEmpty) {
      context.push('/pets/$petId/qr');
    } else {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noAnimalAssociated),
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

  String _formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h > 0 && m > 0) {
      return '${h}h${m.toString().padLeft(2, '0')}';
    } else if (h > 0) {
      return '${h}h';
    } else {
      return '${m}min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black.withOpacity(0.6);
    final borderColor = isDark ? _darkBorder : Colors.transparent;

    final providerName = widget.bookingData?['provider']?['displayName']?.toString() ?? 'la garderie';
    final pet = widget.bookingData?['pet'] as Map<String, dynamic>?;
    final petName = pet?['name']?.toString() ?? l10n.yourAnimalName;
    final endDateStr = widget.bookingData?['endDate']?.toString();
    DateTime? endDate;
    if (endDateStr != null) {
      endDate = DateTime.tryParse(endDateStr);
    }
    final dateStr = endDate != null
        ? DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(endDate)
        : '';

    final hasLateFee = _lateFeeDa != null && _lateFeeDa! > 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.confirmPickupTitle, style: TextStyle(color: textColor)),
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
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: isDark ? Border.all(color: borderColor) : null,
                boxShadow: isDark ? null : const [
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
                      color: hasLateFee
                          ? (isDark ? _orange.withOpacity(0.15) : _orangeSoft)
                          : (isDark ? _green.withOpacity(0.15) : _greenSoft),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      hasLateFee ? Icons.schedule : Icons.pets,
                      color: hasLateFee ? _orange : _green,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.pickupPetAt(petName),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.nearDaycare(providerName),
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
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
                        color: hasLateFee
                            ? (isDark ? _coral.withOpacity(0.15) : _coralSoft)
                            : (isDark ? _green.withOpacity(0.15) : _greenSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: hasLateFee ? _coral : _green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.plannedFor(dateStr),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: hasLateFee ? _coral : _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section frais de retard
            if (_isLoadingLateFee) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark ? Border.all(color: borderColor) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.calculatingFees, style: TextStyle(color: textColor)),
                  ],
                ),
              ),
            ] else if (hasLateFee) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? _orange.withOpacity(0.15) : _orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber, color: _orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.lateFeeTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.lateDelay(_formatHours(_lateFeeHours ?? 0)),
                          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey.shade700),
                        ),
                        Text(
                          l10n.ratePerHour('${_hourlyRate ?? 0}'),
                          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.totalLateFee,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '$_lateFeeDa DA',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.daycareCanAcceptOrRefuse,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? _green.withOpacity(0.15) : _greenSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withOpacity(isDark ? 0.5 : 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: _green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.noLateFee,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Section OTP (si activée)
            if (_showOtpSection) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? _green.withOpacity(0.5) : _green.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.verificationCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.showCodeToDaycare,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
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
                            color: isDark ? _green.withOpacity(0.15) : _greenSoft,
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
                        l10n.expiresInTime(_formatExpiration(_otpExpiresInSeconds)),
                        style: TextStyle(
                          fontSize: 13,
                          color: _otpExpiresInSeconds < 60 ? _coral : (isDark ? Colors.grey[400] : Colors.grey),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (_isLoading) ...[
                      const CircularProgressIndicator(color: _green),
                    ] else ...[
                      Text(
                        l10n.codeExpired,
                        style: const TextStyle(color: _coral, fontWeight: FontWeight.w600),
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
                  color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
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
            Text(
              l10n.chooseConfirmMethod,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),

            // Bouton Scanner QR
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _goToQrScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.scanAnimalQr),
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
                label: Text(l10n.getVerificationCode),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.grey[400] : Colors.grey.shade700,
                  side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Bouton principal de confirmation
            FilledButton.icon(
              onPressed: _isLoading ? null : _confirmPickup,
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
              label: Text(_isLoading ? l10n.confirming : l10n.confirmPickupTitle),
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
                color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: isDark ? Colors.blue[300] : Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.daycareWillValidatePickup,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.blue[300] : Colors.blue.shade700,
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
