// lib/features/pets/vet_pet_medical_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _green = Color(0xFF43AA8B);
const _mint = Color(0xFF4ECDC4);
const _purple = Color(0xFF9B59B6);
const _orange = Color(0xFFF39C12);
const _blue = Color(0xFF3498DB);

/// Provider pour charger les données d'un animal via token (pour vétérinaires)
final vetPetDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, token) async {
  if (token.isEmpty) return null;
  final api = ref.read(apiProvider);
  return api.getPetByToken(token);
});

/// Écran du carnet de santé accessible par le vétérinaire après scan QR
/// Style hub avec État de santé, Historique médical, Statistiques, etc.
class VetPetMedicalScreen extends ConsumerStatefulWidget {
  final String petId;
  final String token;
  final bool bookingConfirmed;

  const VetPetMedicalScreen({
    super.key,
    required this.petId,
    required this.token,
    this.bookingConfirmed = false,
  });

  @override
  ConsumerState<VetPetMedicalScreen> createState() => _VetPetMedicalScreenState();
}

class _VetPetMedicalScreenState extends ConsumerState<VetPetMedicalScreen> {
  String? _expandedSection;

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(vetPetDataProvider(widget.token));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pro'),
        ),
        title: const Text(
          'Carnet de santé',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(vetPetDataProvider(widget.token)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/pro'),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
        data: (petData) {
          if (petData == null) {
            return const Center(child: Text('Animal non trouvé'));
          }
          return _buildHubContent(context, petData);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vet/add-record/${widget.petId}?token=${widget.token}'),
        backgroundColor: _coral,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter un acte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHubContent(BuildContext context, Map<String, dynamic> petData) {
    final name = (petData['name'] ?? 'Animal').toString();
    final breed = (petData['breed'] ?? '').toString();
    final species = (petData['species'] ?? '').toString();
    final gender = (petData['gender'] ?? 'UNKNOWN').toString();
    final birthDate = petData['birthDate']?.toString();
    final photoUrl = petData['photoUrl']?.toString();
    final owner = petData['owner'] as Map<String, dynamic>?;
    final ownerName = owner != null
        ? '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim()
        : 'Propriétaire';
    final ownerPhone = owner?['phone']?.toString() ?? '';

    // Extract all data
    final medicalRecords = _extractList(petData['medicalRecords']);
    final vaccinations = _extractList(petData['vaccinations']);
    final weightRecords = _extractList(petData['weightRecords']);
    final prescriptions = _extractList(petData['prescriptions']);
    final diseases = _extractList(petData['diseaseTrackings']);
    final allergies = _extractList(petData['allergies']);
    final treatments = _extractList(petData['treatments']);

    // Get latest weight for health overview
    final latestWeight = weightRecords.isNotEmpty ? weightRecords.first : null;

    return RefreshIndicator(
      color: _coral,
      onRefresh: () async => ref.invalidate(vetPetDataProvider(widget.token)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confirmation banner si booking confirmé
            if (widget.bookingConfirmed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: _green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Rendez-vous confirmé avec succès',
                        style: TextStyle(fontWeight: FontWeight.w600, color: _green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pet info card with photo
            _buildPetInfoCard(
              name: name,
              species: species,
              breed: breed,
              gender: gender,
              birthDate: birthDate,
              photoUrl: photoUrl,
              ownerName: ownerName,
              ownerPhone: ownerPhone,
            ),

            const SizedBox(height: 24),

            // État de santé overview
            _buildHealthOverview(latestWeight, allergies),

            const SizedBox(height: 24),

            // Accès rapide title
            const Text(
              'Accès rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 16),

            // Action cards
            _buildActionCard(
              icon: Icons.history_rounded,
              title: 'Historique médical',
              subtitle: 'Consultations, diagnostics, traitements',
              color: _blue,
              count: medicalRecords.length,
              isExpanded: _expandedSection == 'medical',
              onTap: () => _toggleSection('medical'),
              expandedContent: _buildMedicalRecordsList(medicalRecords),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.vaccines_rounded,
              title: 'Vaccinations',
              subtitle: 'Calendrier et rappels de vaccins',
              color: _purple,
              count: vaccinations.length,
              isExpanded: _expandedSection == 'vaccinations',
              onTap: () => _toggleSection('vaccinations'),
              expandedContent: _buildVaccinationsList(vaccinations),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.medication_rounded,
              title: 'Ordonnances',
              subtitle: 'Médicaments et traitements prescrits',
              color: _mint,
              count: prescriptions.length,
              isExpanded: _expandedSection == 'prescriptions',
              onTap: () => _toggleSection('prescriptions'),
              expandedContent: _buildPrescriptionsList(prescriptions),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.analytics_rounded,
              title: 'Statistiques de santé',
              subtitle: 'Poids, température, fréquence cardiaque',
              color: _coral,
              count: weightRecords.length,
              isExpanded: _expandedSection == 'stats',
              onTap: () => _toggleSection('stats'),
              expandedContent: _buildHealthStatsList(weightRecords),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.monitor_heart_rounded,
              title: 'Suivi de maladie',
              subtitle: 'Photos, évolution, notes',
              color: _orange,
              count: diseases.length,
              isExpanded: _expandedSection == 'diseases',
              onTap: () => _toggleSection('diseases'),
              expandedContent: _buildDiseasesList(diseases),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.healing_rounded,
              title: 'Traitements en cours',
              subtitle: 'Médicaments et soins actifs',
              color: Colors.teal,
              count: treatments.length,
              isExpanded: _expandedSection == 'treatments',
              onTap: () => _toggleSection('treatments'),
              expandedContent: _buildTreatmentsList(treatments),
            ),

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _toggleSection(String section) {
    setState(() {
      if (_expandedSection == section) {
        _expandedSection = null;
      } else {
        _expandedSection = section;
      }
    });
  }

  Widget _buildPetInfoCard({
    required String name,
    required String species,
    required String breed,
    required String gender,
    required String? birthDate,
    required String? photoUrl,
    required String ownerName,
    required String ownerPhone,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_coral.withOpacity(0.1), _mint.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Photo or icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPetIcon(species))
                      : _buildPetIcon(species),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [if (species.isNotEmpty) species, if (breed.isNotEmpty) breed].join(' • '),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    if (birthDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.cake, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(DateTime.parse(birthDate)),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                gender == 'MALE'
                    ? Icons.male
                    : gender == 'FEMALE'
                        ? Icons.female
                        : Icons.question_mark,
                color: gender == 'MALE'
                    ? Colors.blue
                    : gender == 'FEMALE'
                        ? Colors.pink
                        : Colors.grey,
                size: 32,
              ),
            ],
          ),
          const Divider(height: 24),
          // Owner info
          Row(
            children: [
              Icon(Icons.person, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                ownerName,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              if (ownerPhone.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, size: 14, color: _green),
                      const SizedBox(width: 4),
                      Text(
                        ownerPhone,
                        style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPetIcon(String species) {
    IconData icon;
    switch (species.toUpperCase()) {
      case 'DOG':
      case 'CHIEN':
        icon = Icons.pets;
        break;
      case 'CAT':
      case 'CHAT':
        icon = Icons.pets;
        break;
      case 'BIRD':
      case 'OISEAU':
        icon = Icons.flutter_dash;
        break;
      default:
        icon = Icons.pets;
    }
    return Container(
      color: _coralSoft,
      child: Icon(icon, color: _coral, size: 36),
    );
  }

  Widget _buildHealthOverview(Map<String, dynamic>? latestWeight, List<Map<String, dynamic>> allergies) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _coral,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'État de santé',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      'Dernières mesures enregistrées',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.monitor_weight,
                  label: 'Poids',
                  value: latestWeight != null
                      ? '${(latestWeight['value'] ?? 0).toStringAsFixed(1)} kg'
                      : '— kg',
                  color: _coral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.warning_amber,
                  label: 'Allergies',
                  value: allergies.isEmpty ? 'Aucune' : '${allergies.length}',
                  color: allergies.isEmpty ? _green : _orange,
                ),
              ),
            ],
          ),
          if (allergies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allergies.take(3).map((a) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber, size: 14, color: _orange),
                    const SizedBox(width: 4),
                    Text(
                      (a['name'] ?? 'Allergie').toString(),
                      style: const TextStyle(fontSize: 12, color: _orange, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget expandedContent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? color.withOpacity(0.5) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: expandedContent,
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalRecordsList(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return _buildEmptyState('Aucun historique médical', Icons.medical_services);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: records.take(5).map((r) => _buildMedicalRecordItem(r)).toList(),
      ),
    );
  }

  Widget _buildMedicalRecordItem(Map<String, dynamic> record) {
    final type = (record['type'] ?? 'OTHER').toString();
    final title = (record['title'] ?? '').toString();
    final dateStr = record['date']?.toString();
    DateTime? date;
    if (dateStr != null) date = DateTime.tryParse(dateStr);

    IconData icon;
    Color color;
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        icon = Icons.vaccines;
        color = _green;
        break;
      case 'SURGERY':
        icon = Icons.local_hospital;
        color = Colors.red;
        break;
      case 'CHECKUP':
        icon = Icons.health_and_safety;
        color = _blue;
        break;
      case 'TREATMENT':
        icon = Icons.healing;
        color = _orange;
        break;
      default:
        icon = Icons.medical_services;
        color = _coral;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (date != null)
            Text(
              DateFormat('dd/MM/yy').format(date),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildVaccinationsList(List<Map<String, dynamic>> vaccinations) {
    if (vaccinations.isEmpty) {
      return _buildEmptyState('Aucune vaccination', Icons.vaccines);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: vaccinations.take(5).map((v) {
          final name = (v['name'] ?? 'Vaccin').toString();
          final dateStr = v['date']?.toString();
          DateTime? date;
          if (dateStr != null) date = DateTime.tryParse(dateStr);

          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.vaccines, color: _purple, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yy').format(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrescriptionsList(List<Map<String, dynamic>> prescriptions) {
    if (prescriptions.isEmpty) {
      return _buildEmptyState('Aucune ordonnance', Icons.medication);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: prescriptions.take(5).map((p) {
          final title = (p['title'] ?? 'Ordonnance').toString();
          final dateStr = p['date']?.toString();
          DateTime? date;
          if (dateStr != null) date = DateTime.tryParse(dateStr);

          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _mint.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _mint.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.medication, color: _mint, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yy').format(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHealthStatsList(List<Map<String, dynamic>> weightRecords) {
    if (weightRecords.isEmpty) {
      return _buildEmptyState('Aucune donnée de santé', Icons.analytics);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: weightRecords.take(5).map((w) {
          final value = w['value'] ?? 0;
          final dateStr = w['date']?.toString();
          DateTime? date;
          if (dateStr != null) date = DateTime.tryParse(dateStr);

          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _coral.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _coral.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monitor_weight, color: _coral, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${value.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yy').format(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDiseasesList(List<Map<String, dynamic>> diseases) {
    if (diseases.isEmpty) {
      return _buildEmptyState('Aucun suivi de maladie', Icons.monitor_heart);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: diseases.take(5).map((d) {
          final name = (d['name'] ?? 'Maladie').toString();
          final status = (d['status'] ?? 'ACTIVE').toString();

          Color statusColor;
          String statusLabel;
          switch (status.toUpperCase()) {
            case 'RESOLVED':
              statusColor = _green;
              statusLabel = 'Guéri';
              break;
            case 'MONITORING':
              statusColor = _orange;
              statusLabel = 'Suivi';
              break;
            default:
              statusColor = _coral;
              statusLabel = 'Actif';
          }

          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.monitor_heart, color: statusColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTreatmentsList(List<Map<String, dynamic>> treatments) {
    if (treatments.isEmpty) {
      return _buildEmptyState('Aucun traitement en cours', Icons.healing);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: treatments.take(5).map((t) {
          final name = (t['name'] ?? 'Traitement').toString();
          final dosage = (t['dosage'] ?? '').toString();

          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.healing, color: Colors.teal, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (dosage.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dosage,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
