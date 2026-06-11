import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/farmer_field_data.dart';

/// Read-only ESP8266 sensor readings for admin approval (no editing).
class AdminSensorReadonlyPanel extends StatelessWidget {
  const AdminSensorReadonlyPanel({
    super.key,
    required this.fieldData,
    this.rawFieldData,
    this.deviceId,
    this.ecUsCm,
  });

  final FarmerFieldData fieldData;
  final Map<String, dynamic>? rawFieldData;
  final String? deviceId;
  final double? ecUsCm;

  String _rawNum(String key, double fallback) {
    final v = rawFieldData?[key];
    if (v is num) return _fmt(v.toDouble());
    return _fmt(fallback);
  }

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
                  'Sensor readings are read-only — exact values from Firebase RTDB (raw sensor units).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _grid([
          _item('Nitrogen (N)', '${_rawNum('nitrogen', fieldData.nitrogen)} kg/ha', Icons.grass_rounded),
          _item('Phosphorus (P)', '${_rawNum('phosphorus', fieldData.phosphorus)} kg/ha', Icons.water_drop_outlined),
          _item('Potassium (K)', '${_rawNum('potassium', fieldData.potassium)} kg/ha', Icons.bolt_outlined),
          _item('Soil pH', _rawNum('soil_ph', fieldData.soilPh), Icons.science_outlined),
          _item('Soil moisture', '${_rawNum('soil_moisture', fieldData.soilMoisture)}%', Icons.opacity_outlined),
          _item('Temperature', '${_rawNum('temperature_c', fieldData.temperatureC)} °C', Icons.thermostat_outlined),
          _item(
            'EC',
            '${_rawNum('ec_us_cm', ecUsCm ?? 0)} µS/cm',
            Icons.electric_bolt_outlined,
          ),
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
