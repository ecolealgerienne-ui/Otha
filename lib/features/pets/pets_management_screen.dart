// lib/features/pets/pets_management_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Theme colors
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

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
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final petsAsync = ref.watch(myPetsProvider);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, isDark, l10n, textPrimary),
            Expanded(
              child: petsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _coral),
                ),
                error: (e, _) => _buildErrorState(isDark, l10n, e.toString()),
                data: (pets) {
                  if (pets.isEmpty) {
                    return _buildEmptyState(context, ref, isDark, l10n);
                  }
                  return _buildPetsCarousel(pets, isDark, l10n);
                },
              ),
            ),
          ],
        ),
      ),
      // Floating add button
      floatingActionButton: petsAsync.maybeWhen(
        data: (pets) => pets.isNotEmpty
            ? FloatingActionButton(
                onPressed: () async {
                  await context.push('/pets/add');
                  ref.invalidate(myPetsProvider);
                },
                backgroundColor: _coral,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
  ) {
    final cardColor = isDark ? _darkCard : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? _darkBg : _coralSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _coral,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.myAnimals,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'SFPRO',
                    color: textPrimary,
                  ),
                ),
                Text(
                  l10n.swipeToNavigate,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'SFPRO',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.invalidate(myPetsProvider),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? _darkBg : _coralSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded, color: _coral, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsCarousel(
    List<Map<String, dynamic>> pets,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: pets.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: _PetCard(
                pet: pets[index],
                isDark: isDark,
                l10n: l10n,
              ),
            ),
          ),
        ),
        if (pets.length > 1) _buildPageIndicator(pets.length, isDark),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPageIndicator(int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? _coral : (isDark ? Colors.grey[700] : Colors.grey[300]),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pets,
                size: 64,
                color: _coral,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.noPets,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'SFPRO',
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.addFirstPet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'SFPRO',
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async {
                await context.push('/pets/add');
                ref.invalidate(myPetsProvider);
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addPet),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, AppLocalizations l10n, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: _coral,
          ),
          const SizedBox(height: 16),
          Text(
            '${l10n.error}: $error',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends ConsumerWidget {
  final Map<String, dynamic> pet;
  final bool isDark;
  final AppLocalizations l10n;

  const _PetCard({
    required this.pet,
    required this.isDark,
    required this.l10n,
  });

  String _getSpeciesEmoji(String? species) {
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

  String _getSpeciesLabel(String? species, AppLocalizations l10n) {
    switch (species?.toLowerCase()) {
      case 'dog':
        return l10n.dog;
      case 'cat':
        return l10n.cat;
      case 'bird':
        return l10n.bird;
      case 'rodent':
        return l10n.rodent;
      case 'reptile':
        return l10n.reptile;
      default:
        return l10n.animal;
    }
  }

  String _calculateAge(String? birthDateIso, AppLocalizations l10n) {
    if (birthDateIso == null || birthDateIso.isEmpty) return '';
    try {
      final birthDate = DateTime.parse(birthDateIso);
      final now = DateTime.now();
      final years = now.year - birthDate.year;
      final months = now.month - birthDate.month;

      int totalMonths = years * 12 + months;
      if (now.day < birthDate.day) totalMonths--;

      if (totalMonths < 12) {
        return '$totalMonths ${l10n.months}';
      } else {
        final y = totalMonths ~/ 12;
        return '$y ${y > 1 ? l10n.years : l10n.year}';
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
    final hasPhoto = photoUrl != null && photoUrl.startsWith('http');

    final age = _calculateAge(birthDate, l10n);
    final formattedWeight = _formatWeight(weight);

    // Alerts
    final vaccinations = (pet['vaccinations'] as List?) ?? [];
    final treatments = (pet['treatments'] as List?) ?? [];
    final allergies = (pet['allergies'] as List?) ?? [];

    int upcomingVaccines = 0;
    for (final vax in vaccinations) {
      final nextDue = vax['nextDueDate']?.toString();
      if (nextDue != null && nextDue.isNotEmpty) {
        try {
          final dueDate = DateTime.parse(nextDue);
          final daysUntil = dueDate.difference(DateTime.now()).inDays;
          if (daysUntil >= 0 && daysUntil <= 30) upcomingVaccines++;
        } catch (_) {}
      }
    }

    final activeTreatments = treatments.where((t) => t['isActive'] == true).length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            _buildBackgroundImage(hasPhoto, photoUrl, species),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.35, 0.6, 1.0],
                ),
              ),
            ),

            // Species badge
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _coral.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getSpeciesEmoji(species),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getSpeciesLabel(species, l10n),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SFPRO',
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Gender badge
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: gender == 'MALE'
                      ? Colors.blue.withOpacity(0.3)
                      : gender == 'FEMALE'
                          ? Colors.pink.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: gender == 'MALE'
                        ? Colors.blue.withOpacity(0.5)
                        : gender == 'FEMALE'
                            ? Colors.pink.withOpacity(0.5)
                            : Colors.grey.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  gender == 'MALE'
                      ? Icons.male
                      : gender == 'FEMALE'
                          ? Icons.female
                          : Icons.question_mark,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Content at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'SFPRO',
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Breed + Age + Weight
                    Row(
                      children: [
                        if (breed.isNotEmpty) ...[
                          Text(
                            breed,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SFPRO',
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          if (age.isNotEmpty || formattedWeight.isNotEmpty)
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                        ],
                        if (age.isNotEmpty) ...[
                          Text(
                            age,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'SFPRO',
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                          if (formattedWeight.isNotEmpty)
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                        ],
                        if (formattedWeight.isNotEmpty)
                          Text(
                            formattedWeight,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'SFPRO',
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                      ],
                    ),

                    // Alerts
                    if (upcomingVaccines > 0 || activeTreatments > 0 || allergies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (upcomingVaccines > 0)
                            _AlertBadge(
                              icon: Icons.vaccines,
                              text: '$upcomingVaccines ${l10n.vaccinesDue}',
                              color: Colors.orange,
                            ),
                          if (activeTreatments > 0)
                            _AlertBadge(
                              icon: Icons.medication,
                              text: '$activeTreatments ${l10n.activeTreatments}',
                              color: Colors.blue,
                            ),
                          if (allergies.isNotEmpty)
                            _AlertBadge(
                              icon: Icons.warning_amber_rounded,
                              text: '${allergies.length} ${l10n.allergies}',
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Action buttons with glassmorphism
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              _GlassButton(
                                icon: Icons.medical_services_rounded,
                                label: l10n.healthRecord,
                                onTap: () => context.push('/pets/$id/health-stats'),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              _GlassButton(
                                icon: Icons.qr_code_2_rounded,
                                label: l10n.qrCode,
                                onTap: () => context.push('/pets/$id/qr'),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              _GlassButton(
                                icon: Icons.edit_rounded,
                                label: l10n.modify,
                                onTap: () async {
                                  await context.push('/pets/edit', extra: pet);
                                  ref.invalidate(myPetsProvider);
                                },
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              _GlassButton(
                                icon: Icons.delete_outline_rounded,
                                label: l10n.delete,
                                color: Colors.red[300],
                                onTap: () => _showDeleteConfirmation(context, ref, id, name, l10n),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundImage(bool hasPhoto, String? photoUrl, String? species) {
    if (hasPhoto) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(species),
      );
    }
    return _buildPlaceholder(species);
  }

  Widget _buildPlaceholder(String? species) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A1A1C), const Color(0xFF1A1010)]
              : [const Color(0xFFFFEEF0), const Color(0xFFFFD6DA)],
        ),
      ),
      child: Center(
        child: Text(
          _getSpeciesEmoji(species),
          style: const TextStyle(fontSize: 120),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String petId,
    String petName,
    AppLocalizations l10n,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.deletePet,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.confirmDeletePet} "$petName" ?',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[400], size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.deleteWarning,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiProvider);
      final success = await api.deletePet(petId);

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.petDeleted),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.invalidate(myPetsProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _AlertBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _AlertBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
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
              fontFamily: 'SFPRO',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Colors.white;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: buttonColor, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SFPRO',
                    color: buttonColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
