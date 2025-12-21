// lib/features/pets/pet_diseases_screen.dart
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

// Provider pour les maladies d'un animal (par petId)
final diseasesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  final diseases = await api.getDiseases(petId);
  return diseases.cast<Map<String, dynamic>>();
});

// Provider pour les maladies via token (accès vétérinaire)
final diseasesByTokenProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, token) async {
  final api = ref.read(apiProvider);
  final petData = await api.getPetByToken(token);
  final petId = petData['id']?.toString();
  if (petId != null) {
    try {
      final diseases = await api.getDiseases(petId);
      return diseases.cast<Map<String, dynamic>>();
    } catch (_) {}
  }
  return (petData['diseases'] as List?)?.cast<Map<String, dynamic>>() ?? [];
});

class PetDiseasesScreen extends ConsumerWidget {
  final String petId;
  final String? token;

  const PetDiseasesScreen({super.key, required this.petId, this.token});

  bool get isVetAccess => token != null && token!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final appBarBg = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final diseasesAsync = isVetAccess
        ? ref.watch(diseasesByTokenProvider(token!))
        : ref.watch(diseasesProvider(petId));

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
          l10n.diseaseFollowUp,
          style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (isVetAccess) {
                ref.invalidate(diseasesByTokenProvider(token!));
              } else {
                ref.invalidate(diseasesProvider(petId));
              }
            },
            icon: Icon(Icons.refresh, color: textPrimary),
          ),
        ],
      ),
      body: diseasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (error, stack) => _buildError(error.toString(), ref, isDark, l10n, textPrimary, textSecondary),
        data: (diseases) {
          if (diseases.isEmpty) {
            return _buildEmptyState(isDark, l10n, textSecondary);
          }

          final ongoing = diseases.where((d) => d['status'] == 'ONGOING').toList();
          final cured = diseases.where((d) => d['status'] == 'CURED').toList();
          final chronic = diseases.where((d) => d['status'] == 'CHRONIC').toList();
          final monitoring = diseases.where((d) => d['status'] == 'MONITORING').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ongoing.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.monitor_heart_rounded,
                    title: l10n.ongoingStatus,
                    count: ongoing.length,
                    color: _coral,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...ongoing.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDiseaseCard(context, d, isDark, l10n, textPrimary, textSecondary),
                  )),
                  const SizedBox(height: 32),
                ],
                if (chronic.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.sync_rounded,
                    title: l10n.chronicStatus,
                    count: chronic.length,
                    color: _orange,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...chronic.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDiseaseCard(context, d, isDark, l10n, textPrimary, textSecondary),
                  )),
                  const SizedBox(height: 32),
                ],
                if (monitoring.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.visibility_rounded,
                    title: l10n.monitoringStatus,
                    count: monitoring.length,
                    color: _purple,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...monitoring.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDiseaseCard(context, d, isDark, l10n, textPrimary, textSecondary),
                  )),
                  const SizedBox(height: 32),
                ],
                if (cured.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.check_circle_rounded,
                    title: l10n.curedStatus,
                    count: cured.length,
                    color: _mint,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 16),
                  ...cured.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDiseaseCard(context, d, isDark, l10n, textPrimary, textSecondary),
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
              ? '/pets/$petId/diseases/new?token=$token'
              : '/pets/$petId/diseases/new';
          context.push(url).then((_) {
            if (isVetAccess) {
              ref.invalidate(diseasesByTokenProvider(token!));
            } else {
              ref.invalidate(diseasesProvider(petId));
            }
          });
        },
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          l10n.addData,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
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

  Widget _buildDiseaseCard(
    BuildContext context,
    Map<String, dynamic> disease,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color textSecondary,
  ) {
    final id = disease['id']?.toString() ?? '';
    final name = disease['name']?.toString() ?? 'Maladie';
    final description = disease['description']?.toString();
    final status = disease['status']?.toString() ?? 'ONGOING';
    final severity = disease['severity']?.toString();
    final diagnosisDate = disease['diagnosisDate'] != null
        ? DateTime.parse(disease['diagnosisDate'].toString())
        : null;
    final curedDate = disease['curedDate'] != null
        ? DateTime.parse(disease['curedDate'].toString())
        : null;
    final vetName = disease['vetName']?.toString();
    final progressEntries = (disease['progressEntries'] as List?)?.length ?? 0;

    final statusColor = _getStatusColor(status);
    final severityColor = _getSeverityColor(severity);
    final cardColor = isDark ? _darkCard : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final url = isVetAccess
              ? '/pets/$petId/diseases/$id?token=$token'
              : '/pets/$petId/diseases/$id';
          context.push(url);
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
                      _getStatusIcon(status),
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
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusLabel(status, l10n),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (severity != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getSeverityLabel(severity, l10n),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: severityColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (diagnosisDate != null) ...[
                    Icon(Icons.calendar_today, size: 14, color: textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.diagnosis}: ${DateFormat('dd/MM/yyyy').format(diagnosisDate)}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                  if (curedDate != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.check, size: 14, color: _mint),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.cured}: ${DateFormat('dd/MM/yyyy').format(curedDate)}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ],
              ),
              if (vetName != null || progressEntries > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (vetName != null) ...[
                      Icon(Icons.medical_services, size: 14, color: textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        vetName,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                    if (vetName != null && progressEntries > 0) const Spacer(),
                    if (progressEntries > 0) ...[
                      Icon(Icons.timeline, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        '$progressEntries ${l10n.updates}',
                        style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ONGOING':
        return _coral;
      case 'CURED':
        return _mint;
      case 'CHRONIC':
        return _orange;
      case 'MONITORING':
        return _purple;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'MILD':
        return _mint;
      case 'MODERATE':
        return _orange;
      case 'SEVERE':
        return _coral;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'ONGOING':
        return Icons.monitor_heart_rounded;
      case 'CURED':
        return Icons.check_circle_rounded;
      case 'CHRONIC':
        return Icons.sync_rounded;
      case 'MONITORING':
        return Icons.visibility_rounded;
      default:
        return Icons.medical_information;
    }
  }

  String _getStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'ONGOING':
        return l10n.ongoingStatus;
      case 'CURED':
        return l10n.cured;
      case 'CHRONIC':
        return l10n.chronicStatus;
      case 'MONITORING':
        return l10n.monitoringStatus;
      default:
        return status;
    }
  }

  String _getSeverityLabel(String severity, AppLocalizations l10n) {
    switch (severity) {
      case 'MILD':
        return l10n.mildSeverity;
      case 'MODERATE':
        return l10n.moderateSeverity;
      case 'SEVERE':
        return l10n.severeSeverity;
      default:
        return severity;
    }
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noDisease,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.diseaseFollowUpWillAppear,
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
                ref.invalidate(diseasesByTokenProvider(token!));
              } else {
                ref.invalidate(diseasesProvider(petId));
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
