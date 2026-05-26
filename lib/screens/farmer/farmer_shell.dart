import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/farmer_theme.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/farmer_controller.dart';
import 'farmer_dashboard_page.dart';
import 'farmer_history_page.dart';
import 'farmer_profile_page.dart';
import 'recommendation_input_screen.dart';

class FarmerShell extends StatefulWidget {
  const FarmerShell({
    super.key,
    required this.profile,
    required this.api,
    required this.onLogout,
  });

  final UserProfile profile;
  final ApiService api;
  final VoidCallback onLogout;

  @override
  State<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends State<FarmerShell> {
  int _index = 0;
  late UserProfile _profile = widget.profile;
  late final FarmerController _farmer = FarmerController(widget.api);

  @override
  void dispose() {
    _farmer.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    if (i == 0 || i == 2) {
      _farmer.refresh(force: true);
    }
  }

  void _onProfileUpdated(UserProfile p) => setState(() => _profile = p);

  void _onEvaluationComplete() {
    _farmer.invalidate();
    _farmer.refresh(force: true);
    _go(0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FarmerDashboardPage(
        profile: _profile,
        farmer: _farmer,
        onGetRecommendation: () => _go(1),
        onViewHistory: () => _go(2),
        onViewProfile: () => _go(3),
      ),
      RecommendationInputScreen(
        api: widget.api,
        profile: _profile,
        onEvaluationComplete: _onEvaluationComplete,
      ),
      FarmerHistoryPage(api: widget.api, farmer: _farmer),
      FarmerProfilePage(
        profile: _profile,
        api: widget.api,
        onLogout: widget.onLogout,
        onProfileUpdated: _onProfileUpdated,
      ),
    ];

    return Scaffold(
      backgroundColor: FarmerTheme.surface,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          backgroundColor: Colors.white,
          elevation: 0,
          height: 64,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.grass_outlined),
              selectedIcon: Icon(Icons.grass_rounded),
              label: 'Analyze',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
