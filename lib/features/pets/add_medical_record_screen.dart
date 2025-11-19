// lib/features/pets/add_medical_record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import 'pet_medical_history_screen.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

class AddMedicalRecordScreen extends ConsumerStatefulWidget {
  final String petId;
  final String? token; // Si présent, c'est un vétérinaire qui ajoute via QR

  const AddMedicalRecordScreen({super.key, required this.petId, this.token});

  @override
  ConsumerState<AddMedicalRecordScreen> createState() => _AddMedicalRecordScreenState();
}

class _AddMedicalRecordScreenState extends ConsumerState<AddMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vetNameController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'CHECKUP';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final _types = [
    ('VACCINATION', 'Vaccination', Icons.vaccines, Colors.green),
    ('SURGERY', 'Chirurgie', Icons.local_hospital, Colors.red),
    ('CHECKUP', 'Controle', Icons.health_and_safety, Colors.blue),
    ('TREATMENT', 'Traitement', Icons.healing, Colors.orange),
    ('MEDICATION', 'Medicament', Icons.medication, Colors.purple),
    ('OTHER', 'Autre', Icons.medical_services, _coral),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _vetNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _coral),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      final dateIso = _selectedDate.toUtc().toIso8601String();

      if (widget.token != null) {
        // Vétérinaire ajoute via QR token
        await api.createMedicalRecordByToken(
          widget.token!,
          type: _selectedType,
          title: _titleController.text.trim(),
          dateIso: dateIso,
          vetName: _vetNameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      } else {
        // Client ajoute pour son animal
        await api.createMedicalRecord(
          widget.petId,
          type: _selectedType,
          title: _titleController.text.trim(),
          dateIso: dateIso,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          vetName: _vetNameController.text.trim().isEmpty
              ? null
              : _vetNameController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      }

      if (mounted) {
        // Invalider le cache pour rafraîchir la liste
        ref.invalidate(medicalRecordsProvider(widget.petId));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record medical ajoute')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVet = widget.token != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isVet ? 'Ajouter un acte medical' : 'Nouveau record',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selection
            const Text(
              'Type d\'acte',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final isSelected = _selectedType == t.$1;
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$3, size: 16, color: isSelected ? Colors.white : t.$4),
                      const SizedBox(width: 6),
                      Text(t.$2),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedType = t.$1),
                  selectedColor: t.$4,
                  backgroundColor: t.$4.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : t.$4,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide.none,
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Titre *',
                hintText: 'Ex: Vaccination antirabique',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Titre requis' : null,
            ),
            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: const Icon(Icons.calendar_today, color: _coral),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Details de l\'acte medical...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Vet name
            TextFormField(
              controller: _vetNameController,
              decoration: InputDecoration(
                labelText: isVet ? 'Votre nom *' : 'Nom du veterinaire',
                hintText: 'Dr. ...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: isVet
                  ? (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null
                  : null,
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Observations, recommandations...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Submit button
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
