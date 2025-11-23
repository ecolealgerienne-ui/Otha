import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

/// Provider pour les validations en attente
final pendingValidationsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiProvider);
  return await api.getPendingValidations();
});

class ProPendingValidationsScreen extends ConsumerWidget {
  const ProPendingValidationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValidations = ref.watch(pendingValidationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Validations en attente',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: asyncValidations.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _coral),
        ),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erreur: $e'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.refresh(pendingValidationsProvider),
                  style: FilledButton.styleFrom(backgroundColor: _coral),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (validations) {
          if (validations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune validation en attente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toutes les confirmations clients ont été traitées',
                    style: TextStyle(color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingValidationsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: validations.length,
              itemBuilder: (context, i) {
                final booking = validations[i] as Map<String, dynamic>;
                return _ValidationCard(
                  booking: booking,
                  onValidated: () => ref.invalidate(pendingValidationsProvider),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ValidationCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onValidated;

  const _ValidationCard({required this.booking, this.onValidated});

  @override
  ConsumerState<_ValidationCard> createState() => _ValidationCardState();
}

class _ValidationCardState extends ConsumerState<_ValidationCard> {
  bool _isLoading = false;

  String get _clientName {
    final user = widget.booking['user'] as Map<String, dynamic>?;
    return user?['displayName']?.toString() ?? 'Client';
  }

  String get _serviceName {
    final service = widget.booking['service'] as Map<String, dynamic>?;
    return service?['title']?.toString() ?? 'Service';
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

  String? get _deadline {
    final iso = widget.booking['proResponseDeadline']?.toString();
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(now);

      if (diff.isNegative) return 'Expiré';
      if (diff.inDays > 0) return '${diff.inDays}j restants';
      if (diff.inHours > 0) return '${diff.inHours}h restantes';
      return '${diff.inMinutes}min restantes';
    } catch (_) {
      return null;
    }
  }

  Future<void> _validate(bool approved) async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      await api.proValidateClientConfirmation(
        bookingId: widget.booking['id'],
        approved: approved,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '✅ Rendez-vous validé, commission créée'
                : '❌ Rendez-vous refusé, client signalé',
          ),
          backgroundColor: approved ? Colors.green : Colors.orange,
        ),
      );

      widget.onValidated?.call();
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec icône alerte
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber, color: Colors.red.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Validation requise',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.red,
                      ),
                    ),
                    if (_deadline != null)
                      Text(
                        _deadline!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Infos rendez-vous
          Text(
            'Le client affirme s\'être présenté à ce rendez-vous :',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• $_clientName\n• $_serviceName\n• $_dateStr',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),

          // Question
          Text(
            'Confirmez-vous que ce client s\'est bien présenté ?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          // Boutons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _validate(false),
                  icon: const Icon(Icons.close),
                  label: const Text('Non'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : () => _validate(true),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isLoading ? 'En cours...' : 'Oui'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
