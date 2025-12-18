// lib/features/daycare/daycare_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale_provider.dart';

// Design constants - même thème que vet_details_screen
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

// Commission cachée ajoutée au prix affiché
const kDaycareCommissionDa = 100;

class DaycareDetailScreen extends ConsumerStatefulWidget {
  final String providerId;
  final Map<String, dynamic>? daycareData;

  const DaycareDetailScreen({
    super.key,
    required this.providerId,
    this.daycareData,
  });

  @override
  ConsumerState<DaycareDetailScreen> createState() => _DaycareDetailScreenState();
}

class _DaycareDetailScreenState extends ConsumerState<DaycareDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final daycare = widget.daycareData ?? {};

    final name = (daycare['displayName'] ?? 'Garderie').toString();
    final bio = (daycare['bio'] ?? l10n.notSpecified).toString();
    final address = (daycare['address'] ?? '').toString();
    final distanceKm = daycare['distanceKm'] as double?;
    final images = daycare['images'] as List<dynamic>? ?? [];
    final capacity = daycare['capacity'];
    final animalTypes = daycare['animalTypes'] as List<dynamic>? ?? [];
    final hourlyRate = daycare['hourlyRate'];
    final dailyRate = daycare['dailyRate'];
    final is24_7 = daycare['is24_7'] == true;
    final openingTime = daycare['openingTime']?.toString() ?? '08:00';
    final closingTime = daycare['closingTime']?.toString() ?? '20:00';
    final availableDays = daycare['availableDays'] as List<dynamic>? ?? List.filled(7, true);

    final bgColor = isDark ? _darkBg : Colors.white;
    final cardColor = isDark ? _darkCard : const Color(0xFFF7F9FB);
    final cardBorder = isDark ? _darkCardBorder : const Color(0xFFE6EDF2);
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Header avec image
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image gallery
                  images.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              images[index].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                            );
                          },
                        )
                      : _buildPlaceholder(isDark),

                  // Gradient pour lisibilite
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),

                  // Badges
                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Distance
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 24/7
                        if (is24_7)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _coral,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.open247,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Image indicators
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentImageIndex == index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF2D2D2D)),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),

                  // Adresse
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(fontSize: 14, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Capacité
                  if (capacity != null) ...[
                    _buildSectionTitle(l10n.maxCapacity, Icons.pets, isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.pets, color: _coral, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.animalsCount(capacity as int),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Horaires
                  _buildSectionTitle(l10n.schedules, Icons.access_time, isDark),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.schedule, color: _coral, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          is24_7 ? l10n.open247 : l10n.openFromTo(openingTime, closingTime),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Jours disponibles
                  _buildSectionTitle(l10n.availableDays, Icons.calendar_today, isDark),
                  const SizedBox(height: 8),
                  _buildDaysRow(availableDays, isDark, l10n, textPrimary, textSecondary),

                  const SizedBox(height: 20),

                  // Tarifs
                  if (hourlyRate != null || dailyRate != null) ...[
                    _buildSectionTitle(l10n.pricing, Icons.payments, isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? _coral.withOpacity(0.1) : _coralSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _coral.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          if (hourlyRate != null)
                            _buildPricingRow(
                              l10n.hourlyRate,
                              '${(hourlyRate as int) + kDaycareCommissionDa} DA${l10n.perHour}',
                              textPrimary,
                            ),
                          if (hourlyRate != null && dailyRate != null)
                            const Divider(height: 20),
                          if (dailyRate != null)
                            _buildPricingRow(
                              l10n.dailyRate,
                              '${(dailyRate as int) + kDaycareCommissionDa} DA${l10n.perDay}',
                              textPrimary,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Types d'animaux
                  if (animalTypes.isNotEmpty) ...[
                    _buildSectionTitle(l10n.acceptedAnimals, Icons.category, isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: animalTypes.map((type) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pets, size: 16, color: _coral),
                              const SizedBox(width: 6),
                              Text(
                                type.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Description
                  _buildSectionTitle(l10n.aboutDaycare, Icons.info_outline, isDark),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Text(
                      bio,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bouton de reservation
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: bgColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Prix
              if (hourlyRate != null || dailyRate != null)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.fromPrice, style: TextStyle(fontSize: 12, color: textSecondary)),
                      Text(
                        hourlyRate != null
                            ? '${(hourlyRate as int) + kDaycareCommissionDa} DA${l10n.perHour}'
                            : '${(dailyRate as int) + kDaycareCommissionDa} DA${l10n.perDay}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              // Bouton
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    context.push('/explore/daycare/${widget.providerId}/book', extra: daycare);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _coral,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    l10n.bookNow,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? _darkCard : _coralSoft,
      child: Center(
        child: Icon(
          Icons.pets,
          size: 64,
          color: _coral.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _coral, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF2D2D2D),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingRow(String label, String price, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
        ),
        Text(
          price,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _coral,
          ),
        ),
      ],
    );
  }

  Widget _buildDaysRow(List<dynamic> availableDays, bool isDark, AppLocalizations l10n, Color textPrimary, Color? textSecondary) {
    final days = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isAvailable = index < availableDays.length && availableDays[index] == true;
        return Container(
          width: 42,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isAvailable ? _coral : (isDark ? _darkCard : Colors.grey[200]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            days[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAvailable ? Colors.white : textSecondary,
            ),
          ),
        );
      }),
    );
  }
}
