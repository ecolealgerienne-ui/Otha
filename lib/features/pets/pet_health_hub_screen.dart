// lib/features/pets/pet_health_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF36C6C);
const _ink = Color(0xFF222222);
const _mint = Color(0xFF4ECDC4);
const _purple = Color(0xFF9B59B6);
const _orange = Color(0xFFF39C12);
const _green = Color(0xFF43AA8B);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

// Provider pour les infos d'un animal (propriétaire)
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

// Provider pour les infos d'un animal via token (vétérinaire)
final petInfoByTokenProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, token) async {
  if (token.isEmpty) return null;
  final api = ref.read(apiProvider);
  return api.getPetByToken(token);
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
  final String? token;
  final bool isVetAccess;
  final bool bookingConfirmed;

  const PetHealthHubScreen({
    super.key,
    required this.petId,
    this.token,
    this.isVetAccess = false,
    this.bookingConfirmed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final appBarBg = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final petAsync = isVetAccess && token != null
        ? ref.watch(petInfoByTokenProvider(token!))
        : ref.watch(petInfoProvider(petId));
    final healthAsync = ref.watch(latestHealthDataProvider(petId));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () {
            if (isVetAccess) {
              context.go('/pro');
            } else {
              context.pop();
            }
          },
        ),
        title: petAsync.when(
          data: (pet) => Text(
            '${l10n.petHealth} ${pet?['name'] ?? ''}',
            style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
          ),
          loading: () => Text(l10n.petHealth, style: TextStyle(color: textPrimary)),
          error: (_, __) => Text(l10n.petHealth, style: TextStyle(color: textPrimary)),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (isVetAccess && token != null) {
                ref.invalidate(petInfoByTokenProvider(token!));
              } else {
                ref.invalidate(petInfoProvider(petId));
              }
              ref.invalidate(latestHealthDataProvider(petId));
            },
            icon: Icon(Icons.refresh, color: textPrimary),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _coral,
        onRefresh: () async {
          if (isVetAccess && token != null) {
            ref.invalidate(petInfoByTokenProvider(token!));
          } else {
            ref.invalidate(petInfoProvider(petId));
          }
          ref.invalidate(latestHealthDataProvider(petId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner de confirmation RDV (pour vets)
              if (bookingConfirmed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? _green.withOpacity(0.2) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: _green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.appointmentConfirmedSuccess,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: _green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Info propriétaire (pour vets)
              if (isVetAccess)
                petAsync.when(
                  data: (pet) {
                    if (pet == null) return const SizedBox.shrink();
                    final owner = pet['owner'] as Map<String, dynamic>?;
                    if (owner == null) return const SizedBox.shrink();
                    final ownerName = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim();
                    final ownerPhone = owner['phone']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? _darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 20, color: textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            '${l10n.owner}: $ownerName',
                            style: TextStyle(fontSize: 14, color: textSecondary),
                          ),
                          if (ownerPhone.isNotEmpty) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone, size: 14, color: _green),
                                  const SizedBox(width: 4),
                                  Text(
                                    ownerPhone,
                                    style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

              // Vue d'ensemble rapide
              _buildQuickOverview(healthAsync, isDark, l10n, textPrimary, textSecondary),
              const SizedBox(height: 32),

              // Section titre
              Text(
                l10n.quickAccess,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Cartes d'accès rapide
              _buildActionCard(
                context: context,
                icon: Icons.history_rounded,
                title: l10n.medicalHistoryTitle,
                subtitle: l10n.consultationsDiagnosis,
                color: Colors.blue,
                gradientColor: Colors.blue.withOpacity(0.7),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  final url = isVetAccess && token != null
                      ? '/pets/$petId/medical?token=$token'
                      : '/pets/$petId/medical';
                  context.push(url);
                },
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.analytics_rounded,
                title: l10n.healthStats,
                subtitle: l10n.weightTempHeart,
                color: _coral,
                gradientColor: _coral.withOpacity(0.7),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  final url = isVetAccess && token != null
                      ? '/pets/$petId/health-stats-detail?token=$token'
                      : '/pets/$petId/health-stats-detail';
                  context.push(url);
                },
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.medication_rounded,
                title: l10n.prescriptions,
                subtitle: l10n.prescribedMedications,
                color: _mint,
                gradientColor: _mint.withOpacity(0.7),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  final url = isVetAccess && token != null
                      ? '/pets/$petId/prescriptions?token=$token'
                      : '/pets/$petId/prescriptions';
                  context.push(url);
                },
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.vaccines_rounded,
                title: l10n.vaccinations,
                subtitle: l10n.vaccineCalendar,
                color: _purple,
                gradientColor: _purple.withOpacity(0.7),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  final url = isVetAccess && token != null
                      ? '/pets/$petId/vaccinations?token=$token'
                      : '/pets/$petId/vaccinations';
                  context.push(url);
                },
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context: context,
                icon: Icons.monitor_heart_rounded,
                title: l10n.diseaseFollowUp,
                subtitle: l10n.photosEvolutionNotes,
                color: _orange,
                gradientColor: _orange.withOpacity(0.7),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () {
                  final url = isVetAccess && token != null
                      ? '/pets/$petId/diseases?token=$token'
                      : '/pets/$petId/diseases';
                  context.push(url);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOverview(
    AsyncValue<Map<String, dynamic>?> healthAsync,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color textSecondary,
  ) {
    return healthAsync.when(
      data: (stats) {
        if (stats == null) {
          return _buildEmptyOverview(isDark, l10n, textSecondary);
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
              colors: isDark
                  ? [_coral.withOpacity(0.2), _mint.withOpacity(0.2)]
                  : [_coral.withOpacity(0.1), _mint.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.white, width: 2),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.healthStatus,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          l10n.latestMeasurements,
                          style: TextStyle(fontSize: 13, color: textSecondary),
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
                        label: l10n.weight,
                        value: '${currentWeight.toStringAsFixed(1)} ${l10n.kg}',
                        color: _coral,
                        isDark: isDark,
                        textPrimary: textPrimary,
                      ),
                    ),
                  if (currentWeight != null && currentTemp != null) const SizedBox(width: 12),
                  if (currentTemp != null)
                    Expanded(
                      child: _buildMiniStat(
                        icon: Icons.thermostat,
                        label: l10n.temp,
                        value: '${currentTemp.toStringAsFixed(1)}°C',
                        color: _mint,
                        isDark: isDark,
                        textPrimary: textPrimary,
                      ),
                    ),
                  if ((currentWeight != null || currentTemp != null) && currentHeart != null)
                    const SizedBox(width: 12),
                  if (currentHeart != null)
                    Expanded(
                      child: _buildMiniStat(
                        icon: Icons.favorite,
                        label: l10n.heart,
                        value: '$currentHeart ${l10n.bpm}',
                        color: _purple,
                        isDark: isDark,
                        textPrimary: textPrimary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingSkeleton(isDark),
      error: (_, __) => _buildEmptyOverview(isDark, l10n, textSecondary),
    );
  }

  Widget _buildEmptyOverview(bool isDark, AppLocalizations l10n, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.noHealthDataYet,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.dataWillAppearAfterVisits,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required Color textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
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
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
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
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
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
              colors: isDark
                  ? [_darkCard, color.withOpacity(0.1)]
                  : [Colors.white, color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2), width: 2),
            boxShadow: isDark ? null : [
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
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
                        color: textSecondary,
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
