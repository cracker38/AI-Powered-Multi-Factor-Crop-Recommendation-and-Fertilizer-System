import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/brand.dart';
import '../../core/constants.dart';
import '../../models/admin_prediction.dart';
import '../../models/admin_user.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../widgets/auth/forgot_password_helper.dart';
import '../../utils/admin_csv_export.dart';
import '../../widgets/admin/admin_shared.dart';
import '../../widgets/shared/about_app_section.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({
    super.key,
    required this.profile,
    required this.api,
    required this.onLogout,
  });

  final UserProfile profile;
  final ApiService api;
  final VoidCallback onLogout;

  Future<void> _resetPassword(BuildContext context) async {
    await ForgotPasswordHelper.promptAndSend(
      context,
      initialEmail: profile.email,
    );
  }

  Future<void> _exportFarmers(BuildContext context) async {
    try {
      final raw = await api.adminListUsers();
      final farmers = raw.map(AdminUser.fromJson).where((u) => u.isFarmer).toList();
      if (farmers.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No farmers to export')));
        }
        return;
      }
      final csv = AdminCsvExport.farmers(farmers);
      if (context.mounted) {
        await AdminCsvExport.copyToClipboard(context, csv, label: 'Farmers export');
      }
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _exportPredictions(BuildContext context) async {
    try {
      final raw = await api.adminListPredictions(limit: 50);
      final items = raw.map(AdminPrediction.fromJson).toList();
      if (items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No evaluations to export')));
        }
        return;
      }
      final csv = AdminCsvExport.predictions(items);
      if (context.mounted) {
        await AdminCsvExport.copyToClipboard(context, csv, label: 'Evaluations export');
      }
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AdminPageHeader(
            title: 'Admin settings',
            subtitle: profile.email,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _sectionTitle('Administrator'),
              _tile(Icons.person_rounded, 'Display name', profile.displayName ?? 'Administrator'),
              _tile(Icons.email_rounded, 'Email', profile.email),
              _tile(Icons.shield_rounded, 'Role', 'System administrator'),
              const SizedBox(height: 20),
              _sectionTitle('Security'),
              AdminSurfaceCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                  title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Send Firebase password reset email'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _resetPassword(context),
                ),
              ),
              const SizedBox(height: 8),
              _tile(Icons.verified_user_rounded, 'Access control', 'Admin-only API routes · Firestore RBAC'),
              const SizedBox(height: 20),
              _sectionTitle('Data export'),
              AdminSurfaceCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.people_rounded, color: AppColors.primary),
                      title: const Text('Export farmers', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('CSV to clipboard — email, district, evaluations'),
                      trailing: const Icon(Icons.copy_rounded),
                      onTap: () => _exportFarmers(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.eco_rounded, color: AppColors.primary),
                      title: const Text('Export evaluations', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Last 50 crop recommendations with confidence'),
                      trailing: const Icon(Icons.copy_rounded),
                      onTap: () => _exportPredictions(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const AboutAppSection(),
              const SizedBox(height: 16),
              _sectionTitle('Platform'),
              _tile(Icons.api_rounded, 'API endpoint', kDefaultApiBase),
              _tile(Icons.cloud_rounded, 'Database', 'Cloud Firestore'),
              _tile(Icons.psychology_rounded, 'Intelligence', 'Crop ML · fertilizer engine · Open-Meteo'),
              _tile(Icons.verified_rounded, 'Build', Brand.versionLabel),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorText,
                    side: const BorderSide(color: AppColors.errorText),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );

  Widget _tile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdminSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}
