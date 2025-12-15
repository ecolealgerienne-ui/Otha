// lib/features/pets/pet_vaccinations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);
const _orange = Color(0xFFF39C12);
const _purple = Color(0xFF9B59B6);

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
  final String? token; // Token optionnel pour accès vétérinaire

  const PetVaccinationsScreen({super.key, required this.petId, this.token});

  bool get isVetAccess => token != null && token!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Utiliser le provider approprié selon le mode d'accès
    final vaccinationsAsync = isVetAccess
        ? ref.watch(vaccinationsByTokenProvider(token!))
        : ref.watch(vaccinationsProvider(petId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Vaccinations',
          style: TextStyle(fontWeight: FontWeight.w700),
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
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: vaccinationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _purple)),
        error: (error, stack) => _buildError(error.toString(), ref),
        data: (vaccinations) {
          if (vaccinations.isEmpty) {
            return _buildEmptyState();
          }

          // Trier: rappels en retard d'abord, puis à venir, puis les autres
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

          // Séparer en catégories
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
                // Statistiques rapides
                if (overdue.isNotEmpty || upcoming.isNotEmpty)
                  _buildStatsCards(overdue.length, upcoming.length),

                if (overdue.isNotEmpty || upcoming.isNotEmpty)
                  const SizedBox(height: 24),

                // En retard
                if (overdue.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.warning_rounded,
                    title: 'Rappels en retard',
                    count: overdue.length,
                    color: _coral,
                  ),
                  const SizedBox(height: 16),
                  ...overdue.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.overdue),
                  )),
                  const SizedBox(height: 32),
                ],

                // À venir (< 30 jours)
                if (upcoming.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.schedule_rounded,
                    title: 'Prochainement',
                    count: upcoming.length,
                    color: _orange,
                  ),
                  const SizedBox(height: 16),
                  ...upcoming.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.upcoming),
                  )),
                  const SizedBox(height: 32),
                ],

                // À venir (> 30 jours)
                if (future.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.event_available_rounded,
                    title: 'Planifiés',
                    count: future.length,
                    color: _mint,
                  ),
                  const SizedBox(height: 16),
                  ...future.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.future),
                  )),
                  const SizedBox(height: 32),
                ],

                // Sans rappel
                if (noReminder.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.vaccines_rounded,
                    title: 'Effectués',
                    count: noReminder.length,
                    color: _purple,
                  ),
                  const SizedBox(height: 16),
                  ...noReminder.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildVaccinationCard(context, ref, v, VaccineStatus.done),
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
        label: const Text(
          'Ajouter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildStatsCards(int overdueCount, int upcomingCount) {
    return Row(
      children: [
        if (overdueCount > 0)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _coral.withOpacity(0.3), width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: _coral, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$overdueCount',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _coral,
                          ),
                        ),
                        Text(
                          'En retard',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
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
                color: _orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _orange.withOpacity(0.3), width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: _orange, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$upcomingCount',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _orange,
                          ),
                        ),
                        Text(
                          'À venir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
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
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
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
  ) {
    final id = vaccination['id']?.toString() ?? '';
    final name = vaccination['name']?.toString() ?? 'Vaccin';
    final date = vaccination['date'] != null
        ? DateTime.parse(vaccination['date'].toString())
        : null;
    final nextDueDate = vaccination['nextDueDate'] != null
        ? DateTime.parse(vaccination['nextDueDate'].toString())
        : null;
    final batchNumber = vaccination['batchNumber']?.toString();
    final vetName = vaccination['vetName']?.toString();
    final notes = vaccination['notes']?.toString();

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showVaccinationDetails(context, ref, vaccination);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: const [
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
                      color: statusColor.withOpacity(0.1),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        if (date != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Effectué le ${DateFormat('dd/MM/yyyy').format(date)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
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
                const Divider(height: 1),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
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
                              'Prochain rappel',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
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
                      if (status == VaccineStatus.overdue || status == VaccineStatus.upcoming) ...[
                        Text(
                          _getDaysText(nextDueDate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (batchNumber != null || vetName != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (batchNumber != null) ...[
                      Icon(Icons.qr_code, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Lot: $batchNumber',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                    if (batchNumber != null && vetName != null) const SizedBox(width: 12),
                    if (vetName != null) ...[
                      Icon(Icons.medical_services, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vetName,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

  void _showVaccinationDetails(BuildContext context, WidgetRef ref, Map<String, dynamic> vaccination) {
    final id = vaccination['id']?.toString() ?? '';
    final name = vaccination['name']?.toString() ?? 'Vaccin';
    final date = vaccination['date'] != null
        ? DateTime.parse(vaccination['date'].toString())
        : null;
    final nextDueDate = vaccination['nextDueDate'] != null
        ? DateTime.parse(vaccination['nextDueDate'].toString())
        : null;
    final batchNumber = vaccination['batchNumber']?.toString();
    final vetName = vaccination['vetName']?.toString();
    final notes = vaccination['notes']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
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
                    _confirmDelete(context, ref, id, name);
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
              _buildDetailRow(Icons.calendar_today, 'Date', DateFormat('dd/MM/yyyy').format(date)),
            if (nextDueDate != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(Icons.event, 'Rappel', DateFormat('dd/MM/yyyy').format(nextDueDate)),
            ],
            if (batchNumber != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(Icons.qr_code, 'Lot', batchNumber),
            ],
            if (vetName != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(Icons.medical_services, 'Vétérinaire', vetName),
            ],
            if (notes != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notes,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
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
              child: const Text('Fermer'),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le vaccin'),
        content: Text('Êtes-vous sûr de vouloir supprimer "$name" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
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
                    const SnackBar(
                      content: Text('Vaccin supprimé'),
                      backgroundColor: _coral,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: const Text('Supprimer'),
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

  String _getDaysText(DateTime nextDue) {
    final now = DateTime.now();
    final diff = nextDue.difference(now).inDays;

    if (diff < 0) {
      final days = diff.abs();
      return days == 1 ? 'Retard 1j' : 'Retard ${days}j';
    } else if (diff == 0) {
      return 'Aujourd\'hui';
    } else {
      return diff == 1 ? 'Dans 1j' : 'Dans ${diff}j';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.vaccines_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'Aucun vaccin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez les vaccins de votre animal',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Erreur',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: Colors.grey.shade600)),
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
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

enum VaccineStatus {
  overdue,   // En retard
  upcoming,  // À venir (< 30 jours)
  future,    // Planifié (> 30 jours)
  done,      // Effectué sans rappel
}
