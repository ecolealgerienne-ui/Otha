import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/session_controller.dart';

class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    const coral = Color(0xFFF36C6C);

    // ✅ Si bootstrap pas encore termine, afficher loading
    if (!session.bootstrapped) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
                errorBuilder: (_, __, ___) => Icon(Icons.pets, size: 80, color: coral),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: coral),
            ],
          ),
        ),
      );
    }

    // ✅ Si deja connecte, rediriger vers home (le router devrait gerer ca mais au cas ou)
    if (session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final role = (session.user?['role'] ?? 'USER').toString();
          if (role == 'admin') {
            context.go('/admin/hub');
          } else {
            context.go('/home');
          }
        }
      });
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: coral)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Décoration en fond, alignée à droite
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.9,
                  child: Image.asset(
                    'assets/images/Decoration.png',
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.9,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAM',
                        style: const TextStyle(
                          fontSize: 76,
                          fontWeight: FontWeight.w800,
                          height: 0.95,
                        ).copyWith(color: coral),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _HomeLetter('H'),
                          _HomeLetter('o'),
                          _HomeLetter('m'),
                          _HomeLetter('e'),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  _PrimaryPillButton(
                    label: 'Particulier',
                    onPressed: () => context.push('/start/user'),
                  ),
                  const SizedBox(height: 16),
                  _DarkPillButton(
                    label: 'Professional',
                    onPressed: () => context.push('/start/pro'),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLetter extends StatelessWidget {
  final String c;
  const _HomeLetter(this.c);

  @override
  Widget build(BuildContext context) {
    return Text(
      c,
      style: const TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryPillButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.25),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _DarkPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _DarkPillButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.25),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
