// lib/features/pets/pet_qr_code_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import 'pet_medical_history_screen.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

class PetQrCodeScreen extends ConsumerStatefulWidget {
  final String petId;

  const PetQrCodeScreen({super.key, required this.petId});

  @override
  ConsumerState<PetQrCodeScreen> createState() => _PetQrCodeScreenState();
}

class _PetQrCodeScreenState extends ConsumerState<PetQrCodeScreen> {
  String? _token;
  DateTime? _expiresAt;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  Future<void> _generateToken() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final result = await api.generatePetAccessToken(widget.petId);

      setState(() {
        _token = result['token']?.toString();
        final expiresStr = result['expiresAt']?.toString();
        if (expiresStr != null) {
          _expiresAt = DateTime.tryParse(expiresStr);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatExpiry() {
    if (_expiresAt == null) return '';
    final now = DateTime.now();
    final diff = _expiresAt!.difference(now);
    if (diff.inMinutes > 0) {
      return 'Expire dans ${diff.inMinutes} minutes';
    }
    return 'Expire';
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petInfoProvider(widget.petId));
    final petName = petAsync.whenOrNull(data: (pet) => pet?['name']?.toString()) ?? 'Animal';

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
          'QR Code Medical',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _coral))
          : _error != null
              ? _buildErrorState()
              : _buildQrCode(petName),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Erreur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _generateToken,
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCode(String petName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Pet name
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
              children: [
                Icon(Icons.pets, size: 32, color: _coral),
                const SizedBox(height: 8),
                Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                if (_token != null)
                  QrImageView(
                    data: _token!,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _ink,
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _coralSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 16, color: _coral),
                      const SizedBox(width: 6),
                      Text(
                        _formatExpiry(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _coral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _coral.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: _coral, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInstruction('1', 'Montrez ce QR code a votre veterinaire'),
                const SizedBox(height: 8),
                _buildInstruction('2', 'Il pourra voir l\'historique medical'),
                const SizedBox(height: 8),
                _buildInstruction('3', 'Et ajouter les nouveaux actes medicaux'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Regenerate button
          OutlinedButton.icon(
            onPressed: _generateToken,
            icon: const Icon(Icons.refresh),
            label: const Text('Generer un nouveau code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _coral,
              side: const BorderSide(color: _coral),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _coralSoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _coral,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
