// lib/features/pets/vet_scan_pet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

class VetScanPetScreen extends ConsumerStatefulWidget {
  const VetScanPetScreen({super.key});

  @override
  ConsumerState<VetScanPetScreen> createState() => _VetScanPetScreenState();
}

class _VetScanPetScreenState extends ConsumerState<VetScanPetScreen> {
  MobileScannerController? _controller;
  bool _isScanning = true;
  String? _scannedToken;
  Map<String, dynamic>? _petData;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _activeBooking; // Booking actif trouvé après scan
  bool _isConfirmingBooking = false; // Loading pour le bouton de confirmation
  String? _bookingType; // Type de booking: 'vet' ou 'daycare'

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isLoading) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final token = barcode!.rawValue!;

    setState(() {
      _isScanning = false;
      _scannedToken = token;
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final petData = await api.getPetByToken(token);

      setState(() {
        _petData = petData;
      });

      // Chercher un booking actif pour ce pet (vet ou daycare)
      try {
        final petId = petData['id']?.toString();
        if (petId != null && petId.isNotEmpty) {
          // Essayer d'abord de trouver un booking vétérinaire
          debugPrint('🔍 Recherche booking vétérinaire pour pet: $petId');
          var activeBooking = await api.findActiveBookingForPet(petId);
          var bookingType = 'vet';

          // ✅ FIX: Vérifier si le booking a un ID valide (pas juste un objet vide)
          final hasValidVetBooking = activeBooking != null &&
                                      activeBooking['id'] != null &&
                                      activeBooking['id'].toString().isNotEmpty &&
                                      activeBooking['id'].toString() != 'null';

          if (hasValidVetBooking) {
            debugPrint('✅ Booking vétérinaire trouvé: ${activeBooking!['id']}');
          } else {
            debugPrint('❌ Aucun booking vétérinaire trouvé');
            activeBooking = null; // Reset pour chercher daycare
          }

          // Si pas de booking vétérinaire, chercher un booking garderie
          if (activeBooking == null) {
            debugPrint('🔍 Recherche booking garderie pour pet: $petId');
            activeBooking = await api.findActiveDaycareBookingForPet(petId);
            bookingType = 'daycare';

            // ✅ FIX: Vérifier si le booking daycare a un ID valide
            final hasValidDaycareBooking = activeBooking != null &&
                                            activeBooking['id'] != null &&
                                            activeBooking['id'].toString().isNotEmpty &&
                                            activeBooking['id'].toString() != 'null';

            if (hasValidDaycareBooking) {
              debugPrint('✅ Booking garderie trouvé: ${activeBooking!['id']}');
            } else {
              debugPrint('❌ Aucun booking garderie trouvé');
              activeBooking = null; // Reset
            }
          }

          if (activeBooking != null) {
            debugPrint('📝 Type de booking: $bookingType');
            setState(() {
              _activeBooking = activeBooking;
              _bookingType = bookingType;
              _isLoading = false;
            });

            // Auto-confirmer le booking immédiatement
            await _confirmBooking();
            return; // Sortir de la fonction après confirmation
          } else {
            debugPrint('⚠️ Aucun booking actif trouvé (ni vet ni daycare)');
          }
        }
      } catch (e) {
        // Logger l'erreur pour debugging
        debugPrint('⚠️ Erreur lors de la recherche de booking: $e');
        // Si erreur autre que 404, on doit l'afficher
        if (!e.toString().toLowerCase().contains('404')) {
          setState(() {
            _error = 'Erreur lors de la vérification du rendez-vous: ${_formatErrorMessage(e.toString())}';
            _isLoading = false;
          });
          return;
        }
        // Sinon, c'est juste qu'il n'y a pas de booking, on continue
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _isScanning = true;
      _scannedToken = null;
      _petData = null;
      _error = null;
      _activeBooking = null;
      _bookingType = null;
      _isConfirmingBooking = false;
    });
  }

  /// Formatte les messages d'erreur pour l'utilisateur
  String _formatErrorMessage(String error) {
    final lowerError = error.toLowerCase();

    // Erreurs liées au QR code
    if (lowerError.contains('404') || lowerError.contains('not found')) {
      return 'QR code invalide ou expiré.\nVeuillez demander au client de générer un nouveau QR code.';
    }
    if (lowerError.contains('expired')) {
      return 'QR code expiré.\nVeuillez demander au client de générer un nouveau QR code.';
    }

    // Erreurs d'autorisation
    if (lowerError.contains('403') || lowerError.contains('forbidden')) {
      return 'Accès refusé.\nVous n\'êtes pas autorisé à scanner ce QR code.';
    }

    // Erreurs de booking
    if (lowerError.contains('no active booking') || lowerError.contains('aucun rendez-vous')) {
      return 'Aucun rendez-vous actif trouvé pour cet animal aujourd\'hui.\nVérifiez les horaires ou le planning.';
    }
    if (lowerError.contains('wrong pet') || lowerError.contains('mauvais animal')) {
      return 'Cet animal ne correspond pas au rendez-vous.\nVérifiez quel animal est prévu pour ce rendez-vous.';
    }
    if (lowerError.contains('outside opening hours') || lowerError.contains('hors heures d\'ouverture')) {
      return 'Vous êtes actuellement fermé.\nLe scan n\'est possible que pendant vos heures d\'ouverture.';
    }
    if (lowerError.contains('already confirmed') || lowerError.contains('déjà confirmé')) {
      return 'Ce rendez-vous a déjà été confirmé.';
    }

    // Erreurs réseau
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Erreur de connexion.\nVérifiez votre connexion internet.';
    }
    if (lowerError.contains('timeout')) {
      return 'Délai d\'attente dépassé.\nRéessayez dans quelques instants.';
    }

    // Message par défaut plus convivial
    return 'Une erreur est survenue.\nVeuillez réessayer ou contacter le support si le problème persiste.';
  }

  Future<void> _confirmBooking() async {
    if (_activeBooking == null || _isConfirmingBooking) return;

    // Vérifier que le booking a bien un ID valide
    final bookingId = _activeBooking!['id']?.toString();
    if (bookingId == null || bookingId.isEmpty || bookingId == 'null') {
      debugPrint('⚠️ Booking ID invalide: $bookingId');
      return;
    }

    setState(() => _isConfirmingBooking = true);

    try {
      final api = ref.read(apiProvider);

      // Appeler la méthode appropriée selon le type de booking
      if (_bookingType == 'daycare') {
        await api.confirmDaycareDropOff(bookingId);
      } else {
        await api.proConfirmBooking(bookingId);
      }

      if (!mounted) return;

      final message = _bookingType == 'daycare'
          ? '✅ Réception de l\'animal confirmée avec succès'
          : '✅ Rendez-vous confirmé avec succès';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );

      // Réinitialiser l'état après succès
      setState(() {
        _activeBooking = null;
        _bookingType = null;
        _isConfirmingBooking = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${_formatErrorMessage(e.toString())}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      setState(() => _isConfirmingBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Scanner Patient',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isScanning ? _buildScanner() : _buildResult(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
              // Overlay
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: _coral, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner, size: 32, color: _coral),
              const SizedBox(height: 12),
              const Text(
                'Scannez le QR code du client',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pointez la camera vers le QR code affiche sur l\'ecran du client',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _coral));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erreur de scan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                _formatErrorMessage(_error!),
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _resetScan,
                style: FilledButton.styleFrom(
                  backgroundColor: _coral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Scanner a nouveau'),
              ),
            ],
          ),
        ),
      );
    }

    if (_petData == null) return const SizedBox.shrink();

    return _buildPetInfo();
  }

  Widget _buildPetInfo() {
    final name = (_petData!['name'] ?? 'Animal').toString();
    final breed = (_petData!['breed'] ?? '').toString();
    final gender = (_petData!['gender'] ?? 'UNKNOWN').toString();
    final idNumber = (_petData!['idNumber'] ?? '').toString();
    final owner = _petData!['owner'] as Map<String, dynamic>?;
    final ownerName = owner != null
        ? '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim()
        : 'Proprietaire';
    final ownerPhone = owner?['phone']?.toString() ?? '';
    final medicalRecords = (_petData!['medicalRecords'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _coralSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.pets, color: _coral, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          if (breed.isNotEmpty || idNumber.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              [if (idNumber.isNotEmpty) idNumber, if (breed.isNotEmpty) breed]
                                  .join(' - '),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
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
                      size: 28,
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Owner info
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      ownerName,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    if (ownerPhone.isNotEmpty) ...[
                      const Spacer(),
                      Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        ownerPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ⚠️ Le dossier médical n'est accessible QUE pour les vétérinaires
          // Les garderies et les scans sans booking n'ont pas accès au dossier médical
          if (_bookingType == 'vet') ...[
            // Add record button
            FilledButton.icon(
              onPressed: () => context.push('/vet/add-record/${_petData!['id']}?token=$_scannedToken'),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un acte medical'),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Medical history
            const Text(
              'Historique medical',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Afficher les dossiers médicaux seulement pour les vétérinaires
          if (_bookingType == 'vet') ...[
            if (medicalRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.medical_services, size: 32, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'Aucun historique',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...medicalRecords.map((record) => _buildRecordCard(record)),

            const SizedBox(height: 24),
          ],

          // Scan again
          OutlinedButton.icon(
            onPressed: _resetScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner un autre patient'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _coral,
              side: const BorderSide(color: _coral),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final type = (record['type'] ?? 'OTHER').toString();
    final title = (record['title'] ?? '').toString();
    final dateStr = record['date']?.toString();
    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    IconData icon;
    Color color;
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        icon = Icons.vaccines;
        color = Colors.green;
        break;
      case 'SURGERY':
        icon = Icons.local_hospital;
        color = Colors.red;
        break;
      case 'CHECKUP':
        icon = Icons.health_and_safety;
        color = Colors.blue;
        break;
      case 'TREATMENT':
        icon = Icons.healing;
        color = Colors.orange;
        break;
      case 'MEDICATION':
        icon = Icons.medication;
        color = Colors.purple;
        break;
      default:
        icon = Icons.medical_services;
        color = _coral;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
