// lib/features/petshop/user_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes commandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
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
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune commande',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vos commandes apparaitront ici',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
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

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final createdAt = order['createdAt'] ?? order['created_at'];
    final totalDa = order['totalDa'] ?? order['total_da'] ?? 0;
    final items = (order['items'] ?? []) as List;
    final provider = order['provider'] as Map<String, dynamic>?;
    final providerName = provider?['displayName'] ?? 'Boutique';

    DateTime? date;
    if (createdAt != null) {
      date = DateTime.tryParse(createdAt.toString());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to order details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      providerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 8),

              // Date
              if (date != null)
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),

              // Items preview
              Text(
                '${items.length} article(s)',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total'),
                  Text(
                    '$totalDa DA',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'PENDING':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        label = 'En attente';
        break;
      case 'CONFIRMED':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        label = 'Confirmee';
        break;
      case 'PREPARING':
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        label = 'En preparation';
        break;
      case 'READY':
        backgroundColor = Colors.teal[100]!;
        textColor = Colors.teal[800]!;
        label = 'Prete';
        break;
      case 'DELIVERED':
      case 'COMPLETED':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        label = 'Livree';
        break;
      case 'CANCELLED':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        label = 'Annulee';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Aujourd\'hui ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
