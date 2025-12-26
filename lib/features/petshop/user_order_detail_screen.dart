// lib/features/petshop/user_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

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
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    // Theme colors
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(l10n.petshopMyOrder),
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (e, _) => Center(child: Text('${l10n.error}: $e', style: TextStyle(color: textPrimary))),
        data: (order) {
          if (order == null || order.isEmpty) {
            return Center(child: Text(l10n.petshopOrderNotFound, style: TextStyle(color: textPrimary)));
          }

          final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
          final deliveryMode = (order['deliveryMode'] ?? 'pickup').toString();
          final createdAt = order['createdAt'] ?? order['created_at'];
          final items = (order['items'] as List?) ?? [];

          // Backend calculates commission as % of subtotal
          final subtotalDa = _asInt(order['subtotalDa'] ?? 0);
          final commissionDa = _asInt(order['commissionDa'] ?? 0);
          final deliveryFeeDa = _asInt(order['deliveryFeeDa'] ?? 0);
          final totalDa = _asInt(order['totalDa'] ?? order['total'] ?? 0);
          final provider = order['provider'] as Map<String, dynamic>?;
          final shopName = provider?['displayName'] ?? 'Animalerie';
          final shopAddress = (provider?['address'] ?? '').toString();
          final shopLat = provider?['lat'];
          final shopLng = provider?['lng'];
          final phone = (order['phone'] ?? '').toString();
          final address = (order['deliveryAddress'] ?? '').toString();
          final notes = (order['notes'] ?? '').toString();

          DateTime? date;
          if (createdAt != null) {
            date = DateTime.tryParse(createdAt.toString());
          }

          // Check if ready for pickup
          final isReadyForPickup = deliveryMode == 'pickup' && (status == 'READY' || status == 'CONFIRMED');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status card with pickup notification
                _buildStatusCard(status, date, isDark, cardColor, textPrimary, textSecondary, l10n, isReadyForPickup, deliveryMode),
                const SizedBox(height: 16),

                // Ready for pickup banner
                if (isReadyForPickup)
                  _buildReadyForPickupBanner(isDark, l10n),
                if (isReadyForPickup)
                  const SizedBox(height: 16),

                // Shop info with itinerary button
                _buildShopCard(shopName, shopAddress, shopLat, shopLng, isDark, cardColor, textPrimary, textSecondary, borderColor, l10n),
                const SizedBox(height: 16),

                // Order items with images
                _buildItemsCard(items, isDark, cardColor, textPrimary, textSecondary, borderColor, l10n),
                const SizedBox(height: 16),

                // Delivery info
                if (deliveryMode == 'delivery' && (phone.isNotEmpty || address.isNotEmpty || notes.isNotEmpty))
                  _buildDeliveryInfoCard(phone, address, notes, isDark, cardColor, textPrimary, textSecondary, borderColor, l10n),
                if (deliveryMode == 'delivery' && (phone.isNotEmpty || address.isNotEmpty || notes.isNotEmpty))
                  const SizedBox(height: 16),

                // Total with breakdown
                _buildTotalCard(subtotalDa, commissionDa, deliveryFeeDa, totalDa, isDark, textPrimary, textSecondary, l10n),
                const SizedBox(height: 24),

                // Action buttons based on status
                _buildActionButtons(context, ref, order, status, deliveryMode, shopLat, shopLng, isDark, l10n),
                const SizedBox(height: 16),

                // Return to home
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : _coral,
                      side: BorderSide(color: isDark ? borderColor : _coral),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.home_rounded, size: 20),
                    label: Text(l10n.petshopBackToHome, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(String status, DateTime? date, bool isDark, Color cardColor, Color textPrimary, Color? textSecondary, AppLocalizations l10n, bool isReadyForPickup, String deliveryMode) {
    final statusInfo = _getStatusInfo(status, l10n);
    final dateStr = date != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal())
        : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : Colors.transparent),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusInfo.color.withOpacity(isDark ? 0.2 : 0.1),
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
                  '${l10n.petshopOrderedOn} $dateStr',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (deliveryMode == 'delivery' ? Colors.blue : Colors.purple).withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        deliveryMode == 'delivery' ? Icons.local_shipping_rounded : Icons.store_rounded,
                        size: 12,
                        color: deliveryMode == 'delivery' ? Colors.blue : Colors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        deliveryMode == 'delivery' ? l10n.petshopDeliveryInfo : l10n.petshopPickupInfo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: deliveryMode == 'delivery' ? Colors.blue : Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyForPickupBanner(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)]
              : [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.petshopReadyForPickup,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.petshopPickupHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(String shopName, String shopAddress, dynamic shopLat, dynamic shopLng, bool isDark, Color cardColor, Color textPrimary, Color? textSecondary, Color borderColor, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, size: 20, color: _coral),
              const SizedBox(width: 8),
              Text(l10n.petshopSeller, style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(shopName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textPrimary)),
          if (shopAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(shopAddress, style: TextStyle(color: textSecondary, fontSize: 13)),
                ),
              ],
            ),
          ],
          // Itinerary button
          if (shopLat != null && shopLng != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMapsItinerary(shopLat, shopLng),
                icon: const Icon(Icons.directions, size: 18),
                label: Text(l10n.petshopGoToStore),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMapsItinerary(dynamic lat, dynamic lng) async {
    final latitude = lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0;
    final longitude = lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildItemsCard(List items, bool isDark, Color cardColor, Color textPrimary, Color? textSecondary, Color borderColor, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag, size: 20, color: _coral),
              const SizedBox(width: 8),
              Text(l10n.petshopOrderItems, style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final product = item['product'] as Map<String, dynamic>?;
            final title = product?['title'] ?? 'Produit';
            final quantity = _asInt(item['quantity'] ?? 1);
            final priceDa = _asInt(item['priceDa'] ?? 0);
            final itemTotal = priceDa * quantity;
            final imageUrls = product?['imageUrls'] as List?;
            final imageUrl = imageUrls?.isNotEmpty == true ? imageUrls!.first.toString() : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: isDark ? _darkCardBorder : _coralSoft,
                      child: imageUrl != null && imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 24, color: _coral),
                            )
                          : const Icon(Icons.inventory_2, size: 24, color: _coral),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('x$quantity', style: TextStyle(color: textSecondary, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('${_da(priceDa)}/u', style: TextStyle(color: textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(_da(itemTotal), style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard(String phone, String address, String notes, bool isDark, Color cardColor, Color textPrimary, Color? textSecondary, Color borderColor, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, size: 20, color: _coral),
              const SizedBox(width: 8),
              Text(l10n.petshopDeliveryInfo, style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (phone.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Text(phone, style: TextStyle(color: textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (address.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(address, style: TextStyle(color: textPrimary))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (notes.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(notes, style: TextStyle(color: textSecondary))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalCard(int subtotalDa, int commissionDa, int deliveryFeeDa, int totalDa, bool isDark, Color textPrimary, Color? textSecondary, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _coral.withOpacity(0.1) : _coralSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _coral.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 20, color: _coral),
              const SizedBox(width: 8),
              Text(l10n.petshopSummary, style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          _buildPriceRow(l10n.petshopSubtotal, _da(subtotalDa), textPrimary, textSecondary),
          const SizedBox(height: 6),
          _buildPriceRow(l10n.petshopServiceFee, _da(commissionDa), textPrimary, textSecondary),
          if (deliveryFeeDa > 0) ...[
            const SizedBox(height: 6),
            _buildPriceRow(l10n.petshopDeliveryFee, _da(deliveryFeeDa), textPrimary, textSecondary),
          ],
          Divider(height: 20, color: _coral.withOpacity(0.5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.petshopTotal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
              Text(_da(totalDa), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _coral)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color textPrimary, Color? textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Map<String, dynamic> order, String status, String deliveryMode, dynamic shopLat, dynamic shopLng, bool isDark, AppLocalizations l10n) {
    final id = (order['id'] ?? '').toString();

    // Different actions based on status
    if (status == 'PENDING') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _cancelOrder(context, ref, id, l10n),
          icon: const Icon(Icons.cancel_outlined),
          label: Text(l10n.petshopCancelOrder),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else if (status == 'CONFIRMED' || status == 'READY') {
      return Column(
        children: [
          // Itinerary button for pickup orders
          if (deliveryMode == 'pickup' && shopLat != null && shopLng != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openMapsItinerary(shopLat, shopLng),
                icon: const Icon(Icons.directions),
                label: Text(l10n.petshopGoToStore),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (deliveryMode == 'pickup' && shopLat != null && shopLng != null)
            const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _confirmDelivery(context, ref, id, l10n),
              icon: const Icon(Icons.check_circle),
              label: Text(l10n.petshopConfirmReception),
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
              onPressed: () => _cancelOrder(context, ref, id, l10n),
              icon: const Icon(Icons.cancel_outlined),
              label: Text(l10n.petshopCancelOrder),
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
          color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(l10n.petshopOrderDelivered, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    } else if (status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, color: Colors.red),
            const SizedBox(width: 8),
            Text(l10n.petshopOrderCancelled, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _confirmDelivery(BuildContext context, WidgetRef ref, String orderId, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.petshopConfirmReceptionQuestion),
        content: Text(l10n.petshopReceivedOrder),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.petshopNo)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: Text(l10n.petshopYesReceived),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiProvider).updatePetshopOrderStatus(orderId: orderId, status: 'DELIVERED');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.petshopReceptionConfirmed), backgroundColor: Colors.green),
        );
        ref.invalidate(_orderDetailProvider(orderId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    }
  }

  Future<void> _cancelOrder(BuildContext context, WidgetRef ref, String orderId, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.petshopCancelOrderQuestion),
        content: Text(l10n.petshopCancelIrreversible),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.petshopNo)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.petshopYesCancel),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiProvider).updatePetshopOrderStatus(orderId: orderId, status: 'CANCELLED');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.petshopOrderCancelled), backgroundColor: Colors.orange),
        );
        ref.invalidate(_orderDetailProvider(orderId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    }
  }

  _StatusInfo _getStatusInfo(String status, AppLocalizations l10n) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo(l10n.petshopStatusPending, Icons.hourglass_empty, Colors.orange);
      case 'CONFIRMED':
        return _StatusInfo(l10n.petshopStatusConfirmed, Icons.thumb_up, Colors.blue);
      case 'PREPARING':
        return _StatusInfo(l10n.petshopStatusPreparing, Icons.kitchen, Colors.purple);
      case 'READY':
        return _StatusInfo(l10n.petshopStatusReady, Icons.inventory, Colors.teal);
      case 'DELIVERED':
      case 'COMPLETED':
        return _StatusInfo(l10n.petshopStatusDelivered, Icons.check_circle, Colors.green);
      case 'CANCELLED':
        return _StatusInfo(l10n.petshopStatusCancelled, Icons.cancel, Colors.red);
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
