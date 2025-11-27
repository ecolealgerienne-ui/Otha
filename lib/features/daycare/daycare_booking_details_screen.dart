import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

class DaycareBookingDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;

  const DaycareBookingDetailsScreen({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<DaycareBookingDetailsScreen> createState() => _DaycareBookingDetailsScreenState();
}

class _DaycareBookingDetailsScreenState extends ConsumerState<DaycareBookingDetailsScreen> {
  bool _cancelling = false;

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
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

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: const Text('Cette action est irréversible. Voulez-vous vraiment annuler cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);

    try {
      final api = ref.read(apiProvider);
      await api.cancelDaycareBooking(widget.booking['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation annulée avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      // Retourner true pour indiquer qu'il y a eu un changement
      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final pet = booking['pet'] as Map<String, dynamic>?;
    final provider = booking['provider'] as Map<String, dynamic>?;
    final providerUser = provider?['user'] as Map<String, dynamic>?;
    final status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);
    final priceDa = booking['priceDa'] ?? 0;
    final commissionDa = booking['commissionDa'] ?? 100;
    final totalDa = booking['totalDa'] ?? (priceDa + commissionDa);
    final notes = booking['notes']?.toString();

    final actualDropOff = booking['actualDropOff'] != null
        ? DateTime.parse(booking['actualDropOff']).toLocal()
        : null;
    final actualPickup = booking['actualPickup'] != null
        ? DateTime.parse(booking['actualPickup']).toLocal()
        : null;

    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    final canCancel = status == 'PENDING' || status == 'CONFIRMED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la réservation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Statut
          Center(
            child: Chip(
              label: Text(
                _getStatusLabel(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              backgroundColor: _getStatusColor(status),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),

          const SizedBox(height: 24),

          // Animal
          _Section(
            title: 'Animal',
            icon: Icons.pets,
            children: [
              _InfoRow('Nom', pet?['name'] ?? 'Non spécifié'),
              _InfoRow('Espèce', pet?['species'] ?? 'Non spécifié'),
              if (pet?['breed'] != null)
                _InfoRow('Race', pet!['breed']),
              if (pet?['age'] != null)
                _InfoRow('Âge', '${pet!['age']} ans'),
            ],
          ),

          const SizedBox(height: 16),

          // Garderie
          _Section(
            title: 'Garderie',
            icon: Icons.home,
            children: [
              _InfoRow('Nom', provider?['displayName'] ?? 'Non spécifié'),
              if (provider?['address'] != null)
                _InfoRow('Adresse', provider!['address']),
              if (providerUser?['phone'] != null)
                _InfoRow('Téléphone', providerUser!['phone']),
            ],
          ),

          const SizedBox(height: 16),

          // Dates
          _Section(
            title: 'Dates',
            icon: Icons.calendar_today,
            children: [
              _InfoRow('Arrivée prévue', dateFormat.format(startDate)),
              _InfoRow('Départ prévu', dateFormat.format(endDate)),
              if (actualDropOff != null)
                _InfoRow(
                  'Déposé le',
                  dateFormat.format(actualDropOff),
                  valueColor: Colors.green,
                ),
              if (actualPickup != null)
                _InfoRow(
                  'Récupéré le',
                  dateFormat.format(actualPickup),
                  valueColor: Colors.blue,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Prix
          _Section(
            title: 'Tarification',
            icon: Icons.payments,
            children: [
              _InfoRow('Prix de base', '$priceDa DA'),
              _InfoRow('Commission', '$commissionDa DA'),
              const Divider(),
              _InfoRow(
                'Total',
                '$totalDa DA',
                valueFontWeight: FontWeight.bold,
                valueColor: const Color(0xFFF36C6C),
              ),
            ],
          ),

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              title: 'Notes',
              icon: Icons.note,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    notes,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Bouton Annuler
          if (canCancel)
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _cancelling ? null : _cancelBooking,
                icon: _cancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel),
                label: const Text('Annuler la réservation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFF36C6C)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight? valueFontWeight;

  const _InfoRow(
    this.label,
    this.value, {
    this.valueColor,
    this.valueFontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: valueFontWeight ?? FontWeight.w500,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
