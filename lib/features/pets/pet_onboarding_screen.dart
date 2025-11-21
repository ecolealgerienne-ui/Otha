import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

class PetOnboardingScreen extends ConsumerStatefulWidget {
  /// Si non null, on édite ce pet au lieu d'en créer un nouveau
  final Map<String, dynamic>? existingPet;

  const PetOnboardingScreen({super.key, this.existingPet});

  @override
  ConsumerState<PetOnboardingScreen> createState() => _PetOnboardingScreenState();
}

class _PetOnboardingScreenState extends ConsumerState<PetOnboardingScreen> {
  // Champs de base
  final _name = TextEditingController();
  String _gender = 'UNKNOWN'; // 'MALE' | 'FEMALE' | 'UNKNOWN'
  int? _ageYears;             // affichage uniquement
  double? _weightKg;

  // Infos supplémentaires
  final _color = TextEditingController();
  final _city = TextEditingController();
  final _breed = TextEditingController();
  final _microchip = TextEditingController();  // Numéro de puce
  final _allergies = TextEditingController();   // Allergies connues
  final _notes = TextEditingController();       // Notes/description
  String? _animalType;
  DateTime? _neuteredAt;
  DateTime? _birthDate;  // Date de naissance exacte

  // Image locale pour l'aperçu
  File? _photoFile;
  String? _existingPhotoUrl;  // URL de la photo existante (mode édition)

  bool _saving = false;
  bool get _isEditMode => widget.existingPet != null;

  @override
  void initState() {
    super.initState();
    _loadExistingPet();
  }

