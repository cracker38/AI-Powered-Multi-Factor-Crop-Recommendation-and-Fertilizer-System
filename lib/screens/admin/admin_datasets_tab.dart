import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../services/admin_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/admin/admin_section_title.dart';

class AdminDatasetsTab extends StatefulWidget {
  const AdminDatasetsTab({super.key, required this.api, required this.admin});

  final ApiService api;
  final AdminController admin;

  @override
  State<AdminDatasetsTab> createState() => _AdminDatasetsTabState();
}

class _AdminDatasetsTabState extends State<AdminDatasetsTab> {
  List<Map<String, dynamic>> _datasets = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _syncAdmin() {
    widget.admin.invalidate();
    widget.admin.loadAnalytics(force: true);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.api.adminListDatasets();
      setState(() {
        _datasets = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final nameCtrl = TextEditingController(
      text: file.name.replaceAll(RegExp(r'\.(csv|xlsx|xls)$', caseSensitive: false), ''),
    );
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Dataset name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            Text(
              'Required columns: N, P, K, soil_moisture, temperature, humidity, ph, rainfall, label',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, nameCtrl.text.trim()), child: const Text('Upload')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    setState(() => _uploading = true);
    try {
      await widget.api.adminUploadDataset(name: name, bytes: bytes, filename: file.name);
      _syncAdmin();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dataset validated and uploaded')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editName(Map<String, dynamic> d) async {
    final ctrl = TextEditingController(text: d['name'] as String? ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename dataset'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.api.adminUpdateDataset(d['id'].toString(), name);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete dataset?'),
        content: Text('Remove "${d['name']}"? This cannot be undone.'),
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
      await widget.api.adminDeleteDataset(d['id'].toString());
      _syncAdmin();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminSectionTitle(title: 'Training datasets'),
          if (_datasets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Upload CSV or Excel with soil nutrients (N,P,K), pH, temperature, rainfall, humidity, and crop labels.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._datasets.map(_card),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file_rounded),
            label: Text(_uploading ? 'Validating upload…' : 'Upload CSV / Excel'),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> d) {
    final active = d['is_active'] == true;
    final created = d['created_at'];
    String? when;
    if (created is String) {
      final dt = DateTime.tryParse(created);
      if (dt != null) when = DateFormat.yMMMd().format(dt);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AppColors.primary : Colors.grey.shade200, width: active ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editName(d);
                  if (v == 'delete') _delete(d);
                  if (v == 'activate') _activate(d['id'].toString());
                },
                itemBuilder: (_) => [
                  if (!active) const PopupMenuItem(value: 'activate', child: Text('Activate')),
                  const PopupMenuItem(value: 'edit', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          Text('${d['row_count']} rows · ${d['filename']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (when != null) Text('Uploaded $when', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          if (active)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Chip(label: Text('Active for training'), backgroundColor: Color(0xFFE8F5E9)),
            ),
        ],
      ),
    );
  }

  Future<void> _activate(String id) async {
    try {
      await widget.api.adminActivateDataset(id);
      _syncAdmin();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dataset activated')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
