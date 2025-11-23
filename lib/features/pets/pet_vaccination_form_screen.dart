// lib/features/pets/pet_vaccination_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);
const _purple = Color(0xFF9B59B6);

class PetVaccinationFormScreen extends ConsumerStatefulWidget {
  final String petId;
  final String? vaccinationId; // null = create, non-null = edit

  const PetVaccinationFormScreen({
    super.key,
    required this.petId,
    this.vaccinationId,
  });

  @override
  ConsumerState<PetVaccinationFormScreen> createState() => _PetVaccinationFormScreenState();
}

class _PetVaccinationFormScreenState extends ConsumerState<PetVaccinationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _vetNameController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _date = DateTime.now();
  DateTime? _nextDueDate;

  bool _isLoading = false;
  bool _isLoadingInitial = false;

  @override
  void initState() {
    super.initState();
    if (widget.vaccinationId != null) {
      _loadVaccination();
    }
  }

  Future<void> _loadVaccination() async {
    setState(() => _isLoadingInitial = true);
    try {
      final api = ref.read(apiProvider);
      final vaccinations = await api.getVaccinations(widget.petId);
      final vaccination = vaccinations.firstWhere(
        (v) => v['id'] == widget.vaccinationId,
        orElse: () => throw Exception('Vaccination non trouvée'),
      );

      _nameController.text = vaccination['name']?.toString() ?? '';
      _batchNumberController.text = vaccination['batchNumber']?.toString() ?? '';
      _vetNameController.text = vaccination['vetName']?.toString() ?? '';
      _notesController.text = vaccination['notes']?.toString() ?? '';

      setState(() {
        if (vaccination['date'] != null) {
          _date = DateTime.parse(vaccination['date'].toString());
        }
        if (vaccination['nextDueDate'] != null) {
          _nextDueDate = DateTime.parse(vaccination['nextDueDate'].toString());
        }
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
    _batchNumberController.dispose();
    _vetNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);

      if (widget.vaccinationId == null) {
        // Create
        await api.createVaccination(
          widget.petId,
          name: _nameController.text.trim(),
          dateIso: _date.toIso8601String(),
          nextDueDateIso: _nextDueDate?.toIso8601String(),
          batchNumber: _batchNumberController.text.trim().isNotEmpty
              ? _batchNumberController.text.trim()
              : null,
          vetName: _vetNameController.text.trim().isNotEmpty
              ? _vetNameController.text.trim()
              : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vaccin ajouté'),
              backgroundColor: _mint,
            ),
          );
        }
      } else {
        // Update - API doesn't have update method, so delete and recreate
        // For now, show message that edit is not supported
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modification non disponible. Supprimez et recréez le vaccin.'),
              backgroundColor: _coral,
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
    final isEdit = widget.vaccinationId != null;

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
          isEdit ? 'Modifier le vaccin' : 'Nouveau vaccin',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nom du vaccin
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom du vaccin *',
                        hintText: 'Ex: Rage, DHLPP, Vaccin antirabique...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.vaccines),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est obligatoire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date de vaccination
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de vaccination *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_date),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date de rappel
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _nextDueDate ?? _date.add(const Duration(days: 365)),
                          firstDate: _date,
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setState(() => _nextDueDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de rappel',
                          hintText: 'Optionnel',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.event),
                          suffixIcon: _nextDueDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _nextDueDate = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _nextDueDate != null
                              ? DateFormat('dd/MM/yyyy').format(_nextDueDate!)
                              : 'Non défini',
                          style: TextStyle(
                            fontSize: 16,
                            color: _nextDueDate != null ? _ink : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Informations complémentaires
                    const Text(
                      'Informations complémentaires',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Numéro de lot
                    TextFormField(
                      controller: _batchNumberController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de lot',
                        hintText: 'Ex: ABC123XYZ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vétérinaire
                    TextFormField(
                      controller: _vetNameController,
                      decoration: InputDecoration(
                        labelText: 'Vétérinaire',
                        hintText: 'Dr. Martin',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.medical_services),
                      ),
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
                    const SizedBox(height: 32),

                    // Submit Button
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
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
