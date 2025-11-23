import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';

/// Popup pour confirmer un rendez-vous côté client (24h après l'heure prévue)
/// Affichée automatiquement si booking en AWAITING_CONFIRMATION
class BookingConfirmationPopup extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onConfirmed;

  const BookingConfirmationPopup({
    super.key,
    required this.booking,
    this.onConfirmed,
  });

  @override
  ConsumerState<BookingConfirmationPopup> createState() =>
      _BookingConfirmationPopupState();
}

class _BookingConfirmationPopupState
    extends ConsumerState<BookingConfirmationPopup> {
  int _rating = 5;
  String _comment = '';
  bool _isLoading = false;

  String get _providerName {
    final provider = widget.booking['provider'] as Map<String, dynamic>?;
    return provider?['displayName']?.toString() ?? 'le professionnel';
  }

  String get _serviceName {
    final service = widget.booking['service'] as Map<String, dynamic>?;
    return service?['title']?.toString() ?? 'le service';
  }

  String get _dateStr {
    final iso = widget.booking['scheduledAt']?.toString() ?? '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _confirmAttendance() async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      await api.clientRequestConfirmation(
        bookingId: widget.booking['id'],
        rating: _rating,
        comment: _comment.isEmpty ? null : _comment,
      );

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Confirmation envoyée au professionnel',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );

      widget.onConfirmed?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _cancelAttendance() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text(
          'Vous confirmez ne pas vous être rendu à ce rendez-vous ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      await api.clientCancelBooking(widget.booking['id']);

      if (!mounted) return;
      Navigator.pop(context, false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rendez-vous annulé')),
      );

      widget.onConfirmed?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available,
                    color: Color(0xFFF36C6C),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Comment s\'est passé\nvotre rendez-vous ?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Infos RDV
            Text(
              '$_providerName\n$_serviceName\n$_dateStr',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Rating
            const Text(
              'Votre note',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final isSelected = i < _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    isSelected ? Icons.star : Icons.star_border,
                    color: isSelected ? Colors.amber : Colors.grey,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Commentaire
            TextField(
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                border: OutlinedBorder(),
              ),
              maxLines: 3,
              onChanged: (v) => _comment = v,
            ),
            const SizedBox(height: 20),

            // Boutons
            FilledButton(
              onPressed: _isLoading ? null : _confirmAttendance,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF36C6C),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirmer ma présence'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _isLoading ? null : _cancelAttendance,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Je n\'y suis pas allé'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provider pour les bookings en attente de confirmation
final pendingConfirmationBookingsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiProvider);
  final bookings = await api.myBookings();

  // Filtrer ceux en AWAITING_CONFIRMATION
  return bookings.where((b) {
    if (b is! Map) return false;
    final status = (b['status'] ?? '').toString().toUpperCase();
    return status == 'AWAITING_CONFIRMATION';
  }).toList();
});
