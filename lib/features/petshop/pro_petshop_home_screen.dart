import 'dart:math';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';
import 'cart_provider.dart' show kPetshopCommissionDa;

/// ========================= THEME PETSHOP (vert) =========================
class _PetshopColors {
  static const ink = Color(0xFF1F2328);
  static const primary = Color(0xFF2E7D32); // Vert
  static const primarySoft = Color(0xFFE8F5E9);
  static const coral = Color(0xFFF36C6C);
}

ThemeData _petshopTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _PetshopColors.primary,
      secondary: _PetshopColors.primary,
      onPrimary: Colors.white,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: _PetshopColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(_PetshopColors.primary),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: WidgetStatePropertyAll(_PetshopColors.primary.withOpacity(.12)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _PetshopColors.primary),
    dividerColor: _PetshopColors.primarySoft,
  );
}

/// ========================= PROVIDERS =========================

final myPetshopProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) => ref.read(apiProvider).myProvider(),
);

final myProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.read(apiProvider).myProducts();
  } catch (_) {
    return [];
  }
});

final myPetshopOrdersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.read(apiProvider).myPetshopOrders();
  } catch (_) {
    return [];
  }
});

final pendingOrdersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.read(apiProvider).myPetshopOrders(status: 'PENDING');
  } catch (_) {
    return [];
  }
});

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _canonYm(String s) {
  final t = s.replaceAll('/', '-').trim();
  final m = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(t);
  if (m == null) return t;
  final y = m.group(1)!;
  final mo = int.parse(m.group(2)!);
  return '$y-${mo.toString().padLeft(2, '0')}';
}

/// Ledger pour le petshop
class _PetshopLedger {
  final String ym;
  final int ordersCount;
  final int totalRevenue;
  final int commissionDue;
  final int commissionPaid;
  final int netDue;

  const _PetshopLedger({
    required this.ym,
    required this.ordersCount,
    required this.totalRevenue,
    required this.commissionDue,
    required this.commissionPaid,
    required this.netDue,
  });
}

final petshopLedgerProvider = FutureProvider.autoDispose<_PetshopLedger>((ref) async {
  final orders = await ref.watch(myPetshopOrdersProvider.future);

  final nowUtc = DateTime.now().toUtc();
  final ymNow = '${nowUtc.year}-${nowUtc.month.toString().padLeft(2, '0')}';

  int ordersThisMonth = 0;
  int revenueThisMonth = 0;
  int itemsThisMonth = 0;

  for (final order in orders) {
    final status = (order['status'] ?? '').toString().toUpperCase();
    if (status != 'DELIVERED' && status != 'COMPLETED') continue;

    final createdAt = order['createdAt'] ?? order['created_at'];
    if (createdAt == null) continue;

    final date = DateTime.tryParse(createdAt.toString());
    if (date == null) continue;

    final orderYm = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    if (orderYm == ymNow) {
      ordersThisMonth++;
      revenueThisMonth += _asInt(order['totalDa'] ?? order['total'] ?? 0);

      // Count items for commission calculation
      final items = order['items'] as List? ?? [];
      for (final item in items) {
        itemsThisMonth += _asInt(item['quantity'] ?? 1);
      }
    }
  }

  // Commission is per item, not per order
  final commissionDue = itemsThisMonth * kPetshopCommissionDa;

  return _PetshopLedger(
    ym: ymNow,
    ordersCount: ordersThisMonth,
    totalRevenue: revenueThisMonth,
    commissionDue: commissionDue,
    commissionPaid: 0, // TODO: Connect to backend payment tracking
    netDue: commissionDue,
  );
});

/// ========================= MAIN SCREEN =========================

class PetshopHomeScreen extends ConsumerStatefulWidget {
  const PetshopHomeScreen({super.key});

  @override
  ConsumerState<PetshopHomeScreen> createState() => _PetshopHomeScreenState();
}

