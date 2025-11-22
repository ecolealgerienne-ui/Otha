// lib/features/daycare/daycare_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _primary = Color(0xFF00ACC1);
const _primarySoft = Color(0xFFE0F7FA);
const _ink = Color(0xFF222222);

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
    final daycare = widget.daycareData ?? {};
    final name = (daycare['displayName'] ?? 'Garderie').toString();
    final bio = (daycare['bio'] ?? 'Aucune description disponible.').toString();
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

    // Simuler places restantes (dans un vrai système, ça viendrait du backend)
    final remainingSpots = capacity != null ? (capacity as int) - ((capacity as int) ~/ 3) : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // AppBar with image gallery
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
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
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderImage(),
                            );
                          },
                        )
                      : _placeholderImage(),

                  // Gradient overlay for better readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
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
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and distance
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (distanceKm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primarySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 16, color: _primary),
                              const SizedBox(width: 4),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Address
                  if (address.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.place, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Info cards row
                  Row(
                    children: [
                      if (capacity != null)
                        Expanded(
                          child: _infoCard(
                            icon: Icons.pets,
                            title: 'Capacité',
                            value: capacity.toString(),
                            color: Colors.orange,
                          ),
                        ),
                      if (capacity != null && remainingSpots != null)
                        const SizedBox(width: 12),
                      if (remainingSpots != null)
                        Expanded(
                          child: _infoCard(
                            icon: Icons.check_circle,
                            title: 'Places restantes',
                            value: remainingSpots.toString(),
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Availability hours
                  _sectionTitle('Horaires'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: _primary),
                        const SizedBox(width: 12),
                        Text(
                          is24_7
                              ? 'Ouvert 24h/24 - 7j/7'
                              : 'Ouvert de $openingTime à $closingTime',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Pricing
                  if (hourlyRate != null || dailyRate != null) ...[
                    _sectionTitle('Tarifs'),
                    const SizedBox(height: 12),
                    if (hourlyRate != null)
                      _pricingRow(
                        'Tarif horaire',
                        '${(hourlyRate as int) + kDaycareCommissionDa} DA/heure',
                      ),
                    if (dailyRate != null)
                      _pricingRow(
                        'Tarif journalier',
                        '${(dailyRate as int) + kDaycareCommissionDa} DA/jour',
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Animal types
                  if (animalTypes.isNotEmpty) ...[
                    _sectionTitle('Types d\'animaux acceptés'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: animalTypes.map((type) {
                        return Chip(
                          label: Text(type.toString()),
                          backgroundColor: _primarySoft,
                          labelStyle: const TextStyle(color: _primary),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Bio
                  _sectionTitle('À propos'),
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 100), // Space for floating button
                ],
              ),
            ),
          ),
        ],
      ),

      // Floating reservation button
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            // Navigate to booking flow
            context.push('/explore/daycare/${widget.providerId}/book', extra: daycare);
          },
          backgroundColor: _primary,
          icon: const Icon(Icons.calendar_today, color: Colors.white),
          label: const Text(
            'Réserver maintenant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Aucune image',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _ink,
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }
}
