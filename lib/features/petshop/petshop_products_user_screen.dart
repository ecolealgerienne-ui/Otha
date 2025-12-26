// lib/features/petshop/petshop_products_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import 'cart_provider.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

// Note: Commission is calculated by backend as % of subtotal, not added per item

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
  final bool preview;
  const PetshopProductsUserScreen({super.key, required this.providerId, this.preview = false});

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
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    // Theme colors
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade200;

    return Theme(
      data: _themed(context, isDark),
      child: Scaffold(
        backgroundColor: bgColor,
        body: petshopAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: _coral)),
          error: (e, _) => Center(child: Text('${l10n.error}: $e', style: TextStyle(color: textPrimary))),
          data: (petshop) {
            final name = (petshop['displayName'] ?? 'Animalerie').toString();
            final address = (petshop['address'] ?? '').toString();
            final bio = (petshop['bio'] ?? '').toString();
            final avatarUrl = (petshop['avatarUrl'] ?? petshop['photoUrl'] ?? '').toString();
            final hasAvatar = avatarUrl.isNotEmpty && avatarUrl.startsWith('http');

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // Preview banner
                    if (widget.preview)
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: SafeArea(
                            bottom: false,
                            child: Row(
                              children: [
                                const Icon(Icons.visibility, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Mode aperçu - Les clients verront cette page',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Fermer', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Custom App Bar with shop info - compact design
                    SliverAppBar(
                      expandedHeight: 160,
                      pinned: true,
                      backgroundColor: isDark ? _darkCard : _coral,
                      foregroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [_darkCard, _darkBg]
                                  : [_coral, const Color(0xFFFF8A80)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      // Compact avatar
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: isDark ? _darkCardBorder : Colors.white,
                                        backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                                        child: !hasAvatar
                                            ? Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                                style: const TextStyle(
                                                  color: _coral,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 22,
                                                ),
                                              )
                                            : null,
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
                                                fontSize: 18,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black38,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (address.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on,
                                                      size: 12, color: Colors.white70),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      address,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
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
                                    const SizedBox(height: 10),
                                    Text(
                                      bio,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black38,
                                            blurRadius: 2,
                                          ),
                                        ],
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

                    // Search bar with dark mode
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: l10n.petshopSearchProduct,
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? _darkCard : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _coral, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),

                    // Category filters with dark mode
                    SliverToBoxAdapter(
                      child: productsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (products) {
                          final categories = <String>{l10n.petshopAll};
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
                                final selected = cat == _selectedCategory || (i == 0 && _selectedCategory == 'Tous');
                                return InkWell(
                                  onTap: () => setState(() => _selectedCategory = cat),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected ? _coral : (isDark ? _darkCard : Colors.white),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected ? _coral : borderColor,
                                      ),
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: selected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey.shade700),
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
                      loading: () => SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: CircularProgressIndicator(color: _coral),
                          ),
                        ),
                      ),
                      error: (e, _) => SliverToBoxAdapter(
                        child: Center(child: Text('${l10n.error}: $e', style: TextStyle(color: textPrimary))),
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
                              _selectedCategory == 'Tous' ||
                              _selectedCategory == l10n.petshopAll ||
                              cat == _selectedCategory;

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
                                      decoration: BoxDecoration(
                                        color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.search_off, size: 48, color: _coral),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.petshopNoProduct,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.petshopTryModifySearch,
                                      style: TextStyle(color: textSecondary),
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
                                  preview: widget.preview,
                                  isDark: isDark,
                                  l10n: l10n,
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

                // Cart summary bottom bar (hidden in preview mode)
                if (!cart.isEmpty && !widget.preview)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _CartSummaryBar(cart: cart, isDark: isDark, l10n: l10n),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  ThemeData _themed(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _coral,
        surface: isDark ? _darkCard : Colors.white,
        onPrimary: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _coral),
    );
  }
}

