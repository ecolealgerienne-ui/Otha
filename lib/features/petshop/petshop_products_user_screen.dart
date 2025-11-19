// lib/features/petshop/petshop_products_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import 'cart_provider.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

/// Commission ajoutee au prix de chaque produit (en DA)
const int kCommissionDa = 100;

/// Provider pour les details d'une animalerie
final _petshopProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(apiProvider).providerDetails(id);
});

/// Provider pour les produits d'une animalerie
final _petshopProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, providerId) async {
  try {
    final api = ref.read(apiProvider);
    return await api.listPublicProducts(providerId);
  } catch (_) {
    return [];
  }
});

class PetshopProductsUserScreen extends ConsumerStatefulWidget {
  final String providerId;
  const PetshopProductsUserScreen({super.key, required this.providerId});

  @override
  ConsumerState<PetshopProductsUserScreen> createState() => _PetshopProductsUserScreenState();
}

class _PetshopProductsUserScreenState extends ConsumerState<PetshopProductsUserScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petshopAsync = ref.watch(_petshopProvider(widget.providerId));
    final productsAsync = ref.watch(_petshopProductsProvider(widget.providerId));
    final cart = ref.watch(cartProvider);

    return Theme(
      data: _themed(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: petshopAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (petshop) {
            final name = (petshop['displayName'] ?? 'Animalerie').toString();
            final address = (petshop['address'] ?? '').toString();
            final bio = (petshop['bio'] ?? '').toString();

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // Custom App Bar with shop info
                    SliverAppBar(
                      expandedHeight: 180,
                      pinned: true,
                      backgroundColor: Colors.white,
                      foregroundColor: _ink,
                      surfaceTintColor: Colors.transparent,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_coral, Color(0xFFFF8A80)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.white,
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                          style: const TextStyle(
                                            color: _coral,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 24,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 20,
                                              ),
                                            ),
                                            if (address.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on,
                                                      size: 14, color: Colors.white70),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      address,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (bio.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      bio,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Search bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un produit...',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),

                    // Category filters
                    SliverToBoxAdapter(
                      child: productsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (products) {
                          final categories = <String>{'Tous'};
                          for (final p in products) {
                            final cat = (p['category'] ?? '').toString();
                            if (cat.isNotEmpty) categories.add(cat);
                          }
                          if (categories.length <= 1) return const SizedBox.shrink();

                          return SizedBox(
                            height: 44,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final cat = categories.elementAt(i);
                                final selected = cat == _selectedCategory;
                                return InkWell(
                                  onTap: () => setState(() => _selectedCategory = cat),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected ? _coral : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected ? _coral : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: selected ? Colors.white : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Products grid
                    productsAsync.when(
                      loading: () => const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                      error: (e, _) => SliverToBoxAdapter(
                        child: Center(child: Text('Erreur: $e')),
                      ),
                      data: (products) {
                        // Filter products
                        var filtered = products.where((p) {
                          final title = (p['title'] ?? '').toString().toLowerCase();
                          final desc = (p['description'] ?? '').toString().toLowerCase();
                          final cat = (p['category'] ?? '').toString();

                          final matchesSearch = _searchQuery.isEmpty ||
                              title.contains(_searchQuery) ||
                              desc.contains(_searchQuery);
                          final matchesCategory =
                              _selectedCategory == 'Tous' || cat == _selectedCategory;

                          return matchesSearch && matchesCategory;
                        }).toList();

                        if (filtered.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(48),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: const BoxDecoration(
                                        color: _coralSoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.search_off, size: 48, color: _coral),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Aucun produit trouve',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Essayez de modifier votre recherche',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return _ProductCard(
                                  product: filtered[index],
                                  providerId: widget.providerId,
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Cart summary bottom bar
                if (!cart.isEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _CartSummaryBar(cart: cart),
                  ),
              ],
            );
          },
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _coral),
    );
  }
}

class _CartSummaryBar extends ConsumerWidget {
  final CartState cart;
  const _CartSummaryBar({required this.cart});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cart info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _coralSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag, size: 16, color: _coral),
                            const SizedBox(width: 4),
                            Text(
                              '${cart.itemCount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _coral,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'article${cart.itemCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Button to view/edit cart
                      InkWell(
                        onTap: () => _showCartModal(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Modifier',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _da(cart.subtotalDa),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),

            // Checkout button
            FilledButton.icon(
              onPressed: () => context.push('/petshop/confirm-order'),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.shopping_cart_checkout, size: 20),
              label: const Text(
                'Commander',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final cart = ref.watch(cartProvider);

          // Close modal if cart becomes empty
          if (cart.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(ctx).canPop()) {
                Navigator.of(ctx).pop();
              }
            });
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Mon panier',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Vider', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final item = cart.items[i];
                      return _CartItemTile(item: item);
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(_da(cart.subtotalDa),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null && item.imageUrl!.startsWith('http')
                ? Image.network(
                    item.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _da(item.priceDa),
                  style: const TextStyle(color: _coral, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          // Quantity controls
          Row(
            children: [
              InkWell(
                onTap: () => ref.read(cartProvider.notifier).decrementQuantity(item.productId),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    item.quantity == 1 ? Icons.delete_outline : Icons.remove,
                    size: 16,
                    color: item.quantity == 1 ? Colors.red : _ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              InkWell(
                onTap: () => ref.read(cartProvider.notifier).incrementQuantity(item.productId),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _coral,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 50,
      height: 50,
      color: _coralSoft,
      child: const Icon(Icons.inventory_2, size: 24, color: _coral),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  final String providerId;
  const _ProductCard({required this.product, required this.providerId});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (product['title'] ?? '').toString();
    final description = (product['description'] ?? '').toString();
    final productId = (product['id'] ?? '').toString();
    final basePrice = _asInt(product['priceDa'] ?? product['price'] ?? 0);
    // Le prix affiché inclut la commission
    final price = basePrice + kCommissionDa;
    final stock = _asInt(product['stock'] ?? 0);
    final imageUrls = product['imageUrls'] as List?;
    final imageUrl =
        imageUrls != null && imageUrls.isNotEmpty ? imageUrls.first.toString() : null;

    final inStock = stock > 0 || stock == 0 && product['stock'] == null;

    // Check if already in cart
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((item) => item.productId == productId).firstOrNull;
    final inCart = cartItem != null;

    void addToCart() {
      ref.read(cartProvider.notifier).addItem(CartItem(
            productId: productId,
            providerId: providerId,
            title: title,
            priceDa: price,
            quantity: 1,
            imageUrl: imageUrl,
          ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('$title ajoute')),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: imageUrl != null && imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                if (!inStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Center(
                        child: Text(
                          'Rupture',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (inCart)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cartItem.quantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Info
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _da(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _coral,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: inStock ? addToCart : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: inStock ? _coral : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            inCart ? Icons.add : Icons.add_shopping_cart,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: _coralSoft,
      child: const Center(
        child: Icon(Icons.inventory_2, size: 40, color: _coral),
      ),
    );
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
