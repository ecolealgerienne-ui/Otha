// lib/features/pets/pet_prescriptions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

// Provider pour les traitements actifs (par petId)
final activeTreatmentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  final pets = await api.myPets();

  for (final pet in pets) {
    final p = pet as Map;
    if (p['id'] == petId) {
      final treatments = (p['treatments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return treatments;
    }
  }
  return [];
});

// Provider pour les traitements via token (accès vétérinaire)
final treatmentsByTokenProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, token) async {
  final api = ref.read(apiProvider);
  final petData = await api.getPetByToken(token);
  final treatments = (petData['treatments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  return treatments;
});

class PetPrescriptionsScreen extends ConsumerWidget {
  final String petId;
  final String? token; // Token optionnel pour accès vétérinaire

  const PetPrescriptionsScreen({super.key, required this.petId, this.token});

  bool get isVetAccess => token != null && token!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final appBarBg = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    // Utiliser le provider approprié selon le mode d'accès
    final treatmentsAsync = isVetAccess
        ? ref.watch(treatmentsByTokenProvider(token!))
        : ref.watch(activeTreatmentsProvider(petId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.prescriptions,
          style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (isVetAccess) {
                ref.invalidate(treatmentsByTokenProvider(token!));
              } else {
                ref.invalidate(activeTreatmentsProvider(petId));
              }
            },
            icon: Icon(Icons.refresh, color: textPrimary),
          ),
        ],
      ),
      body: treatmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (error, stack) => _buildError(error.toString(), ref, isDark, l10n, textPrimary, textSecondary),
        data: (treatments) {
          if (treatments.isEmpty) {
            return _buildEmptyState(isDark, l10n, textSecondary);
          }

          final active = treatments.where((t) => t['isActive'] == true).toList();
          final inactive = treatments.where((t) => t['isActive'] != true).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.medication_rounded,
                    title: l10n.currentTreatments,
                    count: active.length,
                    color: _mint,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...active.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTreatmentCard(context, ref, t, isActive: true, isDark: isDark, l10n: l10n, textPrimary: textPrimary, textSecondary: textSecondary),
                  )),
                  const SizedBox(height: 32),
                ],
                if (inactive.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.history,
                    title: l10n.treatmentHistory,
                    count: inactive.length,
                    color: Colors.grey,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...inactive.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTreatmentCard(context, ref, t, isActive: false, isDark: isDark, l10n: l10n, textPrimary: textPrimary, textSecondary: textSecondary),
                  )),
                ],
              ],
            ),
          );
        },
      ),
      // FloatingActionButton uniquement pour les vétérinaires
      floatingActionButton: isVetAccess
          ? FloatingActionButton.extended(
              onPressed: () async {
                final url = '/pets/$petId/treatments/new?token=$token';
                await context.push(url);
                ref.invalidate(treatmentsByTokenProvider(token!));
              },
              backgroundColor: _mint,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                l10n.addData,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required Color textPrimary,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> treatment, {
    required bool isActive,
    required bool isDark,
    required AppLocalizations l10n,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final name = treatment['name']?.toString() ?? l10n.medication;
    final dosage = treatment['dosage']?.toString();
    final frequency = treatment['frequency']?.toString();
    final startDate = treatment['startDate'] != null
        ? DateTime.parse(treatment['startDate'].toString())
        : null;
    final endDate = treatment['endDate'] != null
        ? DateTime.parse(treatment['endDate'].toString())
        : null;
    final notes = treatment['notes']?.toString();
    final attachments = (treatment['attachments'] as List?)?.cast<String>() ?? [];

    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor = isDark
        ? (isActive ? _mint.withOpacity(0.5) : Colors.grey.shade700)
        : (isActive ? _mint.withOpacity(0.3) : Colors.grey.shade200);
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final noteBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;

    return InkWell(
      onTap: () {
        if (isVetAccess) {
          // Vétérinaire peut modifier
          _navigateToEdit(context, ref, treatment);
        } else {
          // Utilisateur voit juste un résumé en lecture seule
          _showTreatmentDetails(context, treatment, isDark, l10n, textPrimary, textSecondary);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: isDark ? null : const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _mint.withOpacity(isDark ? 0.2 : 0.1)
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication,
                    color: isActive ? _mint : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      if (dosage != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          dosage,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _mint.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.ongoing,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _mint,
                      ),
                    ),
                  ),
              ],
            ),
            if (frequency != null || startDate != null || endDate != null) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 12),
            ],
            if (frequency != null)
              _buildInfoRow(Icons.access_time, l10n.frequency, frequency, textPrimary, textSecondary),
            if (startDate != null)
              _buildInfoRow(
                Icons.calendar_today,
                l10n.startDate,
                DateFormat('dd/MM/yyyy').format(startDate),
                textPrimary,
                textSecondary,
              ),
            if (endDate != null)
              _buildInfoRow(
                Icons.event,
                l10n.endDate,
                DateFormat('dd/MM/yyyy').format(endDate),
                textPrimary,
                textSecondary,
              ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dividerColor),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        attachments[index],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 20),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (notes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: noteBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, WidgetRef ref, Map<String, dynamic> treatment) async {
    final url = '/pets/$petId/treatments/${treatment['id']}/edit?token=$token';
    await context.push(url);
    ref.invalidate(treatmentsByTokenProvider(token!));
  }

  void _showTreatmentDetails(
    BuildContext context,
    Map<String, dynamic> treatment,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color textSecondary,
  ) {
    final name = treatment['name']?.toString() ?? l10n.medication;
    final dosage = treatment['dosage']?.toString();
    final frequency = treatment['frequency']?.toString();
    final startDate = treatment['startDate'] != null
        ? DateTime.parse(treatment['startDate'].toString())
        : null;
    final endDate = treatment['endDate'] != null
        ? DateTime.parse(treatment['endDate'].toString())
        : null;
    final notes = treatment['notes']?.toString();
    final isActive = treatment['isActive'] == true;
    final attachments = (treatment['attachments'] as List?)?.cast<String>() ?? [];

    final sheetBg = isDark ? _darkCard : Colors.white;
    final handleColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final noteBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _mint.withOpacity(isDark ? 0.2 : 0.1)
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.medication_rounded,
                        color: isActive ? _mint : Colors.grey,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.treatmentDetails,
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _mint.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _mint,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.ongoing,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _mint,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                Divider(color: dividerColor),
                const SizedBox(height: 20),

                // Dosage
                if (dosage != null) ...[
                  _buildDetailRow(
                    icon: Icons.medical_services_outlined,
                    label: l10n.dosage,
                    value: dosage,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 16),
                ],

                // Frequency
                if (frequency != null) ...[
                  _buildDetailRow(
                    icon: Icons.access_time,
                    label: l10n.frequency,
                    value: frequency,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 16),
                ],

                // Start date
                if (startDate != null) ...[
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: l10n.startDate,
                    value: DateFormat('dd MMMM yyyy', 'fr').format(startDate),
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 16),
                ],

                // End date
                if (endDate != null) ...[
                  _buildDetailRow(
                    icon: Icons.event,
                    label: l10n.endDate,
                    value: DateFormat('dd MMMM yyyy', 'fr').format(endDate),
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 16),
                ],

                // Attachments
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: dividerColor),
                    ),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      itemCount: attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Afficher l'image en plein écran
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      child: Image.network(
                                        attachments[index],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              attachments[index],
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 76,
                                height: 76,
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 24),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Notes
                if (notes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: noteBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note_alt_outlined, size: 18, color: textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              l10n.notes,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notes,
                          style: TextStyle(
                            fontSize: 14,
                            color: textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      foregroundColor: textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.close,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: textSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noPrescriptions,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.prescriptionsWillAppear,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, WidgetRef ref, bool isDark, AppLocalizations l10n, Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: _coral),
          const SizedBox(height: 16),
          Text(
            l10n.error,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: textSecondary)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (isVetAccess) {
                ref.invalidate(treatmentsByTokenProvider(token!));
              } else {
                ref.invalidate(activeTreatmentsProvider(petId));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
