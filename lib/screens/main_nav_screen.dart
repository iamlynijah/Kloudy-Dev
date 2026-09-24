import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/kloudy_theme.dart';
import '../widgets/tutorial_overlay.dart';
import 'finances_screen.dart';
import 'health_screen.dart';
import 'kloudy_conversations_screen.dart';
import 'life_spaces_screen.dart';
import 'mental_wellness_screen.dart';
import 'weight_screen.dart';
import 'home_screen.dart';
import '../demo/demo_profile.dart';

class MainNavScreen extends StatefulWidget {
  final String userName;

  const MainNavScreen({super.key, required this.userName});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  bool _showTutorial = false;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(userName: widget.userName, onNavigate: _handleHomeAction),
      MyLifeScreen(onOpenSection: _openLifeSection),
      const KloudyConversationsScreen(),
    ];
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    if (DemoProfile.isDemo) return;
    final shown = await SupabaseService.fetchTutorialShown();
    if (!shown && mounted) setState(() => _showTutorial = true);
  }

  void _selectTab(int index) => setState(() => _currentIndex = index);

  void _handleHomeAction(int target) {
    if (target == 5 || target == 6) {
      _selectTab(2);
    } else if (target >= 1 && target <= 4) {
      _openLifeSection(target - 1);
    }
  }

  void _openLifeSection(int section) {
    final Widget page = switch (section) {
      0 => const HealthScreen(),
      1 => const WeightScreen(),
      2 => const FinancesScreen(),
      _ => const MentalWellnessScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          if (_showTutorial)
            TutorialOverlay(
              onComplete: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        backgroundColor: kCard,
        indicatorColor: kKloudyBlue.withValues(alpha: 0.12),
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers_rounded),
            label: 'My life',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'Kloudy',
          ),
        ],
      ),
    );
  }
}
