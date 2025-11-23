// lib/features/bookings/booking_confirmation_popup.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';

const coral = Color(0xFFF36C6C);
const roseLight = Color(0xFFFFEEF0);

/// Provider pour récupérer les bookings en attente de confirmation
final awaitingConfirmationBookingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.read(apiProvider);
    final bookings = await api.myBookings();

    // Filtrer uniquement les bookings en AWAITING_CONFIRMATION
    return bookings.where((b) {
      final status = b['status']?.toString() ?? '';
      return status == 'AWAITING_CONFIRMATION';
    }).toList();
  } catch (e) {
    return [];
  }
});

/// Popup de confirmation pour un rendez-vous
class BookingConfirmationPopup extends ConsumerStatefulWidget {
  const BookingConfirmationPopup({
    super.key,
    required this.booking,
    required this.onDismiss,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onDismiss;

  @override
  ConsumerState<BookingConfirmationPopup> createState() => _BookingConfirmationPopupState();
}

class _BookingConfirmationPopupState extends ConsumerState<BookingConfirmationPopup> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _confirmAttendance() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiProvider);
      await api.clientRequestConfirmation(
        bookingId: widget.booking['id'].toString(),
        rating: _rating,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Demande envoyée au professionnel'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onDismiss();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _cancelAttendance() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiProvider);
      await api.clientCancelBooking(widget.booking['id'].toString());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Rendez-vous annulé'),
          backgroundColor: Colors.orange,
        ),
      );

      widget.onDismiss();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = widget.booking['provider']?['displayName']?.toString() ?? 'votre vétérinaire';
    final serviceTitle = widget.booking['service']?['title']?.toString() ?? 'rendez-vous';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icône
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: roseLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review_outlined, color: coral, size: 36),
              ),
              const SizedBox(height: 16),

              // Titre
              Text(
                'Comment s\'est passé votre rendez-vous ?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Sous-titre
              Text(
                '$serviceTitle avec $providerName',
                style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Sélection d'étoiles
              const Text(
                'Votre note :',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    icon: Icon(
                      starValue <= _rating ? Icons.star : Icons.star_border,
                      color: coral,
                      size: 32,
                    ),
                    onPressed: _isSubmitting ? null : () {
                      setState(() => _rating = starValue);
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Commentaire optionnel
              const Text(
                'Commentaire (optionnel) :',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Partagez votre expérience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton confirmer
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _confirmAttendance,
                style: FilledButton.styleFrom(
                  backgroundColor: coral,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isSubmitting ? 'Envoi...' : 'Confirmer le rendez-vous'),
              ),
              const SizedBox(height: 12),

              // Bouton "je n'y suis pas allé"
              OutlinedButton(
                onPressed: _isSubmitting ? null : _cancelAttendance,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: coral),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Je n\'y suis pas allé', style: TextStyle(color: coral)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
