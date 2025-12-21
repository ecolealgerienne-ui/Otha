import 'dart:async';
import 'dart:math';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/session_controller.dart';

/// ========================= THEME DAYCARE (bleu cyan) =========================
class _DaycareColors {
  static const ink = Color(0xFF1F2328);
  static const inkDark = Color(0xFFFFFFFF);
  static const primary = Color(0xFF00ACC1); // Cyan
  static const primarySoft = Color(0xFFE0F7FA);
  static const primarySoftDark = Color(0xFF1A3A3D);
  static const coral = Color(0xFFF36C6C);
  static const bgLight = Color(0xFFF7F8FA);
  static const bgDark = Color(0xFF121212);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1E1E1E);
  static const amber = Color(0xFFFFA000);
  static const green = Color(0xFF22C55E);
  static const blue = Color(0xFF3B82F6);
}

ThemeData _daycareTheme(BuildContext context, bool isDark) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _DaycareColors.primary,
      secondary: _DaycareColors.primary,
      onPrimary: Colors.white,
      surface: isDark ? _DaycareColors.cardDark : _DaycareColors.cardLight,
    ),
    scaffoldBackgroundColor: isDark ? _DaycareColors.bgDark : _DaycareColors.bgLight,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? _DaycareColors.bgDark : Colors.white,
      foregroundColor: isDark ? _DaycareColors.inkDark : _DaycareColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(_DaycareColors.primary),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: WidgetStatePropertyAll(_DaycareColors.primary.withOpacity(.12)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _DaycareColors.primary),
    dividerColor: isDark ? Colors.white12 : _DaycareColors.primarySoft,
  );
}

/// ========================= PROVIDERS =========================

final myDaycareProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) => ref.read(apiProvider).myProvider(),
);

final myDaycareBookingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final bookings = await api.myDaycareProviderBookings();
  return bookings.map((b) => Map<String, dynamic>.from(b as Map)).toList();
});

final pendingDaycareBookingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bookings = await ref.watch(myDaycareBookingsProvider.future);
  return bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PENDING').toList();
});

/// Provider pour récupérer les validations en attente (PENDING_DROP_VALIDATION ou PENDING_PICKUP_VALIDATION)
final pendingDaycareValidationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.read(apiProvider);
    final result = await api.getDaycarePendingValidations();
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    return [];
  }
});

/// Provider pour récupérer les clients à proximité
/// Filtre côté frontend: seulement les clients < 500m avec localisation fraîche (< 30 min)
final nearbyDaycareClientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);

  // Récupérer les coordonnées du provider
  final myProfile = await ref.watch(myDaycareProfileProvider.future);
  final provLat = (myProfile?['lat'] as num?)?.toDouble();
  final provLng = (myProfile?['lng'] as num?)?.toDouble();

  final result = await api.getDaycareNearbyClients();
  final clients = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // Si pas de coordonnées provider, retourner tel quel (backend gère)
  if (provLat == null || provLng == null) {
    return clients;
  }

  // Filtrer: seulement les clients vraiment proches (< 500m) et avec localisation récente (< 30 min)
  final now = DateTime.now();
  return clients.where((client) {
    final clientLat = (client['lat'] as num?)?.toDouble();
    final clientLng = (client['lng'] as num?)?.toDouble();

    if (clientLat == null || clientLng == null) return false;

    // Calculer distance (Haversine simplifié)
    const R = 6371000.0; // Rayon terre en mètres
    final dLat = (clientLat - provLat) * pi / 180;
    final dLng = (clientLng - provLng) * pi / 180;
    final lat1Rad = provLat * pi / 180;
    final lat2Rad = clientLat * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2);
    final distance = 2 * R * asin(sqrt(a));

    // Vérifier si < 500m
    if (distance > 500) return false;

    // Vérifier fraîcheur de la localisation (si disponible)
    final lastLocationUpdate = client['lastLocationUpdate'] ?? client['updatedAt'];
    if (lastLocationUpdate != null) {
      try {
        final updateTime = DateTime.parse(lastLocationUpdate.toString());
        final age = now.difference(updateTime);
        // Localisation doit être < 30 minutes
        if (age.inMinutes > 30) return false;
      } catch (_) {
        // Si parsing échoue, on garde le client
      }
    }

    return true;
  }).toList();
});

