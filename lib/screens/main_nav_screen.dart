import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'health_screen.dart';
import 'weight_screen.dart';
import 'finances_screen.dart';
import 'mental_wellness_screen.dart';
import 'kloudy_conversations_screen.dart';
import '../services/supabase_service.dart';
import '../widgets/tutorial_overlay.dart';

class MainNavScreen extends StatefulWidget {
  final String userName;

  const MainNavScreen({
    super.key,
    required this.userName,
  });

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  bool _showTutorial = false;

  late final ValueNotifier<bool> _homeActive;
  late final ValueNotifier<bool> _mindsetActive;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _homeActive = ValueNotifier<bool>(true);
    _mindsetActive = ValueNotifier<bool>(false);
    _screens = [
      HomeScreen(
        userName: widget.userName,
        onNavigate: _navigateTo,
        activeNotifier: _homeActive,
      ),
      const HealthScreen(),
      const WeightScreen(),
      const FinancesScreen(),
      MentalWellnessScreen(activeNotifier: _mindsetActive),
      const KloudyConversationsScreen(),
    ];
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final shown = await SupabaseService.fetchTutorialShown();
    if (!shown && mounted) setState(() => _showTutorial = true);
  }

  @override
  void dispose() {
    _homeActive.dispose();
    _mindsetActive.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    _homeActive.value = index == 0;
    _mindsetActive.value = index == 4;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          if (_showTutorial)
            TutorialOverlay(
              onComplete: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _homeActive.value = index == 0;
          _mindsetActive.value = index == 4;
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Nutrition',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Finances',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.self_improvement_outlined),
            activeIcon: Icon(Icons.self_improvement),
            label: 'Mindset',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
