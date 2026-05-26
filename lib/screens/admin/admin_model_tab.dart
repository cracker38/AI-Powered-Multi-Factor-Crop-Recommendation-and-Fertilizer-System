import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../models/admin_analytics.dart';
import '../../services/admin_controller.dart';
import '../../services/api_service.dart';
class AdminModelTab extends StatefulWidget {
  const AdminModelTab({super.key, required this.api, required this.admin});

  final ApiService api;
  final AdminController admin;

  @override
  State<AdminModelTab> createState() => _AdminModelTabState();
}

class _AdminModelTabState extends State<AdminModelTab> {
  AdminAnalytics? _analytics;
  String? _reportText;
  bool _loading = true;
  bool _training = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    String? reportText;
    AdminAnalytics? analytics;
    String? err;

    final a = await widget.admin.loadAnalytics(force: true);
    analytics = a ?? widget.admin.analytics;

    try {
      final report = await widget.api.adminModelReport();
      reportText = report['training_report_text'] as String?;
    } on ApiException catch (e) {
      err = e.message;
    }

    if (mounted) {
      setState(() {
        _analytics = analytics;
        _reportText = reportText;
        _loading = false;
      });
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  Future<void> _train() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Train & deploy model?'),
        content: const Text('Retrains using the active dataset (or sample data). Deploys immediately for all farmers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Train')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _training = true);
    try {
      final r = await widget.api.adminTrainModel();
      widget.admin.invalidate();
      await _load();
      if (mounted) {
        final acc = (r['accuracy'] as num?)?.toDouble();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deployed ${r['best_model']} · ${acc != null ? '${(acc * 100).toStringAsFixed(1)}% accuracy' : 'done'}')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _training = false);
    }
  }

  Future<void> _downloadReport() async {
    try {
      final body = await widget.api.adminDownloadModelReport();
      await Clipboard.setData(ClipboardData(text: body));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training report JSON copied to clipboard')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final a = _analytics!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(a),
          const SizedBox(height: 16),
          _metricsGrid(a),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _training ? null : _train,
            icon: _training
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.model_training_rounded),
            label: Text(_training ? 'Training…' : 'Train & deploy model'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _downloadReport,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download training report'),
          ),
          if (_reportText != null) ...[
            const SizedBox(height: 20),
            const Text('Training summary', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_reportText!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(AdminAnalytics a) {
    final trained = a.lastTrainedAt != null ? DateFormat.yMMMd().add_jm().format(a.lastTrainedAt!) : 'Never';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: a.modelLoaded ? AppColors.primary : Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(a.modelLoaded ? Icons.check_circle : Icons.warning_amber, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                a.modelLoaded ? 'Model deployed' : 'No model',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Version: ${a.modelVersion ?? '—'}'),
          Text('Last trained: $trained'),
        ],
      ),
    );
  }

  Widget _metricsGrid(AdminAnalytics a) {
    String pct(double? v) => v != null ? '${(v * 100).toStringAsFixed(1)}%' : '—';
    return Row(
      children: [
        Expanded(child: _metricTile('Accuracy', pct(a.modelAccuracy))),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('Precision', pct(a.modelPrecision))),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('Recall', pct(a.modelRecall))),
        const SizedBox(width: 8),
        Expanded(child: _metricTile('F1', pct(a.modelF1))),
      ],
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
