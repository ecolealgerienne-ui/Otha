import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

class MyDaycareBookingsScreen extends ConsumerStatefulWidget {
  const MyDaycareBookingsScreen({super.key});

  @override
  ConsumerState<MyDaycareBookingsScreen> createState() => _MyDaycareBookingsScreenState();
}

class _MyDaycareBookingsScreenState extends ConsumerState<MyDaycareBookingsScreen> {
  Future<List<dynamic>>? _bookingsFuture;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookings();
  }

  Future<List<dynamic>> _loadBookings() async {
    final api = ref.read(apiProvider);
    try {
      return await api.myDaycareBookings();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations garderie'),
      ),
      body: Column(
        children: [
          // Filtres
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Toutes',
                  selected: _selectedFilter == 'ALL',
                  onTap: () => setState(() => _selectedFilter = 'ALL'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'En attente',
                  selected: _selectedFilter == 'PENDING',
                  onTap: () => setState(() => _selectedFilter = 'PENDING'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Confirmées',
                  selected: _selectedFilter == 'CONFIRMED',
                  onTap: () => setState(() => _selectedFilter = 'CONFIRMED'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'En cours',
                  selected: _selectedFilter == 'IN_PROGRESS',
                  onTap: () => setState(() => _selectedFilter = 'IN_PROGRESS'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Terminées',
                  selected: _selectedFilter == 'COMPLETED',
                  onTap: () => setState(() => _selectedFilter = 'COMPLETED'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Liste
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _bookingsFuture,
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
                          onPressed: () => setState(() => _bookingsFuture = _loadBookings()),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }

                final allBookings = snap.data ?? [];

                // Filtrer selon le filtre sélectionné
                final filtered = _selectedFilter == 'ALL'
                    ? allBookings
                    : allBookings.where((b) => b['status'] == _selectedFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'ALL'
                              ? 'Aucune réservation'
                              : 'Aucune réservation dans cette catégorie',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/daycare/booking'),
                          icon: const Icon(Icons.add),
                          label: const Text('Réserver une garderie'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: coral,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() => _bookingsFuture = _loadBookings()),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final booking = filtered[index];
                      return _BookingCard(booking: booking);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/daycare/booking'),
        backgroundColor: coral,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle réservation'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF36C6C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingCard({required this.booking});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'En attente';
      case 'CONFIRMED':
        return 'Confirmée';
      case 'IN_PROGRESS':
        return 'En cours';
      case 'COMPLETED':
        return 'Terminée';
      case 'CANCELLED':
        return 'Annulée';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'CONFIRMED':
        return Icons.check_circle;
      case 'IN_PROGRESS':
        return Icons.pets;
      case 'COMPLETED':
        return Icons.done_all;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = booking['pet'] as Map<String, dynamic>?;
    final provider = booking['provider'] as Map<String, dynamic>?;
    final providerUser = provider?['user'] as Map<String, dynamic>?;
    final status = booking['status'] as String;
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final actualDropOff = booking['actualDropOff'] != null
        ? DateTime.parse(booking['actualDropOff']).toLocal()
        : null;
    final actualPickup = booking['actualPickup'] != null
        ? DateTime.parse(booking['actualPickup']).toLocal()
        : null;

    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(status).withOpacity(0.2),
              child: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
            ),
            title: Text(
              provider?['displayName'] ?? 'Garderie',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Animal: ${pet?['name'] ?? 'Non spécifié'}',
            ),
            trailing: Chip(
              label: Text(
                _getStatusLabel(status),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: _getStatusColor(status),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Arrivée: ${dateFormat.format(startDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Départ: ${dateFormat.format(endDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (actualDropOff != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Déposé à ${timeFormat.format(actualDropOff)}',
                        style: const TextStyle(fontSize: 13, color: Colors.green),
                      ),
                    ],
                  ),
                ],
                if (actualPickup != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.logout, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Récupéré à ${timeFormat.format(actualPickup)}',
                        style: const TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prix',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${booking['priceDa']} DA',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Commission',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${booking['commissionDa']} DA',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${booking['totalDa']} DA',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF36C6C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (booking['notes'] != null && booking['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notes: ${booking['notes']}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
