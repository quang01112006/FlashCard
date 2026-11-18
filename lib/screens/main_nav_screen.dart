import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'home_screen.dart';
import 'study_decks_screen.dart';

import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import 'manage_decks_screen.dart';
import 'settings_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  String? _requestedDeckId;
  int _studyRequest = 0;
  void _openStudyDeck(String id) {
    final controller = context.read<CardController>();
    if (controller.isSaving ||
        controller.isLoading ||
        controller.deckById(id) == null) {
      return;
    }
    final tabRoute = ModalRoute.of(context);
    if (tabRoute != null) {
      Navigator.of(context).popUntil((route) => route == tabRoute);
    }
    setState(() {
      _requestedDeckId = id;
      _studyRequest++;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          StudyDecksScreen(
            requestedDeckId: _requestedDeckId,
            requestVersion: _studyRequest,
          ),
          ManageDecksScreen(onStudyDeck: _openStudyDeck),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: 'Học thẻ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style_outlined),
            activeIcon: Icon(Icons.style),
            label: 'Bộ thẻ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
