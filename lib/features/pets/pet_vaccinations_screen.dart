// lib/features/pets/pet_vaccinations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);
const _orange = Color(0xFFF39C12);
const _purple = Color(0xFF9B59B6);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

// Provider pour les vaccinations d'un animal (par petId)
final vaccinationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  final vaccinations = await api.getVaccinations(petId);
  return vaccinations.cast<Map<String, dynamic>>();
});

// Provider pour les vaccinations via token (accès vétérinaire)
final vaccinationsByTokenProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, token) async {
  final api = ref.read(apiProvider);
  final petData = await api.getPetByToken(token);
  final vaccinations = (petData['vaccinations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  return vaccinations;
});

class PetVaccinationsScreen extends ConsumerWidget {
  final String petId;
  final String? token;

  const PetVaccinationsScreen({super.key, required this.petId, this.token});

  bool get isVetAccess => token != null && token!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final appBarBg = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final vaccinationsAsync = isVetAccess
        ? ref.watch(vaccinationsByTokenProvider(token!))
        : ref.watch(vaccinationsProvider(petId));

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
          l10n.vaccinations,
          style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (isVetAccess) {
                ref.invalidate(vaccinationsByTokenProvider(token!));
              } else {
                ref.invalidate(vaccinationsProvider(petId));
              }
            },
            icon: Icon(Icons.refresh, color: textPrimary),
          ),
        ],
      ),
      body: vaccinationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _purple)),
        error: (error, stack) => _buildError(error.toString(), ref, isDark, l10n, textPrimary, textSecondary),
        data: (vaccinations) {
          if (vaccinations.isEmpty) {
            return _buildEmptyState(isDark, l10n, textSecondary);
          }

          final now = DateTime.now();
          final sorted = vaccinations.toList()..sort((a, b) {
            final aNext = a['nextDueDate'] != null ? DateTime.parse(a['nextDueDate'].toString()) : null;
            final bNext = b['nextDueDate'] != null ? DateTime.parse(b['nextDueDate'].toString()) : null;
            if (aNext == null && bNext == null) return 0;
            if (aNext == null) return 1;
            if (bNext == null) return -1;
            final aOverdue = aNext.isBefore(now);
            final bOverdue = bNext.isBefore(now);
            if (aOverdue && !bOverdue) return -1;
            if (!aOverdue && bOverdue) return 1;
            return aNext.compareTo(bNext);
          });

          final overdue = sorted.where((v) {
            if (v['nextDueDate'] == null) return false;
            final next = DateTime.parse(v['nextDueDate'].toString());
            return next.isBefore(now);
          }).toList();

          final upcoming = sorted.where((v) {
            if (v['nextDueDate'] == null) return false;
            final next = DateTime.parse(v['nextDueDate'].toString());
            final diff = next.difference(now).inDays;
            return diff >= 0 && diff <= 30;
          }).toList();

          final future = sorted.where((v) {
            if (v['nextDueDate'] == null) return false;
            final next = DateTime.parse(v['nextDueDate'].toString());
            return next.difference(now).inDays > 30;
          }).toList();

          final noReminder = sorted.where((v) => v['nextDueDate'] == null).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overdue.isNotEmpty || upcoming.isNotEmpty)
                  _buildStatsCards(overdue.length, upcoming.length, isDark, l10n, textSecondary),

                if (overdue.isNotEmpty || upcoming.isNotEmpty)
                  const SizedBox(height: 24),

                if (overdue.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.warning_rounded,
                    title: l10n.overdueReminders,
                    count: overdue.length,
                    color: _coral,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...overdue.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.overdue, isDark, l10n, textPrimary, textSecondary),
                  )),
                  const SizedBox(height: 32),
                ],

                if (upcoming.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.schedule_rounded,
                    title: l10n.upcoming,
                    count: upcoming.length,
                    color: _orange,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...upcoming.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.upcoming, isDark, l10n, textPrimary, textSecondary),
                  )),
                  const SizedBox(height: 32),
                ],

                if (future.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.event_available_rounded,
                    title: l10n.planned,
                    count: future.length,
                    color: _mint,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...future.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.future, isDark, l10n, textPrimary, textSecondary),
                  )),
                  const SizedBox(height: 32),
                ],

                if (noReminder.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.vaccines_rounded,
                    title: l10n.completed,
                    count: noReminder.length,
                    color: _purple,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...noReminder.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.done, isDark, l10n, textPrimary, textSecondary),
                  )),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final url = isVetAccess
              ? '/pets/$petId/vaccinations/new?token=$token'
              : '/pets/$petId/vaccinations/new';
          context.push(url).then((_) {
            if (isVetAccess) {
              ref.invalidate(vaccinationsByTokenProvider(token!));
            } else {
              ref.invalidate(vaccinationsProvider(petId));
            }
          });
        },
        backgroundColor: _purple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          l10n.addData,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildStatsCards(int overdueCount, int upcomingCount, bool isDark, AppLocalizations l10n, Color textSecondary) {
    return Row(
      children: [
        if (overdueCount > 0)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _coral.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _coral.withOpacity(0.3), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: _coral, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$overdueCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _coral,
                          ),
                        ),
                        Text(
                          l10n.overdue,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (overdueCount > 0 && upcomingCount > 0) const SizedBox(width: 12),
        if (upcomingCount > 0)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _orange.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _orange.withOpacity(0.3), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: _orange, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$upcomingCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _orange,
                          ),
                        ),
                        Text(
                          l10n.upcoming,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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

  Widget _buildVaccinationCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> vaccination,
    VaccineStatus status,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color textSecondary,
  ) {
    final name = vaccination['name']?.toString() ?? l10n.vaccination;
    final date = vaccination['date'] != null
        ? DateTime.parse(vaccination['date'].toString())
        : null;
    final nextDueDate = vaccination['nextDueDate'] != null
        ? DateTime.parse(vaccination['nextDueDate'].toString())
        : null;
    final batchNumber = vaccination['batchNumber']?.toString();
    final vetName = vaccination['vetName']?.toString();

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final cardColor = isDark ? _darkCard : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showVaccinationDetails(context, ref, vaccination, isDark, l10n, textPrimary, textSecondary);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 2,
            ),
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
                      color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.vaccines_rounded,
                      color: statusColor,
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
                        if (date != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.date}: ${DateFormat('dd/MM/yyyy').format(date)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                ],
              ),
              if (nextDueDate != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 18, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.nextReminder,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd/MM/yyyy').format(nextDueDate),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status == VaccineStatus.overdue || status == VaccineStatus.upcoming)
                        Text(
                          _getDaysText(nextDueDate, l10n),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (batchNumber != null || vetName != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (batchNumber != null) ...[
                      Icon(Icons.qr_code, size: 14, color: textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.batch}: $batchNumber',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                    if (batchNumber != null && vetName != null) const SizedBox(width: 12),
                    if (vetName != null) ...[
                      Icon(Icons.medical_services, size: 14, color: textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vetName,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showVaccinationDetails(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> vaccination,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color textSecondary,
  ) {
    final id = vaccination['id']?.toString() ?? '';
    final name = vaccination['name']?.toString() ?? l10n.vaccination;
    final date = vaccination['date'] != null
        ? DateTime.parse(vaccination['date'].toString())
        : null;
    final nextDueDate = vaccination['nextDueDate'] != null
        ? DateTime.parse(vaccination['nextDueDate'].toString())
        : null;
    final batchNumber = vaccination['batchNumber']?.toString();
    final vetName = vaccination['vetName']?.toString();
    final notes = vaccination['notes']?.toString();

    final sheetBg = isDark ? _darkCard : Colors.white;
    final handleColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final url = isVetAccess
                        ? '/pets/$petId/vaccinations/$id/edit?token=$token'
                        : '/pets/$petId/vaccinations/$id/edit';
                    context.push(url).then((_) {
                      if (isVetAccess) {
                        ref.invalidate(vaccinationsByTokenProvider(token!));
                      } else {
                        ref.invalidate(vaccinationsProvider(petId));
                      }
                    });
                  },
                  icon: const Icon(Icons.edit),
                  style: IconButton.styleFrom(
                    backgroundColor: _purple.withOpacity(0.1),
                    foregroundColor: _purple,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(context, ref, id, name, l10n);
                  },
                  icon: const Icon(Icons.delete),
                  style: IconButton.styleFrom(
                    backgroundColor: _coral.withOpacity(0.1),
                    foregroundColor: _coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (date != null)
              _buildDetailRow(Icons.calendar_today, l10n.date, DateFormat('dd/MM/yyyy').format(date), textPrimary, textSecondary),
            if (nextDueDate != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(Icons.event, l10n.reminder, DateFormat('dd/MM/yyyy').format(nextDueDate), textPrimary, textSecondary),
            ],
            if (batchNumber != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(Icons.qr_code, l10n.batch, batchNumber, textPrimary, textSecondary),
            ],
            if (vetName != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(Icons.medical_services, l10n.veterinarian, vetName, textPrimary, textSecondary),
            ],
            if (notes != null) ...[
              const SizedBox(height: 24),
              Text(
                l10n.notes,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notes,
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n.close),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textSecondary),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteVaccine),
        content: Text('${l10n.confirmDeleteVaccine} "$name" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final api = ref.read(apiProvider);
                await api.deleteVaccination(petId, id);

                ref.invalidate(vaccinationsProvider(petId));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.vaccineDeleted),
                      backgroundColor: _coral,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.error}: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(VaccineStatus status) {
    switch (status) {
      case VaccineStatus.overdue:
        return _coral;
      case VaccineStatus.upcoming:
        return _orange;
      case VaccineStatus.future:
        return _mint;
      case VaccineStatus.done:
        return _purple;
    }
  }

  IconData _getStatusIcon(VaccineStatus status) {
    switch (status) {
      case VaccineStatus.overdue:
        return Icons.warning_rounded;
      case VaccineStatus.upcoming:
        return Icons.schedule_rounded;
      case VaccineStatus.future:
        return Icons.event_available_rounded;
      case VaccineStatus.done:
        return Icons.check_circle_rounded;
    }
  }

  String _getDaysText(DateTime nextDue, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = nextDue.difference(now).inDays;

    if (diff < 0) {
      final days = diff.abs();
      return '${l10n.delayDays} ${days}${l10n.day}';
    } else if (diff == 0) {
      return l10n.today;
    } else {
      return '${l10n.inDays} $diff${diff == 1 ? l10n.day : l10n.days}';
    }
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.vaccines_outlined,
            size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noVaccine,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addPetVaccines,
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
                ref.invalidate(vaccinationsByTokenProvider(token!));
              } else {
                ref.invalidate(vaccinationsProvider(petId));
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

enum VaccineStatus {
  overdue,
  upcoming,
  future,
  done,
}
