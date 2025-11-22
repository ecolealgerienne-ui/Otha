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
  DateTime _selectedDate = DateTime.now();
  Future<List<dynamic>>? _animalsFuture;

  @override
  void initState() {
    super.initState();
    _animalsFuture = _loadAnimalsForDate(_selectedDate);
  }

  Future<List<dynamic>> _loadAnimalsForDate(DateTime date) async {
    final api = ref.read(apiProvider);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final res = await api.dio.get('/daycare/provider/calendar?date=$dateStr');
      final data = res.data;
      if (data is Map && data['data'] is List) {
        return data['data'] as List;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _animalsFuture = _loadAnimalsForDate(_selectedDate);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _animalsFuture = _loadAnimalsForDate(_selectedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier garderie'),
        actions: [
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.today),
              tooltip: 'Aujourd\'hui',
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                  _animalsFuture = _loadAnimalsForDate(_selectedDate);
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de date
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF36C6C).withOpacity(0.1),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          // Liste des animaux
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _animalsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Erreur: ${snap.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(
                            () => _animalsFuture = _loadAnimalsForDate(_selectedDate),
                          ),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }

                final animals = snap.data ?? [];

                if (animals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun animal ce jour',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(
                    () => _animalsFuture = _loadAnimalsForDate(_selectedDate),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: animals.length,
                    itemBuilder: (ctx, index) {
                      final booking = animals[index];
                      return _AnimalCard(booking: booking);
                    },
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

class _AnimalCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _AnimalCard({required this.booking});

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
        return 'Présent';
      case 'COMPLETED':
        return 'Parti';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = booking['pet'] as Map<String, dynamic>?;
    final user = booking['user'] as Map<String, dynamic>?;
    final status = booking['status'] as String;
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final actualDropOff = booking['actualDropOff'] != null
        ? DateTime.parse(booking['actualDropOff'])
        : null;
    final actualPickup = booking['actualPickup'] != null
        ? DateTime.parse(booking['actualPickup'])
        : null;

    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(status).withOpacity(0.2),
              child: Icon(Icons.pets, color: _getStatusColor(status)),
            ),
            title: Text(
              pet?['name'] ?? 'Animal',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              '${pet?['species'] ?? ''} • ${user?['firstName']} ${user?['lastName']}',
            ),
            trailing: Chip(
              label: Text(
                _getStatusLabel(status),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              backgroundColor: _getStatusColor(status),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TimeInfo(
                        icon: Icons.login,
                        label: 'Arrivée prévue',
                        time: timeFormat.format(startDate),
                        actual: actualDropOff != null ? timeFormat.format(actualDropOff) : null,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TimeInfo(
                        icon: Icons.logout,
                        label: 'Départ prévu',
                        time: timeFormat.format(endDate),
                        actual: actualPickup != null ? timeFormat.format(actualPickup) : null,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (user?['phone'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        user!['phone'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final String? actual;
  final Color color;

  const _TimeInfo({
    required this.icon,
    required this.label,
    required this.time,
    this.actual,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (actual != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  'Réel: $actual',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
