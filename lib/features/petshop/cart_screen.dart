// lib/features/petshop/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'cart_provider.dart';
import '../../core/locale_provider.dart';

// ═══════════════════════════════════════════════════════════════
// COULEURS
// ═══════════════════════════════════════════════════════════════
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF1F2328);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, ref, cart, isDark, l10n, textPrimary, cardColor, borderColor),

            // Content
            Expanded(
              child: cart.isEmpty
                  ? _buildEmptyCart(context, isDark, l10n, textPrimary, textSecondary)
                  : _buildCartContent(context, ref, cart, isDark, textPrimary, textSecondary, cardColor, borderColor),
            ),
          ],
        ),
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _buildBottomBar(context, cart, isDark, cardColor, borderColor),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color cardColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: borderColor)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: _coral,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart_rounded, color: _coral, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Mon Panier',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                if (cart.items.isNotEmpty)
                  Text(
                    '${cart.itemCount} article${cart.itemCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          if (cart.items.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                onPressed: () => _showClearCartDialog(context, ref, isDark),
              ),
            ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 32),
        ),
        title: Text(
          'Vider le panier ?',
          style: TextStyle(
            color: isDark ? Colors.white : _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Tous les articles seront supprimés.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color? textSecondary,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 64, color: _coral),
            ),
            const SizedBox(height: 28),
            Text(
              'Votre panier est vide',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Parcourez nos boutiques pour\ntrouver des produits',
              style: TextStyle(
                color: textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_coral, Color(0xFFFF8A8A)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _coral.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/explore/petshop'),
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Voir les boutiques',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    bool isDark,
    Color textPrimary,
    Color? textSecondary,
    Color cardColor,
    Color borderColor,
  ) {
    final itemsByProvider = cart.itemsByProvider;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Items grouped by provider
        ...itemsByProvider.entries.map((entry) {
          final items = entry.value;
          final providerName = items.first.providerName.isNotEmpty
              ? items.first.providerName
              : 'Boutique';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [_coral.withOpacity(0.15), Colors.transparent]
                          : [_coralSoft.withOpacity(0.5), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_rounded, size: 20, color: _coral),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          providerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${items.length} produit${items.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Products
                ...items.map((item) => _buildCartItem(context, ref, item, isDark, textPrimary, textSecondary, borderColor)),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long_rounded, size: 20, color: Colors.blue.shade400),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Récapitulatif',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSummaryRow(
                'Sous-total produits',
                '${cart.subtotalDa} DA',
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Frais de service ajoutés à la commande',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: borderColor),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sous-total',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${cart.subtotalDa} DA',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: _coral,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bottom spacing for the fixed bottom bar
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    WidgetRef ref,
    CartItem item,
    bool isDark,
    Color textPrimary,
    Color? textSecondary,
    Color borderColor,
  ) {
    final notifier = ref.read(cartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor.withOpacity(0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_not_supported_rounded,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    )
                  : Icon(
                      Icons.inventory_2_rounded,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.priceDa} DA / unité',
                  style: const TextStyle(
                    color: _coral,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                // Quantity controls
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQuantityButton(
                            icon: Icons.remove_rounded,
                            onTap: item.quantity > 1
                                ? () => notifier.decrementQuantity(item.productId)
                                : null,
                            isDark: isDark,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '${item.quantity}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          _buildQuantityButton(
                            icon: Icons.add_rounded,
                            onTap: item.quantity >= item.stock
                                ? null
                                : () => notifier.incrementQuantity(item.productId),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${item.totalDa} DA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Delete button
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade400),
              onPressed: () => notifier.removeItem(item.productId),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled
                ? _coral
                : (isDark ? Colors.grey[700] : Colors.grey[300]),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    required bool isDark,
    required Color textPrimary,
    Color? textSecondary,
    String? info,
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
                fontSize: 15,
                color: textSecondary,
              ),
            ),
            if (info != null)
              Text(
                info,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, CartState cart, bool isDark, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Price column
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sous-total',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cart.subtotalDa} DA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : _ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Checkout button
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_coral, Color(0xFFFF8A8A)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _coral.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/petshop/checkout'),
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Commander',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
