import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/shared/about_app_section.dart';
import '../../core/farmer_theme.dart';
import '../../core/rwanda_districts.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../widgets/auth/forgot_password_helper.dart';
import '../../services/farmer_preferences.dart';
import '../../services/firestore_service.dart';
import '../../widgets/auth/auth_form_card.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/farmer/farmer_card.dart';
import '../../widgets/farmer/farmer_page_header.dart';
import '../../widgets/farmer/farmer_section_title.dart';
import '../../models/prediction_history_item.dart';
import '../../widgets/farmer/farmer_shared.dart';

class FarmerProfilePage extends StatefulWidget {
  const FarmerProfilePage({
    super.key,
    required this.profile,
    required this.api,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  final UserProfile profile;
  final ApiService api;
  final VoidCallback onLogout;
  final void Function(UserProfile profile) onProfileUpdated;

  @override
  State<FarmerProfilePage> createState() => _FarmerProfilePageState();
}

class _FarmerProfilePageState extends State<FarmerProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  String? _district;
  bool _saving = false;
  bool _notifyTips = true;
  bool _assessmentLoading = true;
  String? _assessmentError;
  PredictionHistoryItem? _latestAssessment;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.displayName ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile.phone ?? '');
    _district = widget.profile.district;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final show = await FarmerPreferences.showTipsOnDashboard();
    if (mounted) setState(() => _notifyTips = show);
  }

  Future<void> _loadLatestAssessment() async {
    setState(() {
      _assessmentLoading = true;
      _assessmentError = null;
    });
    try {
      final items = await widget.api.fetchHistory(limit: 1);
      if (!mounted) return;
      setState(() {
        _latestAssessment = items.isNotEmpty ? items.first : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _assessmentError = e.message);
    } finally {
      if (mounted) setState(() => _assessmentLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant FarmerProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.displayName != widget.profile.displayName) {
      _nameCtrl.text = widget.profile.displayName ?? '';
    }
    if (oldWidget.profile.phone != widget.profile.phone) {
      _phoneCtrl.text = widget.profile.phone ?? '';
    }
    if (oldWidget.profile.district != widget.profile.district) {
      _district = widget.profile.district;
    }
    if (oldWidget.profile.id != widget.profile.id) {
      _loadLatestAssessment();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateFarmerProfile(
        displayName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        district: _district,
      );
      await FirestoreService().upsertUserProfile(updated);
      widget.onProfileUpdated(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetPassword() async {
    await ForgotPasswordHelper.promptAndSend(
      context,
      initialEmail: widget.profile.email,
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access your farm data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FarmerTheme.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: FarmerPageHeader(
              title: 'Profile & settings',
              subtitle: widget.profile.email,
              icon: Icons.person_rounded,
              trailing: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  (widget.profile.displayName ?? 'F').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AuthFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FarmerSectionTitle(title: 'Personal information'),
                      AuthTextField(
                        controller: _nameCtrl,
                        label: 'Full name',
                        hint: 'Your full name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _phoneCtrl,
                        label: 'Phone (optional)',
                        hint: '+250 7XX XXX XXX',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _district != null && RwandaDistricts.list.contains(_district) ? _district : null,
                        decoration: const InputDecoration(
                          labelText: 'District (recommended)',
                          helperText: 'Used for live weather and localized recommendations',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select district')),
                          ...RwandaDistricts.list.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                        ],
                        onChanged: (v) => setState(() => _district = v),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save profile', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FarmerCard(
                  child: Column(
                    children: [
                      const FarmerSectionTitle(title: 'Preferences'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notifyTips,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) async {
                          setState(() => _notifyTips = v);
                          await FarmerPreferences.setShowTipsOnDashboard(v);
                        },
                        title: const Text('Extension advisory', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Show Rwanda farming tips on home dashboard'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FarmerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FarmerSectionTitle(title: 'Latest admin assessment'),
                      if (_assessmentLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      else if (_assessmentError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_assessmentError!, style: const TextStyle(color: AppColors.errorText)),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _loadLatestAssessment,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      else if (_latestAssessment == null)
                        const Text(
                          'No admin-generated analysis yet. Once your account is approved, the result will appear here.',
                          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                        )
                      else ...[
                        Text(
                          _latestAssessment!.topCrop.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Suitability ${(_latestAssessment!.topConfidence * 100).toStringAsFixed(1)}% · '
                          'Soil health ${_latestAssessment!.soilHealthScore.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generated ${_latestAssessment!.createdAt.toLocal()}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => showFarmerEvaluationDetail(
                            context,
                            api: widget.api,
                            predictionId: _latestAssessment!.id,
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View full analysis'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FarmerCard(
                  child: Column(
                    children: [
                      const FarmerSectionTitle(title: 'Security'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                        ),
                        title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Email reset link via Firebase'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _resetPassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const AboutAppSection(),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorText,
                    side: const BorderSide(color: AppColors.errorText),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
