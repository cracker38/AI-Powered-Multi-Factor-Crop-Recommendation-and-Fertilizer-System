import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/admin_sensor_field_data.dart';
import '../../models/farmer_field_data.dart';

class AdminSensorReadingPreview extends StatelessWidget {
  const AdminSensorReadingPreview({
    super.key,
    required this.fieldData,
    this.reading,
    this.farmerEmail,
  });

  final FarmerFieldData fieldData;
  final AdminSensorFieldData? reading;
  final String? farmerEmail;

  @override
  Widget build(BuildContext context) {
    final device = reading?.deviceId ?? 'ESP8266_SOIL_01';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sensors_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live ESP8266 soil sensor',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      farmerEmail != null
                          ? 'Readings linked to $farmerEmail · $device'
                          : 'Device $device · 7-in-1 field probe',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Online',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('N', '${fieldData.nitrogen.toStringAsFixed(0)} kg/ha', Icons.grass_rounded),
              _chip('P', '${fieldData.phosphorus.toStringAsFixed(0)} kg/ha', Icons.water_drop_outlined),
              _chip('K', '${fieldData.potassium.toStringAsFixed(0)} kg/ha', Icons.bolt_outlined),
              _chip('pH', fieldData.soilPh.toStringAsFixed(1), Icons.science_outlined),
              _chip('Moisture', '${fieldData.soilMoisture.toStringAsFixed(0)}%', Icons.opacity_outlined),
              _chip('Temp', '${fieldData.temperatureC.toStringAsFixed(1)} °C', Icons.thermostat_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}
