import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';

final daycareCalendarBookingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  final bookings = await api.myDaycareProviderBookings();
  return bookings.map((b) => Map<String, dynamic>.from(b as Map)).toList();
});

class DaycareCalendarScreen extends ConsumerWidget {
  const DaycareCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBookings = ref.watch(daycareCalendarBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Garderie'),
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
      ),
      body: asyncBookings.when(
        data: (bookings) {
          // Filtrer seulement les bookings confirmés, en cours ou complétés
          final relevantBookings = bookings.where((b) {
            final status = b['status'] as String;
            return status == 'CONFIRMED' || status == 'IN_PROGRESS' || status == 'COMPLETED';
          }).toList();

          if (relevantBookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun rendez-vous programmé',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Grouper par date (sans l'heure)
          final Map<String, List<Map<String, dynamic>>> bookingsByDate = {};
          for (final booking in relevantBookings) {
            final startDate = DateTime.parse(booking['startDate'] as String);
            final dateKey = DateFormat('yyyy-MM-dd').format(startDate);

            if (!bookingsByDate.containsKey(dateKey)) {
              bookingsByDate[dateKey] = [];
            }
            bookingsByDate[dateKey]!.add(booking);
          }

          // Trier les dates
          final sortedDates = bookingsByDate.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final dayBookings = bookingsByDate[dateKey]!;

              // Trier les bookings de la journée par heure
              dayBookings.sort((a, b) {
                final timeA = DateTime.parse(a['startDate'] as String);
                final timeB = DateTime.parse(b['startDate'] as String);
                return timeA.compareTo(timeB);
              });

              return _DateCard(
                date: DateTime.parse(dateKey),
                bookings: dayBookings,
              );
            },
          );
        },
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $err'),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> bookings;

  const _DateCard({
    required this.date,
    required this.bookings,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return "Aujourd'hui";
    } else if (dateOnly == tomorrow) {
      return "Demain";
    } else {
      // Format: "Lundi 23 Novembre"
      final weekday = DateFormat('EEEE', 'fr_FR').format(date);
      final dayMonth = DateFormat('d MMMM', 'fr_FR').format(date);
      return '${weekday[0].toUpperCase()}${weekday.substring(1)} $dayMonth';
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstBooking = bookings.first;
    final firstTime = DateTime.parse(firstBooking['startDate'] as String);
    final timeFormat = DateFormat('HH:mm');
    final animalCount = bookings.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Afficher tous les animaux de cette journée
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _DayAnimalsView(
              date: date,
              bookings: bookings,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00ACC1).withOpacity(0.1),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              // Icône de calendrier
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACC1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('d').format(date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMM', 'fr_FR').format(date).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Premier rendez-vous: ${timeFormat.format(firstTime)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.pets, size: 16, color: Color(0xFF00ACC1)),
                        const SizedBox(width: 4),
                        Text(
                          '$animalCount ${animalCount > 1 ? 'animaux' : 'animal'} à accueillir',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00ACC1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Flèche
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF00ACC1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayAnimalsView extends ConsumerStatefulWidget {
  final DateTime date;
  final List<Map<String, dynamic>> bookings;

  const _DayAnimalsView({
    required this.date,
    required this.bookings,
  });

  @override
  ConsumerState<_DayAnimalsView> createState() => _DayAnimalsViewState();
}

class _DayAnimalsViewState extends ConsumerState<_DayAnimalsView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markDropOff(String bookingId) async {
    try {
      final api = ref.read(apiProvider);
      await api.markDaycareDropOff(bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Animal marqué comme accueilli'),
            backgroundColor: Colors.green,
          ),
        );
        // Rafraîchir les données
        ref.invalidate(daycareCalendarBookingsProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markPickup(String bookingId) async {
    try {
      final api = ref.read(apiProvider);
      await api.markDaycarePickup(bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Animal marqué comme récupéré'),
            backgroundColor: Colors.blue,
          ),
        );
        // Rafraîchir les données
        ref.invalidate(daycareCalendarBookingsProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(widget.date),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.bookings.length} ${widget.bookings.length > 1 ? 'animaux' : 'animal'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Indicateur de page
                    if (widget.bookings.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00ACC1).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentPage + 1}/${widget.bookings.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00ACC1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // PageView des animaux
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: widget.bookings.length,
                  itemBuilder: (context, index) {
                    final booking = widget.bookings[index];
                    return _AnimalDetailPage(
                      booking: booking,
                      onMarkDropOff: () => _markDropOff(booking['id'] as String),
                      onMarkPickup: () => _markPickup(booking['id'] as String),
                    );
                  },
                ),
              ),

              // Indicateur de swipe
              if (widget.bookings.length > 1)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swipe, size: 20, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Glissez pour voir les autres animaux',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimalDetailPage extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onMarkDropOff;
  final VoidCallback onMarkPickup;

  const _AnimalDetailPage({
    required this.booking,
    required this.onMarkDropOff,
    required this.onMarkPickup,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':
        return 'Confirmé';
      case 'IN_PROGRESS':
        return 'En cours';
      case 'COMPLETED':
        return 'Terminé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = booking['pet'] as Map<String, dynamic>?;
    final petName = pet?['name'] as String? ?? 'Animal';
    final petBreed = pet?['breed'] as String? ?? '';
    final petType = pet?['type'] as String? ?? '';
    final petPhotoUrl = pet?['photoUrl'] as String? ?? '';

    final user = booking['user'] as Map<String, dynamic>?;
    final userName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : 'Client';
    final userPhone = user?['phone'] as String? ?? '';

    final status = booking['status'] as String;
    final startDate = DateTime.parse(booking['startDate'] as String);
    final endDate = DateTime.parse(booking['endDate'] as String);
    final notes = booking['notes'] as String? ?? '';

    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final timeFormat = DateFormat('HH:mm');

    final actualDropOff = booking['actualDropOff'] != null
        ? DateTime.parse(booking['actualDropOff'] as String)
        : null;
    final actualPickup = booking['actualPickup'] != null
        ? DateTime.parse(booking['actualPickup'] as String)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo de l'animal
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00ACC1).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFF00ACC1),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: petPhotoUrl.isNotEmpty
                    ? Image.network(
                        petPhotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) {
                          return const Icon(
                            Icons.pets,
                            size: 60,
                            color: Color(0xFF00ACC1),
                          );
                        },
                      )
                    : const Icon(
                        Icons.pets,
                        size: 60,
                        color: Color(0xFF00ACC1),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Nom de l'animal
          Center(
            child: Text(
              petName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
          ),

          if (petBreed.isNotEmpty || petType.isNotEmpty)
            Center(
              child: Text(
                [petBreed, petType].where((s) => s.isNotEmpty).join(' • '),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Statut
          Center(
            child: Chip(
              label: Text(
                _getStatusLabel(status),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: _getStatusColor(status),
            ),
          ),

          const SizedBox(height: 24),

          // Informations client
          _SectionHeader(title: 'Informations client'),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.person,
            label: 'Client',
            value: userName,
          ),
          if (userPhone.isNotEmpty && (status == 'CONFIRMED' || status == 'IN_PROGRESS' || status == 'COMPLETED'))
            _InfoRow(
              icon: Icons.phone,
              label: 'Téléphone',
              value: userPhone,
            ),

          const SizedBox(height: 24),

          // Horaires
          _SectionHeader(title: 'Horaires'),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.login,
            label: 'Arrivée prévue',
            value: dateFormat.format(startDate),
          ),
          _InfoRow(
            icon: Icons.logout,
            label: 'Départ prévu',
            value: dateFormat.format(endDate),
          ),

          if (actualDropOff != null)
            _InfoRow(
              icon: Icons.check_circle,
              label: 'Arrivée réelle',
              value: 'À ${timeFormat.format(actualDropOff)}',
              valueColor: Colors.green,
            ),

          if (actualPickup != null)
            _InfoRow(
              icon: Icons.done_all,
              label: 'Départ réel',
              value: 'À ${timeFormat.format(actualPickup)}',
              valueColor: Colors.blue,
            ),

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'Notes'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Boutons d'action
          if (status == 'CONFIRMED')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onMarkDropOff,
                icon: const Icon(Icons.login, size: 24),
                label: const Text(
                  'Animal accueilli',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (status == 'IN_PROGRESS')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onMarkPickup,
                icon: const Icon(Icons.logout, size: 24),
                label: const Text(
                  'Animal récupéré',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF222222),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
