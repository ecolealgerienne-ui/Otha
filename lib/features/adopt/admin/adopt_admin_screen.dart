// lib/features/adopt/admin/adopt_admin_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api.dart';

class AdoptAdminScreen extends ConsumerStatefulWidget {
  const AdoptAdminScreen({super.key});

  @override
  ConsumerState<AdoptAdminScreen> createState() => _AdoptAdminScreenState();
}

class _AdoptAdminScreenState extends ConsumerState<AdoptAdminScreen> {
  List<Map<String, dynamic>> _posts = [];
  int _currentIndex = 0;
  bool _loading = false;
  String? _error;
  String? _cursor;

  @override
  void initState() {
    super.initState();
    _loadPendingPosts();
  }

  Future<void> _loadPendingPosts() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final result = await api.adminAdoptList(status: 'PENDING', limit: 10, cursor: _cursor);

      final posts = result['posts'] as List? ?? [];
      setState(() {
        if (_cursor == null) {
          _posts = posts.cast<Map<String, dynamic>>();
        } else {
          _posts.addAll(posts.cast<Map<String, dynamic>>());
        }
        _cursor = result['cursor'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _nextCard() {
    setState(() => _currentIndex++);

    // Load more when approaching the end
    if (_currentIndex >= _posts.length - 2 && _cursor != null && !_loading) {
      _loadPendingPosts();
    }
  }

  Future<void> _approve(String postId) async {
    try {
      final api = ref.read(apiProvider);
      await api.adminAdoptApprove(postId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Annonce approuvée'), backgroundColor: Colors.green),
        );
        _nextCard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(String postId) async {
    final reasons = await _showRejectDialog();
    if (reasons == null) return; // User cancelled

    try {
      final api = ref.read(apiProvider);
      await api.adminAdoptReject(postId, reasons: reasons);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Annonce rejetée'), backgroundColor: Colors.orange),
        );
        _nextCard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<List<String>?> _showRejectDialog() async {
    final selected = <String>{};

    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Raisons du refus'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: selected.contains('Nom inapproprié'),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) selected.add('Nom inapproprié');
                    else selected.remove('Nom inapproprié');
                  }),
                  title: const Text('Nom inapproprié'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: selected.contains('Description inappropriée'),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) selected.add('Description inappropriée');
                    else selected.remove('Description inappropriée');
                  }),
                  title: const Text('Description inappropriée'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: selected.contains('Photo inappropriée'),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) selected.add('Photo inappropriée');
                    else selected.remove('Photo inappropriée');
                  }),
                  title: const Text('Photo inappropriée'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: selected.contains('Contenu suspect'),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) selected.add('Contenu suspect');
                    else selected.remove('Contenu suspect');
                  }),
                  title: const Text('Contenu suspect'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: selected.contains('Informations manquantes'),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) selected.add('Informations manquantes');
                    else selected.remove('Informations manquantes');
                  }),
                  title: const Text('Informations manquantes'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: selected.contains('Doublon'),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) selected.add('Doublon');
                    else selected.remove('Doublon');
                  }),
                  title: const Text('Doublon'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: selected.contains('Autre'),
                  onChanged: (val) => setDialogState(() {
                    if (val == true) selected.add('Autre');
                    else selected.remove('Autre');
                  }),
                  title: const Text('Autre'),
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected.toList()),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _posts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modération Adoptions')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _posts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modération Adoptions')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erreur: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _cursor = null;
                  _currentIndex = 0;
                  _loadPendingPosts();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentIndex >= _posts.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modération Adoptions')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text('Toutes les annonces ont été traitées !', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _posts.clear();
                    _cursor = null;
                    _currentIndex = 0;
                  });
                  _loadPendingPosts();
                },
                child: const Text('Recharger'),
              ),
            ],
          ),
        ),
      );
    }

    final post = _posts[_currentIndex];
    final images = (post['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final user = post['createdBy'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modération Adoptions'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${_posts.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info Card
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '👤 Propriétaire',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Nom: ${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'),
                            Text('Email: ${user?['email'] ?? ''}'),
                            Text('ID: ${user?['id'] ?? ''}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Post Images
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 300,
                        child: PageView.builder(
                          itemCount: images.length,
                          itemBuilder: (ctx, idx) {
                            final img = images[idx];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                img['url'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image, size: 64),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Post Details
                    Text(
                      post['title'] ?? 'Sans titre',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (post['animalName'] != null && (post['animalName'] as String).isNotEmpty)
                      Text('Nom: ${post['animalName']}', style: const TextStyle(fontSize: 18)),

                    Text('Espèce: ${post['species'] ?? '?'}'),
                    if (post['sex'] != null) Text('Sexe: ${post['sex']}'),
                    if (post['ageMonths'] != null) Text('Âge: ${_formatAge(post['ageMonths'])}'),
                    if (post['city'] != null) Text('Ville: ${post['city']}'),

                    const SizedBox(height: 12),

                    if (post['description'] != null && (post['description'] as String).isNotEmpty)
                      Text(
                        post['description'],
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _reject(post['id']),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.close, size: 32),
                      label: const Text('REFUSER', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approve(post['id']),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.check, size: 32),
                      label: const Text('APPROUVER', style: TextStyle(fontSize: 18)),
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

  String _formatAge(int months) {
    if (months < 12) return '$months mois';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) return '$years an${years > 1 ? 's' : ''}';
    return '$years an${years > 1 ? 's' : ''} et $remainingMonths mois';
  }
}
