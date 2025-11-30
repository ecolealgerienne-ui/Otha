import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _green = Color(0xFF43AA8B);
const _greenSoft = Color(0xFFE8F5E9);

/// Ecran d'explication du système de confiance - affiché après la localisation
class TrustExplanationScreen extends ConsumerWidget {
  const TrustExplanationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Contenu scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Illustration
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: _coralSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: _coral,
                        size: 44,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Titre
                    const Text(
                      'Comment ca marche ?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Un systeme simple pour garantir\nune experience de qualite',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Etape 1
                    _buildStep(
                      number: '1',
                      icon: Icons.calendar_today,
                      title: 'Premier rendez-vous',
                      description: 'Reservez votre premier RDV (veto, garderie ou petshop)',
                      color: _coral,
                      bgColor: _coralSoft,
                    ),

                    const SizedBox(height: 12),

                    // Fleche
                    Icon(Icons.arrow_downward, color: Colors.grey[300], size: 24),

                    const SizedBox(height: 12),

                    // Etape 2
                    _buildStep(
                      number: '2',
                      icon: Icons.check_circle,
                      title: 'Honorez votre RDV',
                      description: 'Presentez-vous et finalisez votre reservation',
                      color: Colors.blue,
                      bgColor: Colors.blue.shade50,
                    ),

                    const SizedBox(height: 12),

                    // Fleche
                    Icon(Icons.arrow_downward, color: Colors.grey[300], size: 24),

                    const SizedBox(height: 12),

                    // Etape 3
                    _buildStep(
                      number: '3',
                      icon: Icons.verified,
                      title: 'Compte verifie !',
                      description: 'Reservez sans limite apres votre premier RDV reussi',
                      color: _green,
                      bgColor: _greenSoft,
                    ),

                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Cela nous aide a eviter les abus et garantir un service fiable pour tous.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bouton fixe en bas
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go('/pets/add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _coral,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continuer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  Widget _buildStep({
    required String number,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
