import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

class DaycareBookingsScreen extends ConsumerStatefulWidget {
  const DaycareBookingsScreen({super.key});

  @override
  ConsumerState<DaycareBookingsScreen> createState() => _DaycareBookingsScreenState();
}

class _DaycareBookingsScreenState extends ConsumerState<DaycareBookingsScreen> {
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
      debugPrint('🔄 Chargement des réservations PRO...');
      final res = await api.dio.get('/bookings/provider/me');
      final data = res.data;

      debugPrint('📦 Réponse reçue type: ${data.runtimeType}');

      // Le backend retourne directement un tableau, pas {data: [...]}
      if (data is List) {
        debugPrint('✅ Liste reçue avec ${data.length} réservation(s)');
        if (data.isNotEmpty) {
          debugPrint('📋 Première réservation: ${data[0]}');
        }
        return data;
      }

      // Fallback si jamais c'est dans un wrapper
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        debugPrint('✅ Liste wrappée reçue avec ${list.length} réservation(s)');
        return list;
      }

      debugPrint('⚠️ Format de réponse inattendu, retour liste vide');
      return [];
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur chargement réservations: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _updateStatus(String bookingId, String newStatus) async {
    try {
      final api = ref.read(apiProvider);
      await api.dio.patch(
        '/bookings/$bookingId/provider-status',
        data: {'status': newStatus},
      );

      // Recharger la liste
      setState(() => _bookingsFuture = _loadBookings());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Statut mis à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _markDropOff(String bookingId) async {
    try {
      final api = ref.read(apiProvider);
      await api.dio.patch('/daycare/bookings/$bookingId/drop-off');

      setState(() => _bookingsFuture = _loadBookings());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animal marqué comme déposé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _markPickup(String bookingId) async {
    try {
      final api = ref.read(apiProvider);
      await api.dio.patch('/daycare/bookings/$bookingId/pickup');

      setState(() => _bookingsFuture = _loadBookings());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animal marqué comme récupéré')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservations garderie'),
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
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Annulées',
                  selected: _selectedFilter == 'CANCELLED',
                  onTap: () => setState(() => _selectedFilter = 'CANCELLED'),
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
                          'Aucune réservation',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
                      return _BookingCard(
                        booking: booking,
                        onUpdateStatus: _updateStatus,
                        onMarkDropOff: _markDropOff,
                        onMarkPickup: _markPickup,
                      );
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
  final Function(String bookingId, String status) onUpdateStatus;
  final Function(String bookingId) onMarkDropOff;
  final Function(String bookingId) onMarkPickup;

  const _BookingCard({
    required this.booking,
    required this.onUpdateStatus,
    required this.onMarkDropOff,
    required this.onMarkPickup,
  });

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

    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${user?['firstName']} ${user?['lastName']}\n${user?['phone'] ?? ''}',
            ),
            isThreeLine: true,
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
                        'Arrivée prévue: ${dateFormat.format(startDate)}',
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
                        'Départ prévu: ${dateFormat.format(endDate)}',
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
                if (booking['notes'] != null && booking['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking['notes'],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Actions
          if (status == 'PENDING') ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onUpdateStatus(booking['id'], 'CANCELLED'),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onUpdateStatus(booking['id'], 'CONFIRMED'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirmer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (status == 'CONFIRMED') ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onMarkDropOff(booking['id']),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Marquer comme déposé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF36C6C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ] else if (status == 'IN_PROGRESS') ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onMarkPickup(booking['id']),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Marquer comme récupéré'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