  void _loadExistingPet() {
    final pet = widget.existingPet;
    if (pet == null) return;

    // Détecter si c'est des données d'adoption (AdoptPost) ou un pet existant
    final isAdoptionData = pet.containsKey('animalName') || pet.containsKey('ageMonths');

    if (isAdoptionData) {
      // Données d'adoption : mapper les champs AdoptPost vers Pet
      _name.text = pet['animalName']?.toString() ?? '';

      // Mapper sex (M/F/U) vers gender (MALE/FEMALE/UNKNOWN)
      final sex = pet['sex']?.toString().toUpperCase();
      if (sex == 'M') {
        _gender = 'MALE';
      } else if (sex == 'F') {
        _gender = 'FEMALE';
      } else {
        _gender = 'UNKNOWN';
      }

      // Mapper species (dog/cat/other) vers idNumber
      final species = pet['species']?.toString().toLowerCase();
      _animalType = species; // Utilisé temporairement

      _color.text = pet['color']?.toString() ?? '';
      _city.text = pet['city']?.toString() ?? '';
      _notes.text = pet['description']?.toString() ?? '';

      // Calculer birthDate à partir de ageMonths
      final ageMonths = pet['ageMonths'] as int?;
      if (ageMonths != null) {
        final now = DateTime.now();
        _birthDate = DateTime(now.year, now.month - ageMonths, now.day);
        _ageYears = (ageMonths / 12).floor();
      }

      // Récupérer la première image
      final images = pet['images'] as List?;
      if (images != null && images.isNotEmpty) {
        final firstImage = images[0];
        if (firstImage is Map) {
          _existingPhotoUrl = firstImage['url']?.toString();
        } else if (firstImage is String) {
          _existingPhotoUrl = firstImage;
        }
      }
    } else {
      // Données de pet existant : chargement normal
      _name.text = pet['name'] ?? '';
      _gender = pet['gender'] ?? 'UNKNOWN';
      _weightKg = (pet['weightKg'] as num?)?.toDouble();
      _color.text = pet['color'] ?? '';
      _city.text = pet['country'] ?? '';
      _breed.text = pet['breed'] ?? '';
      _microchip.text = pet['microchipNumber'] ?? '';
      _allergies.text = pet['allergiesNotes'] ?? '';
      _notes.text = pet['description'] ?? '';
      _animalType = pet['idNumber'];
      _existingPhotoUrl = pet['photoUrl'];

      // Parse dates
      if (pet['neuteredAt'] != null) {
        _neuteredAt = DateTime.tryParse(pet['neuteredAt']);
      }
      if (pet['birthDate'] != null) {
        _birthDate = DateTime.tryParse(pet['birthDate']);
      }

      // Calculer l'âge à partir de birthDate
      if (_birthDate != null) {
        final now = DateTime.now();
        _ageYears = now.year - _birthDate!.year;
        if (now.month < _birthDate!.month ||
            (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
          _ageYears = _ageYears! - 1;
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _city.dispose();
    _breed.dispose();
    _microchip.dispose();
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  // -------- Pickers & helpers

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Choisir une photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFFF36C6C)),
              ),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Utiliser la caméra'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFFF36C6C)),
              ),
              title: const Text('Choisir dans la galerie'),
              subtitle: const Text('Sélectionner une image existante'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photoFile != null || _existingPhotoUrl != null) ...[
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline, color: Colors.red.shade400),
                ),
                title: const Text('Supprimer la photo'),
                onTap: () {
                  setState(() {
                    _photoFile = null;
                    _existingPhotoUrl = null;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final x = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (x != null) {
      setState(() {
        _photoFile = File(x.path);
        _existingPhotoUrl = null;
      });
    }
  }

  Future<void> _pickAge() async {
    final initial = (_ageYears ?? 0).clamp(0, 30);
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final ctl = FixedExtentScrollController(initialItem: initial);
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text('Âge de l\'animal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const Divider(height: 16),
              Expanded(
                child: CupertinoPicker(
                  scrollController: ctl,
                  itemExtent: 36,
                  children: List.generate(31, (i) => Center(child: Text('$i ${i <= 1 ? "an" : "ans"}'))),
                  onSelectedItemChanged: (_) {},
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, ctl.selectedItem),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF36C6C)),
                        child: const Text('Confirmer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        _ageYears = result;
        // Calculer une date de naissance approximative
        final now = DateTime.now();
        _birthDate = DateTime(now.year - result, now.month, now.day);
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      initialDate: _birthDate ?? DateTime(now.year - 1),
      helpText: 'Date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        // Recalculer l'âge
        _ageYears = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          _ageYears = _ageYears! - 1;
        }
      });
    }
  }

  Future<void> _pickGender() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Genre de l\'animal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            _genderTile('MALE', 'Mâle', Icons.male),
            _genderTile('FEMALE', 'Femelle', Icons.female),
            _genderTile('UNKNOWN', 'Non spécifié', Icons.help_outline),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (v != null) setState(() => _gender = v);
  }

  Widget _genderTile(String value, String label, IconData icon) {
    final isSelected = _gender == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF36C6C) : const Color(0xFFFFEEF0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFFF36C6C)),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFF36C6C)) : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _pickAnimalType() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final presets = [
          {'name': 'Chien', 'icon': Icons.pets},
          {'name': 'Chat', 'icon': Icons.pets},
          {'name': 'Lapin', 'icon': Icons.cruelty_free},
          {'name': 'Oiseau', 'icon': Icons.flutter_dash},
          {'name': 'Reptile', 'icon': Icons.pest_control},
          {'name': 'NAC', 'icon': Icons.emoji_nature},
          {'name': 'Autre…', 'icon': Icons.add},
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Type d\'animal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ...presets.map((p) => ListTile(
                leading: Icon(p['icon'] as IconData, color: const Color(0xFFF36C6C)),
                title: Text(p['name'] as String),
                trailing: _animalType == p['name'] ? const Icon(Icons.check_circle, color: Color(0xFFF36C6C)) : null,
                onTap: () => Navigator.pop(context, p['name'] as String),
              )),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (type == null) return;

    if (type == 'Autre…') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Type d\'animal'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'ex: Furet, Tortue…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF36C6C)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (ok == true && ctrl.text.trim().isNotEmpty) {
        setState(() => _animalType = ctrl.text.trim());
      }
    } else {
      setState(() => _animalType = type);
    }
  }

  Future<void> _pickNeuteredAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      initialDate: _neuteredAt ?? now,
      helpText: 'Date de stérilisation',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );
    if (picked != null) setState(() => _neuteredAt = picked);
  }

  // -------- Submit
  Future<void> _confirm() async {
    // Validation
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donnez un nom à votre animal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prisma attend un DateTime ISO-8601 complet → on force minuit UTC
    String? neuteredIso;
    if (_neuteredAt != null) {
      neuteredIso = DateTime(_neuteredAt!.year, _neuteredAt!.month, _neuteredAt!.day)
          .toUtc()
          .toIso8601String();
    }

    String? birthDateIso;
    if (_birthDate != null) {
      birthDateIso = DateTime(_birthDate!.year, _birthDate!.month, _birthDate!.day)
          .toUtc()
          .toIso8601String();
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);

      // Upload optionnel de la photo
      String? photoUrl = _existingPhotoUrl;
      if (_photoFile != null) {
        try {
          photoUrl = await api.uploadLocalFile(_photoFile!, folder: 'pets');
        } catch (_) {
          // on ignore l'erreur d'upload pour ne pas bloquer l'enregistrement
        }
      }

      if (_isEditMode) {
        // Mode édition
        await api.updatePet(
          petId: widget.existingPet!['id'].toString(),
          name: _name.text.trim(),
          gender: _gender,
          weightKg: _weightKg,
          color: _color.text.trim().isEmpty ? null : _color.text.trim(),
          country: _city.text.trim().isEmpty ? null : _city.text.trim(),
          idNumber: _animalType,
          breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
          neuteredAtIso: neuteredIso,
          birthDateIso: birthDateIso,
          microchipNumber: _microchip.text.trim().isEmpty ? null : _microchip.text.trim(),
          allergies: _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
          description: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          photoUrl: photoUrl,
        );
      } else {
        // Mode création
        await api.createPet(
          name: _name.text.trim(),
          gender: _gender,
          weightKg: _weightKg,
          color: _color.text.trim().isEmpty ? null : _color.text.trim(),
          country: _city.text.trim().isEmpty ? null : _city.text.trim(),
          idNumber: _animalType,
          breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
          neuteredAtIso: neuteredIso,
          birthDateIso: birthDateIso,
          microchipNumber: _microchip.text.trim().isEmpty ? null : _microchip.text.trim(),
          allergies: _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
          description: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          photoUrl: photoUrl,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Animal mis à jour' : 'Animal ajouté'),
          backgroundColor: Colors.green,
        ),
      );

      if (_isEditMode) {
        Navigator.pop(context, true); // Retourner avec succès
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'enregistrer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);
    const coralSoft = Color(0xFFFFEEF0);
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenu
            Positioned.fill(
              child: Column(
                children: [
                  // Bandeau image
                  SizedBox(
                    height: 260,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                          child: _buildImage(),
                        ),
                        // Gradient overlay pour lisibilité
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.2),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Bouton retour/ignorer
                        Positioned(
                          left: 12,
                          top: 12,
                          child: IconButton(
                            onPressed: () {
                              if (_isEditMode) {
                                Navigator.pop(context);
                              } else {
                                context.go('/home');
                              }
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                            ),
                            icon: Icon(
                              _isEditMode ? Icons.arrow_back : Icons.close,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        // Titre
                        Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              _isEditMode ? 'Modifier' : 'Nouvel animal',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                              ),
                            ),
                          ),
                        ),
                        // Bouton éditer photo
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.camera_alt, size: 20, color: Color(0xFFF36C6C)),
                                  SizedBox(width: 6),
                                  Text('Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Formulaire + panneau
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nom
                          _textField(
                            label: 'Nom de votre animal *',
                            controller: _name,
                            icon: Icons.pets,
                          ),

                          const SizedBox(height: 14),

                          // Chips: Âge, Genre, Poids
                          Row(
                            children: [
                              _chipBox(
                                label: 'Âge',
                                value: _ageYears == null ? '—' : '$_ageYears ${_ageYears == 1 ? "an" : "ans"}',
                                icon: Icons.cake_outlined,
                                onTap: _pickAge,
                              ),
                              const SizedBox(width: 10),
                              _chipBox(
                                label: 'Genre',
                                value: _gender == 'MALE'
                                    ? 'Mâle'
                                    : _gender == 'FEMALE'
                                        ? 'Femelle'
                                        : '—',
                                icon: _gender == 'MALE' ? Icons.male : _gender == 'FEMALE' ? Icons.female : Icons.help_outline,
                                onTap: _pickGender,
                              ),
                              const SizedBox(width: 10),
                              _chipBox(
                                label: 'Poids',
                                value: _weightKg == null ? '-- kg' : '${_weightKg!.toStringAsFixed(1)} kg',
                                icon: Icons.monitor_weight_outlined,
                                onTap: _pickWeight,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Section: Informations de base
                          _sectionHeader('Informations de base', coral),
                          const SizedBox(height: 10),
                          _infoPanel([
                            _infoPanelTile(
                              icon: Icons.pets_outlined,
                              title: 'Type d\'animal',
                              value: _animalType ?? 'Choisir…',
                              onTap: _pickAnimalType,
                            ),
                            _infoPanelTile(
                              icon: Icons.badge_outlined,
                              title: 'Race',
                              controller: _breed,
                              hint: 'Race de votre animal',
                            ),
                            _infoPanelTile(
                              icon: Icons.palette_outlined,
                              title: 'Couleur',
                              controller: _color,
                              hint: 'Couleur de l\'animal',
                            ),
                            _infoPanelTile(
                              icon: Icons.cake_outlined,
                              title: 'Date de naissance',
                              value: _birthDate == null ? 'Sélectionner' : DateFormat('dd/MM/yyyy').format(_birthDate!),
                              onTap: _pickBirthDate,
                            ),
                          ]),

                          const SizedBox(height: 20),

                          // Section: Santé
                          _sectionHeader('Santé & Identification', coral),
                          const SizedBox(height: 10),
                          _infoPanel([
                            _infoPanelTile(
                              icon: Icons.qr_code,
                              title: 'N° Puce / Tatouage',
                              controller: _microchip,
                              hint: 'Numéro d\'identification',
                            ),
                            _infoPanelTile(
                              icon: Icons.content_cut,
                              title: 'Date de stérilisation',
                              value: _neuteredAt == null ? 'Non renseigné' : DateFormat('dd/MM/yyyy').format(_neuteredAt!),
                              onTap: _pickNeuteredAt,
                              trailing: _neuteredAt != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _neuteredAt = null),
                                  )
                                : null,
                            ),
                            _infoPanelTile(
                              icon: Icons.warning_amber_outlined,
                              title: 'Allergies connues',
                              controller: _allergies,
                              hint: 'Ex: poulet, acariens…',
                            ),
                          ]),

                          const SizedBox(height: 20),

                          // Section: Autres
                          _sectionHeader('Autres informations', coral),
                          const SizedBox(height: 10),
                          _infoPanel([
                            _infoPanelTile(
                              icon: Icons.location_city_outlined,
                              title: 'Ville',
                              controller: _city,
                              hint: 'Votre ville',
                            ),
                            _infoPanelTile(
                              icon: Icons.note_outlined,
                              title: 'Notes',
                              controller: _notes,
                              hint: 'Informations supplémentaires…',
                              maxLines: 3,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bouton Confirmer
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + pad.bottom,
              child: SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: coral,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: coral.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(_isEditMode ? 'Enregistrer' : 'Confirmer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_photoFile != null) {
      return Image.file(_photoFile!, fit: BoxFit.cover);
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return Image.network(
        _existingPhotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultImage(),
      );
    } else {
      return _defaultImage();
    }
  }

  Widget _defaultImage() {
    return Container(
      color: const Color(0xFFFFEEF0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: const Color(0xFFF36C6C).withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'Ajouter une photo',
              style: TextStyle(
                color: const Color(0xFFF36C6C).withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWeight() async {
    final ctrl = TextEditingController(text: _weightKg?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Poids (kg)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'ex. 4.2',
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF36C6C)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
      setState(() => _weightKg = v);
    }
  }

  // -------- Widgets utilitaires

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFF36C6C)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: label,
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }

  Widget _chipBox({
    required String label,
    required String value,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE9A4A4)),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: const Color(0xFFF36C6C)),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: Colors.black.withOpacity(.45), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPanel(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE9A4A4))),
        color: Colors.white,
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF5C3C3)),
          ],
        ],
      ),
    );
  }

  Widget _infoPanelTile({
    required IconData icon,
    required String title,
    String? value,
    TextEditingController? controller,
    String? hint,
    VoidCallback? onTap,
    Widget? trailing,
    int maxLines = 1,
  }) {
    if (controller != null) {
      // Mode édition texte
      return ListTile(
        leading: Icon(icon, color: const Color(0xFFF36C6C)),
        title: Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        subtitle: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint ?? '',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else {
      // Mode sélection
      return ListTile(
        leading: Icon(icon, color: const Color(0xFFF36C6C)),
        title: Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        subtitle: Text(
          value ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value == 'Choisir…' || value == 'Sélectionner' || value == 'Non renseigné'
                ? Colors.grey.shade400
                : Colors.black87,
          ),
        ),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: Colors.black38) : null),
        onTap: onTap,
      );
    }
  }
}
