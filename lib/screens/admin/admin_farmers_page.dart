import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../models/admin_user.dart';
import '../../services/api_service.dart';
import '../../utils/admin_csv_export.dart';
import '../../widgets/admin/admin_farmer_approve_sheet.dart';
import '../../widgets/admin/admin_shared.dart';

enum _FarmerFilter { all, pending, active, disabled }

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
      setState(() {
        _all = raw.map(AdminUser.fromJson).toList();
        _loading = false;
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
        list = list.where((u) => u.disabled && !u.isPending).toList();
      case _FarmerFilter.all:
        break;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (u) =>
                u.email.toLowerCase().contains(q) ||
                (u.displayName?.toLowerCase().contains(q) ?? false) ||
                (u.district?.toLowerCase().contains(q) ?? false) ||
                (u.phone?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  int get _farmerCount => _all.where((u) => u.isFarmer).length;

  int get _pendingCount => _all.where((u) => u.isPending).length;

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

  Future<void> _reject(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reject registration?'),
        content: Text('Decline ${user.email}? They will not be able to use crop analysis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorText),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.adminRejectFarmer(user.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
    try {
      await widget.api.adminUpdateUser(user.id, displayName: name);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Farmer updated')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleDisabled(AdminUser user) async {
    final enabling = user.disabled;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(enabling ? 'Enable farmer?' : 'Disable farmer?'),
        content: Text(
          enabling
              ? '${user.email} will be able to sign in again.'
              : '${user.email} will not be able to sign in until re-enabled.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(enabling ? 'Enable' : 'Disable')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.adminUpdateUser(user.id, disabled: !user.disabled);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showDetail(AdminUser user) async {
    try {
      final fresh = await widget.api.adminGetUser(user.id);
      user = AdminUser.fromJson(fresh);
    } on ApiException {
      // Use list data if detail fetch fails.
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.displayName ?? user.email,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _detailRow('Email', user.email),
            _detailRow('Full name', user.displayName ?? '—'),
            _detailRow('Phone', user.phone ?? '—'),
            _detailRow('District', user.district ?? '—'),
            _detailRow('Farm size', user.farmSizeHa != null ? '${user.farmSizeHa!.toStringAsFixed(2)} ha' : '—'),
            _detailRow('Approval', user.approvalStatus),
            if (user.fieldData != null) ...[
              const SizedBox(height: 8),
              const Text('Field data (submitted)', style: TextStyle(fontWeight: FontWeight.w800)),
              _detailRow('N-P-K', '${user.fieldData!.nitrogen}/${user.fieldData!.phosphorus}/${user.fieldData!.potassium} kg/ha'),
              _detailRow('pH / moisture', '${user.fieldData!.soilPh} · ${user.fieldData!.soilMoisture}%'),
              _detailRow('Rain / temp', '${user.fieldData!.rainfallMm} mm · ${user.fieldData!.temperatureC} °C'),
              _detailRow('Soil type', user.fieldData!.soilType),
            ],
            _detailRow(
              'Registered',
              user.createdAt != null ? DateFormat.yMMMd().format(user.createdAt!) : '—',
            ),
            _detailRow('Evaluations', '${user.predictionCount}'),
            _detailRow('Status', user.isPending ? 'Pending approval' : (user.disabled ? 'Disabled' : 'Active')),
            if (user.isPending) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  _approve(user);
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Review & approve'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(c);
                  _reject(user);
                },
                child: const Text('Reject'),
              ),
            ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(c);
                      _editName(user);
                    },
                    child: const Text('Edit name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(c);
                      _toggleDisabled(user);
                    },
                    child: Text(user.disabled ? 'Enable' : 'Disable'),
                  ),
                ),
              ],
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
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

  Future<void> _exportFarmers() async {
    final farmers = _all.where((u) => u.isFarmer).toList();
    if (farmers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No farmers to export')),
        );
      }
      return;
    }
    final csv = AdminCsvExport.farmers(farmers);
    if (mounted) {
      await AdminCsvExport.copyToClipboard(context, csv, label: 'Farmers export');
    }
  }

  Future<void> _delete(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete farmer account?'),
        content: Text(
          'Remove ${user.email} from the platform? Firestore profile and Firebase sign-in will be revoked. Evaluation history is retained for analytics.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorText),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.adminDeleteUser(user.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Farmer removed')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _visible.length,
                              itemBuilder: (_, i) => _farmerCard(_visible[i]),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.isPending
              ? Colors.amber.shade400
              : user.disabled
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
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
        onTap: () => _showDetail(user),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: user.disabled
              ? Colors.orange.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: user.disabled ? Colors.orange.shade800 : AppColors.primary,
            ),
          ),
        ),
        title: Text(
          user.displayName ?? user.email,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(fontSize: 12)),
            if (user.district != null && user.district!.isNotEmpty)
              Text(user.district!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            if (joined != null)
              Text('Joined $joined', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(
              '${user.predictionCount} recommendations',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            if (user.isPending)
              const Text('Pending approval', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600))
            else if (user.disabled)
              const Text('Account disabled', style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
        trailing: user.isPending
            ? SizedBox(
                width: 96,
                child: FilledButton(
                  onPressed: () => _approve(user),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Approve'),
                ),
              )
            : PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            switch (v) {
              case 'edit':
                _editName(user);
              case 'toggle':
                _toggleDisabled(user);
              case 'delete':
                _delete(user);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit name')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(user.disabled ? 'Enable account' : 'Disable account'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete account')),
          ],
        ),
      ),
    );
  }
}
