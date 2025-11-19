// lib/features/petshop/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Panier'),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Vider le panier'),
                    content: const Text('Supprimer tous les articles ?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Vider'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cart.isEmpty
          ? _buildEmptyCart(context)
          : _buildCartContent(context, ref, cart),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _buildBottomBar(context, cart),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Votre panier est vide',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Parcourez nos boutiques pour trouver des produits',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/explore/petshop'),
            icon: const Icon(Icons.storefront),
            label: const Text('Voir les boutiques'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(BuildContext context, WidgetRef ref, CartState cart) {
    final itemsByProvider = cart.itemsByProvider;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Items grouped by provider
        ...itemsByProvider.entries.map((entry) {
          final providerId = entry.key;
          final items = entry.value;
          final providerName = items.first.providerName.isNotEmpty
              ? items.first.providerName
              : 'Boutique';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          providerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                // Products
                ...items.map((item) => _buildCartItem(context, ref, item)),
              ],
            ),
          );
        }),

        const SizedBox(height: 16),

        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recapitulatif',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  'Sous-total',
                  '${cart.subtotalDa} DA',
                ),
                if (cart.commissionDa > 0) ...[
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Frais de service',
                    '${cart.commissionDa} DA',
                    subtitle: '${cart.providerCount} boutique(s)',
                  ),
                ],
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total',
                  '${cart.totalDa} DA',
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, CartItem item) {
    final notifier = ref.read(cartProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported),
                    )
                  : const Icon(Icons.inventory_2),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.priceDa} DA',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Quantity controls
                Row(
                  children: [
                    _buildQuantityButton(
                      icon: Icons.remove,
                      onTap: item.quantity > 1
                          ? () => notifier.decrementQuantity(item.productId)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildQuantityButton(
                      icon: Icons.add,
                      onTap: item.quantity >= item.stock
                          ? null
                          : () => notifier.incrementQuantity(item.productId),
                    ),
                    const Spacer(),
                    Text(
                      '${item.totalDa} DA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => notifier.removeItem(item.productId),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: onTap != null ? Colors.grey[400]! : Colors.grey[200]!,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? Colors.grey[700] : Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    String? subtitle,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  '${cart.totalDa} DA',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => context.push('/petshop/checkout'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Commander'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
