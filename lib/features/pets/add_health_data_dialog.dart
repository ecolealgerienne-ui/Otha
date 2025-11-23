// lib/features/pets/add_health_data_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);

Future<void> showAddHealthDataDialog(BuildContext context, WidgetRef ref, String petId) async {
  final temperatureController = TextEditingController();
  final heartRateController = TextEditingController();
  final notesController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Ajouter des données de santé'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajoutez au moins une donnée',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),

                // Température
                TextField(
                  controller: temperatureController,
                  decoration: InputDecoration(
                    labelText: 'Température (°C)',
                    hintText: 'Ex: 38.5',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.thermostat),
                    helperText: 'Normal: 38-39°C',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                ),
                const SizedBox(height: 16),

                // Rythme cardiaque
                TextField(
                  controller: heartRateController,
                  decoration: InputDecoration(
                    labelText: 'Rythme cardiaque (bpm)',
                    hintText: 'Ex: 80',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.favorite),
                    helperText: 'Normal: 60-140 bpm',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
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
                    hintText: 'Observations...',
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
                      final tempText = temperatureController.text.trim();
                      final hrText = heartRateController.text.trim();

                      if (tempText.isEmpty && hrText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ajoutez au moins une donnée (température ou rythme cardiaque)'),
                          ),
                        );
                        return;
                      }

                      double? temperature;
                      int? heartRate;

                      if (tempText.isNotEmpty) {
                        temperature = double.tryParse(tempText);
                        if (temperature == null || temperature < 30 || temperature > 45) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Température invalide (30-45°C)')),
                          );
                          return;
                        }
                      }

                      if (hrText.isNotEmpty) {
                        heartRate = int.tryParse(hrText);
                        if (heartRate == null || heartRate < 20 || heartRate > 300) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rythme cardiaque invalide (20-300 bpm)')),
                          );
                          return;
                        }
                      }

                      setState(() => isLoading = true);

                      try {
                        final api = ref.read(apiProvider);

                        // Créer un medical record avec les données de santé
                        await api.createMedicalRecord(
                          petId,
                          type: 'HEALTH_CHECK',
                          title: 'Contrôle de santé',
                          dateIso: selectedDate.toIso8601String(),
                          description: 'Données de santé enregistrées manuellement',
                          temperatureC: temperature,
                          heartRate: heartRate,
                          notes: notesController.text.trim().isNotEmpty
                              ? notesController.text.trim()
                              : null,
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Données de santé ajoutées'),
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
                  : const Text('Ajouter'),
            ),
          ],
        );
      },
    ),
  );
}
