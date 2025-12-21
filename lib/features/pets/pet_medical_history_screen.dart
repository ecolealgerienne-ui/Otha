// lib/features/pets/pet_medical_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

/// Provider pour l'historique médical d'un animal (par petId)
final medicalRecordsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  final records = await api.getMedicalRecords(petId);
  return records.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Provider pour l'historique médical via token (accès vétérinaire)
final medicalRecordsByTokenProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, token) async {
  final api = ref.read(apiProvider);
  final petData = await api.getPetByToken(token);
  final records = (petData['medicalRecords'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  return records;
});

/// Provider pour les infos d'un animal
final petInfoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  final pets = await api.myPets();
  for (final pet in pets) {
    if ((pet as Map)['id'] == petId) {
      return Map<String, dynamic>.from(pet);
    }
  }
  return null;
});

/// Provider pour les infos d'un animal via token
final petInfoByTokenProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, token) async {
  final api = ref.read(apiProvider);
  return api.getPetByToken(token);
});

class PetMedicalHistoryScreen extends ConsumerWidget {
  final String petId;
  final String? token;

  const PetMedicalHistoryScreen({super.key, required this.petId, this.token});

  bool get isVetAccess => token != null && token!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final petAsync = isVetAccess
        ? ref.watch(petInfoByTokenProvider(token!))
        : ref.watch(petInfoProvider(petId));
    final recordsAsync = isVetAccess
        ? ref.watch(medicalRecordsByTokenProvider(token!))
        : ref.watch(medicalRecordsProvider(petId));

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, petAsync, isDark, l10n, textPrimary),
            Expanded(
              child: recordsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
                error: (e, _) => Center(child: Text('${l10n.error}: $e', style: TextStyle(color: textPrimary))),
                data: (records) {
                  if (records.isEmpty) {
                    return _buildEmptyState(context, isDark, l10n, textSecondary);
                  }
                  return RefreshIndicator(
                    color: _coral,
                    onRefresh: () async {
                      if (isVetAccess) {
                        ref.invalidate(medicalRecordsByTokenProvider(token!));
                      } else {
                        ref.invalidate(medicalRecordsProvider(petId));
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: records.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecordCard(
                          record: records[i],
                          petId: petId,
                          token: token,
                          isDark: isDark,
                          l10n: l10n,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final url = isVetAccess
              ? '/pets/$petId/medical/add?token=$token'
              : '/pets/$petId/medical/add';
          context.push(url);
        },
        backgroundColor: _coral,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(l10n.addData, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>?> petAsync,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
  ) {
    final petName = petAsync.whenOrNull(data: (pet) => pet?['name']?.toString()) ?? 'Animal';
    final headerBg = isDark ? _darkCard : Colors.white;
    final buttonBg = isDark ? _coral.withOpacity(0.2) : _coralSoft;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: headerBg,
        boxShadow: isDark ? null : const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: _coral,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.healthOf} $petName',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  l10n.medicalHistoryTitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final url = isVetAccess
                  ? '/pets/$petId/health-stats?token=$token'
                  : '/pets/$petId/health-stats';
              context.push(url);
            },
            icon: const Icon(Icons.analytics_outlined),
            tooltip: l10n.healthStats,
            style: IconButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: _coral,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              if (isVetAccess) {
                ref.invalidate(medicalRecordsByTokenProvider(token!));
              } else {
                ref.invalidate(medicalRecordsProvider(petId));
              }
            },
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: _coral,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, AppLocalizations l10n, Color textSecondary) {
    final buttonBg = isDark ? _coral.withOpacity(0.2) : _coralSoft;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: buttonBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services, size: 48, color: _coral),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noHistory,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addFirstRecord,
            style: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final url = isVetAccess
                  ? '/pets/$petId/medical/add?token=$token'
                  : '/pets/$petId/medical/add';
              context.push(url);
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addRecord),
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  final Map<String, dynamic> record;
  final String petId;
  final String? token;
  final bool isDark;
  final AppLocalizations l10n;
  final Color textPrimary;
  final Color textSecondary;

  const _RecordCard({
    required this.record,
    required this.petId,
    this.token,
    required this.isDark,
    required this.l10n,
    required this.textPrimary,
    required this.textSecondary,
  });

  bool get isVetAccess => token != null && token!.isNotEmpty;

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        return Icons.vaccines;
      case 'SURGERY':
        return Icons.local_hospital;
      case 'CHECKUP':
        return Icons.health_and_safety;
      case 'TREATMENT':
        return Icons.healing;
      case 'MEDICATION':
        return Icons.medication;
      default:
        return Icons.medical_services;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        return Colors.green;
      case 'SURGERY':
        return Colors.red;
      case 'CHECKUP':
        return Colors.blue;
      case 'TREATMENT':
        return Colors.orange;
      case 'MEDICATION':
        return Colors.purple;
      default:
        return _coral;
    }
  }

  String _getTypeLabel(String type, AppLocalizations l10n) {
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        return l10n.vaccination;
      case 'SURGERY':
        return l10n.surgery;
      case 'CHECKUP':
        return l10n.checkup;
      case 'TREATMENT':
        return l10n.treatment;
      case 'MEDICATION':
        return l10n.medication;
      default:
        return l10n.other;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (record['id'] ?? '').toString();
    final type = (record['type'] ?? 'OTHER').toString();
    final title = (record['title'] ?? '').toString();
    final description = (record['description'] ?? '').toString();
    final vetName = (record['vetName'] ?? '').toString();
    final notes = (record['notes'] ?? '').toString();
    final images = (record['images'] as List?)?.cast<String>() ?? [];

    DateTime? date;
    final dateStr = record['date']?.toString();
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    final typeColor = _getTypeColor(type);
    final cardColor = isDark ? _darkCard : Colors.white;
    final noteBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getTypeIcon(type), color: typeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getTypeLabel(type, l10n),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ),
                          if (date != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today, size: 12, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(date),
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.deleteRecord),
                        content: Text(l10n.confirmDeleteRecord),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final api = ref.read(apiProvider);
                      await api.deleteMedicalRecord(petId, id);
                      if (isVetAccess) {
                        ref.invalidate(medicalRecordsByTokenProvider(token!));
                      } else {
                        ref.invalidate(medicalRecordsProvider(petId));
                      }
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 20),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (vetName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Dr. $vetName',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: noteBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 14, color: textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(fontSize: 12, color: textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[i],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
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
