// lib/features/pets/pets_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

/// Provider pour la liste des animaux avec toutes leurs données
final myPetsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final pets = await api.myPets();
  return pets.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class PetsManagementScreen extends ConsumerStatefulWidget {
  const PetsManagementScreen({super.key});

  @override
  ConsumerState<PetsManagementScreen> createState() => _PetsManagementScreenState();
}

class _PetsManagementScreenState extends ConsumerState<PetsManagementScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  return Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _currentPage = index),
                          itemCount: pets.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _PetSwipeCard(pet: pets[index]),
                          ),
                        ),
                      ),
                      if (pets.length > 1) _buildPageIndicator(pets.length),
                      const SizedBox(height: 16),
                    ],
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
                  'Swipez pour naviguer',
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

  Widget _buildPageIndicator(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? _coral : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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

class _PetSwipeCard extends ConsumerWidget {
  final Map<String, dynamic> pet;

  const _PetSwipeCard({required this.pet});

  String _getSpeciesIcon(String? species) {
    switch (species?.toLowerCase()) {
      case 'dog':
        return '🐕';
      case 'cat':
        return '🐱';
      case 'bird':
        return '🐦';
      case 'rodent':
        return '🐹';
      case 'reptile':
        return '🦎';
      default:
        return '🐾';
    }
  }

  String _getSpeciesLabel(String? species) {
    switch (species?.toLowerCase()) {
      case 'dog':
        return 'Chien';
      case 'cat':
        return 'Chat';
      case 'bird':
        return 'Oiseau';
      case 'rodent':
        return 'Rongeur';
      case 'reptile':
        return 'Reptile';
      default:
        return 'Animal';
    }
  }

  String _calculateAge(String? birthDateIso) {
    if (birthDateIso == null || birthDateIso.isEmpty) return '';
    try {
      final birthDate = DateTime.parse(birthDateIso);
      final now = DateTime.now();
      final years = now.year - birthDate.year;
      final months = now.month - birthDate.month;

      int totalMonths = years * 12 + months;
      if (now.day < birthDate.day) totalMonths--;

      if (totalMonths < 12) {
        return '$totalMonths mois';
      } else {
        final y = totalMonths ~/ 12;
        final m = totalMonths % 12;
        if (m == 0) return '$y an${y > 1 ? 's' : ''}';
        return '$y an${y > 1 ? 's' : ''} $m mois';
      }
    } catch (_) {
      return '';
    }
  }

  String _formatWeight(dynamic weight) {
    if (weight == null) return '';
    final w = double.tryParse(weight.toString());
    if (w == null) return '';
    return '${w.toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (pet['id'] ?? '').toString();
    final name = (pet['name'] ?? 'Animal').toString();
    final species = pet['species']?.toString();
    final breed = (pet['breed'] ?? '').toString();
    final gender = (pet['gender'] ?? 'UNKNOWN').toString();
    final photoUrl = pet['photoUrl']?.toString();
    final birthDate = pet['birthDate']?.toString();
    final weight = pet['weightKg'];
    final color = (pet['color'] ?? '').toString();
    final isNeutered = pet['isNeutered'] == true;
    final microchip = (pet['microchipNumber'] ?? pet['idNumber'] ?? '').toString();

    // Données avancées
    final vaccinations = (pet['vaccinations'] as List?) ?? [];
    final treatments = (pet['treatments'] as List?) ?? [];
    final allergies = (pet['allergies'] as List?) ?? [];
    final weightRecords = (pet['weightRecords'] as List?) ?? [];

    final age = _calculateAge(birthDate);
    final formattedWeight = _formatWeight(weight);

    // Calculer les alertes
    final alerts = <Widget>[];

    // Vérifier vaccins à venir
    for (final vax in vaccinations) {
      final nextDue = vax['nextDueDate']?.toString();
      if (nextDue != null && nextDue.isNotEmpty) {
        try {
          final dueDate = DateTime.parse(nextDue);
          final daysUntil = dueDate.difference(DateTime.now()).inDays;
          if (daysUntil >= 0 && daysUntil <= 30) {
            alerts.add(_AlertChip(
              icon: Icons.vaccines,
              text: 'Vaccin ${vax['name']} dans $daysUntil j',
              color: daysUntil <= 7 ? Colors.red : Colors.orange,
            ));
          }
        } catch (_) {}
      }
    }

    // Traitements actifs
    final activeTreatments = treatments.where((t) => t['isActive'] == true).length;
    if (activeTreatments > 0) {
      alerts.add(_AlertChip(
        icon: Icons.medication,
        text: '$activeTreatments traitement${activeTreatments > 1 ? 's' : ''} en cours',
        color: Colors.blue,
      ));
    }

    // Allergies
    if (allergies.isNotEmpty) {
      alerts.add(_AlertChip(
        icon: Icons.warning_amber,
        text: '${allergies.length} allergie${allergies.length > 1 ? 's' : ''}',
        color: Colors.red,
      ));
    }

    // Évolution du poids
    String weightTrend = '';
    if (weightRecords.length >= 2) {
      final latest = double.tryParse(weightRecords[0]['weightKg']?.toString() ?? '');
      final previous = double.tryParse(weightRecords[1]['weightKg']?.toString() ?? '');
      if (latest != null && previous != null) {
        final diff = latest - previous;
        if (diff > 0) {
          weightTrend = '+${diff.toStringAsFixed(1)} kg';
        } else if (diff < 0) {
          weightTrend = '${diff.toStringAsFixed(1)} kg';
        }
      }
    }

    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          // Photo section
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _coralSoft,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                        _getSpeciesIcon(species),
                        style: const TextStyle(fontSize: 80),
                      ),
                    )
                  : null,
            ),
          ),

          // Info section
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom et genre
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: gender == 'MALE'
                                ? Colors.blue.shade50
                                : gender == 'FEMALE'
                                    ? Colors.pink.shade50
                                    : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Espèce et race
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _coralSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getSpeciesLabel(species),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
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
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Caractéristiques
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (age.isNotEmpty)
                          _InfoChip(icon: Icons.cake, label: age),
                        if (formattedWeight.isNotEmpty)
                          _InfoChip(
                            icon: Icons.monitor_weight,
                            label: formattedWeight,
                            trailing: weightTrend.isNotEmpty
                                ? Text(
                                    weightTrend,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: weightTrend.startsWith('+')
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                  )
                                : null,
                          ),
                        if (color.isNotEmpty)
                          _InfoChip(icon: Icons.palette, label: color),
                        if (isNeutered)
                          const _InfoChip(icon: Icons.check_circle, label: 'Stérilisé'),
                        if (microchip.isNotEmpty)
                          _InfoChip(icon: Icons.memory, label: 'Pucé'),
                      ],
                    ),

                    // Alertes
                    if (alerts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: alerts,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Boutons d'action
                    Column(
                      children: [
                        // Bouton Modifier
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await context.push('/pets/edit', extra: pet);
                              // Rafraîchir après modification
                              if (context.mounted) {
                                ref.invalidate(myPetsProvider);
                              }
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Modifier les informations'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _coral,
                              side: const BorderSide(color: _coral, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Carnet et QR Code
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/pets/$id/health-stats'),
                                icon: const Icon(Icons.medical_services, size: 18),
                                label: const Text('Carnet'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _coral,
                                  side: const BorderSide(color: _coral, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => context.push('/pets/$id/qr'),
                                icon: const Icon(Icons.qr_code, size: 18),
                                label: const Text('QR Code'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _coral,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _InfoChip({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _AlertChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