/// Provider pour récupérer les frais de retard en attente
final pendingLateFeesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.read(apiProvider);
    final result = await api.getDaycarePendingLateFees();
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    return [];
  }
});

// Commission par défaut (fallback si non définie dans le booking)
const kDefaultDaycareCommissionDa = 100;

/// Ledger pour la garderie
class _DaycareLedger {
  final String ym;
  final int bookingsCount;
  final int totalRevenue;
  final int commissionDue;
  final int commissionPaid;
  final int netDue;

  const _DaycareLedger({
    required this.ym,
    required this.bookingsCount,
    required this.totalRevenue,
    required this.commissionDue,
    required this.commissionPaid,
    required this.netDue,
  });
}

final daycareLedgerProvider = FutureProvider.autoDispose<_DaycareLedger>((ref) async {
  try {
    final bookings = await ref.watch(myDaycareBookingsProvider.future);

    final now = DateTime.now();
    final ymNow = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    int bookingsThisMonth = 0;
    int revenueThisMonth = 0;
    int commissionThisMonth = 0;

    for (final booking in bookings) {
      // Only count completed/delivered bookings
      final status = (booking['status'] ?? '').toString().toUpperCase();
      if (status != 'COMPLETED' && status != 'DELIVERED') continue;

      // Check if this booking is from this month
      final startDate = booking['startDate'];
      if (startDate == null) continue;

      final date = DateTime.tryParse(startDate.toString());
      if (date == null) continue;

      final bookingYm = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      if (bookingYm == ymNow) {
        bookingsThisMonth++;
        revenueThisMonth += _asInt(booking['totalDa'] ?? booking['total'] ?? 0);
        // Utilise la commission du booking si disponible, sinon le défaut
        commissionThisMonth += _asInt(booking['commissionDa'] ?? kDefaultDaycareCommissionDa);
      }
    }

    // Commission totale pour ce mois
    final commissionDue = commissionThisMonth;

    return _DaycareLedger(
      ym: ymNow,
      bookingsCount: bookingsThisMonth,
      totalRevenue: revenueThisMonth,
      commissionDue: commissionDue,
      commissionPaid: 0, // TODO: Connect to backend payment tracking
      netDue: commissionDue,
    );
  } catch (_) {
    final now = DateTime.now();
    final ymNow = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _DaycareLedger(
      ym: ymNow,
      bookingsCount: 0,
      totalRevenue: 0,
      commissionDue: 0,
      commissionPaid: 0,
      netDue: 0,
    );
  }
});

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// ========================= MAIN SCREEN =========================

class DaycareHomeScreen extends ConsumerStatefulWidget {
  const DaycareHomeScreen({super.key});

  @override
  ConsumerState<DaycareHomeScreen> createState() => _DaycareHomeScreenState();
}

class _DaycareHomeScreenState extends ConsumerState<DaycareHomeScreen> {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh toutes les 10 secondes pour voir les clients à proximité
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        ref.invalidate(nearbyDaycareClientsProvider);
        ref.invalidate(pendingDaycareValidationsProvider);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Afficher le dialogue de validation pour un client à proximité
  Future<void> _showClientValidationDialog(
    Map<String, dynamic> booking,
    bool isForPickup,
  ) async {
    final themeMode = ref.read(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bookingId = booking['id']?.toString() ?? '';
    final user = booking['user'] as Map<String, dynamic>?;
    final pet = booking['pet'] as Map<String, dynamic>?;
    final clientName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : l10n.client;
    final petName = pet?['name'] ?? l10n.animal;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? _DaycareColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Titre
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isForPickup
                          ? (isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF3E0))
                          : (isDark ? const Color(0xFF1A2A3A) : const Color(0xFFE3F2FD)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isForPickup ? Icons.logout : Icons.login,
                      color: isForPickup
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isForPickup ? l10n.validatePickup : l10n.validateDropOff,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : null,
                          ),
                        ),
                        Text(
                          '$clientName - $petName',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bouton Scanner QR
              _ValidationOptionButton(
                icon: Icons.qr_code_scanner,
                label: l10n.scanQrCode,
                subtitle: l10n.scanQrSubtitle,
                color: const Color(0xFF00ACC1),
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, 'qr'),
              ),
              const SizedBox(height: 12),

