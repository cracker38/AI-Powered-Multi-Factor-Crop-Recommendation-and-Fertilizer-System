import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/farmer_theme.dart';
import '../../models/farmer_field_data.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../widgets/farmer/farmer_field_data_form.dart';

/// Shown while farmer account awaits admin approval.
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({
    super.key,
    required this.profile,
    required this.api,
    required this.onApproved,
    required this.onLogout,
  });

  final UserProfile profile;
  final ApiService api;
  final VoidCallback onApproved;
  final VoidCallback onLogout;

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _submit(FarmerFieldData data) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.api.submitFieldData(data);
      if (mounted) {
        setState(() => _message = 'Field data submitted. An administrator will review and activate your account.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _busy = true);
    try {
      final profile = await widget.api.syncProfile();
      if (!mounted) return;
      if (profile.isApproved) {
        widget.onApproved();
      } else {
        setState(() => _message = 'Still pending approval. You will be notified when your account is activated.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final rejected = p.approvalStatus == 'rejected';

    return Scaffold(
      backgroundColor: FarmerTheme.surface,
      appBar: AppBar(
        title: const Text('Account status'),
        actions: [
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout_rounded), tooltip: 'Sign out'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: rejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: rejected ? const Color(0xFFEF9A9A) : const Color(0xFFFFCC80)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                  color: rejected ? AppColors.errorText : const Color(0xFFE65100),
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rejected ? 'Account not approved' : 'Waiting for admin approval',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rejected
                            ? 'Your registration was not approved. Contact your local RAB extension officer.'
                            : 'Your farmer account is registered. Submit your soil and climate readings below. '
                                'An administrator will review your data and activate your account before you can run crop analyses.',
                        style: const TextStyle(height: 1.45, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _infoTile('Name', p.displayName ?? '—'),
          _infoTile('Email', p.email),
          _infoTile('District', p.district ?? '—'),
          _infoTile('Farm size', p.farmSizeHa != null ? '${p.farmSizeHa!.toStringAsFixed(2)} ha' : '—'),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
          if (!rejected) ...[
            const SizedBox(height: 24),
            FarmerFieldDataForm(
              initial: p.fieldData,
              busy: _busy,
              api: widget.api,
              district: p.district,
              submitLabel: p.fieldData == null ? 'Submit for admin review' : 'Update field data',
              onSubmit: _submit,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _refreshStatus,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check approval status'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
