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
final nearbyDaycareClientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final result = await api.getDaycareNearbyClients();
  return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

// Commission for daycare: 100 DA per reservation
const kDaycareCommissionDa = 100;

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
      }
    }

    // Commission is per booking (fixed 100 DA)
    final commissionDue = bookingsThisMonth * kDaycareCommissionDa;

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
    final bookingId = booking['id']?.toString() ?? '';
    final user = booking['user'] as Map<String, dynamic>?;
    final pet = booking['pet'] as Map<String, dynamic>?;
    final clientName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : 'Client';
    final petName = pet?['name'] ?? 'Animal';

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: Colors.grey[300],
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
                          ? const Color(0xFFFFF3E0)
                          : const Color(0xFFE3F2FD),
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
                          isForPickup ? 'Valider le retrait' : 'Valider le dépôt',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$clientName - $petName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
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
                label: 'Scanner QR code',
                subtitle: 'Scannez le QR code de l\'animal',
                color: const Color(0xFF00ACC1),
                onTap: () => Navigator.pop(ctx, 'qr'),
              ),
              const SizedBox(height: 12),

              // Bouton OTP
              _ValidationOptionButton(
                icon: Icons.pin,
                label: 'Vérifier code OTP',
                subtitle: 'Entrez le code à 6 chiffres du client',
                color: const Color(0xFF9C27B0),
                onTap: () => Navigator.pop(ctx, 'otp'),
              ),
              const SizedBox(height: 12),

              // Bouton Manuel
              _ValidationOptionButton(
                icon: isForPickup ? Icons.check_circle : Icons.pets,
                label: isForPickup ? 'Confirmer le retrait' : 'Confirmer le dépôt',
                subtitle: 'Validation manuelle sans vérification',
                color: isForPickup
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF4CAF50),
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
      await _showOtpInputDialog(bookingId, isForPickup);
    } else if (result == 'manual') {
      // Confirmer manuellement
      await _confirmManually(bookingId, isForPickup);
    }
  }

  /// Dialog pour saisir le code OTP
  Future<void> _showOtpInputDialog(String bookingId, bool isForPickup) async {
    final otpController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pin, color: Color(0xFF22C55E)),
            ),
            const SizedBox(width: 12),
            Text(isForPickup ? 'Code retrait' : 'Code dépôt'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrez le code à 6 chiffres fourni par le client',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
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
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
            ),
            child: const Text('Valider'),
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
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: Colors.grey[300],
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
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.timer, color: Color(0xFFFFA000)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Frais de retard (${lateFees.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
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
                      : 'Client';
                  final petName = pet?['name'] ?? 'Animal';
                  final lateFeeDa = (fee['lateFeeDa'] as num?)?.toInt() ?? 0;
                  final lateFeeHours = (fee['lateFeeHours'] as num?)?.toDouble() ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF0),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    petName,
                                    style: TextStyle(
                                      color: Colors.grey[600],
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
                                  '${lateFeeHours.toStringAsFixed(1)}h de retard',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
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
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Annuler'),
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
                                child: const Text('Accepter'),
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
                    isDark: isDark,
                    onAvatarTap: () => context.push('/daycare/settings'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // Réservations en attente (si > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: pendingAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (pending) {
                        if (pending.isEmpty) return const SizedBox.shrink();
                        return _PendingBookingsBanner(
                          bookings: pending,
                          isDark: isDark,
                          label: '${pending.length} ${l10n.pendingBookingsX}',
                          onTap: () => context.push('/daycare/bookings'),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ✅ Banner bleu : Clients à proximité (cliquable)
                SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final nearbyAsync = ref.watch(nearbyDaycareClientsProvider);
                      return nearbyAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (clients) {
                          if (clients.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2A3A) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF3B82F6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Color(0xFF3B82F6)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${clients.length} ${l10n.nearbyClientsX}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.tapToValidate,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...clients.take(5).map((c) {
                                    final user = c['user'] as Map<String, dynamic>?;
                                    final pet = c['pet'] as Map<String, dynamic>?;
                                    final clientName = user != null
                                        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
                                        : 'Client';
                                    final petName = pet?['name'] ?? 'Animal';
                                    final status = (c['status'] ?? '').toString().toUpperCase();
                                    final isForPickup = status == 'IN_PROGRESS';

                                    return InkWell(
                                      onTap: () => _showClientValidationDialog(c, isForPickup),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isForPickup
                                                ? const Color(0xFFF59E0B).withOpacity(0.3)
                                                : const Color(0xFF3B82F6).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: isForPickup
                                                    ? const Color(0xFFFFF3E0)
                                                    : const Color(0xFFE3F2FD),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                isForPickup ? Icons.logout : Icons.login,
                                                size: 16,
                                                color: isForPickup
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF3B82F6),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$clientName - $petName',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    isForPickup ? 'Retrait' : 'Dépôt',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isForPickup
                                                          ? const Color(0xFFF59E0B)
                                                          : const Color(0xFF3B82F6),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ✅ Banner vert : Validations en attente (dépôts/retraits)
                SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final validationsAsync = ref.watch(pendingDaycareValidationsProvider);
                      return validationsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (validations) {
                          if (validations.isEmpty) return const SizedBox.shrink();

                          int dropCount = 0;
                          int pickupCount = 0;
                          for (final v in validations) {
                            final st = (v['status'] ?? '').toString().toUpperCase();
                            if (st == 'PENDING_DROP_VALIDATION') {
                              dropCount++;
                            } else if (st == 'PENDING_PICKUP_VALIDATION') {
                              pickupCount++;
                            }
                          }

                          String message;
                          if (dropCount > 0 && pickupCount > 0) {
                            message = '$dropCount dépôt${dropCount > 1 ? 's' : ''} et $pickupCount retrait${pickupCount > 1 ? 's' : ''} à valider';
                          } else if (dropCount > 0) {
                            message = '$dropCount dépôt${dropCount > 1 ? 's' : ''} d\'animal à valider';
                          } else {
                            message = '$pickupCount retrait${pickupCount > 1 ? 's' : ''} d\'animal à valider';
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GestureDetector(
                              onTap: () => context.push('/daycare/pending-validations'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF22C55E)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.pets, color: Color(0xFF22C55E)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        message,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF22C55E),
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF22C55E)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ✅ Banner ambre : Frais de retard en attente
                SliverToBoxAdapter(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final lateFeesAsync = ref.watch(pendingLateFeesProvider);
                      return lateFeesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (lateFees) {
                          if (lateFees.isEmpty) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GestureDetector(
                              onTap: () => _showLateFeesDialog(context, ref, lateFees),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFA000)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.timer, color: Color(0xFFFFA000)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${lateFees.length} frais de retard en attente',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFFA000),
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFFFA000)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Actions rapides
                const SliverToBoxAdapter(child: _ActionGrid()),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Commission du mois
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ledgerAsync.when(
                      loading: () => const _CommissionCard.loading(),
                      error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                      data: (ledger) => _CommissionCard(ledger: ledger),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Statistiques rapides
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _QuickStats(bookingsAsync: bookingsAsync),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Réservations récentes
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
  final bool isDark;
  final VoidCallback? onAvatarTap;
  const _Header({
    required this.daycareName,
    required this.welcomeText,
    required this.isDark,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF00838F), const Color(0xFF006064)]
              : [_DaycareColors.primary, const Color(0xFF0097A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _DaycareColors.primary.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Text(
                daycareName.isNotEmpty ? daycareName.characters.first.toUpperCase() : 'G',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _DaycareColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(welcomeText, style: const TextStyle(color: Colors.white70)),
                Text(
                  daycareName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.pets, color: Colors.white, size: 26),
        ],
      ),
    );
  }
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

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;

    final items = [
      _Action(l10n.managePage, Icons.edit_location, '/daycare/page', const Color(0xFF3A86FF)),
      _Action(l10n.myBookings, Icons.calendar_today, '/daycare/bookings', const Color(0xFFFF6D00)),
      _Action(l10n.calendar, Icons.date_range, '/daycare/calendar', const Color(0xFF00ACC1)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.15,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _ActionCard(item: items[i], isDark: isDark),
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

class _ActionCard extends StatefulWidget {
  final _Action item;
  final bool isDark;
  const _ActionCard({required this.item, required this.isDark});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward(from: Random().nextDouble() * .6);

  late final Animation<double> _scale = Tween(begin: .98, end: 1.0).animate(
    CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final isDark = widget.isDark;
    return ScaleTransition(
      scale: _scale,
      child: InkWell(
        onTap: () => context.push(it.route),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? it.color.withOpacity(.15) : it.color.withOpacity(.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: it.color.withOpacity(isDark ? .3 : .16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: it.color.withOpacity(isDark ? .25 : .15),
                  child: Icon(it.icon, color: it.color),
                ),
                const Spacer(),
                Text(
                  it.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> bookingsAsync;
  const _QuickStats({required this.bookingsAsync});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Aperçu rapide',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.calendar_today,
                  label: 'Réservations actives',
                  value: '$activeBookings',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.check_circle,
                  label: 'Terminées',
                  value: '$completedBookings',
                  color: Colors.green,
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
                  label: 'Total réservations',
                  value: '${bookings.length}',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.schedule,
                  label: 'En attente',
                  value: '${bookings.where((b) => (b['status'] ?? '').toString().toUpperCase() == 'PENDING').length}',
                  color: Colors.orange,
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
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
                    color: Colors.black.withOpacity(0.6),
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

class _RecentBookings extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  const _RecentBookings({required this.bookings});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return _SectionCard(
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Aucune réservation'),
            const SizedBox(height: 8),
            Text(
              'Les réservations de vos clients apparaîtront ici',
              style: TextStyle(color: Colors.black.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Trier par date et prendre les 5 dernières
    final sorted = List<Map<String, dynamic>>.from(bookings)
      ..sort((a, b) {
        final aDate = DateTime.tryParse((a['startDate'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse((b['startDate'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final recent = sorted.take(5).toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Réservations récentes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/daycare/bookings'),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recent.map((booking) {
            final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
            final totalDa = _asInt(booking['totalDa'] ?? 0);
            final startDate = booking['startDate'];
            final endDate = booking['endDate'];
            final user = booking['user'] as Map<String, dynamic>?;
            final userName = (user?['firstName'] ?? 'Client').toString();

            DateTime? start, end;
            if (startDate != null) start = DateTime.tryParse(startDate.toString());
            if (endDate != null) end = DateTime.tryParse(endDate.toString());

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildStatusIcon(status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (start != null && end != null)
                          Text(
                            '${DateFormat('dd/MM').format(start.toLocal())} - ${DateFormat('dd/MM').format(end.toLocal())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _da(totalDa),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'PENDING':
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case 'CONFIRMED':
        icon = Icons.thumb_up;
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        icon = Icons.pets;
        color = Colors.purple;
        break;
      case 'COMPLETED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'CANCELLED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusChip(String status) {
    String label;
    Color color;

    switch (status) {
      case 'PENDING':
        label = 'En attente';
        color = Colors.orange;
        break;
      case 'CONFIRMED':
        label = 'Confirmée';
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        label = 'En cours';
        color = Colors.purple;
        break;
      case 'COMPLETED':
        label = 'Terminée';
        color = Colors.green;
        break;
      case 'CANCELLED':
        label = 'Annulée';
        color = Colors.red;
        break;
      default:
        label = status;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final _DaycareLedger? ledger;
  const _CommissionCard({required this.ledger});
  const _CommissionCard.loading() : ledger = null;

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined, color: Color(0xFFFB8C00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commission du mois',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black.withOpacity(.65)),
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
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.bookingsCount} réservation${l.bookingsCount > 1 ? 's' : ''} terminée${l.bookingsCount > 1 ? 's' : ''}',
            style: TextStyle(color: Colors.black.withOpacity(.6)),
          ),
          const SizedBox(height: 12),

          // Stats
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniPill(Icons.monetization_on, 'Revenus', _da(l.totalRevenue)),
              _miniPill(Icons.receipt, 'Commission', _da(l.commissionDue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _DaycareColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _DaycareColors.primary.withOpacity(.2)),
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
                    style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(.6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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
  final VoidCallback onTap;

  const _ValidationOptionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
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
                      color: Colors.grey[600],
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
