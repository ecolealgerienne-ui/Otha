import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

class DaycarePageEditorScreen extends ConsumerStatefulWidget {
  const DaycarePageEditorScreen({super.key});

  @override
  ConsumerState<DaycarePageEditorScreen> createState() => _DaycarePageEditorScreenState();
}

class _DaycarePageEditorScreenState extends ConsumerState<DaycarePageEditorScreen> {
  // Palette cyan (daycare)
  static const Color _primary = Color(0xFF00ACC1);
  static const Color _primarySoft = Color(0xFFE0F7FA);
  static const Color _ink = Color(0xFF222222);
  static const Color _muted = Color(0xFF6B6B6B);

  // Images (1-3)
  final List<TextEditingController> _imageControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  // Capacité
  final _capacity = TextEditingController();

  // Types d'animaux acceptés
  bool _acceptsSmall = true;
  bool _acceptsMedium = true;
  bool _acceptsLarge = true;

  // Tarifs
  final _hourlyRate = TextEditingController();
  final _dailyRate = TextEditingController();

  String? _errCapacity;
  String? _errHourlyRate;
  String? _errDailyRate;

  bool _loading = false;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final ctrl in _imageControllers) {
      ctrl.dispose();
    }
    _capacity.dispose();
    _hourlyRate.dispose();
    _dailyRate.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _unwrap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map && raw.containsKey('data')) {
      final d = raw['data'];
      if (d == null || (d is Map && d.isEmpty)) return null;
      return (d is Map) ? Map<String, dynamic>.from(d) : null;
    }
    if (raw is Map && raw.isEmpty) return null;
    return (raw is Map) ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> _loadData() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      final raw = await api.myProvider();
      final p = _unwrap(raw) ?? {};

      final specs = (p['specialties'] is Map)
          ? Map<String, dynamic>.from(p['specialties'])
          : <String, dynamic>{};

      // Charger les images
      final images = specs['images'];
      if (images is List) {
        for (int i = 0; i < images.length && i < 3; i++) {
          _imageControllers[i].text = (images[i] ?? '').toString();
        }
      }

      // Charger la capacité
      _capacity.text = (specs['capacity'] ?? '').toString();

      // Charger les types d'animaux
      final animalTypes = specs['animalTypes'];
      if (animalTypes is Map) {
        _acceptsSmall = animalTypes['small'] == true;
        _acceptsMedium = animalTypes['medium'] == true;
        _acceptsLarge = animalTypes['large'] == true;
      }

      // Charger les tarifs
      final pricing = specs['pricing'];
      if (pricing is Map) {
        _hourlyRate.text = (pricing['hourlyRate'] ?? '').toString();
        _dailyRate.text = (pricing['dailyRate'] ?? '').toString();
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  bool _validate() {
    final cap = _capacity.text.trim();
    final hourly = _hourlyRate.text.trim();
    final daily = _dailyRate.text.trim();

    _errCapacity = null;
    _errHourlyRate = null;
    _errDailyRate = null;

    if (cap.isNotEmpty) {
      final n = int.tryParse(cap);
      if (n == null || n <= 0) {
        _errCapacity = 'Capacite invalide';
      }
    }

    if (hourly.isNotEmpty) {
      final n = int.tryParse(hourly);
      if (n == null || n < 0) {
        _errHourlyRate = 'Tarif invalide';
      }
    }

    if (daily.isNotEmpty) {
      final n = int.tryParse(daily);
      if (n == null || n < 0) {
        _errDailyRate = 'Tarif invalide';
      }
    }

    setState(() {});
    return _errCapacity == null && _errHourlyRate == null && _errDailyRate == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final api = ref.read(apiProvider);
    await api.ensureAuth();

    try {
      // Construire la liste des images (ignorer les champs vides)
      final images = _imageControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Construire les types d'animaux
      final animalTypes = {
        'small': _acceptsSmall,
        'medium': _acceptsMedium,
        'large': _acceptsLarge,
      };

      // Construire les tarifs
      final pricing = <String, dynamic>{};
      if (_hourlyRate.text.trim().isNotEmpty) {
        pricing['hourlyRate'] = int.parse(_hourlyRate.text.trim());
      }
      if (_dailyRate.text.trim().isNotEmpty) {
        pricing['dailyRate'] = int.parse(_dailyRate.text.trim());
      }

      // Récupérer les specs actuelles pour ne pas écraser les autres champs
      final raw = await api.myProvider();
      final p = _unwrap(raw) ?? {};
      final existingSpecs = (p['specialties'] is Map)
          ? Map<String, dynamic>.from(p['specialties'])
          : <String, dynamic>{};

      // Fusionner avec les nouvelles données
      final specs = Map<String, dynamic>.from(existingSpecs);
      if (images.isNotEmpty) specs['images'] = images;
      if (_capacity.text.trim().isNotEmpty) specs['capacity'] = int.parse(_capacity.text.trim());
      specs['animalTypes'] = animalTypes;
      if (pricing.isNotEmpty) specs['pricing'] = pricing;

      // Get user info for displayName
      final user = ref.read(sessionProvider).user ?? {};
      final firstName = (user['firstName'] ?? '').toString().trim();
      final lastName = (user['lastName'] ?? '').toString().trim();
      final email = (user['email'] ?? '').toString();
      final fullName = '$firstName $lastName'.trim();
      final displayName = fullName.isEmpty ? email.split('@').first : fullName;

      // Sauvegarder
      await api.upsertMyProvider(
        displayName: displayName,
        specialties: specs,
      );
      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Page mise a jour')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          context.go('/daycare/home');
        }
      },
      child: Theme(
        data: _themed(context),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  context.go('/daycare/home');
                }
              },
            ),
            title: const Text('Gérer la page'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _imagesCard(),
              const SizedBox(height: 12),
              _capacityCard(),
              const SizedBox(height: 12),
              _animalTypesCard(),
              const SizedBox(height: 12),
              _pricingCard(),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? '...' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _themed(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _primary,
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: theme.dividerTheme.copyWith(color: Colors.black12),
      snackBarTheme: theme.snackBarTheme.copyWith(
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _imagesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photos de la garderie', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez 1 a 3 photos pour attirer les clients',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < 3; i++) ...[
            TextField(
              controller: _imageControllers[i],
              decoration: InputDecoration(
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                labelText: 'Photo ${i + 1}',
                hintText: 'URL de la photo',
                isDense: true,
                prefixIcon: const Icon(Icons.image),
              ),
            ),
            if (i < 2) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _capacityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Capacité maximale', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Nombre maximum d\'animaux que vous pouvez accueillir simultanement',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelText: 'Capacite',
              hintText: 'Ex: 10',
              isDense: true,
              errorText: _errCapacity,
              prefixIcon: const Icon(Icons.pets),
              suffixText: 'animaux',
            ),
          ),
        ],
      ),
    );
  }

  Widget _animalTypesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Types d\'animaux acceptes', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Selectionnez les tailles d\'animaux que vous acceptez',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Petits animaux'),
            subtitle: const Text('Chats, petits chiens, etc.', style: TextStyle(fontSize: 12)),
            value: _acceptsSmall,
            onChanged: (v) => setState(() => _acceptsSmall = v ?? false),
            activeColor: _primary,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Animaux moyens'),
            subtitle: const Text('Chiens moyens, etc.', style: TextStyle(fontSize: 12)),
            value: _acceptsMedium,
            onChanged: (v) => setState(() => _acceptsMedium = v ?? false),
            activeColor: _primary,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Grands animaux'),
            subtitle: const Text('Grands chiens, etc.', style: TextStyle(fontSize: 12)),
            value: _acceptsLarge,
            onChanged: (v) => setState(() => _acceptsLarge = v ?? false),
            activeColor: _primary,
          ),
        ],
      ),
    );
  }

  Widget _pricingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tarification', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Definissez vos tarifs horaires et/ou journaliers',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hourlyRate,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelText: 'Tarif horaire',
              hintText: 'Ex: 200',
              isDense: true,
              errorText: _errHourlyRate,
              prefixIcon: const Icon(Icons.schedule),
              suffixText: 'DA/h',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dailyRate,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelText: 'Tarif journalier',
              hintText: 'Ex: 1500',
              isDense: true,
              errorText: _errDailyRate,
              prefixIcon: const Icon(Icons.calendar_today),
              suffixText: 'DA/jour',
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.2)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
