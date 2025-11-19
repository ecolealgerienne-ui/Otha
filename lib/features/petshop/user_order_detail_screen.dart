// lib/features/petshop/user_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import 'cart_provider.dart'; // For kPetshopCommissionDa

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

/// Provider pour les détails d'une commande client
final _orderDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, orderId) async {
  final api = ref.read(apiProvider);
  final orders = await api.myClientOrders();
  return orders.firstWhere((o) => o['id'] == orderId, orElse: () => <String, dynamic>{});
});

class UserOrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const UserOrderDetailScreen({super.key, required this.orderId});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Ma commande'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (order) {
          if (order == null || order.isEmpty) {
            return const Center(child: Text('Commande introuvable'));
          }

          final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
          final createdAt = order['createdAt'] ?? order['created_at'];
          final items = (order['items'] as List?) ?? [];

          // Calculate total item count for commission
          int totalItemCount = 0;
          for (final item in items) {
            totalItemCount += _asInt(item['quantity'] ?? 1);
          }

          // Backend totalDa is product prices only, add commission per item for display
          final baseTotalDa = _asInt(order['totalDa'] ?? order['total'] ?? 0);
          final commissionDa = totalItemCount * kPetshopCommissionDa;
          final totalDa = baseTotalDa + commissionDa;
          final provider = order['provider'] as Map<String, dynamic>?;
          final shopName = provider?['displayName'] ?? 'Animalerie';
          final phone = (order['phone'] ?? '').toString();
          final address = (order['deliveryAddress'] ?? '').toString();
          final notes = (order['notes'] ?? '').toString();

          DateTime? date;
          if (createdAt != null) {
            date = DateTime.tryParse(createdAt.toString());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status card
                _buildStatusCard(status, date),
                const SizedBox(height: 16),

                // Shop info
                _buildInfoCard(
                  'Vendeur',
                  Icons.storefront,
                  [
                    Text(shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),

                // Order items
                _buildItemsCard(items),
                const SizedBox(height: 16),

                // Delivery info
                if (phone.isNotEmpty || address.isNotEmpty || notes.isNotEmpty)
                  _buildDeliveryInfoCard(phone, address, notes),
                if (phone.isNotEmpty || address.isNotEmpty || notes.isNotEmpty)
                  const SizedBox(height: 16),

                // Total with breakdown
                _buildTotalCard(baseTotalDa, commissionDa, totalDa),
                const SizedBox(height: 24),

                // Action buttons based on status
                _buildActionButtons(context, ref, order, status),
                const SizedBox(height: 16),

                // Return to home
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _coral,
                      side: const BorderSide(color: _coral),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retourner a l\'accueil', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(String status, DateTime? date) {
    final statusInfo = _getStatusInfo(status);
    final dateStr = date != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal())
        : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusInfo.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusInfo.icon, color: statusInfo.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: statusInfo.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Commandee le $dateStr',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _coral),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildItemsCard(List items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_bag, size: 20, color: _coral),
              SizedBox(width: 8),
              Text('Articles', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final product = item['product'] as Map<String, dynamic>?;
            final title = product?['title'] ?? 'Produit';
            final quantity = _asInt(item['quantity'] ?? 1);
            final priceDa = _asInt(item['priceDa'] ?? 0);
            // Add commission per item for user display
            final priceWithCommission = (priceDa + kPetshopCommissionDa) * quantity;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _coralSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2, size: 20, color: _coral),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('x$quantity', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(_da(priceWithCommission), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard(String phone, String address, String notes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping, size: 20, color: _coral),
              SizedBox(width: 8),
              Text('Livraison', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (phone.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(phone),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (address.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(address)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (notes.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(notes, style: TextStyle(color: Colors.grey.shade700))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalCard(int baseTotalDa, int commissionDa, int totalDa) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _coralSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _coral.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_da(totalDa), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _coral)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '(+ frais de livraison a convenir avec le vendeur)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Map<String, dynamic> order, String status) {
    final id = (order['id'] ?? '').toString();

    // Different actions based on status
    if (status == 'PENDING') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _cancelOrder(context, ref, id),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Annuler la commande'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else if (status == 'CONFIRMED') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _confirmDelivery(context, ref, id),
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirmer la reception'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _cancelOrder(context, ref, id),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Annuler la commande'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'DELIVERED' || status == 'COMPLETED') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Commande livree', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    } else if (status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Commande annulee', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _confirmDelivery(BuildContext context, WidgetRef ref, String orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la reception ?'),
        content: const Text('Avez-vous bien recu votre commande ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Oui, j\'ai recu'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // Use the client order status update - we need to add this endpoint
      // For now, we'll use the existing update status
      await ref.read(apiProvider).updatePetshopOrderStatus(orderId: orderId, status: 'DELIVERED');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reception confirmee !'), backgroundColor: Colors.green),
        );
        ref.invalidate(_orderDetailProvider(orderId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _cancelOrder(BuildContext context, WidgetRef ref, String orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Cette action est irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiProvider).updatePetshopOrderStatus(orderId: orderId, status: 'CANCELLED');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande annulee'), backgroundColor: Colors.orange),
        );
        ref.invalidate(_orderDetailProvider(orderId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo('En attente', Icons.hourglass_empty, Colors.orange);
      case 'CONFIRMED':
        return _StatusInfo('Confirmee', Icons.thumb_up, Colors.blue);
      case 'PREPARING':
        return _StatusInfo('En preparation', Icons.kitchen, Colors.purple);
      case 'READY':
        return _StatusInfo('Prete', Icons.inventory, Colors.teal);
      case 'DELIVERED':
      case 'COMPLETED':
        return _StatusInfo('Livree', Icons.check_circle, Colors.green);
      case 'CANCELLED':
        return _StatusInfo('Annulee', Icons.cancel, Colors.red);
      default:
        return _StatusInfo(status, Icons.help_outline, Colors.grey);
    }
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;

  _StatusInfo(this.label, this.icon, this.color);
}
