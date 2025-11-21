import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

/// Provider pour vérifier s'il y a des adoptions pendantes
final pendingAdoptionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  try {
    return await api.myPendingPetCreation();
  } catch (e) {
    // Si erreur (pas connecté, etc.), retourner liste vide
    return [];
  }
});

/// Fonction pour afficher le popup d'adoption pendante
Future<void> checkAndShowAdoptionDialog(BuildContext context, WidgetRef ref) async {
  // Vérifier s'il y a des adoptions pendantes
  final adoptionsAsync = ref.read(pendingAdoptionsProvider);

  adoptionsAsync.when(
    data: (adoptions) async {
      if (adoptions.isEmpty) return;

      // Afficher le popup pour la première adoption
      final adoption = adoptions.first;

      if (!context.mounted) return;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _AdoptionCongratulationsDialog(adoption: adoption),
      );

      if (result == true && context.mounted) {
        // Marquer comme vu et ouvrir pet_onboarding
        final api = ref.read(apiProvider);
        final postId = adoption['id']?.toString();

        if (postId != null) {
          try {
            await api.markAdoptPetProfileCreated(postId);
          } catch (e) {
            // Ignorer l'erreur, on laisse l'utilisateur créer le profil
          }
        }

        // Ouvrir pet_onboarding avec les données de l'adoption
        if (context.mounted) {
          await context.push('/pets/add', extra: adoption);
          // Après la création du pet, invalider le provider pour ne plus afficher le popup
          ref.invalidate(pendingAdoptionsProvider);
        }
      }
    },
    loading: () {},
    error: (_, __) {},
  );
}

class _AdoptionCongratulationsDialog extends StatelessWidget {
  final Map<String, dynamic> adoption;

  const _AdoptionCongratulationsDialog({required this.adoption});

  @override
  Widget build(BuildContext context) {
    final animalName = adoption['animalName']?.toString() ?? 'cet animal';
    final images = (adoption['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    final imageUrl = images.isNotEmpty ? images.first : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône félicitations
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                size: 48,
                color: Color(0xFFFF8A8A),
              ),
            ),
            const SizedBox(height: 16),

            // Titre
            const Text(
              '🎉 Félicitations !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              'Vous avez changé une vie en adoptant $animalName !',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Image de l'animal
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.pets, size: 64, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Créez le profil de $animalName pour suivre sa santé, ses vaccins et son bien-être dans l\'application.',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFFF8A8A)),
                      foregroundColor: const Color(0xFFFF8A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Plus tard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A8A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.pets),
                    label: const Text('Créer le profil'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
