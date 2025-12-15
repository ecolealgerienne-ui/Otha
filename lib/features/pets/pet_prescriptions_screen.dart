// lib/features/pets/pet_prescriptions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);

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
    // Utiliser le provider approprié selon le mode d'accès
    final treatmentsAsync = isVetAccess
        ? ref.watch(treatmentsByTokenProvider(token!))
        : ref.watch(activeTreatmentsProvider(petId));

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
          'Ordonnances',
          style: TextStyle(fontWeight: FontWeight.w700),
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
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: treatmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (error, stack) => _buildError(error.toString(), ref),
        data: (treatments) {
          if (treatments.isEmpty) {
            return _buildEmptyState();
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
                    title: 'Traitements en cours',
                    count: active.length,
                    color: _mint,
                  ),
                  const SizedBox(height: 16),
                  ...active.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTreatmentCard(context, ref, t, isActive: true),
                  )),
                  const SizedBox(height: 32),
                ],
                if (inactive.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.history,
                    title: 'Historique',
                    count: inactive.length,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  ...inactive.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTreatmentCard(context, ref, t, isActive: false),
                  )),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final url = isVetAccess
              ? '/pets/$petId/treatments/new?token=$token'
              : '/pets/$petId/treatments/new';
          await context.push(url);
          if (isVetAccess) {
            ref.invalidate(treatmentsByTokenProvider(token!));
          } else {
            ref.invalidate(activeTreatmentsProvider(petId));
          }
        },
        backgroundColor: _mint,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Ajouter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
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

  Widget _buildTreatmentCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> treatment,
    {required bool isActive}
  ) {
    final name = treatment['name']?.toString() ?? 'Médicament';
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

    return InkWell(
      onTap: () async {
        final url = isVetAccess
            ? '/pets/$petId/treatments/${treatment['id']}/edit?token=$token'
            : '/pets/$petId/treatments/${treatment['id']}/edit';
        await context.push(url);
        if (isVetAccess) {
          ref.invalidate(treatmentsByTokenProvider(token!));
        } else {
          ref.invalidate(activeTreatmentsProvider(petId));
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _mint.withOpacity(0.3) : Colors.grey.shade200,
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
                  color: isActive ? _mint.withOpacity(0.1) : Colors.grey.shade100,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (dosage != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        dosage,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
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
                  child: const Text(
                    'En cours',
                    style: TextStyle(
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
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          if (frequency != null)
            _buildInfoRow(Icons.access_time, 'Fréquence', frequency),
          if (startDate != null)
            _buildInfoRow(
              Icons.calendar_today,
              'Début',
              DateFormat('dd/MM/yyyy').format(startDate),
            ),
          if (endDate != null)
            _buildInfoRow(
              Icons.event,
              'Fin',
              DateFormat('dd/MM/yyyy').format(endDate),
            ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
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
                        color: Colors.grey.shade200,
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'Aucune ordonnance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les ordonnances apparaîtront ici',
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
                ref.invalidate(treatmentsByTokenProvider(token!));
              } else {
                ref.invalidate(activeTreatmentsProvider(petId));
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
