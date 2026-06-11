import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../models/admin_pending_sensor_farmer.dart';
import '../../models/admin_user.dart';
import '../../services/api_service.dart';
import '../../utils/admin_csv_export.dart';
import '../../widgets/admin/admin_farmer_approve_sheet.dart';
import '../../widgets/admin/admin_farmer_detail_sheet.dart';
import '../../widgets/admin/admin_farmer_status_badge.dart';
import '../../widgets/admin/admin_pending_sensor_banner.dart';
import '../../widgets/admin/admin_shared.dart';

enum _FarmerFilter { all, pending, active, disabled, rejected }

class AdminFarmersPage extends StatefulWidget {
  const AdminFarmersPage({super.key, required this.api});

  final ApiService api;

  @override
  State<AdminFarmersPage> createState() => _AdminFarmersPageState();
}

class _AdminFarmersPageState extends State<AdminFarmersPage> {
  List<AdminUser> _all = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  _FarmerFilter _filter = _FarmerFilter.all;
  String? _actionUserId;
  AdminPendingSensorFarmer? _pendingSensor;

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
      final raw = await widget.api.adminListUsers();
      final pendingSensor = await widget.api.adminFetchPendingSensorFarmer();
      setState(() {
        _all = raw.map(AdminUser.fromJson).toList();
        _pendingSensor = pendingSensor;
        _loading = false;
        if (pendingSensor != null && _filter == _FarmerFilter.all) {
          _filter = _FarmerFilter.pending;
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load farmers: $e';
        _loading = false;
      });
    }
  }

  List<AdminUser> get _visible {
    var list = _all.where((u) => u.isFarmer).toList();
    switch (_filter) {
      case _FarmerFilter.pending:
        list = list.where((u) => u.isPending).toList();
      case _FarmerFilter.active:
        list = list.where((u) => u.isApproved && !u.disabled).toList();
      case _FarmerFilter.disabled:
        list = list.where((u) => u.disabled && !u.isPending && !u.isRejected).toList();
      case _FarmerFilter.rejected:
        list = list.where((u) => u.isRejected).toList();
      case _FarmerFilter.all:
        break;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((u) {
        return u.email.toLowerCase().contains(q) ||
            (u.displayName?.toLowerCase().contains(q) ?? false) ||
            (u.district?.toLowerCase().contains(q) ?? false) ||
            (u.phone?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  List<AdminUser> get _sortedVisible {
    final list = List<AdminUser>.from(_visible);
    final sensorId = _pendingSensor?.userId;
    if (sensorId != null) {
      list.sort((a, b) {
        if (a.id == sensorId) return -1;
        if (b.id == sensorId) return 1;
        if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
        return 0;
      });
    }
    return list;
  }

  AdminUser? get _pendingSensorUser {
    final id = _pendingSensor?.userId;
    if (id == null) return null;
    for (final u in _all) {
      if (u.id == id) return u;
    }
    return null;
  }

  bool _hasLiveSensor(AdminUser user) => _pendingSensor?.userId == user.id;

  int get _farmerCount => _all.where((u) => u.isFarmer).length;
  int get _pendingCount => _all.where((u) => u.isPending).length;

  Future<void> _approvePendingSensor() async {
    final user = _pendingSensorUser;
    if (user != null) {
      await _approve(user);
    }
  }

  Future<void> _approve(AdminUser user) async {
    final ok = await showAdminFarmerApproveSheet(context, api: widget.api, user: user);
    if (ok == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.displayName ?? user.email} is now active')),
        );
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    Color? confirmColor,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: confirmColor != null ? FilledButton.styleFrom(backgroundColor: confirmColor) : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _reject(AdminUser user) async {
    final ok = await _confirm(
      title: 'Reject registration?',
      message:
          'Decline ${user.email}? Their Firebase sign-in will be disabled and they cannot use crop analysis.',
      confirmLabel: 'Reject',
      confirmColor: AppColors.errorText,
    );
    if (!ok) return;
    setState(() => _actionUserId = user.id);
    try {
      await widget.api.adminRejectFarmer(user.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.email} rejected')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  Future<void> _editName(AdminUser user) async {
    final ctrl = TextEditingController(text: user.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit display name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Display name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _actionUserId = user.id);
    try {
      await widget.api.adminUpdateUser(user.id, displayName: name);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name updated')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  Future<void> _toggleDisabled(AdminUser user) async {
    if (user.isRejected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejected accounts must be re-approved. Tap Re-review & approve.')),
        );
      }
      return;
    }
    if (user.isPending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pending registrations must be approved first.')),
        );
      }
      return;
    }

    final enabling = user.disabled;
    final ok = await _confirm(
      title: enabling ? 'Enable farmer account?' : 'Disable farmer account?',
      message: enabling
          ? '${user.email} will regain Firebase sign-in access and can use the app again.'
          : '${user.email} will be blocked from signing in until you enable the account again.',
      confirmLabel: enabling ? 'Enable' : 'Disable',
      confirmColor: enabling ? AppColors.primary : Colors.orange.shade800,
    );
    if (!ok) return;

    setState(() => _actionUserId = user.id);
    try {
      await widget.api.adminUpdateUser(user.id, disabled: !user.disabled);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(enabling ? '${user.email} enabled' : '${user.email} disabled')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  Future<void> _delete(AdminUser user) async {
    final ok = await _confirm(
      title: 'Delete farmer account?',
      message:
          'Permanently remove ${user.email}? Their profile and Firebase sign-in will be deleted. Evaluation history is retained for analytics.',
      confirmLabel: 'Delete permanently',
      confirmColor: AppColors.errorText,
    );
    if (!ok) return;

    setState(() => _actionUserId = user.id);
    try {
      await widget.api.adminDeleteUser(user.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.email} deleted')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionUserId = null);
    }
  }

  Future<void> _showDetail(AdminUser user) async {
    await showAdminFarmerDetailSheet(
      context,
      api: widget.api,
      user: user,
      onApprove: _approve,
      onReject: _reject,
      onEditName: _editName,
      onToggleDisabled: _toggleDisabled,
      onDelete: _delete,
    );
    await _load();
  }

  Future<void> _exportFarmers() async {
    final farmers = _all.where((u) => u.isFarmer).toList();
    if (farmers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No farmers to export')));
      }
      return;
    }
    final csv = AdminCsvExport.farmers(farmers);
    if (mounted) {
      await AdminCsvExport.copyToClipboard(context, csv, label: 'Farmers export');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: _visible.isEmpty
                          ? ListView(
                              children: const [
                                AdminEmptyState(
                                  icon: Icons.people_outline_rounded,
                                  title: 'No farmers match your filters',
                                  message: 'Try a different search or filter, or wait for new registrations.',
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                              itemCount: _sortedVisible.length + (_pendingSensor != null ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (_pendingSensor != null && i == 0) {
                                  return AdminPendingSensorBanner(
                                    pending: _pendingSensor!,
                                    onApprove: _approvePendingSensor,
                                  );
                                }
                                final index = _pendingSensor != null ? i - 1 : i;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _farmerCard(_sortedVisible[index]),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AdminPageHeader(
      title: 'Farmer accounts',
      subtitle: '$_farmerCount registered · $_pendingCount pending approval',
      trailing: IconButton(
        onPressed: _loading || _all.isEmpty ? null : _exportFarmers,
        icon: const Icon(Icons.download_rounded, color: Colors.white),
        tooltip: 'Export farmers CSV',
      ),
      bottom: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search name, email, or district',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', _FarmerFilter.all),
                const SizedBox(width: 8),
                _filterChip('Pending', _FarmerFilter.pending),
                const SizedBox(width: 8),
                _filterChip('Active', _FarmerFilter.active),
                const SizedBox(width: 8),
                _filterChip('Disabled', _FarmerFilter.disabled),
                const SizedBox(width: 8),
                _filterChip('Rejected', _FarmerFilter.rejected),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _FarmerFilter value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      selectedColor: Colors.white,
      labelStyle: TextStyle(color: selected ? AppColors.primary : Colors.white),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _farmerCard(AdminUser user) {
    final initials = (user.displayName?.isNotEmpty == true
            ? user.displayName!.substring(0, 1)
            : user.email.substring(0, 1))
        .toUpperCase();
    final joined = user.createdAt != null ? DateFormat.yMMMd().format(user.createdAt!) : null;
    final cardBusy = _actionUserId == user.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasLiveSensor(user)
              ? AppColors.primary
              : _borderColor(user),
          width: _hasLiveSensor(user) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: cardBusy ? null : () => _showDetail(user),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _avatarColor(user),
          child: cardBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : Text(initials, style: TextStyle(fontWeight: FontWeight.bold, color: _avatarTextColor(user))),
        ),
        title: Text(user.displayName ?? user.email, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(fontSize: 12)),
            if (user.district != null && user.district!.isNotEmpty)
              Text(user.district!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            if (joined != null)
              Text('Joined $joined', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text('${user.predictionCount} recommendations', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                AdminFarmerStatusBadge(user: user),
                if (_hasLiveSensor(user))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors_rounded, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'ESP8266 live',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: _trailingActions(user, cardBusy),
      ),
    );
  }

  Widget? _trailingActions(AdminUser user, bool cardBusy) {
    if (cardBusy) return null;
    if (user.isPending || user.isRejected) {
      return SizedBox(
        width: _hasLiveSensor(user) ? 118 : 108,
        child: FilledButton(
          onPressed: () => _approve(user),
          style: FilledButton.styleFrom(
            backgroundColor: _hasLiveSensor(user) ? AppColors.primary : AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Text(
            _hasLiveSensor(user) ? 'Approve sensor' : (user.isRejected ? 'Re-review' : 'Approve'),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      );
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) {
        switch (v) {
          case 'detail':
            _showDetail(user);
          case 'edit':
            _editName(user);
          case 'toggle':
            _toggleDisabled(user);
          case 'delete':
            _delete(user);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'detail', child: Text('View details')),
        const PopupMenuItem(value: 'edit', child: Text('Edit name')),
        PopupMenuItem(
          value: 'toggle',
          child: Text(user.disabled ? 'Enable account' : 'Disable account'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Delete account')),
      ],
    );
  }

  Color _borderColor(AdminUser user) {
    if (user.isPending) return Colors.amber.shade400;
    if (user.isRejected) return Colors.red.shade200;
    if (user.disabled) return Colors.orange.shade200;
    return Colors.grey.shade200;
  }

  Color _avatarColor(AdminUser user) {
    if (user.isRejected) return Colors.red.withValues(alpha: 0.12);
    if (user.disabled) return Colors.orange.withValues(alpha: 0.15);
    return AppColors.primary.withValues(alpha: 0.12);
  }

  Color _avatarTextColor(AdminUser user) {
    if (user.isRejected) return AppColors.errorText;
    if (user.disabled) return Colors.orange.shade800;
    return AppColors.primary;
  }
}
