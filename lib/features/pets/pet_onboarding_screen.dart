import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Design constants
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

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

  // Mode édition uniquement si c'est un pet existant (pas des données d'adoption)
  bool get _isEditMode {
    if (widget.existingPet == null) return false;
    // Si c'est des données d'adoption (a animalName ou ageMonths), ce n'est PAS un pet existant
    final isAdoptionData = widget.existingPet!.containsKey('animalName') ||
                          widget.existingPet!.containsKey('ageMonths');
    return !isAdoptionData;
  }

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

      // Calculer birthDate à partir de ageMonths (parsing robuste)
      final ageMonthsValue = pet['ageMonths'];
      int? ageMonths;
      if (ageMonthsValue != null) {
        if (ageMonthsValue is int) {
          ageMonths = ageMonthsValue;
        } else if (ageMonthsValue is num) {
          ageMonths = ageMonthsValue.toInt();
        } else if (ageMonthsValue is String) {
          ageMonths = int.tryParse(ageMonthsValue);
        }
      }

      if (ageMonths != null && ageMonths > 0) {
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

      // Parse weightKg de manière robuste (peut être String ou num)
      final weightValue = pet['weightKg'];
      if (weightValue != null) {
        if (weightValue is num) {
          _weightKg = weightValue.toDouble();
        } else if (weightValue is String) {
          _weightKg = double.tryParse(weightValue);
        }
      }

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
        _neuteredAt = DateTime.tryParse(pet['neuteredAt'].toString());
      }
      if (pet['birthDate'] != null) {
        _birthDate = DateTime.tryParse(pet['birthDate'].toString());
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
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.choosePhoto,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: _coral),
              ),
              title: Text(l10n.takePhoto, style: TextStyle(color: textPrimary)),
              subtitle: Text(l10n.useCamera, style: TextStyle(color: textPrimary.withOpacity(0.6))),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: _coral),
              ),
              title: Text(l10n.chooseFromGallery, style: TextStyle(color: textPrimary)),
              subtitle: Text(l10n.selectExistingImage, style: TextStyle(color: textPrimary.withOpacity(0.6))),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photoFile != null || _existingPhotoUrl != null) ...[
              Divider(color: isDark ? _darkCardBorder : Colors.grey.shade200),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline, color: Colors.red.shade400),
                ),
                title: Text(l10n.deletePhoto, style: TextStyle(color: textPrimary)),
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
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final initial = (_ageYears ?? 0).clamp(0, 30);
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor,
      builder: (_) {
        final ctl = FixedExtentScrollController(initialItem: initial);
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(l10n.animalAge, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textPrimary)),
              Divider(height: 16, color: isDark ? _darkCardBorder : Colors.grey.shade200),
              Expanded(
                child: CupertinoPicker(
                  scrollController: ctl,
                  itemExtent: 36,
                  children: List.generate(31, (i) => Center(
                    child: Text(
                      '$i ${i <= 1 ? l10n.year : l10n.years}',
                      style: TextStyle(color: textPrimary),
                    ),
                  )),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
                        ),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, ctl.selectedItem),
                        style: FilledButton.styleFrom(backgroundColor: _coral),
                        child: Text(l10n.confirm),
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
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      initialDate: _birthDate ?? DateTime(now.year - 1),
      helpText: l10n.petBirthDate,
      cancelText: l10n.cancel,
      confirmText: l10n.confirm,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: _coral, surface: _darkCard)
                : const ColorScheme.light(primary: _coral),
          ),
          child: child!,
        );
      },
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
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.animalGender,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
              ),
            ),
            _genderTile('MALE', l10n.male, Icons.male, isDark, textPrimary),
            _genderTile('FEMALE', l10n.female, Icons.female, isDark, textPrimary),
            _genderTile('UNKNOWN', l10n.notSpecifiedGender, Icons.help_outline, isDark, textPrimary),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (v != null) setState(() => _gender = v);
  }

  Widget _genderTile(String value, String label, IconData icon, bool isDark, Color textPrimary) {
    final isSelected = _gender == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? _coral : (isDark ? _coral.withOpacity(0.15) : _coralSoft),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? Colors.white : _coral),
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: textPrimary)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: _coral) : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _pickAnimalType() async {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: cardColor,
      builder: (_) {
        final presets = [
          {'name': l10n.dog, 'icon': Icons.pets},
          {'name': l10n.cat, 'icon': Icons.pets},
          {'name': l10n.rabbit, 'icon': Icons.cruelty_free},
          {'name': l10n.bird, 'icon': Icons.flutter_dash},
          {'name': l10n.reptile, 'icon': Icons.pest_control},
          {'name': l10n.nac, 'icon': Icons.emoji_nature},
          {'name': l10n.other, 'icon': Icons.add},
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.animalType,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                ),
              ),
              ...presets.map((p) => ListTile(
                leading: Icon(p['icon'] as IconData, color: _coral),
                title: Text(p['name'] as String, style: TextStyle(color: textPrimary)),
                trailing: _animalType == p['name'] ? const Icon(Icons.check_circle, color: _coral) : null,
                onTap: () => Navigator.pop(context, p['name'] as String),
              )),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (type == null) return;

    if (type == l10n.other) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(l10n.animalType, style: TextStyle(color: textPrimary)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              hintText: 'ex: Furet, Tortue…',
              hintStyle: TextStyle(color: textPrimary.withOpacity(0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: _coral),
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
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      initialDate: _neuteredAt ?? now,
      helpText: l10n.sterilizationDate,
      cancelText: l10n.cancel,
      confirmText: l10n.confirm,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: _coral, surface: _darkCard)
                : const ColorScheme.light(primary: _coral),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _neuteredAt = picked);
  }

  // -------- Submit
  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);

    // Validation
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.giveAnimalName),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          content: Text(_isEditMode ? l10n.animalUpdated : l10n.animalAdded),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          content: Text('${l10n.unableToSave}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor = isDark ? _darkCardBorder : const Color(0xFFE9A4A4);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau image
            SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: _buildImage(isDark),
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
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
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
                        backgroundColor: isDark ? _darkCard.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                      ),
                      icon: Icon(
                        _isEditMode ? Icons.arrow_back_ios_new_rounded : Icons.close,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 20,
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
                        _isEditMode ? l10n.editPet : l10n.newAnimal,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? _darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt, size: 18, color: _coral),
                            const SizedBox(width: 6),
                            Text(
                              l10n.photo,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Formulaire + panneau
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom
                    _textField(
                      label: l10n.animalNameRequired,
                      controller: _name,
                      icon: Icons.pets,
                      isDark: isDark,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                    const SizedBox(height: 14),

                    // Chips: Âge, Genre, Poids
                    Row(
                      children: [
                        _chipBox(
                          label: l10n.petAge,
                          value: _ageYears == null ? '—' : '$_ageYears ${_ageYears == 1 ? l10n.year : l10n.years}',
                          icon: Icons.cake_outlined,
                          onTap: _pickAge,
                          isDark: isDark,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 10),
                        _chipBox(
                          label: l10n.petGender,
                          value: _gender == 'MALE'
                              ? l10n.male
                              : _gender == 'FEMALE'
                                  ? l10n.female
                                  : '—',
                          icon: _gender == 'MALE' ? Icons.male : _gender == 'FEMALE' ? Icons.female : Icons.help_outline,
                          onTap: _pickGender,
                          isDark: isDark,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 10),
                        _chipBox(
                          label: l10n.petWeight,
                          value: _weightKg == null ? '-- kg' : '${_weightKg!.toStringAsFixed(1)} kg',
                          icon: Icons.monitor_weight_outlined,
                          onTap: _pickWeight,
                          isDark: isDark,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section: Informations de base
                    _sectionHeader(l10n.basicInfoSection, _coral, textPrimary),
                    const SizedBox(height: 10),
                    _infoPanel(
                      isDark: isDark,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        _infoPanelTile(
                          icon: Icons.pets_outlined,
                          title: l10n.animalType,
                          value: _animalType ?? l10n.choose,
                          onTap: _pickAnimalType,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _infoPanelTile(
                          icon: Icons.badge_outlined,
                          title: l10n.petBreed,
                          controller: _breed,
                          hint: l10n.petBreed,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _infoPanelTile(
                          icon: Icons.palette_outlined,
                          title: l10n.petColor,
                          controller: _color,
                          hint: l10n.petColor,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _infoPanelTile(
                          icon: Icons.cake_outlined,
                          title: l10n.petBirthDate,
                          value: _birthDate == null ? l10n.selectDate : DateFormat('dd/MM/yyyy').format(_birthDate!),
                          onTap: _pickBirthDate,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section: Santé
                    _sectionHeader(l10n.healthIdSection, _coral, textPrimary),
                    const SizedBox(height: 10),
                    _infoPanel(
                      isDark: isDark,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        _infoPanelTile(
                          icon: Icons.qr_code,
                          title: l10n.microchipNumber,
                          controller: _microchip,
                          hint: l10n.microchipNumber,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _infoPanelTile(
                          icon: Icons.content_cut,
                          title: l10n.sterilizationDate,
                          value: _neuteredAt == null ? l10n.notProvided : DateFormat('dd/MM/yyyy').format(_neuteredAt!),
                          onTap: _pickNeuteredAt,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          trailing: _neuteredAt != null
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: textSecondary),
                                onPressed: () => setState(() => _neuteredAt = null),
                              )
                            : null,
                        ),
                        _infoPanelTile(
                          icon: Icons.warning_amber_outlined,
                          title: l10n.knownAllergies,
                          controller: _allergies,
                          hint: 'Ex: poulet, acariens…',
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section: Autres
                    _sectionHeader(l10n.otherInfoSection, _coral, textPrimary),
                    const SizedBox(height: 10),
                    _infoPanel(
                      isDark: isDark,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        _infoPanelTile(
                          icon: Icons.location_city_outlined,
                          title: l10n.city,
                          controller: _city,
                          hint: l10n.city,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        _infoPanelTile(
                          icon: Icons.note_outlined,
                          title: l10n.notes,
                          controller: _notes,
                          hint: l10n.notes,
                          maxLines: 3,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bouton Confirmer en bas
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _coral.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(_isEditMode ? l10n.save : l10n.confirm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(bool isDark) {
    if (_photoFile != null) {
      return Image.file(_photoFile!, fit: BoxFit.cover);
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return Image.network(
        _existingPhotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultImage(isDark),
      );
    } else {
      return _defaultImage(isDark);
    }
  }

  Widget _defaultImage(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: isDark ? _darkCard : _coralSoft,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: _coral.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              l10n.addPhoto,
              style: TextStyle(
                color: _coral.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWeight() async {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final ctrl = TextEditingController(text: _weightKg?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.weightKg, style: TextStyle(color: textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: textPrimary),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'ex. 4.2',
            hintStyle: TextStyle(color: textPrimary.withOpacity(0.5)),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: textPrimary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _coral, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _coral),
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

  Widget _sectionHeader(String title, Color color, Color textPrimary) {
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
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textPrimary),
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: _coral) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _coral, width: 2),
        ),
        isDense: true,
        filled: true,
        fillColor: cardColor,
        hintText: label,
        hintStyle: TextStyle(color: textSecondary),
      ),
    );
  }

  Widget _chipBox({
    required String label,
    required String value,
    IconData? icon,
    VoidCallback? onTap,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            color: cardColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: _coral),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPanel({
    required List<Widget> children,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: cardColor,
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? _darkCardBorder : const Color(0xFFF5C3C3),
              ),
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
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final l10n = AppLocalizations.of(context);

    if (controller != null) {
      // Mode édition texte
      return ListTile(
        leading: Icon(icon, color: _coral),
        title: Text(title, style: TextStyle(fontSize: 13, color: textSecondary)),
        subtitle: TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint ?? '',
            hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    } else {
      // Mode sélection
      final isPlaceholder = value == l10n.choose || value == l10n.selectDate || value == l10n.notProvided;
      return ListTile(
        leading: Icon(icon, color: _coral),
        title: Text(title, style: TextStyle(fontSize: 13, color: textSecondary)),
        subtitle: Text(
          value ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isPlaceholder ? textSecondary.withOpacity(0.6) : textPrimary,
          ),
        ),
        trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: textSecondary) : null),
        onTap: onTap,
      );
    }
  }
}
