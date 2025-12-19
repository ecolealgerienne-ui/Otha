import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'admin_shared.dart';
import 'admin_editor.dart';
import 'admin_user_detail_screen.dart';

/// ================= Thème admin (saumon) =================
ThemeData _adminTheme(BuildContext context) {
  final base = Theme.of(context);
  const salmon = AdminColors.salmon;
  const ink = AdminColors.ink;
  const soft = Color(0xFFFFE7E7);

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: salmon,
      secondary: salmon,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const MaterialStatePropertyAll(salmon),
        foregroundColor: const MaterialStatePropertyAll(Colors.white),
        overlayColor: MaterialStatePropertyAll(salmon.withOpacity(.12)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const MaterialStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const MaterialStatePropertyAll(salmon),
        side: const MaterialStatePropertyAll(
          BorderSide(color: salmon, width: 1.2),
        ),
        overlayColor: MaterialStatePropertyAll(salmon.withOpacity(.08)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        textStyle: const MaterialStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      fillColor: salmon,
      selectedColor: Colors.white,
      color: ink,
      borderRadius: BorderRadius.circular(10),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: salmon),
    dividerColor: soft,
  );
}

/// ================= Helpers =================
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String _firstLetter(String s) =>
    s.isEmpty ? '?' : s.substring(0, 1).toUpperCase();

/// Canonicalise 'YYYY-M' → 'YYYY-MM'
String _canonYm(String s) {
  final t = s.replaceAll('/', '-').trim();
  final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(t) ??
      RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(t);
  if (m == null) return t;
  final y = m.group(1)!;
  final mo = int.parse(m.group(2)!);
  return '$y-${mo.toString().padLeft(2, '0')}';
}

/// ============ Badges status (soft #FFE7E7 + emoji blanc) ============
class _StatusEmojiBar extends StatelessWidget {
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  const _StatusEmojiBar({
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
  });

  static const _soft = Color(0xFFFFE7E7);

  Widget _chip(String emoji, int n) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AdminColors.salmon.withOpacity(.55),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AdminColors.salmon,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$n',
              style: const TextStyle(
                color: AdminColors.salmon,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('⏳', pending),
          const SizedBox(width: 8),
          _chip('📅', confirmed),
          const SizedBox(width: 8),
          _chip('✅', completed),
          const SizedBox(width: 8),
          _chip('❌', cancelled),
        ],
      ),
    );
  }
}

