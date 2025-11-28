// lib/features/pets/pet_health_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _mint = Color(0xFF4ECDC4);
const _purple = Color(0xFF9B59B6);
const _orange = Color(0xFFF39C12);

// Provider pour les infos d'un animal
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

// Provider pour récupérer les dernières données de santé
final latestHealthDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, petId) async {
  try {
    final api = ref.read(apiProvider);
    final stats = await api.getHealthStats(petId);
    return stats;
  } catch (e) {
    return null;
  }
});

class PetHealthHubScreen extends ConsumerWidget {
  final String petId;

  const PetHealthHubScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petInfoProvider(petId));
    final healthAsync = ref.watch(latestHealthDataProvider(petId));

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
        title: petAsync.when(
          data: (pet) => Text(
            'Santé de ${pet?['name'] ?? 'Animal'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          loading: () => const Text('Santé'),
          error: (_, __) => const Text('Santé'),
        ),
      ),
      body: RefreshIndicator(
        color: _coral,
        onRefresh: () async {
          ref.invalidate(latestHealthDataProvider(petId));
          ref.invalidate(petInfoProvider(petId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vue d'ensemble rapide
              _buildQuickOverview(healthAsync),
              const SizedBox(height: 32),

              // Section titre
              const Text(
                'Accès rapide',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),

              // Cartes d'accès rapide
              _buildActionCard(
                context: context,
                icon: Icons.history_rounded,
                title: 'Historique médical',
                subtitle: 'Consultations, diagnostics, traitements',
                color: Colors.blue,
                gradientColor: Colors.blue.withOpacity(0.7),
                onTap: () => context.push('/pets/$petId/medical'),
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.analytics_rounded,
                title: 'Statistiques de santé',
                subtitle: 'Poids, température, fréquence cardiaque',
                color: _coral,
                gradientColor: _coral.withOpacity(0.7),
                onTap: () => context.push('/pets/$petId/health-stats-detail'),
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.medication_rounded,
                title: 'Ordonnances',
                subtitle: 'Médicaments et traitements prescrits',
                color: _mint,
                gradientColor: _mint.withOpacity(0.7),
                onTap: () => context.push('/pets/$petId/prescriptions'),
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.vaccines_rounded,
                title: 'Vaccinations',
                subtitle: 'Calendrier et rappels de vaccins',
                color: _purple,
                gradientColor: _purple.withOpacity(0.7),
                onTap: () => context.push('/pets/$petId/vaccinations'),
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.monitor_heart_rounded,
                title: 'Suivi de maladie',
                subtitle: 'Photos, évolution, notes',
                color: _orange,
                gradientColor: _orange.withOpacity(0.7),
                onTap: () => context.push('/pets/$petId/diseases'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOverview(AsyncValue<Map<String, dynamic>?> healthAsync) {
    return healthAsync.when(
      data: (stats) {
        if (stats == null) {
          return _buildEmptyOverview();
        }

        final weight = stats['weight'] as Map<String, dynamic>?;
        final temp = stats['temperature'] as Map<String, dynamic>?;
        final heart = stats['heartRate'] as Map<String, dynamic>?;

        final currentWeight = weight?['current'];
        final currentTemp = temp?['current'];
        final currentHeart = heart?['current'];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_coral.withOpacity(0.1), _mint.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _coral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'État de santé',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        Text(
                          'Dernières mesures enregistrées',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (currentWeight != null)
                    Expanded(
                      child: _buildMiniStat(
                        icon: Icons.monitor_weight,
                        label: 'Poids',
                        value: '${currentWeight.toStringAsFixed(1)} kg',
                        color: _coral,
                      ),
                    ),
                  if (currentWeight != null && currentTemp != null) const SizedBox(width: 12),
                  if (currentTemp != null)
                    Expanded(
                      child: _buildMiniStat(
                        icon: Icons.thermostat,
                        label: 'Temp.',
                        value: '${currentTemp.toStringAsFixed(1)}°C',
                        color: _mint,
                      ),
                    ),
                  if ((currentWeight != null || currentTemp != null) && currentHeart != null)
                    const SizedBox(width: 12),
                  if (currentHeart != null)
                    Expanded(
                      child: _buildMiniStat(
                        icon: Icons.favorite,
                        label: 'Cœur',
                        value: '$currentHeart bpm',
                        color: _purple,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingSkeleton(),
      error: (_, __) => _buildEmptyOverview(),
    );
  }

  Widget _buildEmptyOverview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade400, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucune donnée de santé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Les données apparaîtront après les visites vétérinaires',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color gradientColor,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, gradientColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
