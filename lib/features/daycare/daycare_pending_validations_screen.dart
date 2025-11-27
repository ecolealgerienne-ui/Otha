// lib/features/daycare/daycare_pending_validations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import 'daycare_home_screen.dart'; // Pour accéder au pendingDaycareValidationsProvider

const _green = Color(0xFF22C55E);
const _greenSoft = Color(0xFFE8F5E9);

class DaycarePendingValidationsScreen extends ConsumerWidget {
  const DaycarePendingValidationsScreen({super.key});

  Future<void> _validateBooking(
    BuildContext context,
    WidgetRef ref,
    String bookingId,
    bool approved,
    String phase, // 'drop' ou 'pickup'
  ) async {
    try {
      final api = ref.read(apiProvider);

      if (phase == 'drop') {
        await api.proValidateDaycareDropOff(bookingId, approved: approved);
      } else {
        await api.proValidateDaycarePickup(bookingId, approved: approved);
      }

      if (!context.mounted) return;

      final action = phase == 'drop' ? 'Dépôt' : 'Retrait';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved
              ? '$action validé avec succès'
              : '$action refusé'),
          backgroundColor: approved ? Colors.green : Colors.orange,
        ),
      );

      // Rafraîchir la liste
      ref.invalidate(pendingDaycareValidationsProvider);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingDaycareValidationsProvider);

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
          'Validations garderie',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: pendingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _green),
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
                        color: _greenSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: _green,
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
                      'Toutes les arrivées/départs sont validés',
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
              final status = (booking['status'] ?? '').toString().toUpperCase();
              final phase = status == 'PENDING_DROP_VALIDATION' ? 'drop' : 'pickup';

              return _DaycareValidationCard(
                booking: booking,
                phase: phase,
                onValidate: (approved) =>
                    _validateBooking(context, ref, booking['id'].toString(), approved, phase),
              );
            },
          );
        },
      ),
    );
  }
}

class _DaycareValidationCard extends StatefulWidget {
  const _DaycareValidationCard({
    required this.booking,
    required this.phase,
    required this.onValidate,
  });

  final Map<String, dynamic> booking;
  final String phase; // 'drop' ou 'pickup'
  final Function(bool approved) onValidate;

  @override
  State<_DaycareValidationCard> createState() => _DaycareValidationCardState();
}

class _DaycareValidationCardState extends State<_DaycareValidationCard> {
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
    final pet = widget.booking['pet'] as Map<String, dynamic>?;

    final clientName = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : 'Client';
    final clientPhone = user?['phone']?.toString() ?? '';
    final petName = pet?['name']?.toString() ?? 'Animal';
    final petSpecies = pet?['species']?.toString() ?? '';

    // Déterminer le type d'action
    final isDrop = widget.phase == 'drop';
    final actionLabel = isDrop ? 'DÉPÔT' : 'RETRAIT';
    final actionIcon = isDrop ? Icons.login : Icons.logout;
    final actionColor = isDrop ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);

    // Date de confirmation client
    final confirmField = isDrop ? 'clientDropConfirmedAt' : 'clientPickupConfirmedAt';
    final confirmAtStr = widget.booking[confirmField]?.toString();
    DateTime? confirmedAt;
    if (confirmAtStr != null) {
      confirmedAt = DateTime.tryParse(confirmAtStr);
    }

    final dateStr = confirmedAt != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(confirmedAt)
        : 'Heure inconnue';

    // Coordonnées de confirmation
    final latField = isDrop ? 'dropCheckinLat' : 'pickupCheckinLat';
    final lngField = isDrop ? 'dropCheckinLng' : 'pickupCheckinLng';
    final lat = (widget.booking[latField] as num?)?.toDouble();
    final lng = (widget.booking[lngField] as num?)?.toDouble();
    final hasLocation = lat != null && lng != null;

    // Méthode de confirmation
    final methodField = isDrop ? 'dropConfirmationMethod' : 'pickupConfirmationMethod';
    final method = widget.booking[methodField]?.toString() ?? 'PROXIMITY';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: actionColor.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec type d'action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.1),
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
                  child: Icon(actionIcon, color: actionColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: actionColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            petName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (petSpecies.isNotEmpty)
                        Text(
                          petSpecies,
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
                // Propriétaire
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: _green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (clientPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        clientPhone,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),

                // Date/heure de confirmation
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Confirmé le $dateStr',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),

                // Méthode de confirmation
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      method == 'PROXIMITY' ? Icons.location_on : Icons.qr_code,
                      size: 18,
                      color: _green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      method == 'PROXIMITY' ? 'Confirmé par proximité GPS' : 'Confirmé par QR code',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Localisation si disponible
                if (hasLocation) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 26),
                      Text(
                        'Position: ${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  isDrop
                      ? 'Le client confirme avoir déposé $petName. Validez-vous ?'
                      : 'Le client confirme récupérer $petName. Validez-vous ?',
                  style: const TextStyle(
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
                        label: Text(_isProcessing ? 'Traitement...' : 'Refuser'),
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
                        label: Text(_isProcessing ? 'Traitement...' : 'Valider'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
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
