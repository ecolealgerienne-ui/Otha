// lib/features/adopt/adopt_create_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _rosePrimary = Color(0xFFFF6B6B);
const _roseLight = Color(0xFFFFE8E8);
const _greenSuccess = Color(0xFF4CD964);

final _myPostsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.myAdoptPosts();
});

class AdoptCreateScreen extends ConsumerWidget {
  const AdoptCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(_myPostsProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: topPadding + 8, left: 16, right: 16, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _roseLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.list_alt, color: _rosePrimary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Mes annonces',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _CreateEditPostScreen()),
                    ).then((_) => ref.invalidate(_myPostsProvider));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _rosePrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Créer', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return _EmptyState(
                    onCreatePost: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const _CreateEditPostScreen()),
                      ).then((_) => ref.invalidate(_myPostsProvider));
                    },
                  );
                }

                // Stats summary
                final approved = posts.where((p) => p['status'] == 'APPROVED').length;
                final pending = posts.where((p) => p['status'] == 'PENDING').length;
                final adopted = posts.where((p) => p['adoptedAt'] != null).length;

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_myPostsProvider),
                  color: _rosePrimary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Stats cards
                      Row(
                        children: [
                          _StatCard(value: '${posts.length}', label: 'Total', color: Colors.grey),
                          const SizedBox(width: 8),
                          _StatCard(value: '$approved', label: 'Actives', color: _greenSuccess),
                          const SizedBox(width: 8),
                          _StatCard(value: '$pending', label: 'En attente', color: Colors.orange),
                          const SizedBox(width: 8),
                          _StatCard(value: '$adopted', label: 'Adoptées', color: _rosePrimary),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Posts list
                      ...posts.map((post) => _PostCard(
                        post: post,
                        onEdit: () {
                          final status = post['status']?.toString() ?? '';
                          if (status == 'ADOPTED' || post['adoptedAt'] != null) {
                            _showDialog(
                              context,
                              'Modification impossible',
                              'Cette annonce a déjà été adoptée et ne peut plus être modifiée.',
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _CreateEditPostScreen(post: post)),
                          ).then((_) => ref.invalidate(_myPostsProvider));
                        },
                        onDelete: () => _confirmDelete(context, ref, post),
                      )),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: _roseLight,
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(color: _rosePrimary),
                    ),
                  ],
                ),
              ),
              error: (err, _) => _ErrorState(
                error: err.toString(),
                onRetry: () => ref.invalidate(_myPostsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(content),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: _rosePrimary),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer l\'annonce'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        final api = ref.read(apiProvider);
        await api.deleteAdoptPost(post['id'].toString());
        ref.invalidate(_myPostsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Annonce supprimée'),
              backgroundColor: Colors.grey[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// Stats card widget
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Post card widget
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final images = (post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    final title = (post['title'] ?? post['animalName'] ?? 'Animal').toString();
    final species = (post['species'] ?? '').toString();
    final city = (post['city'] ?? '').toString();
    final status = (post['status'] ?? 'PENDING').toString();
    final ageMonths = post['ageMonths'] as int?;
    final adoptedAt = post['adoptedAt'];
    final isAdopted = adoptedAt != null;

    final ageText = ageMonths != null
        ? ageMonths < 12
            ? '$ageMonths mois'
            : '${(ageMonths / 12).floor()} an${ageMonths >= 24 ? 's' : ''}'
        : '';

    final speciesLabel = species == 'dog' ? 'Chien' : species == 'cat' ? 'Chat' : species;

    // Status badge
    final statusColor = isAdopted
        ? _greenSuccess
        : status == 'APPROVED'
            ? _greenSuccess
            : status == 'REJECTED'
                ? Colors.red
                : Colors.orange;

    final statusText = isAdopted
        ? 'Adopté'
        : status == 'APPROVED'
            ? 'Active'
            : status == 'REJECTED'
                ? 'Refusée'
                : 'En attente';

    final statusIcon = isAdopted
        ? Icons.check_circle
        : status == 'APPROVED'
            ? Icons.visibility
            : status == 'REJECTED'
                ? Icons.cancel
                : Icons.hourglass_top;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAdopted ? null : onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image with status indicator
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: images.isNotEmpty
                          ? Image.network(
                              images.first,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Status badge on image
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(statusIcon, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (speciesLabel.isNotEmpty) ...[
                            Icon(Icons.pets, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              speciesLabel,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                          if (ageText.isNotEmpty) ...[
                            Text(' • ', style: TextStyle(color: Colors.grey[400])),
                            Text(
                              ageText,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                          if (city.isNotEmpty) ...[
                            Text(' • ', style: TextStyle(color: Colors.grey[400])),
                            Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                city,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Column(
                  children: [
                    if (!isAdopted)
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined, color: Colors.grey[600], size: 20),
                        tooltip: 'Modifier',
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      tooltip: 'Supprimer',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _roseLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.pets, color: _rosePrimary, size: 32),
    );
  }
}

// Empty state
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreatePost;

  const _EmptyState({required this.onCreatePost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _roseLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, size: 64, color: _rosePrimary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucune annonce',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première annonce\npour trouver un foyer à un animal',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onCreatePost,
              style: FilledButton.styleFrom(
                backgroundColor: _rosePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Créer une annonce', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// Error state
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _rosePrimary),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// Create/Edit screen
class _CreateEditPostScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? post;

  const _CreateEditPostScreen({this.post});

  @override
  ConsumerState<_CreateEditPostScreen> createState() => _CreateEditPostScreenState();
}

class _CreateEditPostScreenState extends ConsumerState<_CreateEditPostScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _city;
  late final TextEditingController _desc;

  String _species = 'dog';
  String _sex = 'unknown';
  final List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  bool _submitting = false;

  String _mapSexFromBackend(String? backendSex) {
    if (backendSex == null) return 'unknown';
    final s = backendSex.toUpperCase();
    if (s == 'M') return 'male';
    if (s == 'F') return 'female';
    if (s == 'U') return 'unknown';
    final lower = backendSex.toLowerCase();
    if (lower == 'male' || lower == 'female' || lower == 'unknown') return lower;
    return 'unknown';
  }

  String _mapSexToBackend(String dropdownValue) {
    if (dropdownValue == 'male') return 'M';
    if (dropdownValue == 'female') return 'F';
    return 'U';
  }

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _title = TextEditingController(text: p?['title']?.toString() ?? '');
    _name = TextEditingController(text: p?['animalName']?.toString() ?? '');
    _city = TextEditingController(text: p?['city']?.toString() ?? '');
    _desc = TextEditingController(text: p?['description']?.toString() ?? '');
    _species = (p?['species']?.toString() ?? 'dog').toLowerCase();
    _sex = _mapSexFromBackend(p?['sex']?.toString());

    final ageMonths = p?['ageMonths'] as int?;
    if (ageMonths != null) {
      if (ageMonths < 12) {
        _age = TextEditingController(text: '$ageMonths mois');
      } else {
        _age = TextEditingController(text: '${(ageMonths / 12).floor()} ans');
      }
    } else {
      _age = TextEditingController();
    }

    final images = (p?['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    _existingImageUrls = images ?? [];
  }

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _age.dispose();
    _city.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_newImages.length + _existingImageUrls.length >= 3) return;
    final pic = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (pic != null) setState(() => _newImages.add(pic));
  }

  void _removeNewImage(int i) => setState(() => _newImages.removeAt(i));
  void _removeExistingImage(int i) => setState(() => _existingImageUrls.removeAt(i));

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_newImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une photo')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiProvider);
      final urls = <String>[..._existingImageUrls];
      for (final x in _newImages) {
        final url = await api.uploadLocalFile(File(x.path), folder: 'adopt');
        urls.add(url);
      }

      int? ageMonths;
      final ageText = _age.text.trim().toLowerCase();
      if (ageText.isNotEmpty) {
        final monthsMatch = RegExp(r'(\d+)\s*mois').firstMatch(ageText);
        final yearsMatch = RegExp(r'(\d+)\s*an').firstMatch(ageText);
        if (monthsMatch != null) {
          ageMonths = int.tryParse(monthsMatch.group(1)!);
        } else if (yearsMatch != null) {
          final years = int.tryParse(yearsMatch.group(1)!);
          if (years != null) ageMonths = years * 12;
        }
      }

      final isEdit = widget.post != null;

      if (isEdit) {
        await api.updateAdoptPost(
          widget.post!['id'].toString(),
          title: _title.text.trim(),
          animalName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          species: _species,
          sex: _mapSexToBackend(_sex),
          ageMonths: ageMonths,
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          photos: urls,
        );
      } else {
        await api.createAdoptPost(
          title: _title.text.trim(),
          animalName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          species: _species,
          sex: _mapSexToBackend(_sex),
          ageMonths: ageMonths,
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          photos: urls,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Annonce modifiée - en validation'
                : 'Annonce créée - en validation'),
            backgroundColor: _greenSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.post != null;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: topPadding + 8, left: 12, right: 16, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _roseLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'Modifier l\'annonce' : 'Nouvelle annonce',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Photos section
                  _buildSectionTitle('Photos', Icons.photo_library, required: true),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Existing images
                        ..._existingImageUrls.asMap().entries.map((e) => _buildImageTile(
                          imageUrl: e.value,
                          onRemove: () => _removeExistingImage(e.key),
                        )),
                        // New images
                        ..._newImages.asMap().entries.map((e) => _buildImageTile(
                          file: File(e.value.path),
                          onRemove: () => _removeNewImage(e.key),
                        )),
                        // Add button
                        if (_newImages.length + _existingImageUrls.length < 3)
                          _buildAddImageButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  _buildSectionTitle('Informations', Icons.info_outline, required: true),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _title,
                    label: 'Titre de l\'annonce',
                    hint: 'Ex: Chiot adorable cherche famille',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    maxLength: 140,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _name,
                    label: 'Nom de l\'animal',
                    hint: 'Ex: Max',
                    maxLength: 100,
                  ),
                  const SizedBox(height: 12),

                  // Species & Sex
                  Row(
                    children: [
                      Expanded(child: _buildSpeciesDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSexDropdown()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Age & City
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _age,
                          label: 'Âge',
                          hint: 'Ex: 3 mois',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _city,
                          label: 'Ville',
                          hint: 'Ex: Alger',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  _buildTextField(
                    controller: _desc,
                    label: 'Description',
                    hint: 'Décrivez l\'animal, son caractère...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _rosePrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'Enregistrer les modifications' : 'Publier l\'annonce',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {bool required = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _rosePrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: Colors.red)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _rosePrimary, width: 2),
        ),
        counterText: '',
      ),
      validator: validator,
      maxLength: maxLength,
      maxLines: maxLines,
    );
  }

  Widget _buildSpeciesDropdown() {
    return DropdownButtonFormField<String>(
      value: _species,
      items: const [
        DropdownMenuItem(value: 'dog', child: Text('Chien')),
        DropdownMenuItem(value: 'cat', child: Text('Chat')),
        DropdownMenuItem(value: 'other', child: Text('Autre')),
      ],
      onChanged: (v) => setState(() => _species = v ?? 'dog'),
      decoration: InputDecoration(
        labelText: 'Espèce',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildSexDropdown() {
    return DropdownButtonFormField<String>(
      value: _sex,
      items: const [
        DropdownMenuItem(value: 'unknown', child: Text('Inconnu')),
        DropdownMenuItem(value: 'male', child: Text('Mâle')),
        DropdownMenuItem(value: 'female', child: Text('Femelle')),
      ],
      onChanged: (v) => setState(() => _sex = v ?? 'unknown'),
      decoration: InputDecoration(
        labelText: 'Sexe',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildImageTile({String? imageUrl, File? file, required VoidCallback onRemove}) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? Image.network(imageUrl, width: 100, height: 100, fit: BoxFit.cover)
                : Image.file(file!, width: 100, height: 100, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: _roseLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _rosePrimary.withOpacity(0.3), width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, color: _rosePrimary.withOpacity(0.7), size: 32),
            const SizedBox(height: 4),
            Text(
              'Ajouter',
              style: TextStyle(fontSize: 11, color: _rosePrimary.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
