import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

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
  void initState() {
    super.initState();
    // Refresh on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(petshopOrdersProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(petshopOrdersProvider);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Theme(
      data: _themed(context, isDark),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('Mes commandes'),
          backgroundColor: cardColor,
          foregroundColor: textPrimary,
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
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'En attente',
                      selected: _filterStatus == 'PENDING',
                      onTap: () => setState(() => _filterStatus = 'PENDING'),
                      color: Colors.orange,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confirmees',
                      selected: _filterStatus == 'CONFIRMED',
                      onTap: () => setState(() => _filterStatus = 'CONFIRMED'),
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Livrees',
                      selected: _filterStatus == 'DELIVERED',
                      onTap: () => setState(() => _filterStatus = 'DELIVERED'),
                      color: Colors.green,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Annulees',
                      selected: _filterStatus == 'CANCELLED',
                      onTap: () => setState(() => _filterStatus = 'CANCELLED'),
                      color: Colors.red,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // Orders list
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
                error: (e, _) => Center(
                  child: Text('Erreur: $e', style: TextStyle(color: textPrimary)),
                ),
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
                    return _EmptyState(filter: _filterStatus, isDark: isDark);
                  }

                  return RefreshIndicator(
                    color: _coral,
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
                        isDark: isDark,
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

  ThemeData _themed(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _coral,
        surface: isDark ? _darkCard : Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark ? _darkCard : Colors.white,
        foregroundColor: isDark ? Colors.white : _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : _ink,
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
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    required this.isDark,
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
          color: selected ? chipColor : (isDark ? _darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : (isDark ? _darkCardBorder : Colors.grey.shade300),
          ),
          boxShadow: selected
              ? [BoxShadow(color: chipColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey.shade700),
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
  final bool isDark;
  const _EmptyState({required this.filter, required this.isDark});

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
              color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _coral),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les nouvelles commandes apparaitront ici',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
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
  final bool isDark;

  const _OrderCard({
    required this.order,
    required this.isExpanded,
    required this.onToggle,
    required this.onStatusUpdate,
    required this.isDark,
  });

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (order['id'] ?? '').toString();
    final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final createdAt = order['createdAt'] ?? order['created_at'];
    final items = order['items'] as List? ?? [];
    final deliveryAddress = (order['deliveryAddress'] ?? '').toString();
    final deliveryMode = (order['deliveryMode'] ?? 'pickup').toString();
    final notes = (order['notes'] ?? '').toString();
    final phone = (order['phone'] ?? '').toString();

    // Montants depuis le backend (calculés correctement avec le %)
    final subtotalDa = _asInt(order['subtotalDa'] ?? 0);
    final commissionDa = _asInt(order['commissionDa'] ?? 0);
    final deliveryFeeDa = _asInt(order['deliveryFeeDa'] ?? 0);
    final totalDa = _asInt(order['totalDa'] ?? order['total'] ?? 0);

    // Calculer le % de commission pour l'affichage (approximatif)
    final commissionPercent = subtotalDa > 0 ? (commissionDa * 100 / subtotalDa).round() : 5;

    DateTime? date;
    if (createdAt != null) {
      try {
        date = DateTime.parse(createdAt.toString());
      } catch (_) {}
    }

    final user = order['user'] as Map? ?? {};
    // Show only firstName for clients
    final userName = (user['firstName'] ?? 'Client').toString();
    final userPhone = phone.isNotEmpty ? phone : (user['phone'] ?? '').toString();

    // TRUST SYSTEM: Détection nouveau client
    final isFirstBooking = user['isFirstBooking'] == true;

    final statusInfo = _getStatusInfo(status);

    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : Colors.transparent),
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
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
                          color: statusInfo.color.withOpacity(isDark ? 0.2 : 0.1),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              // TRUST SYSTEM: Badge "Nouveau client"
                              if (isFirstBooking) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orange.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.new_releases, size: 9, color: Colors.orange.shade700),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Nouveau',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _da(totalDa),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _coral,
                            ),
                          ),
                          if (commissionDa > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '$commissionPercent% = ${_da(commissionDa)}',
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
                              color: statusInfo.color.withOpacity(isDark ? 0.2 : 0.1),
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
                        color: isDark ? Colors.grey[500] : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy - HH:mm', 'fr_FR').format(date),
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        // Delivery mode badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (deliveryMode == 'delivery' ? Colors.blue.withOpacity(0.15) : Colors.purple.withOpacity(0.15))
                                : (deliveryMode == 'delivery' ? Colors.blue.shade50 : Colors.purple.shade50),
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
                                deliveryMode == 'delivery' ? 'Livraison' : 'Retrait',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: deliveryMode == 'delivery' ? Colors.blue : Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${items.length} article${items.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: textSecondary,
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
            Divider(height: 1, color: isDark ? _darkCardBorder : Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items
                  Text(
                    'Articles',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    // Check for nested product object first (backend structure)
                    final product = item['product'] as Map<String, dynamic>?;
                    final itemTitle = (product?['title'] ?? item['title'] ?? item['productTitle'] ?? 'Produit').toString();
                    final qty = _asInt(item['quantity'] ?? 1);
                    final price = _asInt(item['priceDa'] ?? item['price'] ?? 0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
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
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _da(price * qty),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Récapitulatif des montants
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? _darkCardBorder.withOpacity(0.5) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? _darkCardBorder : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        _PriceRow(label: 'Sous-total', value: _da(subtotalDa), isDark: isDark),
                        const SizedBox(height: 6),
                        _PriceRow(
                          label: 'Commission ($commissionPercent%)',
                          value: _da(commissionDa),
                          isDark: isDark,
                          valueColor: Colors.green.shade700,
                        ),
                        if (deliveryFeeDa > 0) ...[
                          const SizedBox(height: 6),
                          _PriceRow(
                            label: 'Frais de livraison',
                            value: _da(deliveryFeeDa),
                            isDark: isDark,
                          ),
                        ],
                        Divider(height: 16, color: isDark ? _darkCardBorder : Colors.grey.shade300),
                        _PriceRow(
                          label: 'Total',
                          value: _da(totalDa),
                          isDark: isDark,
                          isBold: true,
                          valueColor: _coral,
                        ),
                      ],
                    ),
                  ),

                  // Mode de livraison/retrait
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: deliveryMode == 'delivery'
                          ? (isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50)
                          : (isDark ? Colors.purple.withOpacity(0.1) : Colors.purple.shade50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: deliveryMode == 'delivery' ? Colors.blue.shade200 : Colors.purple.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          deliveryMode == 'delivery' ? Icons.local_shipping_rounded : Icons.store_rounded,
                          color: deliveryMode == 'delivery' ? Colors.blue : Colors.purple,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deliveryMode == 'delivery' ? 'Livraison à domicile' : 'Retrait en boutique',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: deliveryMode == 'delivery' ? Colors.blue.shade700 : Colors.purple.shade700,
                                ),
                              ),
                              if (deliveryMode == 'delivery' && deliveryAddress.isNotEmpty)
                                Text(
                                  deliveryAddress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (userPhone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          userPhone,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ],

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Note du client',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? _darkCardBorder : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notes,
                        style: TextStyle(
                          color: textSecondary,
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
                              status == 'PENDING'
                                  ? Icons.check
                                  : (deliveryMode == 'delivery' ? Icons.local_shipping : Icons.shopping_bag),
                              size: 18,
                            ),
                            label: Text(
                              status == 'PENDING'
                                  ? 'Confirmer la commande'
                                  : (deliveryMode == 'delivery' ? 'Marquer livrée' : 'Prêt - Récupéré'),
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

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool isBold;
  final Color? valueColor;

  const _PriceRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : _ink;
    final secondaryColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? textColor : secondaryColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? (isBold ? textColor : secondaryColor),
          ),
        ),
      ],
    );
  }
}
