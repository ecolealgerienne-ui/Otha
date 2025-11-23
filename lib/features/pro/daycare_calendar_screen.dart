import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

class DaycareCalendarScreen extends ConsumerStatefulWidget {
  const DaycareCalendarScreen({super.key});

  @override
  ConsumerState<DaycareCalendarScreen> createState() => _DaycareCalendarScreenState();
}

class _DaycareCalendarScreenState extends ConsumerState<DaycareCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  Map<String, List<dynamic>> _bookingsByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthBookings();
  }

  Future<void> _loadMonthBookings() async {
    setState(() => _isLoading = true);

    final api = ref.read(apiProvider);
    try {
      // Charger toutes les réservations du provider
      final bookings = await api.myDaycareProviderBookings();

      // Grouper par date
      final Map<String, List<dynamic>> byDate = {};
      for (final booking in bookings) {
        final b = Map<String, dynamic>.from(booking as Map);
        final status = (b['status'] ?? '').toString().toUpperCase();

        // Seulement les réservations confirmées ou en cours
        if (status != 'CONFIRMED' && status != 'IN_PROGRESS') continue;

        final startDate = DateTime.tryParse((b['startDate'] ?? '').toString());
        final endDate = DateTime.tryParse((b['endDate'] ?? '').toString());

        if (startDate == null || endDate == null) continue;

        // Ajouter le booking à chaque jour de la période
        DateTime current = startDate;
        while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
          final key = DateFormat('yyyy-MM-dd').format(current);
          byDate.putIfAbsent(key, () => []);
          byDate[key]!.add(b);
          current = current.add(const Duration(days: 1));
        }
      }

      setState(() {
        _bookingsByDate = byDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDayAnimals(DateTime date, List<dynamic> bookings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayAnimalsModal(
        date: date,
        bookings: bookings,
        onUpdate: () {
          Navigator.pop(context);
          _loadMonthBookings();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Sélecteur de mois
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF00ACC1).withOpacity(0.1),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                      _loadMonthBookings();
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'fr_FR').format(_focusedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                      _loadMonthBookings();
                    });
                  },
                ),
              ],
            ),
          ),

          // Jours de la semaine
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((day) {
                return Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
                  ),
                );
              }).toList(),
            ),
          ),

          // Grille du calendrier
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: startingWeekday - 1 + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < startingWeekday - 1) {
                    return const SizedBox();
                  }

                  final day = index - (startingWeekday - 1) + 1;
                  final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                  final dateKey = DateFormat('yyyy-MM-dd').format(date);
                  final hasAnimals = _bookingsByDate.containsKey(dateKey) &&
                                    _bookingsByDate[dateKey]!.isNotEmpty;
                  final animalCount = hasAnimals ? _bookingsByDate[dateKey]!.length : 0;
                  final isToday = DateFormat('yyyy-MM-dd').format(date) ==
                                 DateFormat('yyyy-MM-dd').format(DateTime.now());

                  return InkWell(
                    onTap: hasAnimals
                        ? () => _showDayAnimals(date, _bookingsByDate[dateKey]!)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasAnimals
                            ? const Color(0xFF00ACC1).withOpacity(0.15)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: const Color(0xFFF36C6C), width: 2)
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: hasAnimals ? FontWeight.w700 : FontWeight.normal,
                                color: hasAnimals ? const Color(0xFF00ACC1) : Colors.black87,
                              ),
                            ),
                          ),
                          if (hasAnimals)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF36C6C),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$animalCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DayAnimalsModal extends ConsumerWidget {
  final DateTime date;
  final List<dynamic> bookings;
  final VoidCallback onUpdate;

  const _DayAnimalsModal({
    required this.date,
    required this.bookings,
    required this.onUpdate,
  });

  Future<void> _markDropOff(BuildContext context, WidgetRef ref, String bookingId) async {
    final api = ref.read(apiProvider);
    try {
      await api.dio.patch('/daycare/bookings/$bookingId/drop-off');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Animal marqué comme déposé'), backgroundColor: Colors.green),
        );
      }
      onUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markPickup(BuildContext context, WidgetRef ref, String bookingId) async {
    final api = ref.read(apiProvider);
    try {
      await api.dio.patch('/daycare/bookings/$bookingId/pickup');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Animal marqué comme récupéré'), backgroundColor: Colors.green),
        );
      }
      onUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF00ACC1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE d MMMM', 'fr_FR').format(date),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${bookings.length} animal${bookings.length > 1 ? 'ux' : ''}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Liste des animaux
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = Map<String, dynamic>.from(bookings[index] as Map);
                final pet = booking['pet'] as Map<String, dynamic>?;
                final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
                final bookingId = (booking['id'] ?? '').toString();

                final petName = (pet?['name'] ?? 'Animal').toString();
                final petBreed = (pet?['breed'] ?? '').toString();
                final petPhotoUrl = (pet?['photoUrl'] ?? '').toString();

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00ACC1).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      // Image de l'animal
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                        child: Container(
                          width: 100,
                          height: 100,
                          color: const Color(0xFF00ACC1).withOpacity(0.1),
                          child: petPhotoUrl.isNotEmpty
                              ? Image.network(petPhotoUrl, fit: BoxFit.cover)
                              : const Icon(Icons.pets, size: 40, color: Color(0xFF00ACC1)),
                        ),
                      ),

                      // Infos et boutons
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                petName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF222222),
                                ),
                              ),
                              if (petBreed.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  petBreed,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),

                              // Boutons d'action
                              if (status == 'CONFIRMED')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _markDropOff(context, ref, bookingId),
                                    icon: const Icon(Icons.login, size: 18),
                                    label: const Text('Confirmer réception'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),

                              if (status == 'IN_PROGRESS')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _markPickup(context, ref, bookingId),
                                    icon: const Icon(Icons.logout, size: 18),
                                    label: const Text('Animal récupéré'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2196F3),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
