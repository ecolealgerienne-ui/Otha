// lib/features/adopt/adopt_main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'adopt_chats_screen.dart';
import 'adopt_swipe_screen.dart';
import 'adopt_create_screen.dart';

// Simple notifier for current page
class _PageNotifier extends ChangeNotifier {
  int _currentPage = 1; // Start on swipe screen

  int get currentPage => _currentPage;

  void setPage(int page) {
    _currentPage = page;
    notifyListeners();
  }
}

final _currentPageProvider = ChangeNotifierProvider<_PageNotifier>((ref) {
  return _PageNotifier();
});

class AdoptMainScreen extends ConsumerStatefulWidget {
  const AdoptMainScreen({super.key});

  @override
  ConsumerState<AdoptMainScreen> createState() => _AdoptMainScreenState();
}

class _AdoptMainScreenState extends ConsumerState<AdoptMainScreen> {
  late PageController _pageController;

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
    final pageNotifier = ref.watch(_currentPageProvider);
    final currentPage = pageNotifier.currentPage;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          ref.read(_currentPageProvider).setPage(index);
        },
        children: const [
          AdoptChatsScreen(),
          AdoptSwipeScreen(),
          AdoptCreateScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentPage,
        onTap: (index) {
          ref.read(_currentPageProvider).setPage(index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Discussions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Adopter',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Créer',
          ),
        ],
      ),
    );
  }
}
