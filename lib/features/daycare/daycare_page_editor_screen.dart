import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/session_controller.dart';

class DaycarePageEditorScreen extends ConsumerStatefulWidget {
  const DaycarePageEditorScreen({super.key});

  @override
  ConsumerState<DaycarePageEditorScreen> createState() => _DaycarePageEditorScreenState();
}

class _DaycarePageEditorScreenState extends ConsumerState<DaycarePageEditorScreen> {
  // Palette cyan (daycare) - Light mode
  static const Color _primary = Color(0xFF00ACC1);
  static const Color _primarySoft = Color(0xFFE0F7FA);
  static const Color _ink = Color(0xFF222222);
  static const Color _muted = Color(0xFF6B6B6B);

  // Dark mode colors
  static const Color _bgDark = Color(0xFF121212);
  static const Color _cardDark = Color(0xFF1E1E1E);
  static const Color _inkDark = Color(0xFFFFFFFF);
  static const Color _mutedDark = Color(0xFF9E9E9E);

  // Images (liste dynamique)
  final List<String> _imageUrls = [];
  int _selectedImageIndex = 0;
  final ImagePicker _picker = ImagePicker();

  // Provider ID for preview
  String? _providerId;

  // Capacité
  final _capacity = TextEditingController();

  // Types d'animaux personnalisables
  final List<String> _animalTypes = [];
  final _newAnimalTypeController = TextEditingController();

  // Types pré-remplis suggérés
  static const _suggestedTypes = [
    'Petits chiens',
    'Chiens moyens',
    'Grands chiens',
    'Chats',
    'Lapins',
    'Oiseaux',
    'Rongeurs',
  ];

  // Bio de l'annonce
  final _bio = TextEditingController();
  static const int _bioMax = 500;

  // Tarifs
  final _hourlyRate = TextEditingController();
  final _dailyRate = TextEditingController();

  // Horaires de disponibilité
  bool _is24_7 = true;
  String _openingTime = '08:00';
  String _closingTime = '20:00';

  // Jours de disponibilité (Lun=0, Dim=6)
  final List<bool> _availableDays = List.filled(7, true); // Par défaut tous les jours

  String? _errCapacity;
  String? _errHourlyRate;
  String? _errDailyRate;
  String? _errBio;

