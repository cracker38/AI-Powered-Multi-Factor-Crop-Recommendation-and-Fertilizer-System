import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../services/admin_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/admin/admin_shared.dart';
import 'admin_datasets_tab.dart';
import 'admin_model_tab.dart';

class AdminDataPage extends StatelessWidget {
  const AdminDataPage({super.key, required this.api, required this.admin});

  final ApiService api;
  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Data & AI',
            subtitle: 'Upload crop datasets, train KNN models, deploy to farmers',
            bottom: TabBar(
              indicatorColor: AdminTheme.accent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Datasets'),
                Tab(text: 'AI Model'),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AdminTheme.surface,
              child: TabBarView(
                children: [
                  AdminDatasetsTab(api: api, admin: admin),
                  AdminModelTab(api: api, admin: admin),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
