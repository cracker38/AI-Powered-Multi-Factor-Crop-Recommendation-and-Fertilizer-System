import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_theme.dart';
import '../../core/app_colors.dart';
import '../../models/admin_activity_log.dart';
import '../../models/admin_analytics.dart';
import '../../models/admin_notification.dart';
import '../../models/admin_prediction.dart';
import '../../services/admin_controller.dart';
import '../../services/api_service.dart';
import '../../utils/admin_csv_export.dart';
import '../../widgets/admin/admin_crop_chart.dart';
import '../../widgets/admin/admin_section_title.dart';
import '../../widgets/admin/admin_shared.dart';
import '../../widgets/admin/admin_stat_card.dart';

class AdminInsightsPage extends StatefulWidget {
  const AdminInsightsPage({super.key, required this.api, required this.admin});

  final ApiService api;
  final AdminController admin;

  @override
  State<AdminInsightsPage> createState() => _AdminInsightsPageState();
}

class _AdminInsightsPageState extends State<AdminInsightsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminPageHeader(
          title: 'Insights & reports',
          subtitle: 'Analytics, audit trail, and system alerts',
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AdminTheme.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Analytics'),
              Tab(text: 'Activity'),
              Tab(text: 'Alerts'),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: AdminTheme.surface,
            child: TabBarView(
              controller: _tabs,
              children: [
                _AnalyticsTab(api: widget.api, admin: widget.admin),
                _ActivityTab(api: widget.api),
                _AlertsTab(api: widget.api),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab({required this.api, required this.admin});
  final ApiService api;
  final AdminController admin;

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  AdminAnalytics? _a;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final a = await widget.admin.loadAnalytics(force: true);
    if (!mounted) return;
    setState(() {
      _a = a;
      _error = a == null ? (widget.admin.analyticsError ?? 'Failed to load analytics') : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null || _a == null) {
      return ListView(
        children: [AdminErrorState(message: _error ?? 'Unknown error', onRetry: _load)],
      );
    }
    final a = _a!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              AdminStatCard(
                icon: Icons.people,
                label: 'Active farmers',
                value: '${a.activeFarmers}',
                color: const Color(0xFF1976D2),
                subtitle: '${a.disabledFarmers} disabled',
              ),
              AdminStatCard(
                icon: Icons.eco,
                label: 'Evaluations',
                value: '${a.totalPredictions}',
                color: AppColors.primary,
                subtitle: 'Avg ${a.avgPredictionsPerFarmer.toStringAsFixed(1)}/farmer',
              ),
              AdminStatCard(
                icon: Icons.compost_rounded,
                label: 'Soil health avg',
                value: a.avgSoilHealthScore > 0 ? a.avgSoilHealthScore.toStringAsFixed(0) : '—',
                color: const Color(0xFF00897B),
                subtitle: 'Across evaluations',
              ),
              AdminStatCard(
                icon: Icons.star_rounded,
                label: 'Outcome feedback',
                value: '${a.outcomeFeedbackCount}',
                color: const Color(0xFFF57C00),
                subtitle: a.avgOutcomeRating != null
                    ? 'Avg ${a.avgOutcomeRating!.toStringAsFixed(1)}/5'
                    : 'Awaiting ratings',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const AdminSectionTitle(title: 'Most recommended crops'),
          AdminCropChart(distribution: a.cropDistribution),
          const AdminSectionTitle(title: 'Fertilizer plans issued'),
          if (a.fertilizerUsage.isEmpty)
            const AdminEmptyState(
              icon: Icons.compost_outlined,
              title: 'No fertilizer data yet',
              message: 'Issued fertilizer plans appear after farmers run evaluations.',
            )
          else
            AdminCropChart(distribution: a.fertilizerUsage),
          if (a.fertilizerFollowRatePct != null) ...[
            const SizedBox(height: 8),
            Text(
              '${a.fertilizerFollowRatePct!.toStringAsFixed(0)}% of farmers reported following fertilizer guidance',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              try {
                final preds = await widget.api.adminListPredictions(limit: 50);
                final csv = AdminCsvExport.predictions(
                  preds.map((e) => AdminPrediction.fromJson(e)).toList(),
                );
                if (context.mounted) {
                  await AdminCsvExport.copyToClipboard(context, csv, label: 'Predictions export');
                }
              } on ApiException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export evaluations (CSV)'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({required this.api});
  final ApiService api;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  List<AdminActivityLog> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.api.adminActivityLogs(limit: 40);
      setState(() {
        _logs = raw.map(AdminActivityLog.fromJson).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return ListView(children: [AdminErrorState(message: _error!, onRetry: _load)]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _logs.isEmpty
          ? ListView(
              children: const [
                AdminEmptyState(
                  icon: Icons.history_rounded,
                  title: 'No activity logged',
                  message: 'Administrative actions will appear in this audit trail.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (_, i) => _logTile(_logs[i]),
            ),
    );
  }

  Widget _logTile(AdminActivityLog log) {
    final when = log.createdAt != null ? DateFormat.MMMd().add_jm().format(log.createdAt!) : '';
    final color = switch (log.severity) {
      'error' => AppColors.errorText,
      'warning' => Colors.orange.shade800,
      _ => AppColors.primary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: AdminTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.action.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (log.detail.isNotEmpty) Text(log.detail, style: const TextStyle(fontSize: 12)),
                Text('${log.actorEmail} · $when', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsTab extends StatefulWidget {
  const _AlertsTab({required this.api});
  final ApiService api;

  @override
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<_AlertsTab> {
  List<AdminNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.api.adminNotifications();
      setState(() {
        _items = raw.map(AdminNotification.fromJson).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _read(AdminNotification n) async {
    if (n.read) return;
    try {
      await widget.api.adminMarkNotificationRead(n.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return ListView(children: [AdminErrorState(message: _error!, onRetry: _load)]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _items.isEmpty
          ? ListView(
              children: const [
                AdminEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No alerts',
                  message: 'Security and system notifications appear here.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final n = _items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: n.read ? Colors.white : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ListTile(
                    onTap: () => _read(n),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                    subtitle: Text(n.message),
                    leading: Icon(
                      n.severity == 'error' ? Icons.error_outline_rounded : Icons.notifications_active_rounded,
                      color: n.severity == 'error' ? AppColors.errorText : AppColors.primary,
                    ),
                    trailing: n.read ? null : const Icon(Icons.circle, size: 10, color: AppColors.primary),
                  ),
                );
              },
            ),
    );
  }
}
