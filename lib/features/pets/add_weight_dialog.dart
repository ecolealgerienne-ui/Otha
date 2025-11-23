// lib/features/pets/add_weight_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);

Future<void> showAddWeightDialog(BuildContext context, WidgetRef ref, String petId, {Map<String, dynamic>? record}) async {
  final isEdit = record != null;
  final weightController = TextEditingController(
    text: record != null ? record['weightKg']?.toString() ?? '' : '',
  );
  final notesController = TextEditingController(
    text: record?['notes']?.toString() ?? '',
  );
  DateTime selectedDate = record != null && record['date'] != null
      ? DateTime.parse(record['date'].toString())
      : DateTime.now();
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(isEdit ? 'Modifier le poids' : 'Ajouter un poids'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Poids
                TextField(
                  controller: weightController,
                  decoration: InputDecoration(
                    labelText: 'Poids (kg) *',
                    hintText: 'Ex: 12.5',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.monitor_weight),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 16),

                // Date
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Informations complémentaires...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final weightText = weightController.text.trim();
                      if (weightText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Le poids est obligatoire')),
                        );
                        return;
                      }

                      final weight = double.tryParse(weightText);
                      if (weight == null || weight <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Poids invalide')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final api = ref.read(apiProvider);

                        if (isEdit) {
                          // Pour éditer, on doit supprimer et recréer (pas d'endpoint update)
                          await api.deleteWeightRecord(petId, record!['id'].toString());
                        }

                        await api.createWeightRecord(
                          petId,
                          weightKg: weight,
                          dateIso: selectedDate.toIso8601String(),
                          notes: notesController.text.trim().isNotEmpty
                              ? notesController.text.trim()
                              : null,
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Poids modifié' : 'Poids ajouté'),
                              backgroundColor: _mint,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: _coral),
                          );
                        }
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: _mint),
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(isEdit ? 'Modifier' : 'Ajouter'),
            ),
          ],
        );
      },
    ),
  );
}