              // Bouton OTP
              _ValidationOptionButton(
                icon: Icons.pin,
                label: l10n.verifyOtp,
                subtitle: l10n.verifyOtpSubtitle,
                color: const Color(0xFF9C27B0),
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, 'otp'),
              ),
              const SizedBox(height: 12),

              // Bouton Manuel
              _ValidationOptionButton(
                icon: isForPickup ? Icons.check_circle : Icons.pets,
                label: l10n.confirmManually,
                subtitle: l10n.confirmManuallySubtitle,
                color: isForPickup
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF4CAF50),
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, 'manual'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result == 'qr') {
      // Naviguer vers le scanner QR
      context.push('/scan-pet');
    } else if (result == 'otp') {
      // Afficher la dialog OTP
      await _showOtpInputDialog(bookingId, isForPickup, isDark);
    } else if (result == 'manual') {
      // Confirmer manuellement
      await _confirmManually(bookingId, isForPickup);
    }
  }

  /// Dialog pour saisir le code OTP
  Future<void> _showOtpInputDialog(String bookingId, bool isForPickup, bool isDark) async {
    final l10n = AppLocalizations.of(context);
    final otpController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _DaycareColors.cardDark : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2E1A) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pin, color: Color(0xFF22C55E)),
            ),
            const SizedBox(width: 12),
            Text(
              isForPickup ? l10n.pickupCode : l10n.dropOffCode,
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.verifyOtpSubtitle,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: isDark ? Colors.white : null,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : null),
                counterText: '',
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
            ),
            child: Text(l10n.verify),
          ),
        ],
      ),
    );

    if (result == true && otpController.text.length == 6) {
      await _validateWithOtp(bookingId, otpController.text, isForPickup);
    }
    otpController.dispose();
  }

  /// Valider avec le code OTP
  Future<void> _validateWithOtp(String bookingId, String otp, bool isForPickup) async {
    try {
      final api = ref.read(apiProvider);
      await api.validateDaycareByOtp(
        bookingId,
        otp: otp,
        phase: isForPickup ? 'pickup' : 'drop',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isForPickup
              ? 'Retrait validé avec succès !'
              : 'Dépôt validé avec succès !'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code invalide: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Confirmer manuellement
  Future<void> _confirmManually(String bookingId, bool isForPickup) async {
    try {
      final api = ref.read(apiProvider);
      if (isForPickup) {
        await api.markDaycarePickup(bookingId);
      } else {
        await api.markDaycareDropOff(bookingId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isForPickup
              ? 'Retrait confirmé !'
              : 'Dépôt confirmé !'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Afficher la dialog pour gérer les frais de retard
  Future<void> _showLateFeesDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> lateFees,
    bool isDark,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? _DaycareColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Titre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.timer, color: Color(0xFFFFA000)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${l10n.lateFees} (${lateFees.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? Colors.white12 : null),
            // Liste des frais
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: lateFees.length,
                itemBuilder: (_, i) {
                  final fee = lateFees[i];
                  final bookingId = (fee['id'] ?? '').toString();
                  final user = fee['user'] as Map<String, dynamic>?;
                  final pet = fee['pet'] as Map<String, dynamic>?;
                  final clientName = user != null
                      ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
                      : l10n.client;
                  final petName = pet?['name'] ?? l10n.animal;
                  final lateFeeDa = (fee['lateFeeDa'] as num?)?.toInt() ?? 0;
                  final lateFeeHours = (fee['lateFeeHours'] as num?)?.toDouble() ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFFBF0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFA000).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFFFA000).withOpacity(0.2),
                              child: const Icon(Icons.pets, color: Color(0xFFFFA000), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clientName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : null,
                                    ),
                                  ),
                                  Text(
                                    petName,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$lateFeeDa DA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: Color(0xFFFFA000),
                                  ),
                                ),
                                Text(
                                  '${lateFeeHours.toStringAsFixed(1)}${l10n.hoursLate}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _handleLateFee(ctx, ref, bookingId, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
                                  side: BorderSide(color: isDark ? Colors.white38 : Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(l10n.reject),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _handleLateFee(ctx, ref, bookingId, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFA000),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(l10n.accept),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Accepter ou refuser les frais de retard
  Future<void> _handleLateFee(BuildContext ctx, WidgetRef ref, String bookingId, bool accept) async {
    try {
      final api = ref.read(apiProvider);
      await api.handleDaycareLateFee(bookingId, accept: accept);

      if (ctx.mounted) {
        Navigator.pop(ctx); // Fermer la bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? 'Frais de retard acceptés'
                : 'Frais de retard annulés'),
            backgroundColor: accept ? const Color(0xFF22C55E) : Colors.grey,
          ),
        );
      }
      _refreshData();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _refreshData() {
    ref.invalidate(myDaycareProfileProvider);
    ref.invalidate(myDaycareBookingsProvider);
    ref.invalidate(pendingDaycareBookingsProvider);
    ref.invalidate(nearbyDaycareClientsProvider);
    ref.invalidate(pendingDaycareValidationsProvider);
    ref.invalidate(pendingLateFeesProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Dark mode & i18n
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final bgColor = isDark ? _DaycareColors.bgDark : _DaycareColors.bgLight;

    final state = ref.watch(sessionProvider);
    final user = state.user ?? {};
    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    final fallbackUserName =
        [if (first.isNotEmpty) first, if (last.isNotEmpty) last].join(' ').trim();

    final provAsync = ref.watch(myDaycareProfileProvider);
    final daycareName = provAsync.maybeWhen(
      data: (p) {
        final dn = (p?['displayName'] ?? '').toString().trim();
        if (dn.isNotEmpty) return dn;
        return fallbackUserName.isNotEmpty ? fallbackUserName : l10n.myDaycare;
      },
      orElse: () => (fallbackUserName.isNotEmpty ? fallbackUserName : l10n.myDaycare),
    );

    final pendingAsync = ref.watch(pendingDaycareBookingsProvider);
    final bookingsAsync = ref.watch(myDaycareBookingsProvider);
    final ledgerAsync = ref.watch(daycareLedgerProvider);

    return Theme(
      data: _daycareTheme(context, isDark),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myDaycareProfileProvider);
              ref.invalidate(myDaycareBookingsProvider);
              ref.invalidate(pendingDaycareBookingsProvider);
              ref.invalidate(nearbyDaycareClientsProvider);
              ref.invalidate(pendingDaycareValidationsProvider);
              ref.invalidate(pendingLateFeesProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _Header(
                    daycareName: daycareName,
                    welcomeText: l10n.welcome,
                    todayDate: DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                    isDark: isDark,
                    onAvatarTap: () => context.push('/daycare/settings'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ═══════ COMPTEURS D'URGENCE ═══════
                SliverToBoxAdapter(
                  child: _UrgentActionsRow(
                    pendingAsync: pendingAsync,
                    onPendingTap: () => context.push('/daycare/bookings'),
                    onValidationsTap: () => context.push('/daycare/pending-validations'),
                    onLateFeesTap: (fees) => _showLateFeesDialog(context, ref, fees, isDark),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ═══════ CLIENTS À PROXIMITÉ (GPS) ═══════
                SliverToBoxAdapter(
                  child: _NearbyClientsCard(
                    onClientTap: (booking, isPickup) => _showClientValidationDialog(booking, isPickup),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Actions rapides
                const SliverToBoxAdapter(child: _ActionGrid()),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ═══════ STATS DU MOIS ═══════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _MonthlyStatsCard(
                      ledgerAsync: ledgerAsync,
                      bookingsAsync: bookingsAsync,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ═══════ ACTIVITÉ RÉCENTE ═══════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: bookingsAsync.when(
                      loading: () => const _LoadingCard(text: 'Chargement des réservations...'),
                      error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                      data: (bookings) => _RecentBookings(bookings: bookings),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ========================= WIDGETS =========================

class _Header extends StatelessWidget {
  final String daycareName;
  final String welcomeText;
  final String todayDate;
  final bool isDark;
  final VoidCallback? onAvatarTap;
  const _Header({
    required this.daycareName,
    required this.welcomeText,
    required this.todayDate,
    required this.isDark,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = daycareName.isNotEmpty ? daycareName.characters.first.toUpperCase() : 'G';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF00838F), const Color(0xFF004D54)]
              : [const Color(0xFF00BCD4), const Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _DaycareColors.primary.withOpacity(isDark ? 0.4 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Infos à gauche
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date du jour
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        todayDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Bienvenue
                Text(
                  welcomeText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                // Nom de la garderie
                Text(
                  daycareName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar à droite
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _DaycareColors.primary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _DaycareColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
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
}

/// ═══════ COMPTEURS D'URGENCE ═══════
class _UrgentActionsRow extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> pendingAsync;
  final VoidCallback onPendingTap;
  final VoidCallback onValidationsTap;
  final void Function(List<Map<String, dynamic>>) onLateFeesTap;

  const _UrgentActionsRow({
    required this.pendingAsync,
    required this.onPendingTap,
    required this.onValidationsTap,
    required this.onLateFeesTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final pendingCount = pendingAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final validationsAsync = ref.watch(pendingDaycareValidationsProvider);
    final validationsCount = validationsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final lateFeesAsync = ref.watch(pendingLateFeesProvider);
    final lateFees = lateFeesAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <Map<String, dynamic>>[],
    );
    final lateFeesCount = lateFees.length;

    // Si tout est à zéro, ne rien afficher
    if (pendingCount == 0 && validationsCount == 0 && lateFeesCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Réservations en attente
          Expanded(
            child: _UrgentCounter(
              count: pendingCount,
              label: l10n.pendingBookings,
              icon: Icons.schedule,
              color: const Color(0xFFFF6B6B),
              isDark: isDark,
              onTap: pendingCount > 0 ? onPendingTap : null,
            ),
          ),
          const SizedBox(width: 10),
          // Validations à faire
          Expanded(
            child: _UrgentCounter(
              count: validationsCount,
              label: l10n.validations,
              icon: Icons.check_circle_outline,
              color: const Color(0xFF22C55E),
              isDark: isDark,
              onTap: validationsCount > 0 ? onValidationsTap : null,
            ),
          ),
          const SizedBox(width: 10),
          // Frais de retard
          Expanded(
            child: _UrgentCounter(
              count: lateFeesCount,
              label: l10n.lateFees,
              icon: Icons.timer,
              color: const Color(0xFFFFA000),
              isDark: isDark,
              onTap: lateFeesCount > 0 ? () => onLateFeesTap(lateFees) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentCounter extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _UrgentCounter({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems = count > 0;
    final bgColor = hasItems
        ? color.withOpacity(isDark ? 0.2 : 0.1)
        : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08));
    final borderColor = hasItems
        ? color.withOpacity(isDark ? 0.4 : 0.3)
        : (isDark ? Colors.white12 : Colors.grey.withOpacity(0.2));
    final textColor = hasItems ? color : (isDark ? Colors.white38 : Colors.grey);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: hasItems ? 2 : 1),
        ),
        child: Column(
          children: [
            // Compteur avec badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 28, color: textColor),
                if (hasItems)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═══════ CARTE GPS EXPANSIBLE ═══════
class _NearbyClientsCard extends ConsumerStatefulWidget {
  final void Function(Map<String, dynamic> booking, bool isPickup) onClientTap;

  const _NearbyClientsCard({required this.onClientTap});

  @override
  ConsumerState<_NearbyClientsCard> createState() => _NearbyClientsCardState();
}

class _NearbyClientsCardState extends ConsumerState<_NearbyClientsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final nearbyAsync = ref.watch(nearbyDaycareClientsProvider);

    return nearbyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (clients) {
        if (clients.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2A3A) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.2 : 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header cliquable
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icône GPS avec pulsation
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.15 * _pulseAnimation.value),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF3B82F6).withOpacity(0.5 * _pulseAnimation.value),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${clients.length} ${l10n.nearbyClientsX}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : const Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.tapToValidate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : const Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: _isExpanded ? 0.5 : 0,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: isDark ? Colors.white70 : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Liste expansible
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: clients.take(5).map((c) {
                        final user = c['user'] as Map<String, dynamic>?;
                        final pet = c['pet'] as Map<String, dynamic>?;
                        final clientName = user != null
                            ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
                            : 'Client';
                        final petName = pet?['name'] ?? 'Animal';
                        final status = (c['status'] ?? '').toString().toUpperCase();
                        final isForPickup = status == 'IN_PROGRESS';

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Material(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => widget.onClientTap(c, isForPickup),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isForPickup
                                            ? const Color(0xFFFFF3E0)
                                            : const Color(0xFFE3F2FD),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isForPickup ? Icons.logout : Icons.login,
                                        size: 20,
                                        color: isForPickup
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            petName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isDark ? Colors.white : null,
                                            ),
                                          ),
                                          Text(
                                            clientName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? Colors.white60 : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isForPickup
                                            ? const Color(0xFFF59E0B).withOpacity(0.15)
                                            : const Color(0xFF3B82F6).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isForPickup ? 'Retrait' : 'Dépôt',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isForPickup
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right,
                                      color: isDark ? Colors.white38 : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ═══════ STATS DU MOIS AVEC MINI GRAPHE ═══════
class _MonthlyStatsCard extends ConsumerWidget {
  final AsyncValue<_DaycareLedger> ledgerAsync;
  final AsyncValue<List<Map<String, dynamic>>> bookingsAsync;

  const _MonthlyStatsCard({
    required this.ledgerAsync,
    required this.bookingsAsync,
  });

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final ledger = ledgerAsync.maybeWhen(
      data: (l) => l,
      orElse: () => null,
    );

    final bookings = bookingsAsync.maybeWhen(
      data: (b) => b,
      orElse: () => <Map<String, dynamic>>[],
    );

    // Calculer les stats
    final activeBookings = bookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      return status == 'CONFIRMED' || status == 'IN_PROGRESS';
    }).length;

    final completedBookings = bookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      return status == 'COMPLETED';
    }).length;

    // Générer les données pour le mini graphe (7 derniers jours simulés)
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR')
        .format(now)
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E1E), const Color(0xFF252525)]
              : [Colors.white, const Color(0xFFFAFAFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec mois
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _DaycareColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights,
                  color: _DaycareColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.thisMonth,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      monthLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Revenus et graphe
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Montant principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.revenue,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ledger != null ? _da(ledger.totalRevenue) : '---',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              // Mini graphe
              if (ledger != null)
                SizedBox(
                  width: 100,
                  height: 40,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      data: _generateSparklineData(bookings),
                      color: _DaycareColors.primary,
                      isDark: isDark,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Ligne de séparation
          Container(
            height: 1,
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
          ),

          const SizedBox(height: 16),

          // Stats en ligne
          Row(
            children: [
              _MiniStat(
                icon: Icons.event_available,
                value: '$activeBookings',
                label: l10n.inCare,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
              _MiniStat(
                icon: Icons.check_circle,
                value: '$completedBookings',
                label: l10n.completed,
                color: const Color(0xFF22C55E),
                isDark: isDark,
              ),
              _MiniStat(
                icon: Icons.receipt_long,
                value: ledger != null ? _da(ledger.commissionDue) : '---',
                label: l10n.commissionLabel,
                color: const Color(0xFFFFA000),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<double> _generateSparklineData(List<Map<String, dynamic>> bookings) {
    // Générer des données pour les 7 derniers jours basées sur les réservations
    final now = DateTime.now();
    final data = <double>[];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int count = 0;
      for (final b in bookings) {
        final startDate = DateTime.tryParse((b['startDate'] ?? '').toString());
        if (startDate != null && startDate.isAfter(dayStart) && startDate.isBefore(dayEnd)) {
          count++;
        }
      }
      data.add(count.toDouble());
    }

    // S'assurer qu'il y a au moins une variation
    if (data.every((d) => d == 0)) {
      return [0.2, 0.5, 0.3, 0.8, 0.6, 0.9, 0.7];
    }

    return data;
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isDark;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedY = range == 0 ? 0.5 : (data[i] - minVal) / range;
      final y = size.height - (normalizedY * size.height * 0.8) - (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Point final
    final lastX = size.width;
    final lastNormalizedY = range == 0 ? 0.5 : (data.last - minVal) / range;
    final lastY = size.height - (lastNormalizedY * size.height * 0.8) - (size.height * 0.1);

    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionCard extends ConsumerWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _DaycareColors.cardDark : _DaycareColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String text;
  const _LoadingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _PendingBookingsBanner extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final bool isDark;
  final String label;
  final VoidCallback onTap;
  const _PendingBookingsBanner({
    required this.bookings,
    required this.isDark,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E2A1A) : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pending_actions, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tapToValidate,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : null),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right),
              label: Text(l10n.viewAll),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═══════ GRILLE ACTIONS RAPIDES (3 colonnes) ═══════
class _ActionGrid extends ConsumerWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;

    final items = [
      _Action(l10n.managePage, Icons.storefront, '/daycare/page', const Color(0xFF3B82F6)),
      _Action(l10n.myBookings, Icons.event_note, '/daycare/bookings', const Color(0xFFFF6D00)),
      _Action(l10n.calendar, Icons.calendar_month, '/daycare/calendar', _DaycareColors.primary),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.map((item) {
          final isLast = item == items.last;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 10),
              child: _CompactActionCard(item: item, isDark: isDark),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Action {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  const _Action(this.title, this.icon, this.route, this.color);
}

class _CompactActionCard extends StatelessWidget {
  final _Action item;
  final bool isDark;

  const _CompactActionCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? item.color.withOpacity(0.15) : item.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push(item.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.color.withOpacity(isDark ? 0.3 : 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStats extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> bookingsAsync;
  const _QuickStats({required this.bookingsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final bookings = bookingsAsync.value ?? [];

    final activeBookings = bookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      return status == 'CONFIRMED' || status == 'IN_PROGRESS';
    }).length;

    final completedBookings = bookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      return status == 'COMPLETED';
    }).length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.quickAccess,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.calendar_today,
                  label: l10n.confirmedBookings,
                  value: '$activeBookings',
                  color: Colors.blue,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.check_circle,
                  label: l10n.completedBookings,
                  value: '$completedBookings',
                  color: Colors.green,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.pets,
                  label: l10n.allBookings,
                  value: '${bookings.length}',
                  color: Colors.purple,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.schedule,
                  label: l10n.pendingBookings,
                  value: '${bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PENDING').length}',
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : Colors.black.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ═══════ TIMELINE ACTIVITÉ RÉCENTE ═══════
class _RecentBookings extends ConsumerWidget {
  final List<Map<String, dynamic>> bookings;
  const _RecentBookings({required this.bookings});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  String _timeAgo(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    if (bookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? _DaycareColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _DaycareColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pets,
                size: 40,
                color: _DaycareColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noBookings,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.newBookingsWillAppear,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Trier par date et prendre les 5 dernières
    final sorted = List<Map<String, dynamic>>.from(bookings)
      ..sort((a, b) {
        final aDate = DateTime.tryParse((a['createdAt'] ?? a['startDate'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse((b['createdAt'] ?? b['startDate'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final recent = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _DaycareColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _DaycareColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history,
                  color: _DaycareColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.recentBookings,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/daycare/bookings'),
                icon: Text(
                  l10n.viewAll,
                  style: const TextStyle(fontSize: 13),
                ),
                label: const Icon(Icons.arrow_forward_ios, size: 12),
                style: TextButton.styleFrom(
                  foregroundColor: _DaycareColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Timeline
          ...recent.asMap().entries.map((entry) {
            final index = entry.key;
            final booking = entry.value;
            final isLast = index == recent.length - 1;

            final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
            final totalDa = _asInt(booking['totalDa'] ?? 0);
            final createdAt = DateTime.tryParse((booking['createdAt'] ?? booking['startDate'] ?? '').toString());
            final pet = booking['pet'] as Map<String, dynamic>?;
            final user = booking['user'] as Map<String, dynamic>?;
            final petName = pet?['name'] ?? 'Animal';
            final userName = user != null
                ? '${user['firstName'] ?? ''}'.trim()
                : l10n.client;
            final startDate = booking['startDate'];
            final endDate = booking['endDate'];

            DateTime? start, end;
            if (startDate != null) start = DateTime.tryParse(startDate.toString());
            if (endDate != null) end = DateTime.tryParse(endDate.toString());

            final statusInfo = _getStatusInfo(status, l10n);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline indicator
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusInfo.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusInfo.color.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    statusInfo.color.withOpacity(0.5),
                                    statusInfo.color.withOpacity(0.1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Pet name + time ago
                          Row(
                            children: [
                              Icon(
                                Icons.pets,
                                size: 16,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  petName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              if (createdAt != null)
                                Text(
                                  _timeAgo(createdAt, l10n),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Client + dates
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                    if (start != null && end != null)
                                      Text(
                                        '${DateFormat('dd MMM', 'fr_FR').format(start.toLocal())} → ${DateFormat('dd MMM', 'fr_FR').format(end.toLocal())}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Price + Status
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _da(totalDa),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusInfo.color.withOpacity(isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusInfo.icon,
                                          size: 10,
                                          color: statusInfo.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusInfo.label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: statusInfo.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(String status, AppLocalizations l10n) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo(l10n.pendingBookings, Icons.schedule, Colors.orange);
      case 'CONFIRMED':
        return _StatusInfo(l10n.confirmedBookings, Icons.thumb_up, const Color(0xFF3B82F6));
      case 'IN_PROGRESS':
        return _StatusInfo(l10n.inProgressBookings, Icons.pets, const Color(0xFF8B5CF6));
      case 'COMPLETED':
        return _StatusInfo(l10n.completedBookings, Icons.check_circle, const Color(0xFF22C55E));
      case 'CANCELLED':
        return _StatusInfo(l10n.cancelledBookings, Icons.cancel, const Color(0xFFEF4444));
      default:
        return _StatusInfo(status, Icons.help_outline, Colors.grey);
    }
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusInfo(this.label, this.icon, this.color);
}

class _CommissionCard extends ConsumerWidget {
  final _DaycareLedger? ledger;
  const _CommissionCard({required this.ledger});
  const _CommissionCard.loading() : ledger = null;

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    if (ledger == null) {
      return const _SectionCard(
        child: SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final l = ledger!;
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR')
        .format(now)
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined, color: Color(0xFFFB8C00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.commissionLabel} - ${l10n.thisMonth}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black.withOpacity(.65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Montant à payer
          Text(
            _da(l.netDue),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.bookingsCount} ${l10n.completedBookings.toLowerCase()}',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black.withOpacity(.6)),
          ),
          const SizedBox(height: 12),

          // Stats
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniPill(Icons.monetization_on, l10n.revenue, _da(l.totalRevenue), isDark),
              _miniPill(Icons.receipt, l10n.commissionLabel, _da(l.commissionDue), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String label, String value, bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? _DaycareColors.primarySoftDark : _DaycareColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _DaycareColors.primary.withOpacity(isDark ? .3 : .2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _DaycareColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black.withOpacity(.6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : null,
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

/// Widget pour les options de validation dans la popup
class _ValidationOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ValidationOptionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
