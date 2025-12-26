// lib/features/petshop/user_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class UserOrdersScreen extends ConsumerStatefulWidget {
  const UserOrdersScreen({super.key});

  @override
  ConsumerState<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends ConsumerState<UserOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final orders = await api.myClientOrders();
      // Sort by date descending
      orders.sort((a, b) {
        final aDate = DateTime.tryParse((a['createdAt'] ?? a['created_at'] ?? '').toString()) ?? DateTime(2000);
        final bDate = DateTime.tryParse((b['createdAt'] ?? b['created_at'] ?? '').toString()) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
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
              onPressed: _loadOrders,
            ),
          ],
        ),
        body: _buildBody(isDark, cardColor, textPrimary, textSecondary),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color cardColor, Color textPrimary, Color? textSecondary) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _coral));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            _buildGradientButton(
              onTap: _loadOrders,
              icon: Icons.refresh,
              label: 'Reessayer',
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 64, color: _coral),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune commande',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vos commandes apparaitront ici',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildGradientButton(
              onTap: () => context.go('/explore/petshop'),
              icon: Icons.storefront,
              label: 'Voir les boutiques',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _coral,
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _buildOrderCard(order, isDark, cardColor, textPrimary, textSecondary);
        },
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_coral, Color(0xFFFF8A8A)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _coral.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color? textSecondary,
  ) {
    final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final createdAt = order['createdAt'] ?? order['created_at'];
    final items = (order['items'] ?? []) as List;
    final provider = order['provider'] as Map<String, dynamic>?;
    final providerName = provider?['displayName'] ?? 'Boutique';
    final deliveryMode = (order['deliveryMode'] ?? 'pickup').toString();
    final deliveryAddress = (order['deliveryAddress'] ?? '').toString();

    // Montants depuis le backend
    final subtotalDa = _asInt(order['subtotalDa'] ?? 0);
    final commissionDa = _asInt(order['commissionDa'] ?? 0);
    final deliveryFeeDa = _asInt(order['deliveryFeeDa'] ?? 0);
    final totalDa = _asInt(order['totalDa'] ?? order['total_da'] ?? 0);

    DateTime? date;
    if (createdAt != null) {
      date = DateTime.tryParse(createdAt.toString());
    }

    final statusInfo = _getStatusInfo(status, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : Colors.transparent),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        iconColor: textSecondary,
        collapsedIconColor: textSecondary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront, color: _coral, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    providerName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (date != null)
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusInfo.color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusInfo.icon, size: 12, color: statusInfo.color),
                    const SizedBox(width: 4),
                    Text(
                      statusInfo.label,
                      style: TextStyle(
                        color: statusInfo.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
              const Spacer(),
              Text(
                _da(totalDa),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _coral,
                ),
              ),
            ],
          ),
        ),
        children: [
          // Articles
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? _darkCardBorder.withOpacity(0.5) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Articles (${items.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final product = item['product'] as Map<String, dynamic>?;
                  final itemTitle = (product?['title'] ?? item['title'] ?? 'Produit').toString();
                  final qty = _asInt(item['quantity'] ?? 1);
                  final price = _asInt(item['priceDa'] ?? item['price'] ?? 0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${qty}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: _coral,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            itemTitle,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _da(price * qty),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Récapitulatif des montants
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? _darkCardBorder.withOpacity(0.5) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildPriceRow('Sous-total', _da(subtotalDa), isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary),
                if (commissionDa > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow('Frais de service', _da(commissionDa), isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary),
                ],
                if (deliveryFeeDa > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow('Frais de livraison', _da(deliveryFeeDa), isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary),
                ],
                Divider(height: 16, color: isDark ? _darkCardBorder : Colors.grey.shade300),
                _buildPriceRow('Total', _da(totalDa), isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, isBold: true, valueColor: _coral),
              ],
            ),
          ),

          // Adresse de livraison
          if (deliveryMode == 'delivery' && deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: Colors.blue.shade400, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adresse de livraison',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deliveryAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    required bool isDark,
    required Color textPrimary,
    Color? textSecondary,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? textPrimary : textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? (isBold ? textPrimary : textSecondary),
          ),
        ),
      ],
    );
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  _StatusInfo _getStatusInfo(String status, bool isDark) {
    switch (status) {
      case 'PENDING':
        return _StatusInfo('En attente', Colors.orange, Icons.hourglass_empty);
      case 'CONFIRMED':
        return _StatusInfo('Confirmee', Colors.blue, Icons.thumb_up);
      case 'PREPARING':
        return _StatusInfo('En preparation', Colors.purple, Icons.inventory_2);
      case 'READY':
        return _StatusInfo('Prete', Colors.teal, Icons.check_circle_outline);
      case 'SHIPPED':
        return _StatusInfo('Expediee', Colors.indigo, Icons.local_shipping);
      case 'DELIVERED':
      case 'COMPLETED':
        return _StatusInfo('Livree', Colors.green, Icons.check_circle);
      case 'CANCELLED':
        return _StatusInfo('Annulee', Colors.red, Icons.cancel);
      default:
        return _StatusInfo(status, Colors.grey, Icons.help_outline);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Aujourd\'hui ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return DateFormat('dd MMM yyyy - HH:mm', 'fr_FR').format(date);
    }
  }

  ThemeData _themed(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _coral,
        surface: isDark ? _darkCard : Colors.white,
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _coral),
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusInfo(this.label, this.color, this.icon);
}
