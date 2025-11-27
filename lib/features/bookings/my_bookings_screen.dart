import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _green = Color(0xFF43AA8B);

final myBookingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return await ref.read(apiProvider).myBookings();
});

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return _green;
      case 'PENDING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      case 'CANCELLED':
      case 'CANCELLED_BY_USER':
      case 'CANCELLED_BY_PRO':
        return Colors.red;
      case 'NO_SHOW':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':
        return 'Confirmé';
      case 'PENDING':
        return 'En attente';
      case 'COMPLETED':
        return 'Terminé';
      case 'CANCELLED':
        return 'Annulé';
      case 'CANCELLED_BY_USER':
        return 'Annulé par vous';
      case 'CANCELLED_BY_PRO':
        return 'Annulé par le pro';
      case 'NO_SHOW':
        return 'Absent';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(myBookingsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mes rendez-vous'),
      ),
      body: asyncList.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun rendez-vous',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myBookingsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final b = items[i] as Map<String, dynamic>;
                final status = b['status']?.toString() ?? 'PENDING';
                final scheduledAt = b['scheduledAt'] != null
                    ? DateTime.tryParse(b['scheduledAt'].toString())
                    : null;
                final service = b['service'] as Map<String, dynamic>?;
                final provider = b['provider'] as Map<String, dynamic>?;
                final pet = b['pet'] as Map<String, dynamic>?;

                final serviceTitle = service?['title']?.toString() ?? 'Service';
                final providerName = provider?['businessName']?.toString() ??
                    provider?['displayName']?.toString() ??
                    'Professionnel';
                final petName = pet?['name']?.toString();

                // Peut confirmer: status CONFIRMED et date dans les prochaines 24h
                final canConfirm = status == 'CONFIRMED' &&
                    scheduledAt != null &&
                    scheduledAt.isAfter(DateTime.now().subtract(const Duration(hours: 2))) &&
                    scheduledAt.isBefore(DateTime.now().add(const Duration(hours: 24)));

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: status badge + date
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ),
                                if (scheduledAt != null)
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(scheduledAt),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Service title
                            Text(
                              serviceTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Provider name
                            Row(
                              children: [
                                Icon(
                                  Icons.store,
                                  size: 16,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    providerName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Pet name if exists
                            if (petName != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.pets,
                                    size: 16,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    petName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Bouton confirmer présence
                      if (canConfirm) ...[
                        const Divider(height: 1),
                        InkWell(
                          onTap: () {
                            context.push(
                              '/booking/${b['id']}/confirm',
                              extra: b,
                            );
                          },
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on, color: _coral, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Confirmer ma présence',
                                  style: TextStyle(
                                    color: _coral,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(myBookingsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
