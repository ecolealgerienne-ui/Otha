// lib/features/daycare/daycare_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

const _primary = Color(0xFF00ACC1);
const _primarySoft = Color(0xFFE0F7FA);
const _ink = Color(0xFF222222);

// Commission cachée ajoutée au prix total
const kDaycareCommissionDa = 100;

/// Provider pour charger les animaux de l'utilisateur
final _userPetsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final pets = await api.myPets();
    return pets.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    return [];
  }
});

class DaycareBookingScreen extends ConsumerStatefulWidget {
  final String providerId;
  final Map<String, dynamic>? daycareData;

  const DaycareBookingScreen({
    super.key,
    required this.providerId,
    this.daycareData,
  });

  @override
  ConsumerState<DaycareBookingScreen> createState() => _DaycareBookingScreenState();
}

class _DaycareBookingScreenState extends ConsumerState<DaycareBookingScreen> {
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Selected pets
  final Set<String> _selectedPetIds = {};

  // Date range
  DateTime? _startDate;
  DateTime? _endDate;

  // Time selection
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  // Booking type (hourly or daily)
  String _bookingType = 'hourly'; // 'hourly' or 'daily'

  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daycare = widget.daycareData ?? {};
    final name = (daycare['displayName'] ?? 'Garderie').toString();
    final hourlyRate = daycare['hourlyRate'] as int?;
    final dailyRate = daycare['dailyRate'] as int?;

