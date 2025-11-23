// lib/features/pets/pet_disease_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);
const _orange = Color(0xFFF39C12);
const _purple = Color(0xFF9B59B6);

class PetDiseaseFormScreen extends ConsumerStatefulWidget {
  final String petId;
  final String? diseaseId; // null = create, non-null = edit

  const PetDiseaseFormScreen({
    super.key,
    required this.petId,
    this.diseaseId,
  });

  @override
  ConsumerState<PetDiseaseFormScreen> createState() => _PetDiseaseFormScreenState();
}

class _PetDiseaseFormScreenState extends ConsumerState<PetDiseaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();
  final _vetNameController = TextEditingController();
  final _imagesController = TextEditingController();

  String _status = 'ONGOING';
  String? _severity;
  DateTime _diagnosisDate = DateTime.now();
  DateTime? _curedDate;

  bool _isLoading = false;
  bool _isLoadingInitial = false;

  @override
  void initState() {
    super.initState();
    if (widget.diseaseId != null) {
      _loadDisease();
    }
  }

  Future<void> _loadDisease() async {
    setState(() => _isLoadingInitial = true);
    try {
      final api = ref.read(apiProvider);
      final disease = await api.getDisease(widget.petId, widget.diseaseId!);

      _nameController.text = disease['name']?.toString() ?? '';
      _descriptionController.text = disease['description']?.toString() ?? '';
      _symptomsController.text = disease['symptoms']?.toString() ?? '';
      _treatmentController.text = disease['treatment']?.toString() ?? '';
      _notesController.text = disease['notes']?.toString() ?? '';
      _vetNameController.text = disease['vetName']?.toString() ?? '';

      setState(() {
        _status = disease['status']?.toString() ?? 'ONGOING';
        _severity = disease['severity']?.toString();
        if (disease['diagnosisDate'] != null) {
          _diagnosisDate = DateTime.parse(disease['diagnosisDate'].toString());
        }
        if (disease['curedDate'] != null) {
          _curedDate = DateTime.parse(disease['curedDate'].toString());
        }
        final images = (disease['images'] as List?)?.cast<String>() ?? [];
        _imagesController.text = images.join('\n');
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
    _descriptionController.dispose();
    _symptomsController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    _vetNameController.dispose();
    _imagesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);

      // Parse image URLs from text (one per line)
      final imageLines = _imagesController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (widget.diseaseId == null) {
        // Create
        await api.createDisease(
          widget.petId,
          name: _nameController.text.trim(),
          diagnosisDateIso: _diagnosisDate.toIso8601String(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          status: _status,
          severity: _severity,
          curedDateIso: _curedDate?.toIso8601String(),
          vetName: _vetNameController.text.trim().isNotEmpty
              ? _vetNameController.text.trim()
              : null,
          symptoms: _symptomsController.text.trim().isNotEmpty
              ? _symptomsController.text.trim()
              : null,
          treatment: _treatmentController.text.trim().isNotEmpty
              ? _treatmentController.text.trim()
              : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          images: imageLines.isNotEmpty ? imageLines : null,
        );

        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maladie ajoutée'),
              backgroundColor: _mint,
            ),
          );
        }
      } else {
        // Update
        await api.updateDisease(
          widget.petId,
          widget.diseaseId!,
          name: _nameController.text.trim(),
          diagnosisDateIso: _diagnosisDate.toIso8601String(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          status: _status,
          severity: _severity,
          curedDateIso: _curedDate?.toIso8601String(),
          vetName: _vetNameController.text.trim().isNotEmpty
              ? _vetNameController.text.trim()
              : null,
          symptoms: _symptomsController.text.trim().isNotEmpty
              ? _symptomsController.text.trim()
              : null,
          treatment: _treatmentController.text.trim().isNotEmpty
              ? _treatmentController.text.trim()
              : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          images: imageLines.isNotEmpty ? imageLines : null,
        );

        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maladie mise à jour'),
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
    final isEdit = widget.diseaseId != null;

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
          isEdit ? 'Modifier la maladie' : 'Nouvelle maladie',
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
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom de la maladie *',
                        hintText: 'Ex: Allergie cutanée, Otite...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est obligatoire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Description brève de la maladie',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Status
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: 'Statut *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ONGOING', child: Text('En cours')),
                        DropdownMenuItem(value: 'CURED', child: Text('Guérie')),
                        DropdownMenuItem(value: 'CHRONIC', child: Text('Chronique')),
                        DropdownMenuItem(value: 'MONITORING', child: Text('Sous surveillance')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value ?? 'ONGOING';
                          if (_status != 'CURED') {
                            _curedDate = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Severity
                    DropdownButtonFormField<String?>(
                      value: _severity,
                      decoration: InputDecoration(
                        labelText: 'Sévérité',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Non spécifié')),
                        DropdownMenuItem(value: 'MILD', child: Text('Légère')),
                        DropdownMenuItem(value: 'MODERATE', child: Text('Modérée')),
                        DropdownMenuItem(value: 'SEVERE', child: Text('Sévère')),
                      ],
                      onChanged: (value) => setState(() => _severity = value),
                    ),
                    const SizedBox(height: 16),

                    // Diagnosis Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _diagnosisDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _diagnosisDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de diagnostic *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_diagnosisDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cured Date (only if status is CURED)
                    if (_status == 'CURED') ...[
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _curedDate ?? DateTime.now(),
                            firstDate: _diagnosisDate,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _curedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date de guérison',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _curedDate != null
                                ? DateFormat('dd/MM/yyyy').format(_curedDate!)
                                : 'Non spécifié',
                            style: TextStyle(
                              fontSize: 16,
                              color: _curedDate != null ? _ink : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Vet Name
                    TextFormField(
                      controller: _vetNameController,
                      decoration: InputDecoration(
                        labelText: 'Nom du vétérinaire',
                        hintText: 'Dr. Martin',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.medical_services),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Détails médicaux
                    const Text(
                      'Détails médicaux',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Symptoms
                    TextFormField(
                      controller: _symptomsController,
                      decoration: InputDecoration(
                        labelText: 'Symptômes',
                        hintText: 'Toux, éternuements, perte d\'appétit...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Treatment
                    TextFormField(
                      controller: _treatmentController,
                      decoration: InputDecoration(
                        labelText: 'Traitement',
                        hintText: 'Antibiotiques, pommade...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
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

                    // Section: Photos
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URLs des images (une par ligne)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Images (URLs)
                    TextFormField(
                      controller: _imagesController,
                      decoration: InputDecoration(
                        labelText: 'URLs des images',
                        hintText: 'https://example.com/image1.jpg\nhttps://example.com/image2.jpg',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
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
