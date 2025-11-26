// lib/features/bookings/booking_thanks_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BookingThanksScreen extends StatelessWidget {
  const BookingThanksScreen({super.key, required this.createdBooking});

  final Map<String, dynamic> createdBooking;

  static const coral = Color(0xFFF36C6C);
  static const roseLight = Color(0xFFFFEEF0);

  @override
  Widget build(BuildContext context) {
    final id = (createdBooking['id'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Merci')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
              border: Border.all(color: const Color(0xFFFFD6DA)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: roseLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: coral, size: 36),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Merci d\'avoir pris rendez-vous',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Veuillez patienter la confirmation du vétérinaire.\n'
                  'Nous vous notifierons dès qu\'il confirme.',
                  textAlign: TextAlign.center,
                ),
                if (id.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Réservation #$id', style: TextStyle(color: Colors.black.withOpacity(.6))),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go('/home'),
                    style: FilledButton.styleFrom(
                      backgroundColor: coral,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Terminer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
