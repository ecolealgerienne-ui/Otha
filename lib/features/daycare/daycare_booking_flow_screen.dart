import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

class DaycareBookingFlowScreen extends ConsumerStatefulWidget {
  final String? daycareId;

  const DaycareBookingFlowScreen({super.key, this.daycareId});

  @override
  ConsumerState<DaycareBookingFlowScreen> createState() => _DaycareBookingFlowScreenState();
}

class _DaycareBookingFlowScreenState extends ConsumerState<DaycareBookingFlowScreen> {
  final _formKey = GlobalKey<FormState>();

  // Data
  String? _selectedDaycareId;
  Map<String, dynamic>? _selectedDaycare;
  String? _selectedPetId;
  Map<String, dynamic>? _selectedPet;
  DateTime? _startDate;
  DateTime? _endDate;
  final _notesController = TextEditingController();
  int _priceDa = 1000; // Prix par défaut

  // Loading states
  Future<List<dynamic>>? _daycaresFuture;
  Future<List<dynamic>>? _petsFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _daycaresFuture = _loadDaycares();
    _petsFuture = _loadPets();
    _selectedDaycareId = widget.daycareId;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _loadDaycares() async {
    final api = ref.read(apiProvider);
    try {
      // Charger les providers de type daycare
      final providers = await api.nearbyProviders(lat: 0, lng: 0, radiusKm: 1000);

      // Filtrer seulement les garderies approuvées
      return providers.where((p) {
        final spec = p['specialties'] as Map<String, dynamic>?;
        return spec?['kind'] == 'daycare' && p['isApproved'] == true;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> _loadPets() async {
    final api = ref.read(apiProvider);
    try {
      return await api.myPets();
    } catch (e) {
      return [];
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 1)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDaycareId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une garderie')),
      );
      return;
    }

    if (_selectedPetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un animal')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner les dates')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final api = ref.read(apiProvider);
      await api.dio.post('/daycare/bookings', data: {
        'petId': _selectedPetId,
        'providerId': _selectedDaycareId,
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
        'priceDa': _priceDa,
        'notes': _notesController.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation créée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/daycare/my-bookings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réserver une garderie'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sélection garderie
            Text(
              'Garderie',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: _daycaresFuture,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final daycares = snap.data ?? [];

                if (daycares.isEmpty) {
                  return const Text('Aucune garderie disponible');
                }

                return DropdownButtonFormField<String>(
                  value: _selectedDaycareId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.home),
                  ),
                  hint: const Text('Sélectionnez une garderie'),
                  items: daycares.map((d) {
                    return DropdownMenuItem<String>(
                      value: d['id'],
                      child: Text(d['displayName'] ?? 'Garderie'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDaycareId = val;
                      _selectedDaycare = daycares.firstWhere((d) => d['id'] == val);
                    });
                  },
                  validator: (val) => val == null ? 'Requis' : null,
                );
              },
            ),

            const SizedBox(height: 24),

            // Sélection animal
            Text(
              'Animal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: _petsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pets = snap.data ?? [];

                if (pets.isEmpty) {
                  return Column(
                    children: [
                      const Text('Vous n\'avez pas encore d\'animal'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/pets'),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un animal'),
                      ),
                    ],
                  );
                }

                return DropdownButtonFormField<String>(
                  value: _selectedPetId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.pets),
                  ),
                  hint: const Text('Sélectionnez un animal'),
                  items: pets.map((p) {
                    return DropdownMenuItem<String>(
                      value: p['id'],
                      child: Text('${p['name']} (${p['species'] ?? 'Animal'})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPetId = val;
                      _selectedPet = pets.firstWhere((p) => p['id'] == val);
                    });
                  },
                  validator: (val) => val == null ? 'Requis' : null,
                );
              },
            ),

            const SizedBox(height: 24),

            // Dates
            Text(
              'Dates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Date de début
            InkWell(
              onTap: _pickStartDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.calendar_today),
                  labelText: 'Arrivée',
                ),
                child: Text(
                  _startDate != null
                      ? DateFormat('dd/MM/yyyy à HH:mm').format(_startDate!)
                      : 'Sélectionner',
                  style: TextStyle(
                    color: _startDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Date de fin
            InkWell(
              onTap: _pickEndDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.event),
                  labelText: 'Départ',
                ),
                child: Text(
                  _endDate != null
                      ? DateFormat('dd/MM/yyyy à HH:mm').format(_endDate!)
                      : 'Sélectionner',
                  style: TextStyle(
                    color: _endDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Prix
            Text(
              'Prix journalier (DA)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _priceDa.toString(),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.payments),
                suffixText: 'DA',
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => _priceDa = int.tryParse(val) ?? 1000,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Requis';
                if (int.tryParse(val) == null) return 'Nombre invalide';
                if (int.parse(val) < 0) return 'Prix invalide';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Notes
            Text(
              'Notes (optionnel)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.note),
                hintText: 'Informations supplémentaires...',
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Résumé
            if (_startDate != null && _endDate != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: coral.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Résumé',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text('Prix de base: ${_priceDa} DA'),
                    Text('Commission: 100 DA'),
                    const Divider(),
                    Text(
                      'Total: ${_priceDa + 100} DA',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Bouton de soumission
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Réserver',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
