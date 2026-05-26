import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/brand.dart';

class AboutAppSection extends StatelessWidget {
  const AboutAppSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                Brand.productName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Spacer(),
              Text(
                Brand.versionLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Brand.productFullName,
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '${Brand.region} · ${Brand.tagline}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
