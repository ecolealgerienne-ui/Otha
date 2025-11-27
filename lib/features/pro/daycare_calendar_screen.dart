import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
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

  /// Afficher la dialog pour saisir le code OTP
  Future<void> _showOtpDialog(String bookingId, String phase) async {
    final otpController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pin, color: Color(0xFF22C55E)),
            ),
            const SizedBox(width: 12),
            Text(phase == 'drop' ? 'Code dépôt' : 'Code retrait'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrez le code à 6 chiffres fourni par le client',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result == true && otpController.text.length == 6) {
      await _validateOtp(bookingId, otpController.text, phase);
    }
    otpController.dispose();
  }

  Future<void> _validateOtp(String bookingId, String otp, String phase) async {
    try {
      final api = ref.read(apiProvider);
      await api.validateDaycareByOtp(bookingId, otp: otp, phase: phase);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(phase == 'drop' ? 'Dépôt validé avec succès !' : 'Retrait validé avec succès !'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        ref.invalidate(daycareCalendarBookingsProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code invalide: $e'),
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
                    final bookingId = booking['id'] as String;
                    return _AnimalDetailPage(
                      booking: booking,
                      onMarkDropOff: () => _markDropOff(bookingId),
                      onMarkPickup: () => _markPickup(bookingId),
                      onScanQR: () async {
                        await context.push('/scan-pet');
                        // Rafraîchir les données après retour du scan
                        ref.invalidate(daycareCalendarBookingsProvider);
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Fermer le modal
                        }
                      },
                      onVerifyDropOtp: () => _showOtpDialog(bookingId, 'drop'),
                      onVerifyPickupOtp: () => _showOtpDialog(bookingId, 'pickup'),
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
  final VoidCallback onScanQR;
  final VoidCallback onVerifyDropOtp;
  final VoidCallback onVerifyPickupOtp;

  const _AnimalDetailPage({
    required this.booking,
    required this.onMarkDropOff,
    required this.onMarkPickup,
    required this.onScanQR,
    required this.onVerifyDropOtp,
    required this.onVerifyPickupOtp,
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
    final userName = user?['firstName'] as String? ?? 'Client';  // Seulement le prénom
    final userPhone = user?['phone'] as String? ?? '';

    final status = booking['status'] as String;
    final startDate = DateTime.parse(booking['startDate'] as String);
    final endDate = DateTime.parse(booking['endDate'] as String);
    final notes = booking['notes'] as String? ?? '';

    // Prix
    final priceDa = booking['priceDa'] as int? ?? 0;
    final commissionDa = booking['commissionDa'] as int? ?? 0;
    final totalDa = booking['totalDa'] as int? ?? 0;

    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final timeFormat = DateFormat('HH:mm');

    final actualDropOff = booking['actualDropOff'] != null
        ? DateTime.parse(booking['actualDropOff'] as String).toLocal()
        : null;
    final actualPickup = booking['actualPickup'] != null
        ? DateTime.parse(booking['actualPickup'] as String).toLocal()
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header avec photo de l'animal
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00ACC1).withOpacity(0.1),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Photo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00ACC1).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: petPhotoUrl.isNotEmpty
                        ? Image.network(
                            petPhotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              return Container(
                                color: const Color(0xFF00ACC1).withOpacity(0.1),
                                child: const Icon(
                                  Icons.pets,
                                  size: 50,
                                  color: Color(0xFF00ACC1),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFF00ACC1).withOpacity(0.1),
                            child: const Icon(
                              Icons.pets,
                              size: 50,
                              color: Color(0xFF00ACC1),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nom
                Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                  textAlign: TextAlign.center,
                ),

                if (petBreed.isNotEmpty || petType.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [petBreed, petType].where((s) => s.isNotEmpty).join(' • '),
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 12),

                // Statut
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Carte Client
          _InfoCard(
            title: 'Client',
            icon: Icons.person_outline,
            color: const Color(0xFF00ACC1),
            children: [
              _InfoTile(
                icon: Icons.person,
                label: 'Prénom',
                value: userName,
              ),
              if (userPhone.isNotEmpty && (status == 'CONFIRMED' || status == 'IN_PROGRESS' || status == 'COMPLETED'))
                _InfoTile(
                  icon: Icons.phone,
                  label: 'Téléphone',
                  value: userPhone,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Carte Prix
          _InfoCard(
            title: 'Tarif',
            icon: Icons.payments_outlined,
            color: const Color(0xFFFF6D00),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Service',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '$priceDa DA',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ],
                    ),
                    if (commissionDa > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Commission',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '$commissionDa DA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total à payer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF222222),
                          ),
                        ),
                        Text(
                          '$totalDa DA',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF6D00),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Carte Horaires
          _InfoCard(
            title: 'Horaires',
            icon: Icons.schedule_outlined,
            color: const Color(0xFF3A86FF),
            children: [
              _InfoTile(
                icon: Icons.login,
                label: 'Arrivée prévue',
                value: dateFormat.format(startDate),
              ),
              _InfoTile(
                icon: Icons.logout,
                label: 'Départ prévu',
                value: dateFormat.format(endDate),
              ),
              if (actualDropOff != null)
                _InfoTile(
                  icon: Icons.check_circle,
                  label: 'Arrivée réelle',
                  value: 'À ${timeFormat.format(actualDropOff)}',
                  valueColor: const Color(0xFF4CAF50),
                ),
              if (actualPickup != null)
                _InfoTile(
                  icon: Icons.done_all,
                  label: 'Départ réel',
                  value: 'À ${timeFormat.format(actualPickup)}',
                  valueColor: const Color(0xFF2196F3),
                ),
            ],
          ),

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Notes',
              icon: Icons.sticky_note_2_outlined,
              color: const Color(0xFF8E44AD),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E44AD).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote, size: 20, color: Colors.purple[300]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notes,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Boutons d'action
          if (status == 'CONFIRMED') ...[
            // Bouton Scanner QR Code
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00ACC1), Color(0xFF26C6DA)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00ACC1).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onScanQR,
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text(
                  'Scanner QR code',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton Vérifier code OTP
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onVerifyDropOtp,
                icon: const Icon(Icons.pin, size: 24),
                label: const Text(
                  'Vérifier code OTP',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton manuel "Animal accueilli"
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onMarkDropOff,
                icon: const Icon(Icons.pets, size: 24),
                label: const Text(
                  'Animal accueilli (manuel)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],

          // ✅ Boutons pour IN_PROGRESS (retrait)
          if (status == 'IN_PROGRESS') ...[
            // Bouton Scanner QR Code (retrait)
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00ACC1), Color(0xFF26C6DA)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00ACC1).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onScanQR,
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text(
                  'Scanner QR code',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton Vérifier code OTP (retrait)
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onVerifyPickupOtp,
                icon: const Icon(Icons.pin, size: 24),
                label: const Text(
                  'Vérifier code OTP',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton manuel "Animal récupéré"
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onMarkPickup,
                icon: const Icon(Icons.check_circle, size: 24),
                label: const Text(
                  'Animal récupéré',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Widget pour les cartes d'information
class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget pour les lignes d'information
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
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