class _CartSummaryBar extends ConsumerWidget {
  final CartState cart;
  final bool isDark;
  final AppLocalizations l10n;
  const _CartSummaryBar({required this.cart, required this.isDark, required this.l10n});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
                          color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
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
                        cart.itemCount > 1 ? l10n.petshopArticles : l10n.petshopArticle,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Button to view/edit cart
                      InkWell(
                        onTap: () => _showCartModal(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.petshopModify,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _da(cart.subtotalDa),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: textPrimary,
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
              label: Text(
                l10n.petshopOrder,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartModal(BuildContext context, WidgetRef ref) {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    // Theme colors
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade200;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final cart = ref.watch(cartProvider);
          final currentIsDark = ref.watch(themeProvider) == AppThemeMode.dark;

          // Theme colors (re-read in case theme changed)
          final modalCardColor = currentIsDark ? _darkCard : Colors.white;
          final modalTextPrimary = currentIsDark ? Colors.white : _ink;
          final modalBorderColor = currentIsDark ? _darkCardBorder : Colors.grey.shade200;

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
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: modalCardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: modalBorderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: currentIsDark ? _coral.withOpacity(0.15) : _coralSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shopping_bag, color: _coral, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.petshopMyCart,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: modalTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clear();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(l10n.petshopClear),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: modalBorderColor),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final item = cart.items[i];
                      return _CartItemTile(item: item, isDark: currentIsDark, l10n: l10n);
                    },
                  ),
                ),
                Divider(height: 1, color: modalBorderColor),
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.petshopSubtotal, style: TextStyle(fontWeight: FontWeight.w600, color: modalTextPrimary)),
                      Text(_da(cart.subtotalDa),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: _coral)),
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
  final bool isDark;
  final AppLocalizations l10n;
  const _CartItemTile({required this.item, required this.isDark, required this.l10n});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = isDark ? _darkCardBorder : Colors.grey.shade50;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? _darkCardBorder : Colors.transparent),
      ),
      child: Row(
        children: [
          // Image - bigger
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.imageUrl != null && item.imageUrl!.startsWith('http')
                ? Image.network(
                    item.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _da(item.priceDa),
                  style: const TextStyle(color: _coral, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
          // Quantity controls - bigger buttons
          Row(
            children: [
              InkWell(
                onTap: () => ref.read(cartProvider.notifier).decrementQuantity(item.productId),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? _darkCard : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? _darkCardBorder : Colors.transparent),
                  ),
                  child: Icon(
                    item.quantity == 1 ? Icons.delete_outline : Icons.remove,
                    size: 18,
                    color: item.quantity == 1 ? Colors.red : textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textPrimary),
                ),
              ),
              InkWell(
                onTap: () => ref.read(cartProvider.notifier).incrementQuantity(item.productId),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _coral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, size: 18, color: Colors.white),
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
  final bool preview;
  final bool isDark;
  final AppLocalizations l10n;
  const _ProductCard({
    required this.product,
    required this.providerId,
    required this.isDark,
    required this.l10n,
    this.preview = false,
  });

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (product['title'] ?? '').toString();
    final description = (product['description'] ?? '').toString();
    final productId = (product['id'] ?? '').toString();
    // Display base price - commission is applied at checkout
    final price = _asInt(product['priceDa'] ?? product['price'] ?? 0);
    final stock = _asInt(product['stock'] ?? 0);
    final imageUrls = product['imageUrls'] as List?;
    final imageUrl =
        imageUrls != null && imageUrls.isNotEmpty ? imageUrls.first.toString() : null;

    final inStock = stock > 0 || stock == 0 && product['stock'] == null;

    // Theme colors
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade200;

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
              Expanded(child: Text('$title ${l10n.petshopAddedToCart}')),
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
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : const [
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
                      child: Center(
                        child: Text(
                          l10n.petshopOutOfStock,
                          style: const TextStyle(
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: textSecondary,
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
                      if (!preview)
                        InkWell(
                          onTap: inStock ? addToCart : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: inStock ? _coral : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
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
      color: isDark ? _darkCardBorder : _coralSoft,
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
