// lib/features/adopt/adopt_main_screen.dart
import 'package:flutter/material.dart';
import 'adopt_chats_screen.dart';
import 'adopt_swipe_screen.dart';
import 'adopt_create_screen.dart';

class AdoptMainScreen extends StatefulWidget {
  const AdoptMainScreen({super.key});

  @override
  State<AdoptMainScreen> createState() => _AdoptMainScreenState();
}

class _AdoptMainScreenState extends State<AdoptMainScreen> {
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
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Désactive le swipe latéral
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
