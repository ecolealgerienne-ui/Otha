// lib/features/adopt/adopt_create_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';

const _roseSoft = Color(0xFFFFEEF0);
const _roseBorder = Color(0xFFFFD6DA);

final _myPostsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.myAdoptPosts();
});

class AdoptCreateScreen extends ConsumerWidget {
  const AdoptCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(_myPostsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mes annonces',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const _CreateEditPostScreen()),
                      ).then((_) => ref.invalidate(_myPostsProvider));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A8A), // Rose saumon
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer'),
                  ),
                ],
              ),
            ),

            // Posts list
            Expanded(
              child: postsAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pets, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune annonce',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Créez votre première annonce',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return _PostCard(
                        post: post,
                        onEdit: () {
                          // Vérifier si l'annonce est adoptée
                          final status = post['status']?.toString() ?? '';
                          if (status == 'ADOPTED') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Modification impossible'),
                                content: const Text('Cette annonce a déjà été adoptée et ne peut plus être modifiée.'),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _CreateEditPostScreen(post: post),
                            ),
                          ).then((_) => ref.invalidate(_myPostsProvider));
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Supprimer'),
                              content: const Text('Supprimer cette annonce ?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              final api = ref.read(apiProvider);
                              await api.deleteAdoptPost(post['id'].toString());
                              ref.invalidate(_myPostsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Annonce supprimée')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            }
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: $err'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(_myPostsProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  final Map<String, dynamic> post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _handleMarkAsAdopted(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    final postId = post['id']?.toString();
    if (postId == null) return;

    try {
      // Récupérer les conversations pour ce post
      final conversations = await api.getAdoptPostConversations(postId);

      if (!context.mounted) return;

      if (conversations.isEmpty) {
        // Aucune conversation, marquer simplement comme adopté
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Marquer comme adopté'),
            content: const Text(
              'Aucune conversation trouvée. Voulez-vous quand même marquer cet animal comme adopté ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF8A8A)),
                child: const Text('Marquer adopté'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await api.markAdoptPostAsAdopted(postId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Animal marqué comme adopté')),
            );
            ref.invalidate(_myPostsProvider);
          }
        }
      } else {
        // Afficher la liste des contacts pour choisir l'adoptant
        final adopterId = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Qui a adopté cet animal ?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sélectionnez la personne qui a adopté l\'animal :'),
                  const SizedBox(height: 16),
                  ...conversations.map((conv) {
                    final name = conv['adopterName']?.toString() ?? 'Anonyme';
                    final lastMsg = conv['lastMessage']?.toString() ?? '';
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        lastMsg.isEmpty ? 'Aucun message' : lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFEEF0),
                        child: Icon(Icons.person, color: Color(0xFFFF8A8A)),
                      ),
                      onTap: () => Navigator.pop(ctx, conv['adopterId']?.toString()),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
            ],
          ),
        );

        if (adopterId != null) {
          await api.markAdoptPostAsAdopted(postId, adoptedById: adopterId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Animal marqué comme adopté')),
            );
            ref.invalidate(_myPostsProvider);
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final ageText = ageMonths != null
        ? ageMonths < 12
            ? '$ageMonths mois'
            : '${(ageMonths / 12).floor()} an${ageMonths >= 24 ? 's' : ''}'
        : '';

    // Priorité à "Adopté" si adoptedAt existe
    final isAdopted = adoptedAt != null;
    final statusColor = isAdopted
        ? const Color(0xFF4CAF50) // Vert pour adopté
        : status == 'APPROVED'
            ? Colors.green
            : status == 'REJECTED'
                ? Colors.red
                : Colors.orange;

    final statusText = isAdopted
        ? 'Adopté ✓'
        : status == 'APPROVED'
            ? 'Approuvée'
            : status == 'REJECTED'
                ? 'Refusée'
                : 'En attente';

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
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: Icon(Icons.pets, color: Colors.grey[400]),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: Icon(Icons.pets, color: Colors.grey[400]),
                        ),
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
                      Text(
                        [species, ageText, city].where((s) => s.isNotEmpty).join(' • '),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'adopted') _handleMarkAsAdopted(context, ref);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    if (!isAdopted) // N'afficher "Adopté" que si pas encore adopté
                      const PopupMenuItem(
                        value: 'adopted',
                        child: Row(
                          children: [
                            Icon(Icons.pets, size: 18, color: Color(0xFF4CAF50)),
                            SizedBox(width: 8),
                            Text('Marquer adopté'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
          ),
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

  // Map backend sex enum (M/F/U) to dropdown values (male/female/unknown)
  String _mapSexFromBackend(String? backendSex) {
    if (backendSex == null) return 'unknown';
    final s = backendSex.toUpperCase();
    if (s == 'M') return 'male';
    if (s == 'F') return 'female';
    if (s == 'U') return 'unknown';
    // Fallback pour valeurs lowercase complètes
    final lower = backendSex.toLowerCase();
    if (lower == 'male' || lower == 'female' || lower == 'unknown') return lower;
    return 'unknown';
  }

  // Map dropdown value back to backend enum (male → M, female → F, unknown → U)
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

    // Normaliser species en lowercase pour matcher le dropdown
    _species = (p?['species']?.toString() ?? 'dog').toLowerCase();

    // Mapper sex depuis le backend (M/F/U) vers le dropdown (male/female/unknown)
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
        const SnackBar(content: Text('Ajoute au moins une photo')),
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

      // Parse age text to months
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
          sex: _mapSexToBackend(_sex), // Convertir vers enum backend (M/F/U)
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
          sex: _mapSexToBackend(_sex), // Convertir vers enum backend (M/F/U)
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
                ? 'Annonce modifiée - en validation admin'
                : 'Annonce créée - en validation admin'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.post != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier l\'annonce' : 'Nouvelle annonce'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Title
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Titre de l\'annonce *',
                  hintText: 'Ex: Chiot adorable cherche famille',
                  filled: true,
                  fillColor: _roseSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
                maxLength: 140,
              ),
              const SizedBox(height: 16),

              // Animal name
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'animal',
                  hintText: 'Ex: Max',
                  filled: true,
                  fillColor: _roseSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 16),

              // Species & Sex
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
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
                        fillColor: _roseSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
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
                        fillColor: _roseSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Age
              TextFormField(
                controller: _age,
                decoration: InputDecoration(
                  labelText: 'Âge',
                  hintText: 'Ex: 3 mois, 2 ans',
                  filled: true,
                  fillColor: _roseSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // City
              TextFormField(
                controller: _city,
                decoration: InputDecoration(
                  labelText: 'Ville',
                  filled: true,
                  fillColor: _roseSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _desc,
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  fillColor: _roseSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              // Photos
              const Text(
                'Photos (max 3)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Existing images
                  ...List.generate(_existingImageUrls.length, (i) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _existingImageUrls[i],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _removeExistingImage(i),
                          ),
                        ),
                      ],
                    );
                  }),
                  // New images
                  ...List.generate(_newImages.length, (i) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_newImages[i].path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _removeNewImage(i),
                          ),
                        ),
                      ],
                    );
                  }),
                  // Add button
                  if (_newImages.length + _existingImageUrls.length < 3)
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _roseSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _roseBorder, width: 2),
                        ),
                        child: Icon(Icons.add_a_photo, color: Colors.grey[600], size: 32),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit button
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A8A), // Rose saumon
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _submitting
                      ? 'Publication…'
                      : isEdit
                          ? 'Modifier l\'annonce'
                          : 'Publier l\'annonce',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
