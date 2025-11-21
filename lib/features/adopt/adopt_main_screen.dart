// lib/features/adopt/adopt_main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'adopt_chats_screen.dart';
import 'adopt_swipe_screen.dart';
import 'adopt_create_screen.dart';

final _currentPageProvider = StateProvider<int>((ref) => 1); // Start on swipe screen

class AdoptMainScreen extends ConsumerWidget {
  const AdoptMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(_currentPageProvider);
    final pageController = PageController(initialPage: currentPage);

    return Scaffold(
      body: PageView(
        controller: pageController,
        onPageChanged: (index) {
          ref.read(_currentPageProvider.notifier).state = index;
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
          ref.read(_currentPageProvider.notifier).state = index;
          pageController.animateToPage(
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
