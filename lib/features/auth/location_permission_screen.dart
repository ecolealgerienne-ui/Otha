import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

/// Écran de permission de géolocalisation affiché après l'inscription
/// Explique les avantages et permet d'activer ou passer
class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen> {
  bool _loading = false;

  Future<void> _requestLocationPermission() async {
    setState(() => _loading = true);

    try {
      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Ouvrir les paramètres de localisation
        await Geolocator.openLocationSettings();
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // Demander la permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        // Permission refusée définitivement
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission refusée. Vous pouvez l\'activer dans les paramètres.'),
            backgroundColor: _coral,
          ),
        );
      } else if (permission == LocationPermission.denied) {
        // Permission refusée
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission de localisation refusée'),
            backgroundColor: _coral,
          ),
        );
      } else {
        // Permission accordée - afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localisation activée !'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Dans tous les cas, aller à l'ajout d'animal
      _goToNextScreen();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _coral,
        ),
      );
    }
  }

  void _skip() {
    _goToNextScreen();
  }

  void _goToNextScreen() {
    if (!mounted) return;
    // Aller vers l'ajout d'animal
    context.go('/pets/add');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Illustration
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: _coralSoft,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Cercles concentriques pour effet "radar"
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _coral.withOpacity(0.2), width: 2),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _coral.withOpacity(0.3), width: 2),
                      ),
                    ),
                    // Icône centrale
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: _coral,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Titre
              const Text(
                'Meilleure expérience',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2D2D),
                ),
              ),

              const SizedBox(height: 12),

              // Sous-titre
              Text(
                'Activez la localisation pour profiter\npleinement de l\'application',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Avantages
              _buildAdvantageItem(
                icon: Icons.calendar_today,
                title: 'Confirmer vos visites',
                description: 'Validation automatique chez le vétérinaire et en garderie',
              ),
              const SizedBox(height: 16),
              _buildAdvantageItem(
                icon: Icons.explore,
                title: 'Services à proximité',
                description: 'Vétérinaires, garderies et petshops proches de vous',
              ),
              const SizedBox(height: 16),
              _buildAdvantageItem(
                icon: Icons.pets,
                title: 'Dépôt et récupération',
                description: 'Confirmation facilitée pour les garderies',
              ),

              const Spacer(),

              // Bouton principal
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _requestLocationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: _coral.withOpacity(0.4),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.location_on),
                  label: Text(
                    _loading ? 'Activation...' : 'Activer la localisation',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bouton secondaire
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: _loading ? null : _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Passer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Note de confidentialité
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Votre position n\'est jamais partagée sans votre accord',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
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
    );
  }

  Widget _buildAdvantageItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _coralSoft.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _coral.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: _coral, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
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
