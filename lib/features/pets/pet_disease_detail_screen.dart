// lib/features/pets/pet_disease_detail_screen.dart
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

// Provider pour les détails d'une maladie
final diseaseDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String petId, String diseaseId})>((ref, params) async {
  final api = ref.read(apiProvider);
  final disease = await api.getDisease(params.petId, params.diseaseId);
  return disease;
});

class PetDiseaseDetailScreen extends ConsumerWidget {
  final String petId;
  final String diseaseId;

  const PetDiseaseDetailScreen({
    super.key,
    required this.petId,
    required this.diseaseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diseaseAsync = ref.watch(diseaseDetailProvider((petId: petId, diseaseId: diseaseId)));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: diseaseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (error, stack) => _buildError(context, error.toString(), ref),
        data: (disease) => _buildContent(context, ref, disease),
      ),
      floatingActionButton: diseaseAsync.maybeWhen(
        data: (disease) {
          final status = disease['status']?.toString() ?? 'ONGOING';
          if (status != 'CURED') {
            return FloatingActionButton.extended(
              onPressed: () {
                _showAddProgressDialog(context, ref);
              },
              backgroundColor: _orange,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
              label: const Text(
                'Mise à jour',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            );
          }
          return null;
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Map<String, dynamic> disease) {
    final name = disease['name']?.toString() ?? 'Maladie';
    final description = disease['description']?.toString();
    final status = disease['status']?.toString() ?? 'ONGOING';
    final severity = disease['severity']?.toString();
    final diagnosisDate = disease['diagnosisDate'] != null
        ? DateTime.parse(disease['diagnosisDate'].toString())
        : null;
    final curedDate = disease['curedDate'] != null
        ? DateTime.parse(disease['curedDate'].toString())
        : null;
    final vetName = disease['vetName']?.toString();
    final symptoms = disease['symptoms']?.toString();
    final treatment = disease['treatment']?.toString();
    final notes = disease['notes']?.toString();
    final images = (disease['images'] as List?)?.cast<String>() ?? [];
    final progressEntries = (disease['progressEntries'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final statusColor = _getStatusColor(status);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: statusColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/pets/$petId/diseases/$diseaseId/edit').then((_) {
                    ref.invalidate(diseaseDetailProvider((petId: petId, diseaseId: diseaseId)));
                  });
                } else if (value == 'delete') {
                  _confirmDelete(context, ref, name);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    _getStatusIcon(status),
                    size: 60,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Status & Severity badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (severity != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(severity),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getSeverityLabel(severity),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Description
              if (description != null) ...[
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Photo gallery
              if (images.isNotEmpty) ...[
                _buildSectionTitle('Photos', Icons.photo_library),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          images[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey.shade200,
                            child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Informations
              _buildSectionTitle('Informations', Icons.info_outline),
              const SizedBox(height: 12),
              _buildInfoCard([
                if (diagnosisDate != null)
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Diagnostic',
                    value: DateFormat('dd/MM/yyyy').format(diagnosisDate),
                  ),
                if (curedDate != null)
                  _InfoRow(
                    icon: Icons.check_circle,
                    label: 'Date de guérison',
                    value: DateFormat('dd/MM/yyyy').format(curedDate),
                    valueColor: _mint,
                  ),
                if (vetName != null)
                  _InfoRow(
                    icon: Icons.medical_services,
                    label: 'Vétérinaire',
                    value: vetName,
                  ),
              ]),
              const SizedBox(height: 24),

              // Symptoms
              if (symptoms != null) ...[
                _buildSectionTitle('Symptômes', Icons.sick),
                const SizedBox(height: 12),
                _buildTextCard(symptoms),
                const SizedBox(height: 24),
              ],

              // Treatment
              if (treatment != null) ...[
                _buildSectionTitle('Traitement', Icons.medication),
                const SizedBox(height: 12),
                _buildTextCard(treatment),
                const SizedBox(height: 24),
              ],

              // Notes
              if (notes != null) ...[
                _buildSectionTitle('Notes', Icons.note),
                const SizedBox(height: 12),
                _buildTextCard(notes),
                const SizedBox(height: 24),
              ],

              // Timeline
              if (progressEntries.isNotEmpty) ...[
                _buildSectionTitle('Évolution', Icons.timeline),
                const SizedBox(height: 16),
                ...progressEntries.asMap().entries.map((entry) {
                  final isLast = entry.key == progressEntries.length - 1;
                  return _buildTimelineEntry(entry.value, isLast);
                }),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _ink),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(rows[i].icon, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  '${rows[i].label}:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rows[i].value,
                    style: TextStyle(
                      fontSize: 13,
                      color: rows[i].valueColor ?? _ink,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTimelineEntry(Map<String, dynamic> entry, bool isLast) {
    final date = entry['date'] != null
        ? DateTime.parse(entry['date'].toString())
        : null;
    final notes = entry['notes']?.toString() ?? '';
    final severity = entry['severity']?.toString();
    final treatmentUpdate = entry['treatmentUpdate']?.toString();
    final images = (entry['images'] as List?)?.cast<String>() ?? [];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: _orange.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          date != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(date)
                              : 'Date inconnue',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (severity != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getSeverityColor(severity).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getSeverityLabel(severity),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getSeverityColor(severity),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notes,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    if (treatmentUpdate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _mint.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.medication, size: 16, color: _mint),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                treatmentUpdate,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                images[index],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 30),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProgressDialog(BuildContext context, WidgetRef ref) {
    final notesController = TextEditingController();
    String? selectedSeverity;
    final treatmentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une mise à jour'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes *',
                  hintText: 'Évolution observée...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSeverity,
                decoration: const InputDecoration(
                  labelText: 'Sévérité',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'MILD', child: Text('Légère')),
                  DropdownMenuItem(value: 'MODERATE', child: Text('Modérée')),
                  DropdownMenuItem(value: 'SEVERE', child: Text('Sévère')),
                ],
                onChanged: (value) => selectedSeverity = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: treatmentController,
                decoration: const InputDecoration(
                  labelText: 'Mise à jour traitement',
                  hintText: 'Changement de dosage, nouveau médicament...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Les notes sont obligatoires')),
                );
                return;
              }

              try {
                final api = ref.read(apiProvider);
                await api.addDiseaseProgress(
                  petId,
                  diseaseId,
                  notes: notesController.text.trim(),
                  severity: selectedSeverity,
                  treatmentUpdate: treatmentController.text.trim().isNotEmpty
                      ? treatmentController.text.trim()
                      : null,
                );

                ref.invalidate(diseaseDetailProvider((petId: petId, diseaseId: diseaseId)));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mise à jour ajoutée'),
                      backgroundColor: _mint,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _orange),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la maladie'),
        content: Text('Êtes-vous sûr de vouloir supprimer "$name" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final api = ref.read(apiProvider);
                await api.deleteDisease(petId, diseaseId);

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Return to list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Maladie supprimée'),
                      backgroundColor: _coral,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ONGOING':
        return _coral;
      case 'CURED':
        return _mint;
      case 'CHRONIC':
        return _orange;
      case 'MONITORING':
        return _purple;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'MILD':
        return _mint;
      case 'MODERATE':
        return _orange;
      case 'SEVERE':
        return _coral;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'ONGOING':
        return Icons.monitor_heart_rounded;
      case 'CURED':
        return Icons.check_circle_rounded;
      case 'CHRONIC':
        return Icons.sync_rounded;
      case 'MONITORING':
        return Icons.visibility_rounded;
      default:
        return Icons.medical_information;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'ONGOING':
        return 'En cours';
      case 'CURED':
        return 'Guérie';
      case 'CHRONIC':
        return 'Chronique';
      case 'MONITORING':
        return 'Surveillance';
      default:
        return status;
    }
  }

  String _getSeverityLabel(String severity) {
    switch (severity) {
      case 'MILD':
        return 'Légère';
      case 'MODERATE':
        return 'Modérée';
      case 'SEVERE':
        return 'Sévère';
      default:
        return severity;
    }
  }

  Widget _buildError(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Erreur',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
}
