import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';

// Commission par défaut (fallback si non définie dans le profil)
const int kDefaultCommissionDa = 100;

/// Provider pour récupérer le profil du provider (et sa commission)
final _myProviderProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiProvider);
  return api.myProvider();
});

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class ProServicesScreen extends ConsumerStatefulWidget {
  const ProServicesScreen({super.key});
  @override
  ConsumerState<ProServicesScreen> createState() => _ProServicesScreenState();
}

class _ProServicesScreenState extends ConsumerState<ProServicesScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  final List<Map<String, dynamic>> _items = [];
  bool _didFirstLoad = false; // pour relancer au retour d’onglet

  // UI extras
  final _search = TextEditingController();
  String _filter = 'ALL'; // ALL | HOME | CLINIC

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFirstLoad) {
      _didFirstLoad = true;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (mounted) {
      setState(() {
        _loading = initial ? true : false;
        if (initial) _error = null;
      });
    }
    try {
      final api = ref.read(apiProvider);
      await api.ensureAuth();
      await api.myProvider(); // warm-up providerId

      final list = await api.myServices();
      _items
        ..clear()
        ..addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      if (mounted) setState(() {});
    } catch (e) {
      _error = e.toString();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _upsertLocal(Map<String, dynamic> svc) {
    final id = (svc['id'] ?? '').toString();
    final idx = _items.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (idx >= 0) {
      _items[idx] = svc;
    } else {
      _items.insert(0, svc);
    }
    setState(() {});
  }

  void _removeLocal(String id) {
    _items.removeWhere((e) => (e['id'] ?? '').toString() == id);
    setState(() {});
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _items.where((s) {
      final title = (s['title'] ?? '').toString().toLowerCase();
      final desc = (s['description'] ?? '').toString().toLowerCase();
      final isHome = title.contains('domicile') || desc.contains('[a_domicile]');
      final matchQuery = q.isEmpty || title.contains(q) || desc.contains(q);
      final matchFilter = switch (_filter) {
        'HOME' => isHome,
        'CLINIC' => !isHome,
        _ => true,
      };
      return matchQuery && matchFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final count = _filtered.length;

    // Récupérer la commission personnalisée du provider
    final providerAsync = ref.watch(_myProviderProvider);
    final commissionDa = providerAsync.maybeWhen(
      data: (p) => _asInt(p?['vetCommissionDa']) ?? kDefaultCommissionDa,
      orElse: () => kDefaultCommissionDa,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Services & Tarifs'),
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _EditServiceSheet(commissionDa: commissionDa),
          );
          if (created != null) _upsertLocal(created);
        },
        label: const Text('Nouveau'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty
              ? _EmptyState(onRefresh: _load, error: _error)
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: const SizedBox(height: 12)),
                      // Header joli + compteur
                      SliverToBoxAdapter(
                        child: _Header(
                          total: _items.length,
                          showing: count,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      // Barre de recherche
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _SearchBar(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            onClear: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      // Filtres
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _Segmented(
                            value: _filter,
                            onChanged: (v) => setState(() => _filter = v),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),

                      // Liste
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        sliver: SliverList.separated(
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemCount: count,
                          itemBuilder: (ctx, i) {
                            final s = _filtered[i];
                            final title =
                                (s['title'] ?? 'Service').toString().trim();
                            final durationMin =
                                _asInt(s['durationMin'] ?? s['duration']);
                            final priceServer =
                                _asInt(s['price'] ?? s['priceCents']);
                            int? basePrice =
                                priceServer != null ? priceServer - commissionDa : null;
                            if (basePrice != null && basePrice < 0) basePrice = 0;

                            final desc =
                                (s['description'] ?? '').toString().trim();
                            final isHome = title.toLowerCase().contains('domicile') ||
                                desc.contains('[A_DOMICILE]');
                            final id = (s['id'] ?? '').toString();

                            return _ServiceCard(
                              title: title,
                              description: desc.replaceAll('[A_DOMICILE]', '').trim(),
                              durationMin: durationMin,
                              basePriceDa: basePrice,
                              totalPriceDa: priceServer,
                              commissionDa: commissionDa,
                              isHome: isHome,
                              onTap: () async {
                                final updated = await showModalBottomSheet<
                                    Map<String, dynamic>>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => _EditServiceSheet(existing: s, commissionDa: commissionDa),
                                );
                                if (updated != null) _upsertLocal(updated);
                              },
                              onMenuSelected: (v) async {
                                if (v == 'edit') {
                                  final updated =
                                      await showModalBottomSheet<Map<String, dynamic>>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => _EditServiceSheet(existing: s, commissionDa: commissionDa),
                                  );
                                  if (updated != null) _upsertLocal(updated);
                                } else if (v == 'delete') {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Supprimer le service ?'),
                                      content: Text('“$title” sera définitivement supprimé.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(dialogCtx).pop(false),
                                          child: const Text('Annuler'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.of(dialogCtx).pop(true),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    try {
                                      if (id.isEmpty) {
                                        throw Exception('Identifiant de service manquant.');
                                      }
                                      await ref.read(apiProvider).deleteMyService(id);
                                      _removeLocal(id);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Service supprimé')),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Suppression impossible: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh, this.error});
  final Future<void> Function({bool initial}) onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medical_services_outlined, size: 42, color: Colors.black38),
            const SizedBox(height: 8),
            const Text('Aucun service. Ajoutez-en avec le bouton +'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => onRefresh(initial: true),
              child: const Text('Rafraîchir'),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }
}

/// =====================
/// UI Components
/// =====================

class _Header extends StatelessWidget {
  const _Header({required this.total, required this.showing});
  final int total;
  final int showing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7DFF), Color(0xFF6C5CE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.medical_services, color: Color(0xFF2E7DFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vos services', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 2),
                Text(
                  '$showing affiché${showing > 1 ? 's' : ''} / $total',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher un service…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'ALL', label: Text('Tous'), icon: Icon(Icons.list)),
        ButtonSegment(value: 'CLINIC', label: Text('En cabinet'), icon: Icon(Icons.local_hospital_outlined)),
        ButtonSegment(value: 'HOME', label: Text('À domicile'), icon: Icon(Icons.home_outlined)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: const ButtonStyle(visualDensity: VisualDensity.comfortable),
      showSelectedIcon: false,
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.description,
    required this.durationMin,
    required this.basePriceDa,
    required this.totalPriceDa,
    required this.commissionDa,
    required this.isHome,
    required this.onTap,
    required this.onMenuSelected,
  });

  final String title;
  final String description;
  final int? durationMin;
  final int? basePriceDa;   // hors commission (pro)
  final int? totalPriceDa;  // total payé par le client
  final int commissionDa;
  final bool isHome;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (durationMin != null)
        _chip(icon: Icons.schedule, label: '${durationMin} min'),
      if (isHome)
        _chip(icon: Icons.home_outlined, label: 'À domicile'),
      if (basePriceDa != null && totalPriceDa != null)
        _chip(icon: Icons.payments_outlined, label: '${basePriceDa} + $commissionDa = $totalPriceDa DA'),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .98, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 6))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40, width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medical_services, color: Color(0xFF2E7DFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: -4,
                        children: chips,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, height: 1.2),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: onMenuSelected,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// =====================
/// Bottom sheet d’édition (inchangé côté logique)
/// =====================

class _EditServiceSheet extends ConsumerStatefulWidget {
  const _EditServiceSheet({this.existing, required this.commissionDa});
  final Map<String, dynamic>? existing;
  final int commissionDa;

  @override
  ConsumerState<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends ConsumerState<_EditServiceSheet> {
  final _title = TextEditingController();
  final _duration = TextEditingController();
  final _price = TextEditingController(); // prix saisi HORS commission
  final _desc = TextEditingController();
  bool _atHome = false; // UI-only
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      final rawTitle = (e['title'] ?? '').toString();
      final desc = (e['description'] ?? '').toString();
      final isHome =
          rawTitle.toLowerCase().contains('domicile') ||
          desc.contains('[A_DOMICILE]');

      _title.text = rawTitle.replaceAll(
        RegExp(r'\s*\(à domicile\)$', caseSensitive: false),
        '',
      );

      final d = _asInt(e['durationMin'] ?? e['duration']);
      if (d != null) _duration.text = d.toString();

      final pServer = _asInt(e['price'] ?? e['priceCents']); // total (incl. commission)
      if (pServer != null) {
        final base = pServer - widget.commissionDa;
        _price.text = (base > 0 ? base : 0).toString();
      }

      _atHome = isHome;
      _desc.text = desc.replaceAll('[A_DOMICILE]', '').trim();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _price.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Modifier le service' : 'Nouveau service',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Intitulé *',
                  hintText: 'Consultation, Vaccination…',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _duration,
                decoration: const InputDecoration(
                  labelText: 'Durée (minutes) *',
                  hintText: 'ex: 20',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),

              // Prix obligatoire (hors commission)
              TextField(
                controller: _price,
                decoration: InputDecoration(
                  labelText: 'Tarif (DA, hors commission) *',
                  hintText: 'ex: 2000',
                  helperText: '+${widget.commissionDa} DA de commission seront ajoutés automatiquement',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                value: _atHome,
                onChanged: (v) => setState(() => _atHome = v),
                title: const Text('À domicile'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (enregistrée, visible client)',
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final titleRaw = _title.text.trim();
                          final dur = int.tryParse(_duration.text.trim());
                          final basePrice = int.tryParse(_price.text.trim());

                          if (titleRaw.isEmpty || dur == null || basePrice == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Titre, durée et tarif sont obligatoires')),
                            );
                            return;
                          }
                          if (dur < 15) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('La durée minimale est 15 minutes')),
                            );
                            return;
                          }
                          if (basePrice < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Le tarif doit être positif')),
                            );
                            return;
                          }

                          final priceToSend = basePrice + widget.commissionDa;

                          final titleForApi = _atHome && !titleRaw.toLowerCase().contains('domicile')
                              ? '$titleRaw (à domicile)'
                              : titleRaw;

                          final descRaw = _desc.text.trim();
                          final descForApi = _atHome && !descRaw.contains('[A_DOMICILE]')
                              ? (descRaw.isEmpty ? '[A_DOMICILE]' : '$descRaw [A_DOMICILE]')
                              : (descRaw.isEmpty ? null : descRaw);

                          setState(() => _saving = true);
                          try {
                            Map<String, dynamic> saved;
                            if (isEdit) {
                              final id = (widget.existing!['id'] ?? '').toString();
                              saved = await ref.read(apiProvider).updateMyService(
                                    id,
                                    title: titleForApi,
                                    durationMin: dur,
                                    price: priceToSend,
                                    description: descForApi,
                                  );
                            } else {
                              saved = await ref.read(apiProvider).createMyService(
                                    title: titleForApi,
                                    durationMin: dur,
                                    price: priceToSend,
                                    description: descForApi,
                                  );
                            }
                            if (mounted) Navigator.pop(context, saved);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(_saving ? '...' : (isEdit ? 'Enregistrer' : 'Créer')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
