import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../core/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/admin_controller.dart';
import '../../services/api_service.dart';
import 'admin_dashboard_page.dart';
import 'admin_data_page.dart';
import 'admin_farmers_page.dart';
import 'admin_insights_page.dart';
import 'admin_settings_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.profile,
    required this.api,
    required this.onLogout,
  });

  final UserProfile profile;
  final ApiService api;
  final VoidCallback onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final AdminController _admin;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _admin = AdminController(widget.api);
    _admin.checkApiHealth();
    _admin.loadAnalytics();
  }

  @override
  void dispose() {
    _admin.dispose();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _admin,
      builder: (context, _) {
        final pages = [
          AdminDashboardPage(
            admin: _admin,
            profile: widget.profile,
            onNavigateFarmers: () => _go(1),
            onNavigateData: () => _go(2),
            onNavigateInsights: () => _go(3),
            onNavigateSettings: () => _go(4),
          ),
          AdminFarmersPage(api: widget.api),
          AdminDataPage(api: widget.api, admin: _admin),
          AdminInsightsPage(api: widget.api, admin: _admin),
          AdminSettingsPage(
            profile: widget.profile,
            api: widget.api,
            onLogout: widget.onLogout,
          ),
        ];

        return Scaffold(
          backgroundColor: AdminTheme.surface,
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _go,
            backgroundColor: Colors.white,
            elevation: 8,
            shadowColor: Colors.black26,
            indicatorColor: AppColors.primary.withValues(alpha: 0.14),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Farmers',
              ),
              NavigationDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub_rounded),
                label: 'Data',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
