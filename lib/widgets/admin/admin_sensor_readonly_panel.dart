import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/farmer_field_data.dart';

/// Read-only ESP8266 sensor readings for admin approval (no editing).
class AdminSensorReadonlyPanel extends StatelessWidget {
  const AdminSensorReadonlyPanel({
    super.key,
    required this.fieldData,
    this.deviceId,
    this.ecUsCm,
  });

  final FarmerFieldData fieldData;
  final String? deviceId;
  final double? ecUsCm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sensor readings are read-only. Values are taken directly from Firebase RTDB without modification.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _grid([
          _item('Nitrogen (N)', '${_fmt(fieldData.nitrogen)} kg/ha', Icons.grass_rounded),
          _item('Phosphorus (P)', '${_fmt(fieldData.phosphorus)} kg/ha', Icons.water_drop_outlined),
          _item('Potassium (K)', '${_fmt(fieldData.potassium)} kg/ha', Icons.bolt_outlined),
          _item('Soil pH', _fmt(fieldData.soilPh), Icons.science_outlined),
          _item('Soil moisture', '${_fmt(fieldData.soilMoisture)}%', Icons.opacity_outlined),
          _item('Temperature', '${_fmt(fieldData.temperatureC)} °C', Icons.thermostat_outlined),
          if (ecUsCm != null) _item('EC', '${_fmt(ecUsCm!)} µS/cm', Icons.electric_bolt_outlined),
          _item('Soil type', fieldData.soilType, Icons.landscape_outlined),
        ]),
      ],
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  Widget _grid(List<Widget> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items,
    );
  }

  Widget _item(String label, String value, IconData icon) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}
