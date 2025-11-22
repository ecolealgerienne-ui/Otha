import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

class DaycarePageEditorScreen extends ConsumerStatefulWidget {
  const DaycarePageEditorScreen({super.key});

  @override
  ConsumerState<DaycarePageEditorScreen> createState() => _DaycarePageEditorScreenState();
}

class _DaycarePageEditorScreenState extends ConsumerState<DaycarePageEditorScreen> {
  // Palette cyan (daycare)
  static const Color _primary = Color(0xFF00ACC1);
  static const Color _primarySoft = Color(0xFFE0F7FA);
  static const Color _ink = Color(0xFF222222);
  static const Color _muted = Color(0xFF6B6B6B);

  // Images (liste dynamique)
  final List<String> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();

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
      // Récupérer les services existants
      final existingServices = await api.listMyServices();

      // Service horaire
      if (pricing.containsKey('hourlyRate')) {
        final hourlyRate = pricing['hourlyRate'] as int;
        final existingHourly = existingServices.firstWhere(
          (s) => (s['title'] ?? '').toString().toLowerCase().contains('garde horaire'),
          orElse: () => {},
        );

        if (existingHourly.isEmpty) {
          // Créer nouveau service horaire
          await api.createService(
            title: 'Garde horaire',
            durationMin: 60, // 1 heure par défaut
            price: hourlyRate,
            description: 'Garde d\'animaux à l\'heure',
          );
        } else {
          // Mettre à jour le prix si différent
          final serviceId = existingHourly['id'] as String;
          await api.updateService(
            serviceId: serviceId,
            title: 'Garde horaire',
            durationMin: 60,
            price: hourlyRate,
            description: 'Garde d\'animaux à l\'heure',
          );
        }
      }

      // Service journalier
      if (pricing.containsKey('dailyRate')) {
        final dailyRate = pricing['dailyRate'] as int;
        final existingDaily = existingServices.firstWhere(
          (s) => (s['title'] ?? '').toString().toLowerCase().contains('garde journalière'),
          orElse: () => {},
        );

        if (existingDaily.isEmpty) {
          // Créer nouveau service journalier
          await api.createService(
            title: 'Garde journalière',
            durationMin: 1440, // 24 heures = 1440 minutes
            price: dailyRate,
            description: 'Garde d\'animaux à la journée',
          );
        } else {
          // Mettre à jour le prix si différent
          final serviceId = existingDaily['id'] as String;
          await api.updateService(
            serviceId: serviceId,
            title: 'Garde journalière',
            durationMin: 1440,
            price: dailyRate,
            description: 'Garde d\'animaux à la journée',
          );
        }
      }
    } catch (e) {
      // Ne pas bloquer la sauvegarde si la création des services échoue
      debugPrint('Erreur création services garderie: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Theme(
        data: _themed(context),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  context.go('/daycare/home');
                }
              },
            ),
            title: const Text('Gérer la page'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _imagesCard(),
              const SizedBox(height: 12),
              _bioCard(),
              const SizedBox(height: 12),
              _capacityCard(),
              const SizedBox(height: 12),
              _animalTypesCard(),
              const SizedBox(height: 12),
              _pricingCard(),
              const SizedBox(height: 12),
              _availabilityCard(),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? '...' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        ],
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
