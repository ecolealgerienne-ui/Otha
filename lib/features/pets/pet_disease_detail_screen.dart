// lib/features/pets/pet_disease_detail_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF36C6C);
const _mint = Color(0xFF4ECDC4);
const _ink = Color(0xFF222222);
const _orange = Color(0xFFF39C12);
const _purple = Color(0xFF9B59B6);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

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
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final diseaseAsync = ref.watch(diseaseDetailProvider((petId: petId, diseaseId: diseaseId)));

    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      body: diseaseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (error, stack) => _buildError(context, error.toString(), ref, isDark, l10n, textPrimary, textSecondary),
        data: (disease) => _buildContent(context, ref, disease, isDark, l10n, textPrimary, textSecondary),
      ),
      floatingActionButton: diseaseAsync.maybeWhen(
        data: (disease) {
          final status = disease['status']?.toString() ?? 'ONGOING';
          if (status != 'CURED') {
            return FloatingActionButton.extended(
              onPressed: () {
                _showAddProgressDialog(context, ref, isDark, l10n, textPrimary, textSecondary);
              },
              backgroundColor: _orange,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
              label: Text(
                l10n.update,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            );
          }
          return null;
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> disease,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color textSecondary,
  ) {
    final name = disease['name']?.toString() ?? l10n.diseaseFollowUp;
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
    final cardColor = isDark ? _darkCard : Colors.white;

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
              color: cardColor,
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/pets/$petId/diseases/$diseaseId/edit').then((_) {
                    ref.invalidate(diseaseDetailProvider((petId: petId, diseaseId: diseaseId)));
                  });
                } else if (value == 'delete') {
                  _confirmDelete(context, ref, name, isDark, l10n, textPrimary);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l10n.edit, style: TextStyle(color: textPrimary)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.delete, style: TextStyle(color: textPrimary)),
                ),
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
                      _getStatusLabel(status, l10n),
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
                        _getSeverityLabel(severity, l10n),
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
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Photo gallery
              if (images.isNotEmpty) ...[
                _buildSectionTitle(l10n.photos, Icons.photo_library, textPrimary),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showFullscreenImage(context, images[index], images, index, isDark, l10n),
                        child: Hero(
                          tag: 'disease_image_$index',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              images[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Informations
              _buildSectionTitle(l10n.information, Icons.info_outline, textPrimary),
              const SizedBox(height: 12),
              _buildInfoCard([
                if (diagnosisDate != null)
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: l10n.diagnosis,
                    value: DateFormat('dd/MM/yyyy').format(diagnosisDate),
                  ),
                if (curedDate != null)
                  _InfoRow(
                    icon: Icons.check_circle,
                    label: l10n.healingDate,
                    value: DateFormat('dd/MM/yyyy').format(curedDate),
                    valueColor: _mint,
                  ),
                if (vetName != null)
                  _InfoRow(
                    icon: Icons.medical_services,
                    label: l10n.veterinarian,
                    value: vetName,
                  ),
              ], isDark, textPrimary, textSecondary),
              const SizedBox(height: 24),

              // Symptoms
              if (symptoms != null) ...[
                _buildSectionTitle(l10n.symptoms, Icons.sick, textPrimary),
                const SizedBox(height: 12),
                _buildTextCard(symptoms, isDark, textSecondary),
                const SizedBox(height: 24),
              ],

              // Treatment
              if (treatment != null) ...[
                _buildSectionTitle(l10n.treatment, Icons.medication, textPrimary),
                const SizedBox(height: 12),
                _buildTextCard(treatment, isDark, textSecondary),
                const SizedBox(height: 24),
              ],

              // Notes
              if (notes != null) ...[
                _buildSectionTitle(l10n.notes, Icons.note, textPrimary),
                const SizedBox(height: 12),
                _buildTextCard(notes, isDark, textSecondary),
                const SizedBox(height: 24),
              ],

              // Timeline
              if (progressEntries.isNotEmpty) ...[
                _buildSectionTitle(l10n.evolution, Icons.timeline, textPrimary),
                const SizedBox(height: 16),
                ...progressEntries.asMap().entries.map((entry) {
                  final isLast = entry.key == progressEntries.length - 1;
                  return _buildTimelineEntry(entry.value, isLast, isDark, l10n, textSecondary);
                }),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color textPrimary) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows, bool isDark, Color textPrimary, Color textSecondary) {
    final cardColor = isDark ? _darkCard : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : const [
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
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(rows[i].icon, size: 16, color: textSecondary),
                const SizedBox(width: 12),
                Text(
                  '${rows[i].label}:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rows[i].value,
                    style: TextStyle(
                      fontSize: 13,
                      color: rows[i].valueColor ?? textPrimary,
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

  Widget _buildTextCard(String text, bool isDark, Color textSecondary) {
    final cardColor = isDark ? _darkCard : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : const [
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
          color: textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTimelineEntry(Map<String, dynamic> entry, bool isLast, bool isDark, AppLocalizations l10n, Color textSecondary) {
    final date = entry['date'] != null
        ? DateTime.parse(entry['date'].toString())
        : null;
    final notes = entry['notes']?.toString() ?? '';
    final severity = entry['severity']?.toString();
    final treatmentUpdate = entry['treatmentUpdate']?.toString();
    final images = (entry['images'] as List?)?.cast<String>() ?? [];

    final cardColor = isDark ? _darkCard : Colors.white;

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
                  border: Border.all(color: isDark ? _darkCard : Colors.white, width: 2),
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
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDark ? null : const [
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
                        Icon(Icons.access_time, size: 14, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          date != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(date)
                              : l10n.unknownDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
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
                              _getSeverityLabel(severity, l10n),
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
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (treatmentUpdate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _mint.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.medication, size: 16, color: _mint),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                treatmentUpdate,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
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
                            return GestureDetector(
                              onTap: () => _showFullscreenImage(context, images[index], images, index, isDark, l10n),
                              child: Hero(
                                tag: 'progress_image_${entry.hashCode}_$index',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    images[index],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80,
                                      height: 80,
                                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                      child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 30),
                                    ),
                                  ),
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

  void _showFullscreenImage(BuildContext context, String imageUrl, List<String> allImages, int initialIndex, bool isDark, AppLocalizations l10n) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenImageViewer(
            images: allImages,
            initialIndex: initialIndex,
            l10n: l10n,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showAddProgressDialog(BuildContext context, WidgetRef ref, bool isDark, AppLocalizations l10n, Color textPrimary, Color textSecondary) {
    showDialog(
      context: context,
      builder: (context) => _AddProgressDialog(
        petId: petId,
        diseaseId: diseaseId,
        isDark: isDark,
        l10n: l10n,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        onSuccess: () {
          ref.invalidate(diseaseDetailProvider((petId: petId, diseaseId: diseaseId)));
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String name, bool isDark, AppLocalizations l10n, Color textPrimary) {
    final dialogBg = isDark ? _darkCard : Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(l10n.deleteDisease, style: TextStyle(color: textPrimary)),
        content: Text(
          '${l10n.confirmDeleteDisease} "$name" ? ${l10n.actionIrreversible}',
          style: TextStyle(color: textPrimary.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
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
                    SnackBar(
                      content: Text(l10n.diseaseDeleted),
                      backgroundColor: _coral,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.error}: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: Text(l10n.delete),
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

  String _getStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'ONGOING':
        return l10n.ongoingStatus;
      case 'CURED':
        return l10n.cured;
      case 'CHRONIC':
        return l10n.chronicStatus;
      case 'MONITORING':
        return l10n.monitoringStatus;
      default:
        return status;
    }
  }

  String _getSeverityLabel(String severity, AppLocalizations l10n) {
    switch (severity) {
      case 'MILD':
        return l10n.mildSeverity;
      case 'MODERATE':
        return l10n.moderateSeverity;
      case 'SEVERE':
        return l10n.severeSeverity;
      default:
        return severity;
    }
  }

  Widget _buildError(BuildContext context, String error, WidgetRef ref, bool isDark, AppLocalizations l10n, Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            l10n.error,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: textSecondary)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: Text(l10n.goBack),
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

/// Fullscreen image viewer with swipe navigation
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final AppLocalizations l10n;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
    required this.l10n,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Black background
            Container(color: Colors.black.withOpacity(0.95)),
            // Image PageView
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {}, // Prevent closing when tapping image
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: _coral,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              widget.l10n.unableToLoadImage,
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
            // Page indicator (if multiple images)
            if (widget.images.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Current / Total indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.images.length,
                        (index) => Container(
                          width: index == _currentIndex ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _currentIndex
                                ? _coral
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for adding progress update with image upload support
class _AddProgressDialog extends ConsumerStatefulWidget {
  final String petId;
  final String diseaseId;
  final bool isDark;
  final AppLocalizations l10n;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onSuccess;

  const _AddProgressDialog({
    required this.petId,
    required this.diseaseId,
    required this.isDark,
    required this.l10n,
    required this.textPrimary,
    required this.textSecondary,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AddProgressDialog> createState() => _AddProgressDialogState();
}

class _AddProgressDialogState extends ConsumerState<_AddProgressDialog> {
  final _notesController = TextEditingController();
  final _treatmentController = TextEditingController();
  String? _selectedSeverity;
  final List<String> _imageUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    _treatmentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final api = ref.read(apiProvider);
      final url = await api.uploadLocalFile(
        File(pickedFile.path),
        folder: 'diseases',
      );
      setState(() {
        _imageUrls.add(url);
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.l10n.imageAdded),
            backgroundColor: _mint,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.l10n.imageUploadError}: $e'),
            backgroundColor: _coral,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.notesAreRequired)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiProvider);
      await api.addDiseaseProgress(
        widget.petId,
        widget.diseaseId,
        notes: _notesController.text.trim(),
        severity: _selectedSeverity,
        treatmentUpdate: _treatmentController.text.trim().isNotEmpty
            ? _treatmentController.text.trim()
            : null,
        images: _imageUrls.isNotEmpty ? _imageUrls : null,
      );

      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.l10n.updateAdded),
            backgroundColor: _mint,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.l10n.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogBg = widget.isDark ? _darkCard : Colors.white;

    return AlertDialog(
      backgroundColor: dialogBg,
      title: Text(widget.l10n.addUpdate, style: TextStyle(color: widget.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notes field
            TextField(
              controller: _notesController,
              style: TextStyle(color: widget.textPrimary),
              decoration: InputDecoration(
                labelText: widget.l10n.notesRequired,
                labelStyle: TextStyle(color: widget.textSecondary),
                hintText: widget.l10n.observedEvolution,
                hintStyle: TextStyle(color: widget.textSecondary.withOpacity(0.5)),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.textSecondary.withOpacity(0.3)),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Severity dropdown
            DropdownButtonFormField<String>(
              value: _selectedSeverity,
              dropdownColor: dialogBg,
              style: TextStyle(color: widget.textPrimary),
              decoration: InputDecoration(
                labelText: widget.l10n.severity,
                labelStyle: TextStyle(color: widget.textSecondary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.textSecondary.withOpacity(0.3)),
                ),
              ),
              items: [
                DropdownMenuItem(value: 'MILD', child: Text(widget.l10n.mildSeverity)),
                DropdownMenuItem(value: 'MODERATE', child: Text(widget.l10n.moderateSeverity)),
                DropdownMenuItem(value: 'SEVERE', child: Text(widget.l10n.severeSeverity)),
              ],
              onChanged: (value) => setState(() => _selectedSeverity = value),
            ),
            const SizedBox(height: 16),

            // Treatment update field
            TextField(
              controller: _treatmentController,
              style: TextStyle(color: widget.textPrimary),
              decoration: InputDecoration(
                labelText: widget.l10n.treatmentUpdate,
                labelStyle: TextStyle(color: widget.textSecondary),
                hintText: widget.l10n.dosageChangeMed,
                hintStyle: TextStyle(color: widget.textSecondary.withOpacity(0.5)),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.textSecondary.withOpacity(0.3)),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Image upload section
            Row(
              children: [
                Icon(Icons.photo_library, size: 18, color: widget.textSecondary),
                const SizedBox(width: 8),
                Text(
                  widget.l10n.photos,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_isUploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _orange,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _pickAndUploadImage,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: Text(widget.l10n.addPhoto),
                    style: TextButton.styleFrom(foregroundColor: _orange),
                  ),
              ],
            ),

            // Display uploaded images
            if (_imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _imageUrls[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _imageUrls.removeAt(index));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ] else if (!_isUploading) ...[
              const SizedBox(height: 8),
              Text(
                widget.l10n.noImages,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.textSecondary.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(widget.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSubmitting || _isUploading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _orange),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.l10n.addData),
        ),
      ],
    );
  }
}