    final petsAsync = ref.watch(_userPetsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Réserver'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $err'),
            ],
          ),
        ),
        data: (pets) {
          if (pets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pets, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun animal enregistré',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vous devez d\'abord enregistrer vos animaux avant de réserver une garderie.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/pets/add');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un animal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daycare name
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Booking type selection
                        if (hourlyRate != null && dailyRate != null) ...[
                          _sectionTitle('Type de réservation'),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'hourly',
                                label: Text('À l\'heure'),
                                icon: Icon(Icons.access_time),
                              ),
                              ButtonSegment(
                                value: 'daily',
                                label: Text('À la journée'),
                                icon: Icon(Icons.calendar_today),
                              ),
                            ],
                            selected: {_bookingType},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _bookingType = newSelection.first;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Pet selection
                        _sectionTitle('Sélectionnez vos animaux'),
                        const SizedBox(height: 12),
                        ...pets.map((pet) => _petCheckbox(pet)),
                        const SizedBox(height: 24),

                        // Date selection
                        _sectionTitle(_bookingType == 'daily' ? 'Dates' : 'Date'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _dateCard(
                                label: _bookingType == 'daily' ? 'Début' : 'Date',
                                date: _startDate,
                                onTap: () => _pickStartDate(context),
                              ),
                            ),
                            if (_bookingType == 'daily') ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dateCard(
                                  label: 'Fin',
                                  date: _endDate,
                                  onTap: () => _pickEndDate(context),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Time selection (only for hourly)
                        if (_bookingType == 'hourly') ...[
                          _sectionTitle('Heures'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _timeCard(
                                  label: 'Arrivée',
                                  time: _startTime,
                                  onTap: () => _pickStartTime(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _timeCard(
                                  label: 'Départ',
                                  time: _endTime,
                                  onTap: () => _pickEndTime(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Client notes
                        _sectionTitle('Notes (optionnel)'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'Informations importantes sur vos animaux...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 4,
                        ),

                        const SizedBox(height: 24),

                        // Total calculation
                        _buildTotalCard(hourlyRate, dailyRate),
                      ],
                    ),
                  ),
                ),

                // Bottom submit button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirmer la réservation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _ink,
      ),
    );
  }

  Widget _petCheckbox(Map<String, dynamic> pet) {
    final id = (pet['id'] ?? '').toString();
    final name = (pet['name'] ?? 'Sans nom').toString();
    final species = (pet['species'] ?? '').toString();
    final breed = (pet['breed'] ?? '').toString();
    final photoUrl = (pet['photoUrl'] ?? '').toString();

    final subtitle = [species, breed].where((s) => s.isNotEmpty).join(' - ');

    return CheckboxListTile(
      value: _selectedPetIds.contains(id),
      onChanged: (bool? value) {
        setState(() {
          if (value == true) {
            _selectedPetIds.add(id);
          } else {
            _selectedPetIds.remove(id);
          }
        });
      },
      title: Text(name),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      secondary: photoUrl.isNotEmpty
          ? CircleAvatar(
              backgroundImage: NetworkImage(photoUrl),
              backgroundColor: _primarySoft,
            )
          : CircleAvatar(
              backgroundColor: _primarySoft,
              child: Icon(Icons.pets, color: _primary),
            ),
      activeColor: _primary,
    );
  }

  Widget _dateCard({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: _primary),
                const SizedBox(width: 8),
                Text(
                  date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Sélectionner',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: date != null ? _ink : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeCard({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: _primary),
                const SizedBox(width: 8),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(int? hourlyRate, int? dailyRate) {
    final total = _calculateTotal(hourlyRate, dailyRate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              Text(
                total != null ? '${total} DA' : '---',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
          if (total != null && _selectedPetIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Pour ${_selectedPetIds.length} animal${_selectedPetIds.length > 1 ? 'ux' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int? _calculateTotal(int? hourlyRate, int? dailyRate) {
    if (_selectedPetIds.isEmpty) return null;

    final numPets = _selectedPetIds.length;

    if (_bookingType == 'hourly' && hourlyRate != null && _startDate != null) {
      // Calculate hours between start and end time
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;
      final durationMinutes = endMinutes - startMinutes;

      if (durationMinutes <= 0) return null;

      final hours = (durationMinutes / 60).ceil();
      final basePrice = hourlyRate * hours * numPets;
      return basePrice + kDaycareCommissionDa;
    } else if (_bookingType == 'daily' && dailyRate != null && _startDate != null && _endDate != null) {
      final days = _endDate!.difference(_startDate!).inDays + 1;

      if (days <= 0) return null;

      final basePrice = dailyRate * days * numPets;
      return basePrice + kDaycareCommissionDa;
    }

    return null;
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner la date de début')),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime(_startDate!.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickStartTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submitBooking() async {
    // Validation
    if (_selectedPetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un animal')),
      );
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bookingType == 'daily'
              ? 'Veuillez sélectionner les dates'
              : 'Veuillez sélectionner la date'),
        ),
      );
      return;
    }

    if (_bookingType == 'daily' && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner la date de fin')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiProvider);

      // Obtenir les infos de la garderie et du premier pet sélectionné
      final daycare = widget.daycareData ?? {};
      final hourlyRate = daycare['hourlyRate'] as int?;
      final dailyRate = daycare['dailyRate'] as int?;
      final basePrice = _bookingType == 'hourly' ? (hourlyRate ?? 1000) : (dailyRate ?? 5000);

      // Récupérer le nom du premier pet
      final petsAsync = ref.read(_userPetsProvider);
      final pets = petsAsync.value ?? [];
      final firstPetId = _selectedPetIds.first;
      final firstPet = pets.firstWhere((p) => p['id'] == firstPetId, orElse: () => {});
      final petName = (firstPet['name'] ?? 'Votre animal').toString();

      // Préparer les dates
      DateTime startDateTime;
      DateTime? endDateTime;

      if (_bookingType == 'hourly') {
        startDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startTime.hour,
          _startTime.minute,
        );
        endDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _endTime.hour,
          _endTime.minute,
        );
      } else {
        // Réservation journalière
        startDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          9,
          0,
        );
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          17,
          0,
        );
      }

      final totalDa = basePrice + kDaycareCommissionDa;

      // Créer la réservation garderie (système séparé)
      final booking = await api.createDaycareBooking(
        petId: firstPetId,
        providerId: widget.providerId,
        startDate: startDateTime.toIso8601String(),
        endDate: endDateTime.toIso8601String(),
        priceDa: basePrice,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (!mounted) return;

      // Naviguer vers l'écran de confirmation
      context.go('/daycare/booking-confirmation', extra: {
        'bookingId': booking['id'],
        'totalDa': totalDa,
        'petName': petName,
        'startDate': startDateTime.toIso8601String(),
        'endDate': endDateTime.toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
