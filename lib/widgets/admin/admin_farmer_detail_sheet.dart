import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../models/admin_sensor_field_data.dart';
import '../../models/admin_user.dart';
import '../../services/api_service.dart';
import 'admin_farmer_status_badge.dart';

typedef AdminFarmerAction = Future<void> Function(AdminUser user);

Future<void> showAdminFarmerDetailSheet(
  BuildContext context, {
  required ApiService api,
  required AdminUser user,
  required AdminFarmerAction onApprove,
  required AdminFarmerAction onReject,
  required AdminFarmerAction onEditName,
  required AdminFarmerAction onToggleDisabled,
  required AdminFarmerAction onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _AdminFarmerDetailSheet(
      api: api,
      initialUser: user,
      onApprove: onApprove,
      onReject: onReject,
      onEditName: onEditName,
      onToggleDisabled: onToggleDisabled,
      onDelete: onDelete,
    ),
  );
}

class _AdminFarmerDetailSheet extends StatefulWidget {
  const _AdminFarmerDetailSheet({
    required this.api,
    required this.initialUser,
    required this.onApprove,
    required this.onReject,
    required this.onEditName,
    required this.onToggleDisabled,
    required this.onDelete,
  });

  final ApiService api;
  final AdminUser initialUser;
  final AdminFarmerAction onApprove;
  final AdminFarmerAction onReject;
  final AdminFarmerAction onEditName;
  final AdminFarmerAction onToggleDisabled;
  final AdminFarmerAction onDelete;

  @override
  State<_AdminFarmerDetailSheet> createState() => _AdminFarmerDetailSheetState();
}

class _AdminFarmerDetailSheetState extends State<_AdminFarmerDetailSheet> {
  late AdminUser _user = widget.initialUser;
  AdminSensorFieldData? _sensor;
  bool _loadingUser = false;
  bool _loadingSensor = true;
  String? _sensorMessage;
  String? _actionBusy;

  @override
  void initState() {
    super.initState();
    _refreshUser();
    _loadSensor();
  }

  Future<void> _refreshUser() async {
    setState(() => _loadingUser = true);
    try {
      final fresh = await widget.api.adminGetUser(_user.id);
      if (mounted) setState(() => _user = AdminUser.fromJson(fresh));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<void> _loadSensor() async {
    setState(() {
      _loadingSensor = true;
      _sensorMessage = null;
    });
    try {
      final reading = await widget.api.adminFetchSensorFieldData(_user.id);
      if (!mounted) return;
      setState(() {
        _sensor = reading;
        _sensorMessage = reading == null
            ? 'No live sensor data for ${_user.email}. Values below are from registration or last approval.'
            : 'Loaded from ${reading.summaryLabel} for this farmer.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _sensorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loadingSensor = false);
    }
  }

  Future<void> _runAction(String key, Future<void> Function() action) async {
    setState(() => _actionBusy = key);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _actionBusy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final field = _sensor?.fieldData ?? _user.fieldData;
    final busy = _actionBusy != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _user.displayName ?? _user.email,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                AdminFarmerStatusBadge(user: _user),
              ],
            ),
            const SizedBox(height: 4),
            Text(_user.email, style: const TextStyle(color: AppColors.textSecondary)),
            if (_loadingUser)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 16),
            _sectionTitle('Account'),
            _row('Phone', _user.phone ?? '—'),
            _row('District', _user.district ?? '—'),
            _row('Farm size', _user.farmSizeHa != null ? '${_user.farmSizeHa!.toStringAsFixed(2)} ha' : '—'),
            _row('Evaluations', '${_user.predictionCount}'),
            _row(
              'Registered',
              _user.createdAt != null ? DateFormat.yMMMd().add_jm().format(_user.createdAt!) : '—',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _sectionTitle('Soil sensor data')),
                TextButton.icon(
                  onPressed: _loadingSensor || busy ? null : _loadSensor,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            if (_loadingSensor)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_sensorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _sensor != null
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _sensorMessage!,
                  style: TextStyle(
                    color: _sensor != null ? AppColors.primary : AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            if (field != null) ...[
              _row('N-P-K', '${field.nitrogen}/${field.phosphorus}/${field.potassium} kg/ha'),
              _row('pH / moisture', '${field.soilPh} · ${field.soilMoisture}%'),
              _row('Temperature', '${field.temperatureC} °C'),
              _row('Soil type', field.soilType),
            ] else
              const Text('No field data on file yet.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            if (_user.isPending || _user.isRejected) ...[
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => _runAction('approve', () => widget.onApprove(_user)),
                icon: _actionBusy == 'approve'
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_user.isRejected ? 'Re-review & approve' : 'Review & approve'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 8),
              if (_user.isPending)
                OutlinedButton(
                  onPressed: busy ? null : () => _runAction('reject', () => widget.onReject(_user)),
                  child: _actionBusy == 'reject'
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Reject registration'),
                ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => _runAction('edit', () => widget.onEditName(_user)),
                      child: const Text('Edit name'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => _runAction('toggle', () => widget.onToggleDisabled(_user)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _user.disabled ? AppColors.primary : Colors.orange.shade800,
                      ),
                      child: _actionBusy == 'toggle'
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_user.disabled ? 'Enable account' : 'Disable account'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _runAction('delete', () => widget.onDelete(_user)),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorText),
              label: const Text('Delete account', style: TextStyle(color: AppColors.errorText)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: AppColors.errorText.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
