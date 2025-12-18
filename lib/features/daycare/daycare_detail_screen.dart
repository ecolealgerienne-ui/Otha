// lib/features/daycare/daycare_detail_screen.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale_provider.dart';

// ═══════════════════════════════════════════════════════════════
// DESIGN CONSTANTS
// ═══════════════════════════════════════════════════════════════
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _teal = Color(0xFF00ACC1);
const _tealSoft = Color(0xFFE0F7FA);
const _green = Color(0xFF43AA8B);
const _greenSoft = Color(0xFFE8F5F0);
const _purple = Color(0xFF7B68EE);
const _purpleSoft = Color(0xFFF0EDFF);
const _orange = Color(0xFFFF9800);
const _orangeSoft = Color(0xFFFFF3E0);

// Dark mode colors
const _darkBg = Color(0xFF0F0F0F);
const _darkCard = Color(0xFF1A1A1A);
const _darkCardAlt = Color(0xFF242424);
const _darkBorder = Color(0xFF2A2A2A);

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

class _DaycareDetailScreenState extends ConsumerState<DaycareDetailScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
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

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero Image Gallery
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: isDark ? _darkCard : Colors.white,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: isDark ? Colors.white : textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                                  errorBuilder: (_, __, ___) => _buildPlaceholder(isDark, l10n),
                                );
                              },
                            )
                          : _buildPlaceholder(isDark, l10n),

                      // Gradient overlays
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),

                      // Distance badge
                      if (distanceKm != null)
                        Positioned(
                          top: 100,
                          right: 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 18, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${distanceKm.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 24/7 badge
                      if (is24_7)
                        Positioned(
                          top: 100,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_green, Color(0xFF66BB6A)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _green.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.open247,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Image indicators
                      if (images.length > 1)
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentImageIndex == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                  boxShadow: _currentImageIndex == index
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.5),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    transform: Matrix4.translationValues(0, -24, 0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),

                          // Address
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.place_rounded, size: 18, color: _coral),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: TextStyle(fontSize: 14, color: textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Capacity Card
                          if (capacity != null)
                            _buildInfoCard(
                              icon: Icons.pets_rounded,
                              title: l10n.maxCapacity,
                              value: l10n.animalsCount(capacity as int),
                              color: _purple,
                              isDark: isDark,
                            ),

                          const SizedBox(height: 20),

                          // Hours Section
                          _buildSectionTitle(l10n.schedules, Icons.schedule_rounded, textPrimary),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? Colors.black : _teal).withOpacity(isDark ? 0.3 : 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: is24_7 ? [_green, const Color(0xFF66BB6A)] : [_teal, const Color(0xFF4DD0E1)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (is24_7 ? _green : _teal).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        is24_7 ? l10n.open247 : l10n.openFromTo(openingTime, closingTime),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.schedules,
                                        style: TextStyle(fontSize: 13, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Available Days
                          _buildSectionTitle(l10n.availableDays, Icons.calendar_month_rounded, textPrimary),
                          const SizedBox(height: 12),
                          _buildDaysRow(availableDays, isDark, l10n),

                          const SizedBox(height: 24),

                          // Pricing Section
                          if (hourlyRate != null || dailyRate != null) ...[
                            _buildSectionTitle(l10n.pricing, Icons.payments_rounded, textPrimary),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [_coral.withOpacity(0.15), _coral.withOpacity(0.08)]
                                      : [_coralSoft, const Color(0xFFFFF5F5)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _coral.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  if (hourlyRate != null)
                                    _buildPricingRow(
                                      l10n.hourlyRate,
                                      '${(hourlyRate as int) + kDaycareCommissionDa} DA${l10n.perHour}',
                                      Icons.hourglass_bottom_rounded,
                                      isDark,
                                      textPrimary,
                                    ),
                                  if (hourlyRate != null && dailyRate != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(color: _coral.withOpacity(0.2)),
                                    ),
                                  if (dailyRate != null)
                                    _buildPricingRow(
                                      l10n.dailyRate,
                                      '${(dailyRate as int) + kDaycareCommissionDa} DA${l10n.perDay}',
                                      Icons.wb_sunny_rounded,
                                      isDark,
                                      textPrimary,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Animal Types
                          if (animalTypes.isNotEmpty) ...[
                            _buildSectionTitle(l10n.acceptedAnimals, Icons.category_rounded, textPrimary),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: animalTypes.map((type) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _coral.withOpacity(0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _coral.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getAnimalIcon(type.toString()), size: 18, color: _coral),
                                      const SizedBox(width: 8),
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
                            const SizedBox(height: 24),
                          ],

                          // About Section
                          _buildSectionTitle(l10n.aboutDaycare, Icons.info_outline_rounded, textPrimary),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              bio,
                              style: TextStyle(
                                fontSize: 15,
                                color: textSecondary,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom Bar with Book Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle indicator
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        // Price preview
                        if (hourlyRate != null || dailyRate != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.fromPrice,
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hourlyRate != null
                                      ? '${(hourlyRate as int) + kDaycareCommissionDa} DA${l10n.perHour}'
                                      : '${(dailyRate as int) + kDaycareCommissionDa} DA${l10n.perDay}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Book button
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_coral, Color(0xFFFF8A80)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _coral.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  context.push('/explore/daycare/${widget.providerId}/book', extra: daycare);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        l10n.bookNow,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildPlaceholder(bool isDark, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [_darkCardAlt, _darkCard]
              : [_coralSoft, const Color(0xFFFFF5F5)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets_rounded, size: 64, color: _coral.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              l10n.noImageAvailable,
              style: TextStyle(color: _coral.withOpacity(0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 22, color: _coral),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withOpacity(0.15), color.withOpacity(0.08)]
              : [color.withOpacity(0.12), color.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, String price, IconData icon, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: _coral),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
        Text(
          price,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _coral,
          ),
        ),
      ],
    );
  }

  Widget _buildDaysRow(List<dynamic> availableDays, bool isDark, AppLocalizations l10n) {
    final days = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isAvailable = index < availableDays.length && availableDays[index] == true;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isAvailable
                ? const LinearGradient(colors: [_coral, Color(0xFFFF8A80)])
                : null,
            color: isAvailable ? null : (isDark ? _darkCardAlt : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isAvailable
                ? [
                    BoxShadow(
                      color: _coral.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            days[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isAvailable ? Colors.white : (isDark ? Colors.white38 : Colors.grey.shade500),
            ),
          ),
        );
      }),
    );
  }

  IconData _getAnimalIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('chien') || lower.contains('dog')) return Icons.pets;
    if (lower.contains('chat') || lower.contains('cat')) return Icons.pets;
    if (lower.contains('oiseau') || lower.contains('bird')) return Icons.flutter_dash;
    return Icons.pets;
  }
}