class _PetshopHomeScreenState extends ConsumerState<PetshopHomeScreen> {
  @override
  Widget build(BuildContext context) {
    const bgSoft = Color(0xFFF7F8FA);

    final state = ref.watch(sessionProvider);
    final user = state.user ?? {};
    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    final fallbackUserName =
        [if (first.isNotEmpty) first, if (last.isNotEmpty) last].join(' ').trim();

    final provAsync = ref.watch(myPetshopProfileProvider);
    final shopName = provAsync.maybeWhen(
      data: (p) {
        final dn = (p?['displayName'] ?? '').toString().trim();
        if (dn.isNotEmpty) return dn;
        return fallbackUserName.isNotEmpty ? fallbackUserName : 'Ma Boutique';
      },
      orElse: () => (fallbackUserName.isNotEmpty ? fallbackUserName : 'Ma Boutique'),
    );

    final pendingAsync = ref.watch(pendingOrdersProvider);
    final ledgerAsync = ref.watch(petshopLedgerProvider);
    final productsAsync = ref.watch(myProductsProvider);
    final ordersAsync = ref.watch(myPetshopOrdersProvider);

    return Theme(
      data: _petshopTheme(context),
      child: Scaffold(
        backgroundColor: bgSoft,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myPetshopProfileProvider);
              ref.invalidate(myProductsProvider);
              ref.invalidate(myPetshopOrdersProvider);
              ref.invalidate(pendingOrdersProvider);
              ref.invalidate(petshopLedgerProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _Header(
                    shopName: shopName,
                    onAvatarTap: () => context.push('/petshop/settings'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // Commandes en attente (si > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: pendingAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (pending) {
                        if (pending.isEmpty) return const SizedBox.shrink();
                        return _PendingOrdersBanner(
                          orders: pending,
                          onTap: () => context.push('/petshop/orders'),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Actions rapides (4 max)
                const SliverToBoxAdapter(child: _ActionGrid()),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Commission du mois
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ledgerAsync.when(
                      loading: () => const _CommissionCard.loading(),
                      error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                      data: (ledger) => _CommissionCard(ledger: ledger),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Statistiques rapides
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _QuickStats(
                      productsAsync: productsAsync,
                      ordersAsync: ordersAsync,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Dernières commandes
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ordersAsync.when(
                      loading: () => const _LoadingCard(text: 'Chargement des commandes...'),
                      error: (e, _) => _SectionCard(child: Text('Erreur: $e')),
                      data: (orders) => _RecentOrders(orders: orders),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _PetshopColors.primary,
          onPressed: () => context.push('/petshop/products/new'),
          icon: const Icon(Icons.add),
          label: const Text('Nouveau produit'),
        ),
      ),
    );
  }
}

/// ========================= WIDGETS =========================

class _Header extends StatelessWidget {
  final String shopName;
  final VoidCallback? onAvatarTap;
  const _Header({required this.shopName, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_PetshopColors.primary, Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Text(
                shopName.isNotEmpty ? shopName.characters.first.toUpperCase() : 'B',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _PetshopColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bienvenue', style: TextStyle(color: Colors.white70)),
                Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.storefront, color: Colors.white, size: 26),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String text;
  const _LoadingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _PendingOrdersBanner extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final VoidCallback onTap;
  const _PendingOrdersBanner({required this.orders, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = orders.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pending_actions, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count commande${count > 1 ? 's' : ''} en attente',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text('Appuyez pour traiter', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Voir'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _Action('Produits', Icons.inventory_2, '/petshop/products', const Color(0xFF3A86FF)),
      _Action('Commandes', Icons.receipt_long, '/petshop/orders', const Color(0xFFFF6D00)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.15,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _ActionCard(item: items[i]),
      ),
    );
  }
}

class _Action {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  const _Action(this.title, this.icon, this.route, this.color);
}

class _ActionCard extends StatefulWidget {
  final _Action item;
  const _ActionCard({required this.item});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward(from: Random().nextDouble() * .6);

  late final Animation<double> _scale = Tween(begin: .98, end: 1.0).animate(
    CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return ScaleTransition(
      scale: _scale,
      child: InkWell(
        onTap: () => context.push(it.route),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: it.color.withOpacity(.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: it.color.withOpacity(.16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: it.color.withOpacity(.15),
                  child: Icon(it.icon, color: it.color),
                ),
                const Spacer(),
                Text(
                  it.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final _PetshopLedger? ledger;
  const _CommissionCard({required this.ledger});
  const _CommissionCard.loading() : ledger = null;

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    if (ledger == null) {
      return const _SectionCard(
        child: SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final l = ledger!;
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR')
        .format(now)
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined, color: Color(0xFFFB8C00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commission du mois',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black.withOpacity(.65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Montant à payer
          Text(
            _da(l.netDue),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.ordersCount} commande${l.ordersCount > 1 ? 's' : ''} livrée${l.ordersCount > 1 ? 's' : ''}',
            style: TextStyle(color: Colors.black.withOpacity(.6)),
          ),
          const SizedBox(height: 12),

          // Stats
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniPill(Icons.monetization_on, 'Revenus', _da(l.totalRevenue)),
              _miniPill(Icons.receipt, 'Commission', _da(l.commissionDue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _PetshopColors.primarySoft),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _PetshopColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.black.withOpacity(.70)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> productsAsync;
  final AsyncValue<List<Map<String, dynamic>>> ordersAsync;
  const _QuickStats({required this.productsAsync, required this.ordersAsync});

  @override
  Widget build(BuildContext context) {
    final products = productsAsync.value ?? [];
    final orders = ordersAsync.value ?? [];

    final activeProducts = products.where((p) => p['active'] != false).length;
    final lowStock = products.where((p) {
      final stock = _asInt(p['stock'] ?? 0);
      return stock > 0 && stock <= 5;
    }).length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apercu rapide',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.inventory_2,
                  label: 'Produits actifs',
                  value: '$activeProducts',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.warning_amber,
                  label: 'Stock faible',
                  value: '$lowStock',
                  color: lowStock > 0 ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.shopping_bag,
                  label: 'Total commandes',
                  value: '${orders.length}',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.check_circle,
                  label: 'Livrees',
                  value: '${orders.where((o) {
                    final s = (o['status'] ?? '').toString().toUpperCase();
                    return s == 'DELIVERED' || s == 'COMPLETED';
                  }).length}',
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _RecentOrders({required this.orders});

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _SectionCard(
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Aucune commande'),
            const SizedBox(height: 8),
            Text(
              'Les commandes de vos clients apparaitront ici',
              style: TextStyle(color: Colors.black.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort by date and take last 5
    final sorted = List<Map<String, dynamic>>.from(orders)
      ..sort((a, b) {
        final aDate = DateTime.tryParse((a['createdAt'] ?? a['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse((b['createdAt'] ?? b['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final recent = sorted.take(5).toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Commandes recentes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/petshop/orders'),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recent.map((order) {
            final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
            final baseTotal = _asInt(order['totalDa'] ?? order['total'] ?? 0);
            final createdAt = order['createdAt'] ?? order['created_at'];
            final user = order['user'] as Map<String, dynamic>?;
            // Show only firstName for clients
            final userName = (user?['firstName'] ?? 'Client').toString();

            // Calculate commission based on items
            final items = order['items'] as List? ?? [];
            int totalItemQty = 0;
            for (final item in items) {
              totalItemQty += _asInt(item['quantity'] ?? 1);
            }
            final commissionDa = totalItemQty * kPetshopCommissionDa;

            DateTime? date;
            if (createdAt != null) {
              date = DateTime.tryParse(createdAt.toString());
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildStatusIcon(status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (date != null)
                          Text(
                            DateFormat('dd/MM HH:mm').format(date.toLocal()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _da(baseTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (commissionDa > 0)
                        Text(
                          '+${_da(commissionDa)} com.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      _buildStatusChip(status),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'PENDING':
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case 'CONFIRMED':
        icon = Icons.thumb_up;
        color = Colors.blue;
        break;
      case 'PREPARING':
        icon = Icons.kitchen;
        color = Colors.purple;
        break;
      case 'READY':
        icon = Icons.inventory;
        color = Colors.teal;
        break;
      case 'DELIVERED':
      case 'COMPLETED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'CANCELLED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusChip(String status) {
    String label;
    Color color;

    switch (status) {
      case 'PENDING':
        label = 'En attente';
        color = Colors.orange;
        break;
      case 'CONFIRMED':
        label = 'Confirmee';
        color = Colors.blue;
        break;
      case 'PREPARING':
        label = 'Preparation';
        color = Colors.purple;
        break;
      case 'READY':
        label = 'Prete';
        color = Colors.teal;
        break;
      case 'DELIVERED':
      case 'COMPLETED':
        label = 'Livree';
        color = Colors.green;
        break;
      case 'CANCELLED':
        label = 'Annulee';
        color = Colors.red;
        break;
      default:
        label = status;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
