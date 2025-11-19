// lib/features/petshop/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Commission par article (en DA) - modifiable pour ajustements futurs
const int kPetshopCommissionDa = 100;

/// Item dans le panier
class CartItem {
  final String productId;
  final String providerId;
  final String providerName; // Nom de la boutique
  final String title;
  final int priceDa; // Prix unitaire avec commission incluse
  final int quantity;
  final String? imageUrl;
  final int stock; // Stock disponible (9999 = illimité)

  CartItem({
    required this.productId,
    required this.providerId,
    this.providerName = '',
    required this.title,
    required this.priceDa,
    required this.quantity,
    this.imageUrl,
    this.stock = 9999, // Default: stock illimité
  });

  /// Total pour cet item (prix * quantité)
  int get totalDa => priceDa * quantity;

  CartItem copyWith({int? quantity, int? stock, String? providerName}) {
    return CartItem(
      productId: productId,
      providerId: providerId,
      providerName: providerName ?? this.providerName,
      title: title,
      priceDa: priceDa,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl,
      stock: stock ?? this.stock,
    );
  }
}

/// État du panier
class CartState {
  final List<CartItem> items;
  final String? providerId; // Un panier ne peut contenir que des produits d'un seul shop

  const CartState({this.items = const [], this.providerId});

  /// Total des produits (sans commission)
  int get subtotalDa => items.fold(0, (sum, item) => sum + (item.priceDa * item.quantity));

  /// Nombre de boutiques différentes dans le panier
  int get providerCount {
    final providers = items.map((i) => i.providerId).toSet();
    return providers.length;
  }

  /// Commission totale (par article)
  int get commissionDa => itemCount * kPetshopCommissionDa;

  /// Total final (produits + commission)
  int get totalDa => subtotalDa + commissionDa;

  /// Nombre total d'articles
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Panier vide ?
  bool get isEmpty => items.isEmpty;

  /// Items groupés par provider
  Map<String, List<CartItem>> get itemsByProvider {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.providerId, () => []).add(item);
    }
    return map;
  }

  CartState copyWith({List<CartItem>? items, String? providerId}) {
    return CartState(
      items: items ?? this.items,
      providerId: providerId ?? this.providerId,
    );
  }
}

/// Notifier pour gérer le panier
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(CartItem item) {
    // Si le panier contient des items d'un autre provider, on le vide d'abord
    if (state.providerId != null && state.providerId != item.providerId) {
      state = CartState(items: [item], providerId: item.providerId);
      return;
    }

    // Chercher si le produit existe déjà
    final existing = state.items.indexWhere((i) => i.productId == item.productId);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + item.quantity,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [...state.items, item],
        providerId: item.providerId,
      );
    }
  }

  void removeItem(String productId) {
    final updated = state.items.where((i) => i.productId != productId).toList();
    state = state.copyWith(
      items: updated,
      providerId: updated.isEmpty ? null : state.providerId,
    );
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final updated = state.items.map((i) {
      if (i.productId == productId) {
        return i.copyWith(quantity: quantity);
      }
      return i;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void incrementQuantity(String productId) {
    final item = state.items.firstWhere(
      (i) => i.productId == productId,
      orElse: () => throw Exception('Item not found'),
    );
    updateQuantity(productId, item.quantity + 1);
  }

  void decrementQuantity(String productId) {
    final item = state.items.firstWhere(
      (i) => i.productId == productId,
      orElse: () => throw Exception('Item not found'),
    );
    updateQuantity(productId, item.quantity - 1);
  }

  /// Convertir les items pour l'API (pour un provider donné)
  /// Note: Backend DTO only accepts productId and quantity
  List<Map<String, dynamic>> toApiItems(String providerId) {
    return state.items
        .where((i) => i.providerId == providerId)
        .map((i) => {
              'productId': i.productId,
              'quantity': i.quantity,
            })
        .toList();
  }

  /// Total pour un provider donné
  int totalForProvider(String providerId) {
    return state.items
        .where((i) => i.providerId == providerId)
        .fold(0, (sum, item) => sum + (item.priceDa * item.quantity));
  }

  void clear() {
    state = const CartState();
  }
}

/// Provider global du panier
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

/// Provider pour le nombre d'items dans le panier (pour afficher dans la barre)
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});
