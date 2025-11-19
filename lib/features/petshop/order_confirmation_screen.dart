// lib/features/petshop/order_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final List<String> orderIds;
  final int totalDa;

  const OrderConfirmationScreen({
    super.key,
    this.orderIds = const [],
    this.totalDa = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 60,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Commande confirmee !',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Votre commande a ete envoyee avec succes.\nVous recevrez une notification lorsqu\'elle sera prete.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Order info
              if (totalDa > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total paye',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '$totalDa DA',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 48),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/petshop/my-orders'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Voir mes commandes'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Retour a l\'accueil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
