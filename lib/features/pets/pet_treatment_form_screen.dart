// lib/features/pets/pet_treatment_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);

class PetTreatmentFormScreen extends ConsumerStatefulWidget {
  final String petId;
  final String? treatmentId; // null = create, non-null = edit

  const PetTreatmentFormScreen({
    super.key,
    required this.petId,
    this.treatmentId,
  });

  @override
  ConsumerState<PetTreatmentFormScreen> createState() => _PetTreatmentFormScreenState();
}

class _PetTreatmentFormScreenState extends ConsumerState<PetTreatmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  List<String> _attachmentUrls = [];
  bool _isUploading = false;

  bool _isLoading = false;
  bool _isLoadingInitial = false;

  @override
  void initState() {
    super.initState();
    if (widget.treatmentId != null) {
      _loadTreatment();
    }
  }

  Future<void> _loadTreatment() async {
    setState(() => _isLoadingInitial = true);
    try {
      final api = ref.read(apiProvider);
      final treatments = await api.getTreatments(widget.petId);
      final treatment = treatments.firstWhere(
        (t) => t['id'] == widget.treatmentId,
        orElse: () => throw Exception('Traitement non trouvé'),
      );

      _nameController.text = treatment['name']?.toString() ?? '';
      _dosageController.text = treatment['dosage']?.toString() ?? '';
      _frequencyController.text = treatment['frequency']?.toString() ?? '';
      _notesController.text = treatment['notes']?.toString() ?? '';

      setState(() {
        if (treatment['startDate'] != null) {
          _startDate = DateTime.parse(treatment['startDate'].toString());
        }
        if (treatment['endDate'] != null) {
          _endDate = DateTime.parse(treatment['endDate'].toString());
        }
        _isActive = treatment['isActive'] == true;
        _attachmentUrls = (treatment['attachments'] as List?)?.cast<String>() ?? [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingInitial = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final api = ref.read(apiProvider);
      final url = await api.uploadLocalFile(File(pickedFile.path), folder: 'prescriptions');

      setState(() {
        _attachmentUrls.add(url);
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image ajoutée'),
            backgroundColor: _mint,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e'), backgroundColor: _coral),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachmentUrls.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);

      if (widget.treatmentId == null) {
        // Create
        await api.createTreatment(
          widget.petId,
          name: _nameController.text.trim(),
          startDateIso: _startDate.toIso8601String(),
          dosage: _dosageController.text.trim().isNotEmpty
              ? _dosageController.text.trim()
              : null,
          frequency: _frequencyController.text.trim().isNotEmpty
              ? _frequencyController.text.trim()
              : null,
          endDateIso: _endDate?.toIso8601String(),
          isActive: _isActive,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          attachments: _attachmentUrls.isNotEmpty ? _attachmentUrls : null,
        );

        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ordonnance ajoutée'),
              backgroundColor: _mint,
            ),
          );
        }
      } else {
        // Update
        await api.updateTreatment(
          widget.petId,
          widget.treatmentId!,
          name: _nameController.text.trim(),
          startDateIso: _startDate.toIso8601String(),
          dosage: _dosageController.text.trim().isNotEmpty
              ? _dosageController.text.trim()
              : null,
          frequency: _frequencyController.text.trim().isNotEmpty
              ? _frequencyController.text.trim()
              : null,
          endDateIso: _endDate?.toIso8601String(),
          isActive: _isActive,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          attachments: _attachmentUrls.isNotEmpty ? _attachmentUrls : null,
        );

        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ordonnance mise à jour'),
              backgroundColor: _mint,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _coral),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.treatmentId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEdit ? 'Modifier l\'ordonnance' : 'Nouvelle ordonnance',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator(color: _coral))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nom du médicament
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom du médicament *',
                        hintText: 'Ex: Amoxicilline, Metacam...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.medication),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est obligatoire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dosage
                    TextFormField(
                      controller: _dosageController,
                      decoration: InputDecoration(
                        labelText: 'Dosage',
                        hintText: 'Ex: 1 comprimé, 5ml...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fréquence
                    TextFormField(
                      controller: _frequencyController,
                      decoration: InputDecoration(
                        labelText: 'Fréquence',
                        hintText: 'Ex: 2x/jour, Matin et soir...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date de début
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de début *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_startDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date de fin
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate.add(const Duration(days: 7)),
                          firstDate: _startDate,
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) {
                          setState(() => _endDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de fin',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.event),
                          suffixIcon: _endDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _endDate = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat('dd/MM/yyyy').format(_endDate!)
                              : 'Non définie',
                          style: TextStyle(
                            fontSize: 16,
                            color: _endDate != null ? _ink : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actif
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      title: const Text('Traitement actif'),
                      subtitle: Text(_isActive ? 'En cours' : 'Terminé'),
                      activeColor: _mint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      tileColor: Colors.white,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Informations complémentaires...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Section: Images d'ordonnances
                    Row(
                      children: [
                        const Text(
                          'Images d\'ordonnances',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickAndUploadImage,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_photo_alternate),
                          label: Text(_isUploading ? 'Upload...' : 'Ajouter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _mint,
                            side: BorderSide(color: _mint),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Prévisualisation des images
                    if (_attachmentUrls.isNotEmpty)
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: _attachmentUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _attachmentUrls[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey.shade200,
                                      child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: _coral,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Aucune image',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Submit Button
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _mint,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEdit ? 'Mettre à jour' : 'Créer',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
