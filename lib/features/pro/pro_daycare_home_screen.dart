import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/session_controller.dart';

class DaycareHomeScreen extends ConsumerStatefulWidget {
  const DaycareHomeScreen({super.key});

  @override
  ConsumerState<DaycareHomeScreen> createState() => _DaycareHomeScreenState();
}

class _DaycareHomeScreenState extends ConsumerState<DaycareHomeScreen> {
  Future<Map<String, dynamic>>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final api = ref.read(apiProvider);

    // Charger en parallèle les données du provider et les réservations
    final results = await Future.wait([
      api.myProvider(),
      _loadBookings(),
    ]);

    return {
      'provider': results[0],
      'bookings': results[1],
    };
  }

  Future<List<dynamic>> _loadBookings() async {
    final api = ref.read(apiProvider);
    try {
      final res = await api.dio.get('/daycare/provider/bookings');
      final data = res.data;
      if (data is Map && data['data'] is List) {
        return data['data'] as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) return;
    context.go('/auth/login?as=pro');
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garderie — Tableau de bord'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snap.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _dataFuture = _loadData()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final data = snap.data!;
          final provider = data['provider'] as Map<String, dynamic>?;
          final bookings = (data['bookings'] as List?) ?? [];

          if (provider == null || provider['isApproved'] != true) {
            return _NotApprovedView(provider: provider);
          }

          // Calculer les stats
          final pending = bookings.where((b) => b['status'] == 'PENDING').length;
          final confirmed = bookings.where((b) => b['status'] == 'CONFIRMED').length;
          final inProgress = bookings.where((b) => b['status'] == 'IN_PROGRESS').length;

          // Prochaines arrivées (confirmées, date future)
          final now = DateTime.now();
          final upcoming = bookings.where((b) {
            if (b['status'] != 'CONFIRMED') return false;
            final start = DateTime.parse(b['startDate']);
            return start.isAfter(now);
          }).toList()
            ..sort((a, b) {
              final aStart = DateTime.parse(a['startDate']);
              final bStart = DateTime.parse(b['startDate']);
              return aStart.compareTo(bStart);
            });

          return RefreshIndicator(
            onRefresh: () async => setState(() => _dataFuture = _loadData()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.pending_actions,
                        label: 'En attente',
                        value: pending.toString(),
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle,
                        label: 'Confirmées',
                        value: confirmed.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.pets,
                        label: 'Présents',
                        value: inProgress.toString(),
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Actions rapides
                _SectionTitle('Actions rapides'),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.calendar_month,
                  title: 'Toutes les réservations',
                  subtitle: '${bookings.length} réservation(s) au total',
                  onTap: () => context.push('/pro/daycare/bookings'),
                ),
                _ActionTile(
                  icon: Icons.calendar_today,
                  title: 'Calendrier',
                  subtitle: 'Vue par jour',
                  onTap: () => context.push('/pro/daycare/calendar'),
                ),

                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle('Prochaines arrivées (${upcoming.length})'),
                  const SizedBox(height: 12),
                  ...upcoming.take(5).map((booking) => _UpcomingCard(booking: booking)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotApprovedView extends StatelessWidget {
  final Map<String, dynamic>? provider;
  const _NotApprovedView({this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Aucun profil garderie trouvé',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Créez votre profil de garderie pour commencer',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/auth/register/pro'),
                child: const Text('Créer mon profil'),
              ),
            ],
          ),
        ),
      );
    }

    final rejected = provider!['rejectedAt'] != null;
    final reason = provider!['rejectionReason']?.toString() ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              rejected ? Icons.cancel : Icons.hourglass_empty,
              size: 64,
              color: rejected ? Colors.red : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              rejected ? 'Candidature rejetée' : 'En attente d\'approbation',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              rejected
                  ? 'Votre candidature a été rejetée par l\'administration.'
                  : 'Votre candidature est en cours d\'examen.',
              textAlign: TextAlign.center,
            ),
            if (rejected && reason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motif du rejet:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(reason),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFF36C6C)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _UpcomingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final pet = booking['pet'] as Map<String, dynamic>?;
    final user = booking['user'] as Map<String, dynamic>?;
    final startDate = DateTime.parse(booking['startDate']);
    final endDate = DateTime.parse(booking['endDate']);

    final dateFormat = DateFormat('dd/MM à HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.2),
          child: const Icon(Icons.pets, color: Colors.blue),
        ),
        title: Text(
          pet?['name'] ?? 'Animal',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Propriétaire: ${user?['firstName']} ${user?['lastName']}'),
            Text('Arrivée: ${dateFormat.format(startDate)}'),
            Text('Départ: ${dateFormat.format(endDate)}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
