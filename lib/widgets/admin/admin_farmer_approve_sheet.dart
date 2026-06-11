import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/rwanda_districts.dart';
import '../../models/admin_sensor_field_data.dart';
import '../../models/admin_user.dart';
import '../../models/farmer_field_data.dart';
import '../../services/api_service.dart';
import 'admin_sensor_reading_preview.dart';
import 'admin_sensor_readonly_panel.dart';

Future<bool?> showAdminFarmerApproveSheet(
  BuildContext context, {
  required ApiService api,
  required AdminUser user,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AdminFarmerApproveSheet(api: api, user: user),
  );
}

class _AdminFarmerApproveSheet extends StatefulWidget {
  const _AdminFarmerApproveSheet({required this.api, required this.user});

  final ApiService api;
  final AdminUser user;

  @override
  State<_AdminFarmerApproveSheet> createState() => _AdminFarmerApproveSheetState();
}

class _AdminFarmerApproveSheetState extends State<_AdminFarmerApproveSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName ?? '');
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  late final _farmSize = TextEditingController(text: (widget.user.farmSizeHa ?? 1).toString());
  late final _notes = TextEditingController();
  late String? _district = widget.user.district;
  bool _busy = false;
  bool _sensorLoading = true;
  bool _sensorLoaded = false;
  AdminSensorFieldData? _sensorReading;
  String? _error;
  String? _sensorMessage;

  @override
  void initState() {
    super.initState();
    _loadSensorFieldData();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _farmSize.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadSensorFieldData() async {
    setState(() {
      _sensorLoading = true;
      _sensorMessage = null;
      _sensorLoaded = false;
      _sensorReading = null;
    });
    try {
      final reading = await widget.api.adminFetchSensorFieldData(widget.user.id);
      if (!mounted) return;
      if (reading != null) {
        setState(() {
          _sensorLoaded = true;
          _sensorReading = reading;
          _sensorMessage =
              'Live ESP8266 readings loaded for this pending farmer. Sensor values cannot be edited.';
        });
      } else {
        setState(() {
          _sensorMessage =
              'No sensor data available yet. Ensure the ESP8266 is online — readings are linked automatically to the last pending farmer (${widget.user.email}).';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _sensorMessage = e.message);
    } finally {
      if (mounted) setState(() => _sensorLoading = false);
    }
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_sensorLoaded || _sensorReading == null) {
      setState(() => _error = 'Cannot approve without live sensor data from Firebase.');
      return;
    }
    final farmSize = double.tryParse(_farmSize.text.replaceAll(',', '.'));
    if (farmSize == null || farmSize <= 0) {
      setState(() => _error = 'Enter a valid farm size in hectares');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.adminApproveFarmer(
        id: widget.user.id,
        displayName: _name.text.trim(),
        farmSizeHa: farmSize,
        sensorFieldData: _sensorReading!.rawFieldData,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        district: _district,
        adminNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.05),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Approve farmer with sensor data',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(widget.user.email, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const Text(
                'The latest ESP8266 reading is assigned to the last pending farmer. Review account details below — soil data comes directly from the sensor and cannot be changed.',
                style: TextStyle(height: 1.4, color: AppColors.textSecondary),
              ),
              if (_sensorLoading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Loading sensor data from Firebase…', style: TextStyle(color: AppColors.textSecondary)),
              ],
              if (_sensorMessage != null && !_sensorLoading) ...[
                const SizedBox(height: 12),
                if (_sensorLoaded && _sensorReading != null) ...[
                  AdminSensorReadingPreview(
                    fieldData: _sensorReading!.fieldData,
                    reading: _sensorReading,
                    farmerEmail: widget.user.email,
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _sensorLoaded ? AppColors.primary.withValues(alpha: 0.06) : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _sensorLoaded ? AppColors.primary.withValues(alpha: 0.2) : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sensorLoaded ? Icons.verified_rounded : Icons.info_outline_rounded,
                        color: _sensorLoaded ? AppColors.primary : Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _sensorMessage!,
                          style: TextStyle(
                            color: _sensorLoaded ? AppColors.primary : Colors.orange.shade900,
                            height: 1.35,
                          ),
                        ),
                      ),
                      TextButton(onPressed: _busy ? null : _loadSensorFieldData, child: const Text('Refresh')),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Account details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().length < 2 ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _district,
                      decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Select district')),
                        ...RwandaDistricts.list.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                      ],
                      onChanged: (v) => setState(() => _district = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _farmSize,
                      decoration: const InputDecoration(
                        labelText: 'Farm size (hectares)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Enter farm size in ha';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Admin notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (_sensorLoaded && _sensorReading != null) ...[
                const SizedBox(height: 20),
                const Text('Soil sensor readings (read-only)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                AdminSensorReadonlyPanel(
                  fieldData: _sensorReading!.fieldData,
                  deviceId: _sensorReading!.deviceId,
                  ecUsCm: _sensorReading!.ecUsCm,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: (_busy || !_sensorLoaded) ? null : _activate,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Activate farmer account'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.errorText)),
              ],
              const SizedBox(height: 8),
              TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }
}