  bool _loading = false;
  bool _uploadingImage = false;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _capacity.dispose();
    _hourlyRate.dispose();
    _dailyRate.dispose();
    _bio.dispose();
    _newAnimalTypeController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _unwrap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map && raw.containsKey('data')) {
      final d = raw['data'];
      if (d == null || (d is Map && d.isEmpty)) return null;
      return (d is Map) ? Map<String, dynamic>.from(d) : null;
    }
    if (raw is Map && raw.isEmpty) return null;
    return (raw is Map) ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> _loadData() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      final raw = await api.myProvider();
      final p = _unwrap(raw) ?? {};

      // Store provider ID for preview
      _providerId = (p['id'] ?? '').toString();

      final specs = (p['specialties'] is Map)
          ? Map<String, dynamic>.from(p['specialties'])
          : <String, dynamic>{};

      // Charger les images
      final images = specs['images'];
      if (images is List) {
        _imageUrls.clear();
        _imageUrls.addAll(images.map((e) => e.toString()));
      }

      // Charger la capacité
      _capacity.text = (specs['capacity'] ?? '').toString();

      // Charger les types d'animaux
      final animalTypes = specs['animalTypes'];
      if (animalTypes is List) {
        _animalTypes.clear();
        _animalTypes.addAll(animalTypes.map((e) => e.toString()));
      }

      // Charger la bio
      _bio.text = (specs['bio'] ?? '').toString();

      // Charger les tarifs
      final pricing = specs['pricing'];
      if (pricing is Map) {
        _hourlyRate.text = (pricing['hourlyRate'] ?? '').toString();
        _dailyRate.text = (pricing['dailyRate'] ?? '').toString();
      }

      // Charger les horaires
      final availability = specs['availability'];
      if (availability is Map) {
        _is24_7 = availability['is24_7'] == true;
        _openingTime = (availability['openingTime'] ?? '08:00').toString();
        _closingTime = (availability['closingTime'] ?? '20:00').toString();

        // Charger les jours disponibles
        final availableDays = availability['availableDays'];
        if (availableDays is List && availableDays.length == 7) {
          for (int i = 0; i < 7; i++) {
            _availableDays[i] = availableDays[i] == true;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _pickAndUploadImage() async {
    if (_imageUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos')),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _uploadingImage = true);

      // Upload via api.uploadLocalFile comme dans settings_screen.dart
      final api = ref.read(apiProvider);
      final file = File(image.path);
      final url = await api.uploadLocalFile(file, folder: 'daycare');

      if (mounted) {
        setState(() {
          _imageUrls.add(url);
          _uploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo ajoutée')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  void _addAnimalType(String type) {
    if (type.trim().isEmpty) return;
    if (_animalTypes.contains(type.trim())) return;

    setState(() {
      _animalTypes.add(type.trim());
    });
  }

  void _removeAnimalType(String type) {
    setState(() {
      _animalTypes.remove(type);
    });
  }

  bool _validate() {
    final cap = _capacity.text.trim();
    final hourly = _hourlyRate.text.trim();
    final daily = _dailyRate.text.trim();
    final bio = _bio.text.trim();

    _errCapacity = null;
    _errHourlyRate = null;
    _errDailyRate = null;
    _errBio = null;

    if (cap.isNotEmpty) {
      final n = int.tryParse(cap);
      if (n == null || n <= 0) {
        _errCapacity = 'Capacite invalide';
      }
    }

    if (hourly.isNotEmpty) {
      final n = int.tryParse(hourly);
      if (n == null || n < 0) {
        _errHourlyRate = 'Tarif invalide';
      }
    }

    if (daily.isNotEmpty) {
      final n = int.tryParse(daily);
      if (n == null || n < 0) {
        _errDailyRate = 'Tarif invalide';
      }
    }

    if (bio.length > _bioMax) {
      _errBio = 'Max $_bioMax caracteres';
    }

    setState(() {});
    return _errCapacity == null && _errHourlyRate == null && _errDailyRate == null && _errBio == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      // Construire les tarifs
      final pricing = <String, dynamic>{};
      if (_hourlyRate.text.trim().isNotEmpty) {
        pricing['hourlyRate'] = int.parse(_hourlyRate.text.trim());
      }
      if (_dailyRate.text.trim().isNotEmpty) {
        pricing['dailyRate'] = int.parse(_dailyRate.text.trim());
      }

      // Récupérer les specs actuelles pour ne pas écraser les autres champs
      final raw = await api.myProvider();
      final p = _unwrap(raw) ?? {};
      final existingSpecs = (p['specialties'] is Map)
          ? Map<String, dynamic>.from(p['specialties'])
          : <String, dynamic>{};

      // Construire les horaires
      final availability = <String, dynamic>{
        'is24_7': _is24_7,
        'openingTime': _openingTime,
        'closingTime': _closingTime,
        'availableDays': _availableDays,
      };

      // Fusionner avec les nouvelles données
      final specs = Map<String, dynamic>.from(existingSpecs);
      specs['images'] = _imageUrls;
      if (_capacity.text.trim().isNotEmpty) {
        specs['capacity'] = int.parse(_capacity.text.trim());
      }
      specs['animalTypes'] = _animalTypes;
      specs['bio'] = _bio.text.trim();
      if (pricing.isNotEmpty) specs['pricing'] = pricing;
      specs['availability'] = availability;

      // Get user info for displayName
      final user = ref.read(sessionProvider).user ?? {};
      final firstName = (user['firstName'] ?? '').toString().trim();
      final lastName = (user['lastName'] ?? '').toString().trim();
      final email = (user['email'] ?? '').toString();
      final fullName = '$firstName $lastName'.trim();
      final displayName = fullName.isEmpty ? email.split('@').first : fullName;

      // Sauvegarder
      await api.upsertMyProvider(
        displayName: displayName,
        specialties: specs,
      );

      // Créer/mettre à jour les services pour permettre les réservations
      await _createOrUpdateDaycareServices(api, pricing);

      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Page mise a jour')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Crée ou met à jour les services de garderie pour permettre les réservations
  Future<void> _createOrUpdateDaycareServices(dynamic api, Map<String, dynamic> pricing) async {
    try {
      debugPrint('🔧 Création/mise à jour des services garderie...');

      // Récupérer les services existants
      final existingServices = await api.listMyServices();
      debugPrint('📋 Services existants: ${existingServices.length}');

      int servicesCreated = 0;
      int servicesUpdated = 0;

      // Service horaire
      if (pricing.containsKey('hourlyRate')) {
        final hourlyRate = pricing['hourlyRate'] as int;
        debugPrint('💰 Tarif horaire: $hourlyRate DA');

        final existingHourly = existingServices.firstWhere(
          (s) => (s['title'] ?? '').toString().toLowerCase().contains('garde horaire'),
          orElse: () => <String, dynamic>{},
        );

        if (existingHourly.isEmpty) {
          // Créer nouveau service horaire
          debugPrint('➕ Création service "Garde horaire"...');
          await api.createService(
            title: 'Garde horaire',
            durationMin: 60, // 1 heure par défaut
            price: hourlyRate,
            description: 'Garde d\'animaux à l\'heure',
          );
          servicesCreated++;
          debugPrint('✅ Service horaire créé');
        } else {
          // Mettre à jour le prix si différent
          final serviceId = existingHourly['id'] as String;
          debugPrint('🔄 Mise à jour service horaire ID: $serviceId');
          await api.updateService(
            serviceId: serviceId,
            title: 'Garde horaire',
            durationMin: 60,
            price: hourlyRate,
            description: 'Garde d\'animaux à l\'heure',
          );
          servicesUpdated++;
          debugPrint('✅ Service horaire mis à jour');
        }
      }

      // Service journalier
      if (pricing.containsKey('dailyRate')) {
        final dailyRate = pricing['dailyRate'] as int;
        debugPrint('💰 Tarif journalier: $dailyRate DA');

        final existingDaily = existingServices.firstWhere(
          (s) => (s['title'] ?? '').toString().toLowerCase().contains('garde journalière'),
          orElse: () => <String, dynamic>{},
        );

        if (existingDaily.isEmpty) {
          // Créer nouveau service journalier
          debugPrint('➕ Création service "Garde journalière"...');
          await api.createService(
            title: 'Garde journalière',
            durationMin: 1440, // 24 heures = 1440 minutes
            price: dailyRate,
            description: 'Garde d\'animaux à la journée',
          );
          servicesCreated++;
          debugPrint('✅ Service journalier créé');
        } else {
          // Mettre à jour le prix si différent
          final serviceId = existingDaily['id'] as String;
          debugPrint('🔄 Mise à jour service journalier ID: $serviceId');
          await api.updateService(
            serviceId: serviceId,
            title: 'Garde journalière',
            durationMin: 1440,
            price: dailyRate,
            description: 'Garde d\'animaux à la journée',
          );
          servicesUpdated++;
          debugPrint('✅ Service journalier mis à jour');
        }
      }

      debugPrint('🎉 Services: $servicesCreated créés, $servicesUpdated mis à jour');

      // Afficher un message à l'utilisateur si des services ont été créés
      if (servicesCreated > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$servicesCreated service(s) de réservation créé(s)')),
        );
      }
    } catch (e, stackTrace) {
      // Logger l'erreur complète
      debugPrint('❌ ERREUR création services garderie: $e');
      debugPrint('Stack trace: $stackTrace');

      // Afficher l'erreur à l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur création services: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          context.go('/daycare/home');
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? _bgDark : const Color(0xFFF5F5F5),
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // AppBar moderne
                SliverAppBar(
                  expandedHeight: 0,
                  floating: true,
                  pinned: true,
                  backgroundColor: isDark ? _cardDark : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: isDark ? _inkDark : _ink,
                        size: 20,
                      ),
                    ),
                    onPressed: () {
                      final nav = Navigator.of(context);
                      if (nav.canPop()) {
                        nav.pop();
                      } else {
                        context.go('/daycare/home');
                      }
                    },
                  ),
                  title: Text(
                    l10n.managePage,
                    style: TextStyle(
                      color: isDark ? _inkDark : _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  actions: [
                    // Bouton preview
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton.icon(
                        onPressed: _providerId != null && _providerId!.isNotEmpty
                            ? () => context.push('/daycare/detail/$_providerId')
                            : null,
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text(l10n.preview),
                        style: TextButton.styleFrom(
                          foregroundColor: _primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                // Contenu
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Galerie photos
                      _buildPhotoGallery(isDark, l10n),
                      const SizedBox(height: 20),

                      // Section titre
                      _buildSectionTitle(l10n.description, Icons.edit_note, isDark),
                      const SizedBox(height: 12),
                      _buildDescriptionCard(isDark, l10n),
                      const SizedBox(height: 24),

                      // Configuration
                      _buildSectionTitle('Configuration', Icons.tune, isDark),
                      const SizedBox(height: 12),
                      _buildConfigRow(isDark, l10n),
                      const SizedBox(height: 16),
                      _buildAnimalTypesCard(isDark, l10n),
                      const SizedBox(height: 24),

                      // Tarification
                      _buildSectionTitle('Tarification', Icons.payments, isDark),
                      const SizedBox(height: 12),
                      _buildPricingCards(isDark, l10n),
                      const SizedBox(height: 24),

                      // Disponibilités
                      _buildSectionTitle('Disponibilités', Icons.schedule, isDark),
                      const SizedBox(height: 12),
                      _buildAvailabilityCard(isDark, l10n),
                    ]),
                  ),
                ),
              ],
            ),

            // Bouton flottant Enregistrer
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildSaveButton(isDark, l10n),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════ WIDGETS HELPER ═══════

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? _inkDark : _ink,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: child,
    );
  }

  // ═══════ GALERIE PHOTOS ═══════
  Widget _buildPhotoGallery(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo principale
        GestureDetector(
          onTap: _imageUrls.isEmpty ? _pickAndUploadImage : null,
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? _cardDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: _imageUrls.isEmpty
                  ? Border.all(
                      color: _primary.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    )
                  : null,
              image: _imageUrls.isNotEmpty && _selectedImageIndex < _imageUrls.length
                  ? DecorationImage(
                      image: NetworkImage(_imageUrls[_selectedImageIndex]),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: _imageUrls.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ajouter des photos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? _inkDark : _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jusqu\'à 5 photos pour votre annonce',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? _mutedDark : _muted,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      // Overlay gradient
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Compteur
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                '${_imageUrls.length}/5',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bouton modifier
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Material(
                          color: _primary,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _pickAndUploadImage,
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Modifier',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // Vignettes
        if (_imageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length + (_imageUrls.length < 5 ? 1 : 0),
              itemBuilder: (context, index) {
                // Bouton ajouter
                if (index == _imageUrls.length) {
                  return _uploadingImage
                      ? Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isDark ? _cardDark : _primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _primary.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isDark ? _cardDark : _primarySoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _primary.withOpacity(0.3),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Icon(Icons.add, color: _primary, size: 28),
                          ),
                        );
                }

                // Vignette image
                final isSelected = index == _selectedImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageIndex = index),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? _primary : Colors.transparent,
                        width: 3,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(_imageUrls[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Bouton supprimer
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ═══════ DESCRIPTION ═══════
  Widget _buildDescriptionCard(bool isDark, AppLocalizations l10n) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _bio,
            minLines: 4,
            maxLines: 6,
            maxLength: _bioMax,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: isDark ? _inkDark : _ink),
            decoration: InputDecoration(
              hintText: 'Décrivez votre garderie, vos services, votre expérience...',
              hintStyle: TextStyle(color: isDark ? _mutedDark : _muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 2),
              ),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
              counterStyle: TextStyle(color: isDark ? _mutedDark : _muted),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════ CONFIGURATION ROW ═══════
  Widget _buildConfigRow(bool isDark, AppLocalizations l10n) {
    final capacity = int.tryParse(_capacity.text) ?? 0;

    return Row(
      children: [
        // Capacité
        Expanded(
          child: _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                Icon(Icons.pets, color: _primary, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Capacité',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? _mutedDark : _muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepperButton(
                      icon: Icons.remove,
                      onTap: capacity > 0
                          ? () {
                              setState(() {
                                _capacity.text = '${capacity - 1}';
                              });
                            }
                          : null,
                      isDark: isDark,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$capacity',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? _inkDark : _ink,
                        ),
                      ),
                    ),
                    _buildStepperButton(
                      icon: Icons.add,
                      onTap: () {
                        setState(() {
                          _capacity.text = '${capacity + 1}';
                        });
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'animaux max',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? _mutedDark : _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Types d'animaux count
        Expanded(
          child: _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.category, color: Color(0xFF22C55E), size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'Types acceptés',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? _mutedDark : _muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_animalTypes.length}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? _inkDark : _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'types d\'animaux',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? _mutedDark : _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDisabled
              ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200)
              : _primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDisabled
                ? (isDark ? Colors.white12 : Colors.grey.shade300)
                : _primary.withOpacity(0.3),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDisabled ? (isDark ? Colors.white24 : Colors.grey) : _primary,
        ),
      ),
    );
  }

  // ═══════ TYPES D'ANIMAUX ═══════
  Widget _buildAnimalTypesCard(bool isDark, AppLocalizations l10n) {
    // Icônes pour chaque type
    IconData _getAnimalIcon(String type) {
      final lower = type.toLowerCase();
      if (lower.contains('chien')) return Icons.pets;
      if (lower.contains('chat')) return Icons.pets;
      if (lower.contains('lapin')) return Icons.cruelty_free;
      if (lower.contains('oiseau')) return Icons.flutter_dash;
      if (lower.contains('rongeur')) return Icons.pest_control_rodent;
      return Icons.pets;
    }

    Color _getAnimalColor(int index) {
      final colors = [
        const Color(0xFF3B82F6),
        const Color(0xFF22C55E),
        const Color(0xFFF59E0B),
        const Color(0xFFEF4444),
        const Color(0xFF8B5CF6),
        const Color(0xFF06B6D4),
        const Color(0xFFEC4899),
      ];
      return colors[index % colors.length];
    }

    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animaux acceptés',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? _inkDark : _ink,
            ),
          ),
          const SizedBox(height: 16),

          // Types sélectionnés
          if (_animalTypes.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _animalTypes.asMap().entries.map((entry) {
                final index = entry.key;
                final type = entry.value;
                final color = _getAnimalColor(index);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getAnimalIcon(type), size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeAnimalType(type),
                        child: Icon(Icons.close, size: 16, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Suggestions
          Text(
            'Ajouter:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? _mutedDark : _muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTypes.where((t) => !_animalTypes.contains(t)).map((type) {
              return GestureDetector(
                onTap: () => _addAnimalType(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        size: 16,
                        color: isDark ? _mutedDark : _muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type,
                        style: TextStyle(
                          color: isDark ? _mutedDark : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Input personnalisé
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newAnimalTypeController,
                  style: TextStyle(color: isDark ? _inkDark : _ink),
                  decoration: InputDecoration(
                    hintText: 'Type personnalisé...',
                    hintStyle: TextStyle(color: isDark ? _mutedDark : _muted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                  ),
                  onSubmitted: (value) {
                    _addAnimalType(value);
                    _newAnimalTypeController.clear();
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  _addAnimalType(_newAnimalTypeController.text);
                  _newAnimalTypeController.clear();
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════ TARIFICATION ═══════
  Widget _buildPricingCards(bool isDark, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _buildPriceCard(
            icon: Icons.schedule,
            title: 'Horaire',
            controller: _hourlyRate,
            suffix: 'DA/h',
            color: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPriceCard(
            icon: Icons.calendar_today,
            title: 'Journalier',
            controller: _dailyRate,
            suffix: 'DA/jour',
            color: const Color(0xFF22C55E),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required String suffix,
    required Color color,
    required bool isDark,
  }) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? _inkDark : _ink,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: color.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: color.withOpacity(isDark ? 0.1 : 0.05),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suffix,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? _mutedDark : _muted,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════ DISPONIBILITÉS ═══════
  Widget _buildAvailabilityCard(bool isDark, AppLocalizations l10n) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle 24/7
          GestureDetector(
            onTap: () => setState(() => _is24_7 = !_is24_7),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _is24_7
                    ? _primary.withOpacity(isDark ? 0.2 : 0.1)
                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _is24_7 ? _primary : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: _is24_7 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _is24_7 ? _primary : (isDark ? Colors.white12 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.all_inclusive,
                      color: _is24_7 ? Colors.white : (isDark ? _mutedDark : _muted),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ouvert 24h/24 - 7j/7',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? _inkDark : _ink,
                          ),
                        ),
                        Text(
                          'Disponible à tout moment',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? _mutedDark : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _is24_7 ? _primary : (isDark ? Colors.white24 : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: _is24_7 ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Horaires personnalisés
          if (!_is24_7) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTimePicker(
                    label: 'Ouverture',
                    time: _openingTime,
                    icon: Icons.wb_sunny,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(_openingTime.split(':')[0]),
                          minute: int.parse(_openingTime.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setState(() {
                          _openingTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.arrow_forward,
                    color: isDark ? _mutedDark : _muted,
                  ),
                ),
                Expanded(
                  child: _buildTimePicker(
                    label: 'Fermeture',
                    time: _closingTime,
                    icon: Icons.nightlight_round,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(_closingTime.split(':')[0]),
                          minute: int.parse(_closingTime.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setState(() {
                          _closingTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],

          // Jours de la semaine
          const SizedBox(height: 24),
          Text(
            'Jours disponibles',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? _inkDark : _ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayCircle('L', 0, isDark),
              _buildDayCircle('M', 1, isDark),
              _buildDayCircle('M', 2, isDark),
              _buildDayCircle('J', 3, isDark),
              _buildDayCircle('V', 4, isDark),
              _buildDayCircle('S', 5, isDark),
              _buildDayCircle('D', 6, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required String time,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              time,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? _inkDark : _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? _mutedDark : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCircle(String day, int index, bool isDark) {
    final isSelected = _availableDays[index];

    return GestureDetector(
      onTap: () => setState(() => _availableDays[index] = !_availableDays[index]),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? _primary : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? _primary : (isDark ? Colors.white24 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? _mutedDark : _muted,
                  ),
                ),
        ),
      ),
    );
  }

  // ═══════ BOUTON ENREGISTRER ═══════
  Widget _buildSaveButton(bool isDark, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _loading ? null : _save,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else ...[
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    l10n.save,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════ OLD METHODS (kept for compatibility) ═══════
  ThemeData _themed(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _primary,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: _primarySoft,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: _ink, fontSize: 13),
        deleteIconColor: _primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: _primary.withOpacity(0.3)),
      ),
      dividerTheme: theme.dividerTheme.copyWith(color: Colors.black12),
      snackBarTheme: theme.snackBarTheme.copyWith(
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _imagesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Photos de la garderie',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Text(
                '${_imageUrls.length}/5',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez jusqu\'à 5 photos pour attirer les clients',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),

          // Slider horizontal des images
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length + 1,
              itemBuilder: (context, index) {
                if (index == _imageUrls.length) {
                  // Bouton ajouter
                  return _uploadingImage
                      ? Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _primary.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : InkWell(
                          onTap: _pickAndUploadImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _primarySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primary.withOpacity(0.3), width: 2, style: BorderStyle.solid),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, color: _primary, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'Ajouter',
                                  style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        );
                }

                // Image existante
                final url = _imageUrls[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(url),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Overlay sombre
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Bouton supprimer
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      // Numéro de position
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bioCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Description de l\'annonce', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Présentez votre garderie aux clients',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            minLines: 4,
            maxLines: 6,
            maxLength: _bioMax,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              hintText: 'Ex: Garderie spacieuse et sécurisée avec jardin clôturé...',
              isDense: true,
              errorText: _errBio,
            ),
          ),
        ],
      ),
    );
  }

  Widget _capacityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Capacité maximale', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Nombre maximum d\'animaux simultanément',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelText: 'Capacite',
              hintText: 'Ex: 10',
              isDense: true,
              errorText: _errCapacity,
              prefixIcon: const Icon(Icons.pets),
              suffixText: 'animaux',
            ),
          ),
        ],
      ),
    );
  }

  Widget _animalTypesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Types d\'animaux acceptés', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Sélectionnez ou ajoutez vos propres types',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),

          // Types sélectionnés
          if (_animalTypes.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _animalTypes.map((type) {
                return Chip(
                  label: Text(type),
                  onDeleted: () => _removeAnimalType(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Types suggérés
          const Text('Suggestions:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTypes.where((t) => !_animalTypes.contains(t)).map((type) {
              return ActionChip(
                label: Text(type),
                onPressed: () => _addAnimalType(type),
                avatar: const Icon(Icons.add, size: 16),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Ajouter type personnalisé
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newAnimalTypeController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    labelText: 'Type personnalisé',
                    hintText: 'Ex: Reptiles',
                    isDense: true,
                    prefixIcon: Icon(Icons.pets),
                  ),
                  onSubmitted: (value) {
                    _addAnimalType(value);
                    _newAnimalTypeController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  _addAnimalType(_newAnimalTypeController.text);
                  _newAnimalTypeController.clear();
                },
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pricingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tarification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Définissez vos tarifs horaires et/ou journaliers',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hourlyRate,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelText: 'Tarif horaire',
              hintText: 'Ex: 200',
              isDense: true,
              errorText: _errHourlyRate,
              prefixIcon: const Icon(Icons.schedule),
              suffixText: 'DA/h',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dailyRate,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelText: 'Tarif journalier',
              hintText: 'Ex: 1500',
              isDense: true,
              errorText: _errDailyRate,
              prefixIcon: const Icon(Icons.calendar_today),
              suffixText: 'DA/jour',
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Horaires de disponibilité', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Indiquez vos horaires d\'ouverture',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),

          // Switch 24/7
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ouvert 24h/24 - 7j/7'),
            value: _is24_7,
            onChanged: (value) => setState(() => _is24_7 = value),
            activeColor: _primary,
          ),

          if (!_is24_7) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(_openingTime.split(':')[0]),
                          minute: int.parse(_openingTime.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setState(() {
                          _openingTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        labelText: 'Ouverture',
                        isDense: true,
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_openingTime),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(_closingTime.split(':')[0]),
                          minute: int.parse(_closingTime.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setState(() {
                          _closingTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        labelText: 'Fermeture',
                        isDense: true,
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_closingTime),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Jours de disponibilité
          const SizedBox(height: 24),
          const Text('Jours de disponibilité', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Cochez les jours où vous êtes disponible',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),

          // Grille des jours de la semaine
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dayButton('Lun', 0),
              _dayButton('Mar', 1),
              _dayButton('Mer', 2),
              _dayButton('Jeu', 3),
              _dayButton('Ven', 4),
              _dayButton('Sam', 5),
              _dayButton('Dim', 6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayButton(String label, int dayIndex) {
    final isAvailable = _availableDays[dayIndex];
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _availableDays[dayIndex] = !_availableDays[dayIndex];
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isAvailable ? _primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAvailable ? _primary : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isAvailable ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.2)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
