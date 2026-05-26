import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_theme.dart';
import '../../core/app_colors.dart';
import '../../core/brand.dart';
import '../../models/admin_activity_log.dart';
import '../../models/admin_analytics.dart';
import '../../models/admin_prediction.dart';
import '../../models/user_profile.dart';
import '../../services/admin_controller.dart';
import '../../services/api_service.dart';
import '../../utils/admin_csv_export.dart';
import '../../widgets/admin/admin_crop_chart.dart';
import '../../widgets/admin/admin_quick_nav.dart';
import '../../widgets/admin/admin_section_title.dart';
import '../../widgets/admin/admin_shared.dart';
import '../../widgets/admin/admin_stat_card.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.admin,
    required this.profile,
    required this.onNavigateFarmers,
    required this.onNavigateData,
    required this.onNavigateInsights,
    required this.onNavigateSettings,
  });

  final AdminController admin;
  final UserProfile profile;
  final VoidCallback onNavigateFarmers;
  final VoidCallback onNavigateData;
  final VoidCallback onNavigateInsights;
  final VoidCallback onNavigateSettings;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminAnalytics? _analytics;
  List<AdminPrediction> _recent = [];
  List<AdminActivityLog> _activity = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastRefresh;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !_loading) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    await widget.admin.checkApiHealth();
    final analytics = await widget.admin.loadAnalytics(force: !silent);
    if (!mounted) return;
    if (analytics == null) {
      setState(() {
        _error = widget.admin.analyticsError ?? 'Could not load dashboard data';
        _analytics = null;
        _loading = false;
      });
      return;
    }
    try {
      final recent = await widget.admin.loadRecentPredictions(limit: 8);
      final logsJson = await widget.admin.api.adminActivityLogs(limit: 6);
      setState(() {
        _analytics = analytics;
        _recent = recent;
        _activity = logsJson.map(AdminActivityLog.fromJson).toList();
        _lastRefresh = DateTime.now();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() {
        _analytics = analytics;
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _exportPredictions() async {
    try {
      final predsJson = await widget.admin.api.adminListPredictions(limit: 50);
      final items = predsJson.map(AdminPrediction.fromJson).toList();
      final csv = AdminCsvExport.predictions(items);
      if (mounted) {
        await AdminCsvExport.copyToClipboard(context, csv, label: 'Predictions export');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.all(20), child: _errorBanner(_error!)),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _systemStatusBanner()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.22,
                ),
                delegate: SliverChildListDelegate([
                  AdminStatCard(
                    icon: Icons.people_alt_rounded,
                    label: 'Registered farmers',
                    value: '${_analytics!.totalFarmers}',
                    color: const Color(0xFF1976D2),
                    subtitle: '${_analytics!.activeFarmers} active',
                  ),
                  AdminStatCard(
                    icon: Icons.assignment_rounded,
                    label: 'Field evaluations',
                    value: '${_analytics!.totalPredictions}',
                    color: AppColors.primary,
                    subtitle: '${_analytics!.avgPredictionsPerFarmer.toStringAsFixed(1)} per farmer',
                  ),
                  AdminStatCard(
                    icon: Icons.favorite_rounded,
                    label: 'Avg soil health',
                    value: _analytics!.avgSoilHealthScore > 0
                        ? _analytics!.avgSoilHealthScore.toStringAsFixed(0)
                        : '—',
                    color: const Color(0xFF00897B),
                  ),
                  AdminStatCard(
                    icon: Icons.star_rounded,
                    label: 'Outcome ratings',
                    value: '${_analytics!.outcomeFeedbackCount}',
                    color: const Color(0xFFF57C00),
                    subtitle: _analytics!.avgOutcomeRating != null
                        ? 'Avg ${_analytics!.avgOutcomeRating!.toStringAsFixed(1)}/5'
                        : 'Awaiting feedback',
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _platformCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AdminQuickNav(
                  onFarmers: widget.onNavigateFarmers,
                  onData: widget.onNavigateData,
                  onInsights: widget.onNavigateInsights,
                  onSettings: widget.onNavigateSettings,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(child: _modelOperationsCard(context)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AdminSectionTitle(
                  title: 'Crop recommendation distribution',
                  action: TextButton(onPressed: _load, child: const Text('Refresh')),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: AdminCropChart(distribution: _analytics!.cropDistribution),
              ),
            ),
            if (_analytics!.fertilizerUsage.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: const SliverToBoxAdapter(
                  child: AdminSectionTitle(title: 'Fertilizer plans issued'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: AdminCropChart(distribution: _analytics!.fertilizerUsage),
                ),
              ),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AdminSectionTitle(
                  title: 'Audit trail',
                  action: TextButton(onPressed: widget.onNavigateInsights, child: const Text('Full log')),
                ),
              ),
            ),
            if (_activity.isEmpty)
              const SliverToBoxAdapter(
                child: AdminEmptyState(
                  icon: Icons.history_rounded,
                  title: 'No audit entries yet',
                  message: 'Admin actions such as dataset uploads and model training appear here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _activityTile(_activity[i]),
                    childCount: _activity.length,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AdminSectionTitle(
                  title: 'Latest farmer evaluations',
                  action: TextButton.icon(
                    onPressed: _exportPredictions,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export'),
                  ),
                ),
              ),
            ),
            if (_recent.isEmpty)
              const SliverToBoxAdapter(
                child: AdminEmptyState(
                  icon: Icons.eco_outlined,
                  title: 'No farmer evaluations yet',
                  message: 'Crop and fertilizer recommendations from registered farmers will show here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _predictionTile(_recent[i]),
                    childCount: _recent.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final refreshed = _lastRefresh != null ? DateFormat.jm().format(_lastRefresh!) : '—';

    return Container(
      width: double.infinity,
      decoration: AdminTheme.headerDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Brand.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Operations dashboard',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ],
                ),
              ),
              AdminLiveBadge(online: widget.admin.apiOnline && _error == null),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            widget.profile.displayName ?? 'Administrator',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${Brand.productFullName} · ${Brand.region}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Text(
            'Last sync $refreshed · Auto-refresh every 60s',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _systemStatusBanner() {
    final a = _analytics!;
    final modelOk = a.modelLoaded;
    final apiOk = widget.admin.apiOnline;
    return AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Platform health', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              if (widget.admin.healthChecking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _healthRow('REST API', apiOk ? 'Reachable' : 'Unreachable', apiOk),
          _healthRow('ML crop engine', modelOk ? 'Deployed · ${a.modelVersion ?? "—"}' : 'Train required', modelOk),
          _healthRow(
            'Training datasets',
            '${a.trainingDatasetsCount} on file',
            a.trainingDatasetsCount > 0,
          ),
          _healthRow(
            'Farmer accounts',
            '${a.activeFarmers} active · ${a.disabledFarmers} disabled',
            a.totalFarmers > 0,
          ),
          if (a.fertilizerFollowRatePct != null) ...[
            const Divider(height: 20),
            Text(
              '${a.fertilizerFollowRatePct!.toStringAsFixed(0)}% of farmers report following fertilizer guidance',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _healthRow(String label, String value, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 18,
            color: ok ? AppColors.primary : Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _platformCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary.withValues(alpha: 0.92)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Precision agriculture platform',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Serving ${_analytics!.activeFarmers} active farmers with multi-factor crop and fertilizer intelligence.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const Icon(Icons.hub_rounded, color: AdminTheme.accent, size: 40),
        ],
      ),
    );
  }

  Widget _modelOperationsCard(BuildContext context) {
    final a = _analytics!;
    final acc = a.bestAccuracy;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text('AI & data operations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a.modelLoaded
                ? 'Model ${a.modelVersion ?? "—"} is active for farmer evaluations.'
                : 'Train and deploy a model before farmers can receive recommendations.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          if (acc != null) ...[
            const SizedBox(height: 8),
            Text(
              'Validation accuracy: ${(acc * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onNavigateData,
                  icon: const Icon(Icons.storage_rounded, size: 18),
                  label: const Text('Datasets & ML'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onNavigateFarmers,
                  icon: const Icon(Icons.people_rounded, size: 18),
                  label: const Text('Farmers'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityTile(AdminActivityLog log) {
    final when = log.createdAt != null ? DateFormat.MMMd().add_Hm().format(log.createdAt!) : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_rounded, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                if (log.detail.isNotEmpty)
                  Text(log.detail, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  '${log.actorEmail} · $when',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionTile(AdminPrediction p) {
    final pct = (p.topConfidence * 100).toStringAsFixed(0);
    final when = p.createdAt != null ? DateFormat.MMMd().add_jm().format(p.createdAt!) : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => showAdminPredictionSheet(context, p),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.topCrop.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  p.farmerName ?? p.farmerEmail ?? 'Farmer',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (p.district != null && p.district!.isNotEmpty)
                  Text(p.district!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                if (when.isNotEmpty)
                  Text(when, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
              Text(p.modelVersion, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorText),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: AppColors.errorText))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }
}
