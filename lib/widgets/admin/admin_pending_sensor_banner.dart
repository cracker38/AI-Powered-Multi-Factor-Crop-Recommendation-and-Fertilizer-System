import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/admin_pending_sensor_farmer.dart';
import 'admin_sensor_reading_preview.dart';

class AdminPendingSensorBanner extends StatelessWidget {
  const AdminPendingSensorBanner({
    super.key,
    required this.pending,
    required this.onApprove,
  });

  final AdminPendingSensorFarmer pending;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending approval · sensor ready',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${pending.label} is waiting for activation. Live soil readings from the ESP8266 are already in Firebase and will pre-fill the approval form.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          AdminSensorReadingPreview(
            fieldData: pending.fieldData,
            farmerEmail: pending.email,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check_circle_rounded),
            label: Text('Approve ${pending.label} with sensor data'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