Widget _pillMini(String emoji, int n) {
  const soft = Color(0xFFFFE7E7);
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 32),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AdminColors.salmon.withOpacity(.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AdminColors.salmon,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$n',
            style: const TextStyle(
              color: AdminColors.salmon,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

/// ===========================================================
/// ===================== USERS ===============================
/// ===========================================================
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _q = TextEditingController();

Future<List<Map<String, dynamic>>> _load() async {
  final api = ref.read(apiProvider);
  // On filtre explicitement les clients (role=USER)
  final rows = await api.adminListUsers(
    q: _q.text.trim(),
    role: 'USER',
    limit: 1000,
    offset: 0,
  );
  return rows.map<Map<String, dynamic>>((e) {
    return (e is Map)
        ? Map<String, dynamic>.from(e as Map)
        : <String, dynamic>{};
  }).toList();
}

Future<void> _handleResetQuotas(BuildContext context, String userId, String userName) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset quotas adoption'),
      content: Text(
        'Voulez-vous réinitialiser les quotas d\'adoption (annonces + swipes) pour $userName ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Reset'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    final api = ref.read(apiProvider);
    await api.adminResetUserAdoptQuotas(userId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Quotas réinitialisés')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}

Future<void> _handleResetTrust(BuildContext context, String userId, String userName) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Lever la restriction'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lever la restriction de compte pour $userName ?'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Cette action va:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 8),
                Text('• Remettre le statut à "NEW"', style: TextStyle(fontSize: 12)),
                Text('• Décrémenter le compteur de no-show', style: TextStyle(fontSize: 12)),
                Text('• Lever la restriction de compte', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Lever restriction'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    final api = ref.read(apiProvider);
    await api.adminResetUserTrustStatus(userId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Restriction levée'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Future<void> _showEditUserDialog(BuildContext context, Map<String, dynamic> user) async {
  final userId = user['id']?.toString() ?? '';
  final firstNameCtl = TextEditingController(text: user['firstName']?.toString() ?? '');
  final lastNameCtl = TextEditingController(text: user['lastName']?.toString() ?? '');
  final emailCtl = TextEditingController(text: user['email']?.toString() ?? '');
  final phoneCtl = TextEditingController(text: user['phone']?.toString() ?? '');
  final cityCtl = TextEditingController(text: user['city']?.toString() ?? '');

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Modifier utilisateur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameCtl,
              decoration: const InputDecoration(
                labelText: 'Prénom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastNameCtl,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtl,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cityCtl,
              decoration: const InputDecoration(
                labelText: 'Ville',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );

  if (result != true) return;

  try {
    final api = ref.read(apiProvider);
    await api.adminUpdateUser(
      userId,
      firstName: firstNameCtl.text.trim(),
      lastName: lastNameCtl.text.trim(),
      email: emailCtl.text.trim(),
      phone: phoneCtl.text.trim(),
      city: cityCtl.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Utilisateur modifié')),
      );
      setState(() {}); // Recharger la liste
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _adminTheme(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Clients')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _q,
                decoration: InputDecoration(
                  hintText: 'Rechercher nom, email, téléphone…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _load(),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Erreur: ${snap.error}'));
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return const Center(child: Text('Aucun résultat'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = items[i];
                        final email = (m['email'] ?? '').toString();
                        final first = (m['firstName'] ?? '').toString();
                        final last = (m['lastName'] ?? '').toString();
                        final phone = (m['phone'] ?? '').toString();
                        final role = (m['role'] ?? '').toString();
                        final reportedCount = (m['reportedConversationsCount'] ?? 0) as int;
                        final trustStatus = (m['trustStatus'] ?? 'NEW').toString();
                        final name = [
                          first,
                          last,
                        ].where((e) => e.trim().isNotEmpty).join(' ').trim();
                        final avatarSeed = (name.isEmpty ? email : name);
                        final userId = m['id']?.toString() ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE7E7),
                            child: Text(
                              _firstLetter(avatarSeed),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AdminColors.ink,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name.isEmpty ? '(Sans nom)' : name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (reportedCount > 0) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: '$reportedCount conversation(s) signalée(s)',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🚩', style: TextStyle(fontSize: 12)),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$reportedCount',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              // Badge RESTRICTED
                              if (trustStatus == 'RESTRICTED') ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Compte restreint',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('🚫', style: TextStyle(fontSize: 12)),
                                        SizedBox(width: 2),
                                        Text(
                                          'RESTRICTED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              // Badge VERIFIED
                              if (trustStatus == 'VERIFIED') ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Utilisateur vérifié',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('✓', style: TextStyle(fontSize: 12, color: Colors.green)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            [
                              email,
                              if (phone.isNotEmpty) phone,
                              if (role.isNotEmpty) 'role=$role',
                            ].join(' • '),
                          ),
                          onTap: () {
                            // Naviguer vers la page de détails
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AdminUserDetailScreen(user: m),
                              ),
                            );
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _showEditUserDialog(context, m);
                              } else if (value == 'reset_quotas') {
                                await _handleResetQuotas(context, userId, name.isEmpty ? email : name);
                              } else if (value == 'reset_trust') {
                                await _handleResetTrust(context, userId, name.isEmpty ? email : name);
                              } else if (value == 'view_reported') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AdminUserDetailScreen(user: m),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Modifier'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'reset_quotas',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh, size: 18),
                                    SizedBox(width: 8),
                                    Text('Reset quotas adoption'),
                                  ],
                                ),
                              ),
                              if (trustStatus == 'RESTRICTED')
                                const PopupMenuItem(
                                  value: 'reset_trust',
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_open, size: 18, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Lever restriction', style: TextStyle(color: Colors.green)),
                                    ],
                                  ),
                                ),
                              if (reportedCount > 0)
                                const PopupMenuItem(
                                  value: 'view_reported',
                                  child: Row(
                                    children: [
                                      Text('🚩', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 8),
                                      Text('Voir conversations signalées'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===========================================================
/// ================= PROS APPROUVÉS ==========================
/// ===========================================================
class AdminProsApprovedPage extends ConsumerStatefulWidget {
  const AdminProsApprovedPage({super.key});
  @override
  ConsumerState<AdminProsApprovedPage> createState() =>
      _AdminProsApprovedPageState();
}

class _AdminProsApprovedPageState extends ConsumerState<AdminProsApprovedPage> {
  final _q = TextEditingController();

  Future<List<dynamic>> _load() async {
    final api = ref.read(apiProvider);
    final rows = await api.listProviderApplications(
      status: 'approved',
      limit: 1000,
    );
    final needle = _q.text.trim().toLowerCase();
    if (needle.isEmpty) return rows;
    return rows.where((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final name = (m['displayName'] ?? '').toString().toLowerCase();
      final addr = (m['address'] ?? '').toString().toLowerCase();
      final u = Map<String, dynamic>.from((m['user'] ?? const {}) as Map);
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(needle) ||
          addr.contains(needle) ||
          email.contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _adminTheme(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Pros approuvés')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _q,
                decoration: InputDecoration(
                  hintText: 'Rechercher pro…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _load(),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Erreur: ${snap.error}'));
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return const Center(child: Text('Aucun pro approuvé'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = Map<String, dynamic>.from(items[i] as Map);
                        final name = (p['displayName'] ?? '').toString();
                        final addr = (p['address'] ?? '').toString();
                        final u = Map<String, dynamic>.from(
                          (p['user'] ?? const {}) as Map,
                        );
                        final email = (u['email'] ?? '').toString();
                        final lat = (p['lat'] as num?)?.toDouble();
                        final lng = (p['lng'] as num?)?.toDouble();

                        final avatarSeed = (name.isEmpty ? email : name);
                        return ListTile(
                          onTap: () => showProviderEditor(
                            context,
                            ref,
                            p,
                            mode: ProviderEditorMode.approved,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE7E7),
                            child: Text(
                              _firstLetter(avatarSeed),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AdminColors.ink,
                              ),
                            ),
                          ),
                          title: Text(
                            name.isEmpty ? '(Sans nom)' : name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (email.isNotEmpty) email,
                              if (addr.isNotEmpty) addr,
                              if (lat != null && lng != null)
                                'lat=${lat.toStringAsFixed(4)} lng=${lng.toStringAsFixed(4)}',
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===========================================================
/// ==================== CANDIDATURES =========================
/// ===========================================================
class AdminApplicationsPage extends ConsumerStatefulWidget {
  const AdminApplicationsPage({super.key});
  @override
  ConsumerState<AdminApplicationsPage> createState() =>
      _AdminApplicationsPageState();
}

class _AdminApplicationsPageState extends ConsumerState<AdminApplicationsPage> {
  String _tab = 'pending'; // 'pending' | 'rejected'
  Future<List<dynamic>> _load() =>
      ref.read(apiProvider).listProviderApplications(status: _tab, limit: 1000);

  @override
  Widget build(BuildContext context) {
    final chipStyle = Theme.of(context).chipTheme.copyWith(
      side: const BorderSide(color: Colors.transparent),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );

    return Theme(
      data: _adminTheme(context).copyWith(chipTheme: chipStyle),
      child: Scaffold(
        appBar: AppBar(title: const Text('Candidatures')),
        body: Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7E7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AdminColors.salmon.withOpacity(0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(10),
                    selectedColor: Colors.white,
                    color: AdminColors.ink,
                    fillColor: AdminColors.salmon,
                    isSelected: [_tab == 'pending', _tab == 'rejected'],
                    onPressed: (i) =>
                        setState(() => _tab = i == 0 ? 'pending' : 'rejected'),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('En attente'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('Rejetées'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _load(),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Erreur: ${snap.error}'));
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        _tab == 'pending'
                            ? 'Aucune candidature'
                            : 'Aucun rejet',
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = Map<String, dynamic>.from(items[i] as Map);
                        final id = (p['id'] ?? '').toString();
                        final name = (p['displayName'] ?? '').toString();
                        final addr = (p['address'] ?? '').toString();
                        final u = Map<String, dynamic>.from(
                          (p['user'] ?? const {}) as Map,
                        );
                        final email = (u['email'] ?? '').toString();
                        final role = (u['role'] ?? '').toString();

                        final avatarSeed = (name.isEmpty ? email : name);
                        return ListTile(
                          onTap: () => showProviderEditor(
                            context,
                            ref,
                            p,
                            mode: _tab == 'pending'
                                ? ProviderEditorMode.pending
                                : ProviderEditorMode.rejected,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE7E7),
                            child: Text(
                              _firstLetter(avatarSeed),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AdminColors.ink,
                              ),
                            ),
                          ),
                          title: Text(
                            name.isEmpty ? '(Sans nom)' : name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (role.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(role),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getRoleLabel(role),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                [email, if (addr.isNotEmpty) addr].join(' • '),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_tab == 'pending') ...[
                                TextButton(
                                  onPressed: () async {
                                    await ref
                                        .read(apiProvider)
                                        .rejectProvider(id);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Rejeté ❌')),
                                    );
                                    setState(() {});
                                  },
                                  child: const Text(
                                    'Rejeter',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                FilledButton(
                                  onPressed: () async {
                                    await ref
                                        .read(apiProvider)
                                        .approveProvider(id);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Approuvé ✅'),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  child: const Text('Approuver'),
                                ),
                              ] else ...[
                                FilledButton(
                                  onPressed: () async {
                                    await ref
                                        .read(apiProvider)
                                        .approveProvider(id);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Ré-approuvé ✅'),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  child: const Text('Ré-approuver'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'vet':
        return 'VÉTÉRINAIRE';
      case 'daycare':
        return 'GARDERIE';
      case 'petshop':
        return 'PETSHOP';
      case 'admin':
        return 'ADMIN';
      default:
        return role.toUpperCase();
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'vet':
        return const Color(0xFFE57373); // Red/Pink for vets
      case 'daycare':
        return const Color(0xFF4CAF50); // Green for daycare
      case 'petshop':
        return const Color(0xFF64B5F6); // Blue for petshop
      case 'admin':
        return const Color(0xFF9575CD); // Purple for admin
      default:
        return Colors.grey;
    }
  }
}

/// ===========================================================
/// ===================== COMMISSIONS =========================
/// Générées(scope) = somme des `dueDa` sur l’historique (tous pros)
/// Collecté(scope) = somme des `collectedDa` (backend)
/// Net(scope)      = max(Générées - Collecté, 0)
/// Scope = "ALL" (toute période) ou "YYYY-MM" (mois donné)
/// ===========================================================
class AdminCommissionsPage extends ConsumerStatefulWidget {
  const AdminCommissionsPage({super.key});
  @override
  ConsumerState<AdminCommissionsPage> createState() =>
      _AdminCommissionsPageState();
}

class _AdminCommissionsPageState extends ConsumerState<AdminCommissionsPage> {
  int _reload = 0;

  // "ALL" = tout le temps ; sinon "YYYY-MM"
  late String _scope;
  late List<String> _months;

  @override
  void initState() {
    super.initState();
    _scope = 'ALL';
    final now = DateTime.now().toUtc();
    _months = List.generate(36, (i) {
      final d = DateTime.utc(now.year, now.month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  Widget _metric(String label, int amount) {
    return Text(
      '$label: ${formatDa(amount)}',
      style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(.65)),
      overflow: TextOverflow.ellipsis,
    );
  }

  // ---- Agrégations (backend only) -----------------------------------------

  Future<Map<String, int>> _totalsForScope() async {
    final approved = await ref
        .read(apiProvider)
        .listProviderApplications(status: 'approved', limit: 1000, offset: 0);

    final futures = <Future<Map<String, int>>>[];
    for (final raw in approved) {
      final p = (raw is Map)
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final pid = (p['id'] ?? '').toString();
      if (pid.isEmpty) continue;
      futures.add(_sumProvider(pid));
    }

    int due = 0, coll = 0;
    final parts = await Future.wait(futures);
    for (final m in parts) {
      due += m['due'] ?? 0;
      coll += m['collected'] ?? 0;
    }
    final net = (due - coll) < 0 ? 0 : (due - coll);
    return {'due': due, 'collected': coll, 'net': net};
  }

  // AdminCommissionsPage::_sumProvider (backend only)
  Future<Map<String, int>> _sumProvider(String providerId) async {
    final hist = await ref
        .read(apiProvider)
        .adminHistoryMonthly(months: 120, providerId: providerId);

    int due = 0, coll = 0;
    if (_scope == 'ALL') {
      for (final e in hist) {
        final d = _asInt((e as Map)['dueDa']);
        final c = _asInt((e as Map)['collectedDa']);
        due += d;
        coll += (c > d ? d : c);
      }
    } else {
      final scope = _canonYm(_scope);
      final row = hist
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            m['month'] = _canonYm((m['month'] ?? '').toString());
            return m;
          })
          .firstWhere(
            (e) => (e['month'] ?? '').toString() == scope,
            orElse: () => const <String, dynamic>{},
          );
      final d = _asInt(row['dueDa']);
      final c = _asInt(row['collectedDa']);
      due = d;
      coll = (c > d ? d : c);
    }
    final net = (due - coll) < 0 ? 0 : (due - coll);
    return {'due': due, 'collected': coll, 'net': net};
  }

  Future<List<Map<String, dynamic>>> _rowsForScope() async {
    final approved = await ref
        .read(apiProvider)
        .listProviderApplications(status: 'approved', limit: 1000, offset: 0);
    final futures = <Future<Map<String, dynamic>>>[];

    for (final raw in approved) {
      final p = (raw is Map)
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final pid = (p['id'] ?? '').toString();
      if (pid.isEmpty) continue;
      futures.add(_rowProviderScope(p));
    }

    final rows = await Future.wait(futures);
    rows.sort((a, b) => (_asInt(b['dueDa'])).compareTo(_asInt(a['dueDa'])));
    return rows;
  }

  // AdminCommissionsPage::_rowProviderScope (backend only)
  Future<Map<String, dynamic>> _rowProviderScope(
      Map<String, dynamic> provider) async {
    final pid = (provider['id'] ?? '').toString();
    final hist = await ref
        .read(apiProvider)
        .adminHistoryMonthly(months: 120, providerId: pid);

    final canonHist = hist
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['month'] = _canonYm((m['month'] ?? '').toString());
          return m;
        })
        .toList();

    int due = 0, coll = 0, completed = 0;
    if (_scope == 'ALL') {
      for (final e in canonHist) {
        final d = _asInt(e['dueDa']);
        final c = _asInt(e['collectedDa']);
        due += d;
        coll += (c > d ? d : c);
        completed += _asInt(e['completed']);
      }
    } else {
      final scope = _canonYm(_scope);
      final row = canonHist.firstWhere(
        (e) => (e['month'] ?? '').toString() == scope,
        orElse: () => const <String, dynamic>{},
      );
      final d = _asInt(row['dueDa']);
      final c = _asInt(row['collectedDa']);
      due = d;
      coll = (c > d ? d : c);
      completed = _asInt(row['completed']);
    }
    final net = (due - coll) < 0 ? 0 : (due - coll);
    return {
      'provider': provider,
      'completed': completed,
      'dueDa': due,
      'collectedDa': coll,
      'netDa': net
    };
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _adminTheme(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Commissions')),
        body: Column(
          children: [
            // Barre de filtre scope
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  const Text('Période', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _scope,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem(value: 'ALL', child: Text('Tout le temps')),
                      ..._months.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                    ],
                    onChanged: (v) => setState(() {
                      _scope = v ?? 'ALL';
                      _reload++;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Contenu
            Expanded(
              child: FutureBuilder<Map<String, int>>(
                key: ValueKey('tot-$_scope-$_reload'),
                future: _totalsForScope(),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Erreur: ${snap.error}'));
                  }
                  final s = snap.data ?? const {'due': 0, 'collected': 0, 'net': 0};
                  final net = s['net'] ?? 0;
                  final due = s['due'] ?? 0;
                  final coll = s['collected'] ?? 0;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      MoneyCardDa(title: 'À percevoir', amountDa: net, color: Colors.orange, icon: Icons.receipt_long),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: MoneyCardDa(title: 'Collecté', amountDa: coll, color: Colors.green, icon: Icons.task_alt)),
                        const SizedBox(width: 10),
                        Expanded(child: MoneyCardDa(title: 'Générées', amountDa: due, color: Colors.blueGrey, icon: Icons.summarize)),
                      ]),
                      const SizedBox(height: 18),
                      Text(
                        _scope == 'ALL' ? 'Détail par pro (tout le temps)' : 'Détail par pro — ${_scope}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),

                      FutureBuilder<List<Map<String, dynamic>>>(
                        key: ValueKey('rows-$_scope-$_reload'),
                        future: _rowsForScope(),
                        builder: (ctx, s2) {
                          if (s2.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (s2.hasError) return Text('Erreur: ${s2.error}');
                          final rows = (s2.data ?? const []);
                          if (rows.isEmpty) return const Text('Aucun pro approuvé');

                          return Column(
                            children: rows.map((e) {
                              final p = Map<String, dynamic>.from(e['provider'] as Map);
                              final id = (p['id'] ?? '').toString();
                              final name = (p['displayName'] ?? '').toString();
                              final u = Map<String, dynamic>.from((p['user'] ?? const {}) as Map);
                              final email = (u['email'] ?? '').toString();

                              final completed = _asInt(e['completed']);
                              final dueDa = _asInt(e['dueDa']);
                              final collDa = _asInt(e['collectedDa']);
                              final netDa = _asInt(e['netDa']);
                              final titleText = name.isEmpty ? '(Sans nom)' : name;

                              return Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.of(context)
                                        .push(
                                          MaterialPageRoute(
                                            builder: (_) => AdminProviderHistoryPage(
                                              providerId: id,
                                              displayName: titleText,
                                              email: email,
                                            ),
                                          ),
                                        )
                                        .then((_) => setState(() => _reload++));
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color(0xFFFFE7E7),
                                          child: Icon(Icons.pets, color: AdminColors.ink),
                                        ),
                                        const SizedBox(width: 12),

                                        // Colonne gauche : titre + infos
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                titleText,
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(email, overflow: TextOverflow.ellipsis),
                                              Text(
                                                '$completed RDV complétés',
                                                style: TextStyle(color: Colors.black.withOpacity(.65)),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Colonne droite : montants (empilés)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              formatDa(netDa),
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                            const SizedBox(height: 6),
                                            _metric('Générées', dueDa),
                                            const SizedBox(height: 2),
                                            _metric('Collecté', collDa),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===========================================================
/// ========== Historique par pro (saumon + emojis) ===========
/// ===========================================================
class AdminProviderHistoryPage extends ConsumerStatefulWidget {
  final String providerId;
  final String displayName;
  final String email;
  const AdminProviderHistoryPage({
    super.key,
    required this.providerId,
    required this.displayName,
    required this.email,
  });

  @override
  ConsumerState<AdminProviderHistoryPage> createState() =>
      _AdminProviderHistoryPageState();
}

class _AdminProviderHistoryPageState
    extends ConsumerState<AdminProviderHistoryPage> {
  late String _selectedMonth; // 'YYYY-MM'
  late List<String> _months;
  int _reload = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _months = List.generate(12, (i) {
      final d = DateTime.utc(now.year, now.month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
    _selectedMonth = _months.first;
  }

  Map<String, dynamic> _normalizeMonthRow(Map<String, dynamic> m) {
    final month = _canonYm((m['month'] ?? '').toString());
    final due = _asInt(m['dueDa']);
    int collected = _asInt(m['collectedDa']);
    if (collected > due) collected = due;
    final net = (due - collected) < 0 ? 0 : (due - collected);
    return {
      'month': month,
      'pending': _asInt(m['pending']),
      'confirmed': _asInt(m['confirmed']),
      'completed': _asInt(m['completed']),
      'cancelled': _asInt(m['cancelled']),
      'dueDa': due,
      'collectedDa': collected,
      'netDa': net,
    };
  }

  Future<Map<String, dynamic>> _summaryForMonthFromHistory(String month) async {
    final list = await ref
        .read(apiProvider)
        .adminHistoryMonthly(months: 24, providerId: widget.providerId);

    final byMonth = {
      for (final raw in list)
        _canonYm((raw['month'] ?? '').toString()):
            Map<String, dynamic>.from(raw as Map),
    };

    final ym = _canonYm(month);
    final m = byMonth[ym] ?? const <String, dynamic>{};
    return _normalizeMonthRow({'month': ym, ...m});
  }

  Future<List<Map<String, dynamic>>> _history() async {
    final list = await ref
        .read(apiProvider)
        .adminHistoryMonthly(months: 12, providerId: widget.providerId);
    return list.map<Map<String, dynamic>>((raw) {
      final m = (raw is Map)
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      m['month'] = _canonYm((m['month'] ?? '').toString());
      return _normalizeMonthRow(m);
    }).toList();
  }

  Future<void> _markCollected() async {
    setState(() => _busy = true);
    try {
      final ym = _canonYm(_selectedMonth);
      await ref
          .read(apiProvider)
          .adminCollectMonth(month: ym, providerId: widget.providerId);
      if (!mounted) return;
      setState(() => _reload++);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marqué comme collecté')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uncollect() async {
    setState(() => _busy = true);
    try {
      final ym = _canonYm(_selectedMonth);
      await ref
          .read(apiProvider)
          .adminUncollectMonth(month: ym, providerId: widget.providerId);
      if (!mounted) return;
      setState(() => _reload++);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Collecte annulée')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleName = widget.displayName.isEmpty
        ? '(Sans nom)'
        : widget.displayName;
    final avatarSeed = widget.displayName.isEmpty
        ? widget.email
        : widget.displayName;

    return Theme(
      data: _adminTheme(context),
      child: Scaffold(
        appBar: AppBar(title: Text('Historique — $titleName')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFE7E7),
                  child: Text(
                    _firstLetter(avatarSeed),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AdminColors.ink,
                    ),
                  ),
                ),
                title: Text(
                  titleName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(widget.email),
              ),
            ),
            const SizedBox(height: 12),

            // Sélecteur mois
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFE7E7).withOpacity(.7),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Mois',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedMonth,
                    items: _months
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedMonth = v ?? _selectedMonth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Actions
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _markCollected,
                icon: const Icon(Icons.task_alt),
                label: const Text('Déjà collecté'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _uncollect,
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(height: 12),

            // Résumé
            FutureBuilder<Map<String, dynamic>>(
              key: ValueKey('sum-${_selectedMonth}-$_reload'),
              future: _summaryForMonthFromHistory(_selectedMonth),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snap.hasError) return Text('Erreur: ${snap.error}');
                final s = snap.data ?? const {};
                final pending = _asInt(s['pending']);
                final confirmed = _asInt(s['confirmed']);
                final completed = _asInt(s['completed']);
                final cancelled = _asInt(s['cancelled']);
                final dueDa = _asInt(s['dueDa']);
                final collDa = _asInt(s['collectedDa']);
                final netDa = _asInt(s['netDa']);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusEmojiBar(
                      pending: pending,
                      confirmed: confirmed,
                      completed: completed,
                      cancelled: cancelled,
                    ),
                    const SizedBox(height: 12),
                    MoneyCardDa(
                      title: 'À percevoir',
                      amountDa: netDa,
                      color: Colors.orange,
                      icon: Icons.receipt_long,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: MoneyCardDa(
                            title: 'Collecté',
                            amountDa: collDa,
                            color: Colors.green,
                            icon: Icons.task_alt,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MoneyCardDa(
                            title: 'Générées',
                            amountDa: dueDa,
                            color: Colors.blueGrey,
                            icon: Icons.summarize,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),

            // Historique
            const Text(
              'Historique mensuel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey('hist-$_reload'),
              future: _history(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) return Text('Erreur: ${snap.error}');
                final rows = snap.data ?? const [];
                if (rows.isEmpty) return const Text('Aucun historique');

                return Column(
                  children: rows.map((e) {
                    final month = (e['month'] ?? '').toString();
                    final pending = _asInt(e['pending']);
                    final confirmed = _asInt(e['confirmed']);
                    final completed = _asInt(e['completed']);
                    final cancelled = _asInt(e['cancelled']);
                    final dueDa = _asInt(e['dueDa']);
                    final collDa = _asInt(e['collectedDa']);
                    final netDa = _asInt(e['netDa']);

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        title: Text(
                          month,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _pillMini('⏳', pending),
                              const SizedBox(width: 6),
                              _pillMini('📅', confirmed),
                              const SizedBox(width: 6),
                              _pillMini('✅', completed),
                              const SizedBox(width: 6),
                              _pillMini('❌', cancelled),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatDa(netDa),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'collectés: ${formatDa(collDa)}',
                              style: TextStyle(
                                color: Colors.black.withOpacity(.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => setState(() => _selectedMonth = month),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
/// ========== Modération Adoptions (Tinder-like) ==========
class AdminAdoptPostsPage extends ConsumerStatefulWidget {
  const AdminAdoptPostsPage({super.key});
  @override
  ConsumerState<AdminAdoptPostsPage> createState() => _AdminAdoptPostsPageState();
}

class _AdminAdoptPostsPageState extends ConsumerState<AdminAdoptPostsPage> {
  List<Map<String, dynamic>> _posts = [];
  int _currentIndex = 0;
  bool _loading = false;
  String? _error;
  String? _cursor;
  int _totalPending = 0;

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

      final posts = result['data'] as List? ?? [];
      final counts = result['counts'] as Map<String, dynamic>? ?? {};
      setState(() {
        if (_cursor == null) {
          _posts = posts.cast<Map<String, dynamic>>();
          _totalPending = counts['PENDING'] as int? ?? 0;
        } else {
          _posts.addAll(posts.cast<Map<String, dynamic>>());
        }
        _cursor = result['nextCursor'];
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
    setState(() {
      _currentIndex++;
      _totalPending = (_totalPending - 1).clamp(0, 999999);
    });

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

  Future<void> _approveAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout approuver'),
        content: const Text('Approuver toutes les annonces en attente ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approuver tout')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiProvider);
      final result = await api.adminAdoptApproveAll();
      final count = result['approved'] as int? ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $count annonce(s) approuvée(s)'), backgroundColor: Colors.green),
        );
        // Reload
        setState(() {
          _posts.clear();
          _cursor = null;
          _currentIndex = 0;
        });
        _loadPendingPosts();
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

  String _formatAge(int months) {
    if (months < 12) return '$months mois';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) return '$years an${years > 1 ? 's' : ''}';
    return '$years an${years > 1 ? 's' : ''} et $remainingMonths mois';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _adminTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Modération Adoptions'),
          actions: [
            if (_totalPending > 0)
              IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Tout approuver',
                onPressed: _approveAll,
              ),
            if (_totalPending > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminColors.salmon.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_totalPending en attente',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.salmon,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _loading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _posts.isEmpty
                ? _ErrorViewAdopt(message: _error!, onRetry: () {
                    _cursor = null;
                    _currentIndex = 0;
                    _loadPendingPosts();
                  })
                : _currentIndex >= _posts.length
                    ? _CompletedViewAdopt(onReload: () {
                        setState(() {
                          _posts.clear();
                          _cursor = null;
                          _currentIndex = 0;
                        });
                        _loadPendingPosts();
                      })
                    : _PostCard(
                        post: _posts[_currentIndex],
                        currentIndex: _currentIndex,
                        total: _posts.length,
                        onApprove: () => _approve(_posts[_currentIndex]['id']),
                        onReject: () => _reject(_posts[_currentIndex]['id']),
                        formatAge: _formatAge,
                      ),
      ),
    );
  }
}

class _ErrorViewAdopt extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorViewAdopt({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedViewAdopt extends StatelessWidget {
  final VoidCallback onReload;
  const _CompletedViewAdopt({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          const Text('Toutes les annonces ont été traitées !', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onReload,
            child: const Text('Recharger'),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final int currentIndex;
  final int total;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final String Function(int) formatAge;

  const _PostCard({
    required this.post,
    required this.currentIndex,
    required this.total,
    required this.onApprove,
    required this.onReject,
    required this.formatAge,
  });

  @override
  Widget build(BuildContext context) {
    final images = (post['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final user = post['createdBy'] as Map<String, dynamic>?;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Card
                Card(
                  elevation: 0,
                  color: AdminColors.salmon.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AdminColors.salmon.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AdminColors.salmon,
                              child: Text(
                                _firstLetter(user?['firstName'] ?? user?['email'] ?? '?'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim(),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    user?['email'] ?? '',
                                    style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ID: ${user?['id'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5)),
                        ),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Nom: ${post['animalName']}', style: const TextStyle(fontSize: 18)),
                  ),

                _InfoRow(icon: Icons.pets, text: 'Espèce: ${post['species'] ?? '?'}'),
                if (post['sex'] != null) _InfoRow(icon: Icons.wc, text: 'Sexe: ${post['sex']}'),
                if (post['ageMonths'] != null) _InfoRow(icon: Icons.cake, text: 'Âge: ${formatAge(post['ageMonths'])}'),
                if (post['city'] != null) _InfoRow(icon: Icons.location_on, text: 'Ville: ${post['city']}'),

                const SizedBox(height: 12),

                if (post['description'] != null && (post['description'] as String).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post['description'],
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Action Buttons
        Container(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onReject,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.close, size: 28),
                  label: const Text('REFUSER', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.check, size: 28),
                  label: const Text('APPROUVER', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdminColors.salmon),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

/// ================== PAGE TRAÇABILITÉ (anti-fraude) ==================
class AdminTraceabilityPage extends ConsumerStatefulWidget {
  const AdminTraceabilityPage({super.key});
  @override
  ConsumerState<AdminTraceabilityPage> createState() => _AdminTraceabilityPageState();
}

class _AdminTraceabilityPageState extends ConsumerState<AdminTraceabilityPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _global = {};
  List<Map<String, dynamic>> _providers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final result = await api.adminTraceabilityStats();

      setState(() {
        _global = Map<String, dynamic>.from(result['global'] as Map? ?? {});
        _providers = (result['providers'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _rateColor(int rate, {bool inverse = false}) {
    if (inverse) {
      // Pour completion rate: vert = bon
      if (rate >= 80) return Colors.green;
      if (rate >= 50) return Colors.orange;
      return Colors.red;
    } else {
      // Pour cancellation rate: rouge = mauvais
      if (rate <= 10) return Colors.green;
      if (rate <= 25) return Colors.orange;
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _adminTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Traçabilité'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Global stats
                        _buildGlobalStats(),
                        const SizedBox(height: 20),

                        // Providers list
                        Text(
                          'Détail par professionnel',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),

                        if (_providers.isEmpty)
                          const Center(child: Text('Aucun professionnel'))
                        else
                          ..._providers.map(_buildProviderCard),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildGlobalStats() {
    final totalProviders = _asInt(_global['totalProviders']);
    final suspiciousCount = _asInt(_global['suspiciousCount']);
    final totalBookings = _asInt(_global['totalBookings']);
    final totalCompleted = _asInt(_global['totalCompleted']);
    final totalCancelled = _asInt(_global['totalCancelled']);
    final totalCancelledByPro = _asInt(_global['totalCancelledByPro']);
    final totalOtpVerified = _asInt(_global['totalOtpVerified']);
    final totalQrVerified = _asInt(_global['totalQrVerified']);
    final avgCancellationRate = _asInt(_global['avgCancellationRate']);
    final avgCompletionRate = _asInt(_global['avgCompletionRate']);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: AdminColors.salmon),
                const SizedBox(width: 8),
                const Text(
                  'Vue globale',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (suspiciousCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$suspiciousCount suspect${suspiciousCount > 1 ? 's' : ''}',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats grid
            Row(
              children: [
                Expanded(child: _StatMini(label: 'Pros', value: '$totalProviders', icon: Icons.store)),
                Expanded(child: _StatMini(label: 'RDV Total', value: '$totalBookings', icon: Icons.calendar_today)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatMini(
                    label: 'Complétés',
                    value: '$totalCompleted',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatMini(
                    label: 'Annulés',
                    value: '$totalCancelled',
                    icon: Icons.cancel,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatMini(
                    label: 'Annulés par pro',
                    value: '$totalCancelledByPro',
                    icon: Icons.person_off,
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _StatMini(
                    label: 'Vérifiés OTP/QR',
                    value: '${totalOtpVerified + totalQrVerified}',
                    icon: Icons.verified,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Average rates
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$avgCompletionRate%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _rateColor(avgCompletionRate, inverse: true),
                        ),
                      ),
                      const Text('Taux completion moyen', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$avgCancellationRate%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _rateColor(avgCancellationRate),
                        ),
                      ),
                      const Text('Taux annulation moyen', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> p) {
    final name = p['providerName']?.toString() ?? 'Inconnu';
    final email = p['email']?.toString() ?? '';
    final totalBookings = _asInt(p['totalBookings']);
    final completed = _asInt(p['completed']);
    final cancelled = _asInt(p['cancelled']);
    final cancelledByPro = _asInt(p['cancelledByPro']);
    final cancellationRate = _asInt(p['cancellationRate']);
    final completionRate = _asInt(p['completionRate']);
    final proCancellationRate = _asInt(p['proCancellationRate']);
    final verificationRate = _asInt(p['verificationRate']);
    final otpVerified = _asInt(p['otpVerified']);
    final qrVerified = _asInt(p['qrVerified']);
    final simpleConfirm = _asInt(p['simpleConfirm']);
    final completedWithoutConfirmation = _asInt(p['completedWithoutConfirmation']);
    final isSuspicious = p['isSuspicious'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isSuspicious ? Colors.red.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSuspicious
            ? BorderSide(color: Colors.red.shade200, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AdminColors.salmon.withOpacity(0.1),
                  child: Text(
                    _firstLetter(name),
                    style: const TextStyle(color: AdminColors.salmon, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSuspicious) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.warning, color: Colors.red, size: 16),
                          ],
                        ],
                      ),
                      Text(
                        email,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalBookings RDV',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$completed complétés',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Rates
            Row(
              children: [
                _RateBadge(
                  label: 'Completion',
                  rate: completionRate,
                  color: _rateColor(completionRate, inverse: true),
                ),
                const SizedBox(width: 8),
                _RateBadge(
                  label: 'Annulation',
                  rate: cancellationRate,
                  color: _rateColor(cancellationRate),
                ),
                const SizedBox(width: 8),
                _RateBadge(
                  label: 'Ann. par Pro',
                  rate: proCancellationRate,
                  color: _rateColor(proCancellationRate),
                ),
                const SizedBox(width: 8),
                _RateBadge(
                  label: 'Vérification',
                  rate: verificationRate,
                  color: _rateColor(verificationRate, inverse: true),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Confirmation methods
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _MethodChip(icon: Icons.pin, label: 'OTP: $otpVerified', color: Colors.blue),
                _MethodChip(icon: Icons.qr_code, label: 'QR: $qrVerified', color: Colors.purple),
                _MethodChip(icon: Icons.touch_app, label: 'Simple: $simpleConfirm', color: Colors.grey),
                if (completedWithoutConfirmation > 0)
                  _MethodChip(
                    icon: Icons.help_outline,
                    label: 'Sans confirm: $completedWithoutConfirmation',
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AdminColors.salmon;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: c)),
                Text(label, style: TextStyle(fontSize: 10, color: c.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateBadge extends StatelessWidget {
  final String label;
  final int rate;
  final Color color;

  const _RateBadge({
    required this.label,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$rate%',
              style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MethodChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
