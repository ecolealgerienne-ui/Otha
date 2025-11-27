// lib/features/pets/vet_pet_medical_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _green = Color(0xFF43AA8B);

/// Provider pour charger les données d'un animal via token (pour vétérinaires)
final vetPetDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, token) async {
  if (token.isEmpty) return null;
  final api = ref.read(apiProvider);
  return api.getPetByToken(token);
});

/// Écran du carnet médical accessible par le vétérinaire après scan QR
class VetPetMedicalScreen extends ConsumerWidget {
  final String petId;
  final String token;
  final bool bookingConfirmed;

  const VetPetMedicalScreen({
    super.key,
    required this.petId,
    required this.token,
    this.bookingConfirmed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(vetPetDataProvider(token));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pro'),
        ),
        title: const Text(
          'Carnet de santé',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(vetPetDataProvider(token)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/pro'),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
        data: (petData) {
          if (petData == null) {
            return const Center(child: Text('Animal non trouvé'));
          }
          return _buildContent(context, ref, petData);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vet/add-record/$petId?token=$token'),
        backgroundColor: _coral,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter un acte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Map<String, dynamic> petData) {
    final name = (petData['name'] ?? 'Animal').toString();
    final breed = (petData['breed'] ?? '').toString();
    final species = (petData['species'] ?? '').toString();
    final gender = (petData['gender'] ?? 'UNKNOWN').toString();
    final birthDate = petData['birthDate']?.toString();
    final owner = petData['owner'] as Map<String, dynamic>?;
    final ownerName = owner != null
        ? '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim()
        : 'Propriétaire';
    final ownerPhone = owner?['phone']?.toString() ?? '';
    final medicalRecords = (petData['medicalRecords'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return RefreshIndicator(
      color: _coral,
      onRefresh: () async => ref.invalidate(vetPetDataProvider(token)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confirmation banner si booking confirmé
            if (bookingConfirmed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: _green),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Rendez-vous confirmé avec succès',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pet info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _coralSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.pets, color: _coral, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            if (breed.isNotEmpty || species.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [if (species.isNotEmpty) species, if (breed.isNotEmpty) breed].join(' - '),
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        gender == 'MALE'
                            ? Icons.male
                            : gender == 'FEMALE'
                                ? Icons.female
                                : Icons.question_mark,
                        color: gender == 'MALE'
                            ? Colors.blue
                            : gender == 'FEMALE'
                                ? Colors.pink
                                : Colors.grey,
                        size: 28,
                      ),
                    ],
                  ),
                  if (birthDate != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.cake, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text(
                          'Né(e) le ${DateFormat('dd/MM/yyyy').format(DateTime.parse(birthDate))}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  // Owner info
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        'Propriétaire: $ownerName',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      if (ownerPhone.isNotEmpty) ...[
                        const Spacer(),
                        Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          ownerPhone,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section historique médical
            Row(
              children: [
                const Icon(Icons.medical_services, color: _coral),
                const SizedBox(width: 8),
                const Text(
                  'Historique médical',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                Text(
                  '${medicalRecords.length} acte(s)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Liste des records médicaux
            if (medicalRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.medical_services, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun historique médical',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoutez le premier acte médical',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...medicalRecords.map((record) => _buildRecordCard(record)),

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final type = (record['type'] ?? 'OTHER').toString();
    final title = (record['title'] ?? '').toString();
    final description = (record['description'] ?? '').toString();
    final vetName = (record['vetName'] ?? '').toString();
    final notes = (record['notes'] ?? '').toString();
    final dateStr = record['date']?.toString();
    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    IconData icon;
    Color color;
    String typeLabel;
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        icon = Icons.vaccines;
        color = Colors.green;
        typeLabel = 'Vaccination';
        break;
      case 'SURGERY':
        icon = Icons.local_hospital;
        color = Colors.red;
        typeLabel = 'Chirurgie';
        break;
      case 'CHECKUP':
        icon = Icons.health_and_safety;
        color = Colors.blue;
        typeLabel = 'Contrôle';
        break;
      case 'TREATMENT':
        icon = Icons.healing;
        color = Colors.orange;
        typeLabel = 'Traitement';
        break;
      case 'MEDICATION':
        icon = Icons.medication;
        color = Colors.purple;
        typeLabel = 'Médicament';
        break;
      case 'VET_VISIT':
        icon = Icons.local_hospital;
        color = _coral;
        typeLabel = 'Visite vétérinaire';
        break;
      default:
        icon = Icons.medical_services;
        color = _coral;
        typeLabel = 'Autre';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
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
        ],
      ),
    );
  }
}
