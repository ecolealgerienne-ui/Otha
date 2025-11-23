// lib/features/pro/pro_pending_validations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import 'pro_home_screen.dart'; // Pour accéder au pendingValidationsProvider

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFE7E7);

class ProPendingValidationsScreen extends ConsumerWidget {
  const ProPendingValidationsScreen({super.key});

  Future<void> _validateBooking(
    BuildContext context,
    WidgetRef ref,
    String bookingId,
    bool approved,
  ) async {
    try {
      final api = ref.read(apiProvider);
      await api.proValidateClientConfirmation(
        bookingId: bookingId,
        approved: approved,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved
              ? '✅ Rendez-vous validé avec succès'
              : '❌ Rendez-vous refusé'),
          backgroundColor: approved ? Colors.green : Colors.orange,
        ),
      );

      // Rafraîchir la liste
      ref.invalidate(pendingValidationsProvider);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingValidationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Validations en attente',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: pendingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _coral),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Erreur de chargement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (validations) {
          if (validations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _coralSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: _coral,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Aucune validation en attente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tous vos rendez-vous sont à jour',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: validations.length,
            itemBuilder: (context, index) {
              final booking = validations[index];
              return _ValidationCard(
                booking: booking,
                onValidate: (approved) =>
                    _validateBooking(context, ref, booking['id'].toString(), approved),
              );
            },
          );
        },
      ),
    );
  }
}

class _ValidationCard extends StatefulWidget {
  const _ValidationCard({
    required this.booking,
    required this.onValidate,
  });

  final Map<String, dynamic> booking;
  final Function(bool approved) onValidate;

  @override
  State<_ValidationCard> createState() => _ValidationCardState();
}

class _ValidationCardState extends State<_ValidationCard> {
  bool _isProcessing = false;

  Future<void> _handleValidation(bool approved) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    await widget.onValidate(approved);

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.booking['user'] as Map<String, dynamic>?;
    final service = widget.booking['service'] as Map<String, dynamic>?;
    final scheduledAtStr = widget.booking['scheduledAt']?.toString();
    final proResponseDeadlineStr = widget.booking['proResponseDeadline']?.toString();

    final clientName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : 'Client';
    final clientPhone = user?['phone']?.toString() ?? '';
    final serviceTitle = service?['title']?.toString() ?? 'Service';

    DateTime? scheduledAt;
    if (scheduledAtStr != null) {
      scheduledAt = DateTime.tryParse(scheduledAtStr);
    }

    DateTime? deadline;
    if (proResponseDeadlineStr != null) {
      deadline = DateTime.tryParse(proResponseDeadlineStr);
    }

    final dateStr = scheduledAt != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(scheduledAt)
        : 'Date inconnue';

    final deadlineStr = deadline != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(deadline)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (clientPhone.isNotEmpty)
                        Text(
                          clientPhone,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_services, size: 18, color: _coral),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        serviceTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                if (deadlineStr != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Répondre avant le $deadlineStr',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Le client affirme être venu au rendez-vous. Confirmez-vous ?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _handleValidation(false),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.close),
                        label: Text(_isProcessing ? 'Traitement...' : 'Non'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isProcessing ? null : () => _handleValidation(true),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isProcessing ? 'Traitement...' : 'Oui'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
