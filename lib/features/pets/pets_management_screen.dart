// lib/features/pets/pets_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

/// Provider pour la liste des animaux
final myPetsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final pets = await api.myPets();
  return pets.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class PetsManagementScreen extends ConsumerWidget {
  const PetsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(myPetsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: petsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
                error: (e, _) => Center(child: Text('Erreur: $e')),
                data: (pets) {
                  if (pets.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return RefreshIndicator(
                    color: _coral,
                    onRefresh: () async => ref.invalidate(myPetsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: pets.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PetCard(pet: pets[i]),
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
        onPressed: () => context.push('/pets/add'),
        backgroundColor: _coral,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes animaux',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                Text(
                  'Gerez vos animaux et leur sante',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.invalidate(myPetsProvider),
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
            child: const Icon(Icons.pets, size: 48, color: _coral),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun animal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier animal',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/pets/add'),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un animal'),
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

class _PetCard extends ConsumerWidget {
  final Map<String, dynamic> pet;

  const _PetCard({required this.pet});

  String _getAnimalType(String? idNumber) {
    if (idNumber == null) return 'Animal';
    final lower = idNumber.toLowerCase();
    if (lower.contains('chien') || lower.contains('dog')) return 'Chien';
    if (lower.contains('chat') || lower.contains('cat')) return 'Chat';
    if (lower.contains('nac')) return 'NAC';
    if (lower.contains('oiseau') || lower.contains('bird')) return 'Oiseau';
    if (lower.contains('reptile')) return 'Reptile';
    return idNumber;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final inits = parts.take(2).map((e) => e[0]).join().toUpperCase();
    return inits.isEmpty ? 'AN' : inits;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (pet['id'] ?? '').toString();
    final name = (pet['name'] ?? 'Animal').toString();
    final breed = (pet['breed'] ?? '').toString();
    final animalType = _getAnimalType(pet['idNumber']?.toString());
    final gender = (pet['gender'] ?? 'UNKNOWN').toString();
    final photoUrl = pet['photoUrl']?.toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/pets/$id/medical'),
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
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _coralSoft,
                      borderRadius: BorderRadius.circular(12),
                      image: photoUrl != null && photoUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Center(
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                color: _coral,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _coralSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                animalType,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _coral,
                                ),
                              ),
                            ),
                            if (breed.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  breed,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Gender icon
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
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Actions
              Row(
                children: [
                  // Medical history
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/pets/$id/medical'),
                      icon: const Icon(Icons.medical_services, size: 16),
                      label: const Text('Historique'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _coral,
                        side: const BorderSide(color: _coral),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // QR Code
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/pets/$id/qr'),
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('QR Code'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
