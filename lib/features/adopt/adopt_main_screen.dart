// lib/features/adopt/adopt_main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/locale_provider.dart';
import 'adopt_chats_screen.dart';
import 'adopt_swipe_screen.dart';
import 'adopt_create_screen.dart';

class AdoptMainScreen extends ConsumerStatefulWidget {
  const AdoptMainScreen({super.key});

  @override
  ConsumerState<AdoptMainScreen> createState() => _AdoptMainScreenState();
}

class _AdoptMainScreenState extends ConsumerState<AdoptMainScreen> {
  late PageController _pageController;
  int _currentPage = 1; // Start on swipe screen

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        children: const [
          AdoptChatsScreen(),
          AdoptSwipeScreen(),
          AdoptCreateScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (index) {
          setState(() => _currentPage = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: l10n.adoptDiscussions,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.pets),
            label: l10n.adoptAdopter,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_circle_outline),
            label: l10n.adoptCreate,
          ),
        ],
      ),
    );
  }
}
