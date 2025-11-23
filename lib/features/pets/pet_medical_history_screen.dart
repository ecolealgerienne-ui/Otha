// lib/features/pets/pet_medical_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

/// Provider pour l'historique médical d'un animal
final medicalRecordsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  final records = await api.getMedicalRecords(petId);
  return records.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

class PetMedicalHistoryScreen extends ConsumerWidget {
  final String petId;

  const PetMedicalHistoryScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petInfoProvider(petId));
    final recordsAsync = ref.watch(medicalRecordsProvider(petId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, petAsync),
            Expanded(
              child: recordsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
                error: (e, _) => Center(child: Text('Erreur: $e')),
                data: (records) {
                  if (records.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return RefreshIndicator(
                    color: _coral,
                    onRefresh: () async => ref.invalidate(medicalRecordsProvider(petId)),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: records.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecordCard(record: records[i], petId: petId),
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
        onPressed: () => context.push('/pets/$petId/medical/add'),
        backgroundColor: _coral,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AsyncValue<Map<String, dynamic>?> petAsync) {
    final petName = petAsync.whenOrNull(data: (pet) => pet?['name']?.toString()) ?? 'Animal';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(
              backgroundColor: _coralSoft,
              foregroundColor: _coral,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sante de $petName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const Text(
                  'Historique medical',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/pets/$petId/health-stats'),
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Statistiques de santé',
            style: IconButton.styleFrom(
              backgroundColor: _coralSoft,
              foregroundColor: _coral,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => ref.invalidate(medicalRecordsProvider(petId)),
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(
              backgroundColor: _coralSoft,
              foregroundColor: _coral,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _coralSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services, size: 48, color: _coral),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun historique',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez le premier record medical',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/pets/$petId/medical/add'),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un record'),
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

  const _RecordCard({required this.record, required this.petId});

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

  String _getTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        return 'Vaccination';
      case 'SURGERY':
        return 'Chirurgie';
      case 'CHECKUP':
        return 'Controle';
      case 'TREATMENT':
        return 'Traitement';
      case 'MEDICATION':
        return 'Medicament';
      default:
        return 'Autre';
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
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
                // Type icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getTypeLabel(type),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ),
                          if (date != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(date),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Supprimer'),
                        content: const Text('Voulez-vous supprimer ce record ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final api = ref.read(apiProvider);
                      await api.deleteMedicalRecord(petId, id);
                      ref.invalidate(medicalRecordsProvider(petId));
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 20),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (vetName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Dr. $vetName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
                        color: Colors.grey.shade200,
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
