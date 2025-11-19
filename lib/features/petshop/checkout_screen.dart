// lib/features/petshop/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre panier est vide')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      final notifier = ref.read(cartProvider.notifier);

      // Create orders for each provider
      final itemsByProvider = cart.itemsByProvider;
      final orderIds = <String>[];

      for (final entry in itemsByProvider.entries) {
        final providerId = entry.key;
        final items = notifier.toApiItems(providerId);

        final result = await api.createPetshopOrder(
          providerId: providerId,
          items: items,
          deliveryAddress: _addressController.text.trim(),
          notes: _notesController.text.trim(),
        );

        final orderId = result['id']?.toString() ?? '';
        if (orderId.isNotEmpty) {
          orderIds.add(orderId);
        }
      }

      // Clear cart after successful order
      notifier.clear();

      if (mounted) {
        // Navigate to confirmation
        context.go('/petshop/order-confirmation', extra: {
          'orderIds': orderIds,
          'totalDa': cart.totalDa,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
      ),
      body: cart.isEmpty
          ? const Center(child: Text('Votre panier est vide'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Delivery address
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined),
                              SizedBox(width: 8),
                              Text(
                                'Adresse de livraison',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              hintText: 'Entrez votre adresse complete',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'L\'adresse est requise';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.note_outlined),
                              SizedBox(width: 8),
                              Text(
                                'Notes (optionnel)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              hintText: 'Instructions speciales...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order summary
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
                          ...cart.items.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text('${item.totalDa} DA'),
                                  ],
                                ),
                              )),
                          const Divider(height: 24),
                          _buildSummaryRow('Sous-total', '${cart.subtotalDa} DA'),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Frais de livraison',
                            '${cart.commissionDa} DA',
                          ),
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

                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Confirmer la commande',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
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
}
