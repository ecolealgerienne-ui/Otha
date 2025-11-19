import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import 'cart_provider.dart' show kPetshopCommissionDa;

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

final petshopOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.read(apiProvider).myPetshopOrders();
  } catch (e) {
    return [];
  }
});

class PetshopOrdersScreen extends ConsumerStatefulWidget {
  const PetshopOrdersScreen({super.key});

  @override
  ConsumerState<PetshopOrdersScreen> createState() =>
      _PetshopOrdersScreenState();
}

class _PetshopOrdersScreenState extends ConsumerState<PetshopOrdersScreen> {
  String _filterStatus = 'ALL';
  String? _expandedOrderId;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(petshopOrdersProvider);

    return Theme(
      data: _themed(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('Mes commandes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(petshopOrdersProvider),
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Toutes',
                      selected: _filterStatus == 'ALL',
                      onTap: () => setState(() => _filterStatus = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'En attente',
                      selected: _filterStatus == 'PENDING',
                      onTap: () => setState(() => _filterStatus = 'PENDING'),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confirmees',
                      selected: _filterStatus == 'CONFIRMED',
                      onTap: () => setState(() => _filterStatus = 'CONFIRMED'),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Livrees',
                      selected: _filterStatus == 'DELIVERED',
                      onTap: () => setState(() => _filterStatus = 'DELIVERED'),
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Annulees',
                      selected: _filterStatus == 'CANCELLED',
                      onTap: () => setState(() => _filterStatus = 'CANCELLED'),
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            // Orders list
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
                data: (orders) {
                  final filtered = _filterStatus == 'ALL'
                      ? orders
                      : orders.where((o) {
                          final status = (o['status'] ?? '').toString().toUpperCase();
                          return status == _filterStatus;
                        }).toList();

                  // Sort by date descending
                  filtered.sort((a, b) {
                    final aDate = DateTime.tryParse(
                            (a['createdAt'] ?? a['created_at'] ?? '').toString()) ??
                        DateTime(2000);
                    final bDate = DateTime.tryParse(
                            (b['createdAt'] ?? b['created_at'] ?? '').toString()) ??
                        DateTime(2000);
                    return bDate.compareTo(aDate);
                  });

                  if (filtered.isEmpty) {
                    return _EmptyState(filter: _filterStatus);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(petshopOrdersProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _OrderCard(
                        order: filtered[i],
                        isExpanded: _expandedOrderId == filtered[i]['id'],
                        onToggle: () {
                          setState(() {
                            if (_expandedOrderId == filtered[i]['id']) {
                              _expandedOrderId = null;
                            } else {
                              _expandedOrderId = filtered[i]['id']?.toString();
                            }
                          });
                        },
                        onStatusUpdate: () => ref.invalidate(petshopOrdersProvider),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  ThemeData _themed(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _coral,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _coral,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _coral),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _coral;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [BoxShadow(color: chipColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;

    switch (filter) {
      case 'PENDING':
        message = 'Aucune commande en attente';
        icon = Icons.hourglass_empty;
        break;
      case 'CONFIRMED':
        message = 'Aucune commande confirmee';
        icon = Icons.thumb_up_outlined;
        break;
      case 'DELIVERED':
        message = 'Aucune commande livree';
        icon = Icons.local_shipping_outlined;
        break;
      case 'CANCELLED':
        message = 'Aucune commande annulee';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'Aucune commande pour le moment';
        icon = Icons.shopping_bag_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _coralSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _coral),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les nouvelles commandes apparaitront ici',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Map<String, dynamic> order;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onStatusUpdate;

  const _OrderCard({
    required this.order,
    required this.isExpanded,
    required this.onToggle,
    required this.onStatusUpdate,
  });

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (order['id'] ?? '').toString();
    final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final baseTotal = _asInt(order['totalDa'] ?? order['total'] ?? 0);
    final createdAt = order['createdAt'] ?? order['created_at'];
    final items = order['items'] as List? ?? [];
    final deliveryAddress = (order['deliveryAddress'] ?? '').toString();
    final notes = (order['notes'] ?? '').toString();
    final phone = (order['phone'] ?? '').toString();

    // Calculate commission based on item quantities
    int totalItemQty = 0;
    for (final item in items) {
      totalItemQty += _asInt(item['quantity'] ?? 1);
    }
    final commissionDa = totalItemQty * kPetshopCommissionDa;

    DateTime? date;
    if (createdAt != null) {
      try {
        date = DateTime.parse(createdAt.toString());
      } catch (_) {}
    }

    final user = order['user'] as Map? ?? {};
    final userName = (user['displayName'] ?? user['firstName'] ?? 'Client').toString();
    final userPhone = phone.isNotEmpty ? phone : (user['phone'] ?? '').toString();

    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(statusInfo.icon, color: statusInfo.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${id.length > 8 ? id.substring(0, 8) : id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userName,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _da(baseTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _coral,
                            ),
                          ),
                          if (commissionDa > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '+${_da(commissionDa)} com.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusInfo.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusInfo.label,
                              style: TextStyle(
                                color: statusInfo.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy - HH:mm', 'fr_FR').format(date),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${items.length} article${items.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items
                  const Text(
                    'Articles',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    final itemTitle = (item['title'] ?? item['productTitle'] ?? 'Produit').toString();
                    final qty = _asInt(item['quantity'] ?? 1);
                    final price = _asInt(item['priceDa'] ?? item['price'] ?? 0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _coralSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${qty}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: _coral,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              itemTitle,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _da(price * qty),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (deliveryAddress.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Adresse de livraison',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            deliveryAddress,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (userPhone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          userPhone,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Note du client',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notes,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],

                  // Action buttons
                  if (status == 'PENDING' || status == 'CONFIRMED') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (status == 'PENDING') ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateStatus(context, ref, id, 'CANCELLED'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => _updateStatus(
                              context,
                              ref,
                              id,
                              status == 'PENDING' ? 'CONFIRMED' : 'DELIVERED',
                            ),
                            icon: Icon(
                              status == 'PENDING' ? Icons.check : Icons.local_shipping,
                              size: 18,
                            ),
                            label: Text(
                              status == 'PENDING' ? 'Confirmer' : 'Marquer livree',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext context, WidgetRef ref, String orderId, String newStatus) async {
    final api = ref.read(apiProvider);

    try {
      await api.updatePetshopOrderStatus(orderId: orderId, status: newStatus);
      onStatusUpdate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande ${newStatus == 'CANCELLED' ? 'annulee' : 'mise a jour'}'),
            backgroundColor: newStatus == 'CANCELLED' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo('En attente', Colors.orange, Icons.hourglass_empty);
      case 'CONFIRMED':
        return _StatusInfo('Confirmee', Colors.blue, Icons.thumb_up);
      case 'SHIPPED':
        return _StatusInfo('Expediee', Colors.purple, Icons.local_shipping);
      case 'DELIVERED':
        return _StatusInfo('Livree', Colors.green, Icons.check_circle);
      case 'CANCELLED':
        return _StatusInfo('Annulee', Colors.red, Icons.cancel);
      default:
        return _StatusInfo(status, Colors.grey, Icons.help_outline);
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusInfo(this.label, this.color, this.icon);
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
