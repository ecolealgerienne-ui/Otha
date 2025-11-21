// lib/features/adopt/adopt_create_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

class AdoptCreateScreen extends ConsumerStatefulWidget {
  const AdoptCreateScreen({super.key});
  @override
  ConsumerState<AdoptCreateScreen> createState() => _AdoptCreateScreenState();
}

class _AdoptCreateScreenState extends ConsumerState<AdoptCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _desc = TextEditingController();

  String _species = 'dog';
  String _sex = 'unknown';
  final List<XFile> _images = [];
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose(); _name.dispose(); _age.dispose(); _city.dispose();
    _lat.dispose(); _lng.dispose(); _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) return;
    final pic = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (pic != null) setState(() => _images.add(pic));
  }

  void _removeAt(int i) => setState(() => _images.removeAt(i));

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins une photo')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiProvider);
      final urls = <String>[];
      for (final x in _images) {
        final url = await api.uploadLocalFile(File(x.path), folder: 'adopt');
        urls.add(url);
      }

      final lat = double.tryParse(_lat.text.trim());
      final lng = double.tryParse(_lng.text.trim());

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

      await api.createAdoptPost(
        title: _title.text.trim(),
        animalName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        species: _species,
        sex: _sex,
        ageMonths: ageMonths,
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        lat: lat,
        lng: lng,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        photos: urls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce envoyée en validation admin')),
        );
        context.go('/adopt');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle annonce')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titre de l\'annonce',
                  hintText: 'Ex: Chiot adorable cherche famille',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
                maxLength: 140,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'animal (optionnel)',
                  hintText: 'Ex: Max',
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 12),
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
                      decoration: const InputDecoration(labelText: 'Espèce'),
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
                      decoration: const InputDecoration(labelText: 'Sexe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _age, decoration: const InputDecoration(labelText: 'Âge (ex: 3 mois, 2 ans)')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'Ville (optionnel)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _lat, decoration: const InputDecoration(labelText: 'Latitude (optionnel)'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _lng, decoration: const InputDecoration(labelText: 'Longitude (optionnel)'))),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ...List.generate(_images.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_images[i].path), width: 96, height: 96, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: -8, top: -8,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.black54),
                              onPressed: () => _removeAt(i),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_images.length < 3)
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Photo'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.check),
                label: Text(_submitting ? 'Publication…' : 'Publier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
