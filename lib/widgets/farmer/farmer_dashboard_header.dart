import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/brand.dart';
import '../../core/farmer_theme.dart';
import 'farmer_shared.dart';

class FarmerDashboardHeader extends StatelessWidget {
  const FarmerDashboardHeader({
    super.key,
    required this.displayName,
    this.district,
    this.evaluationCount = 0,
    this.avgSoilHealth,
    this.lastCrop,
    this.apiOnline = true,
  });

  final String displayName;
  final String? district;
  final int evaluationCount;
  final double? avgSoilHealth;
  final String? lastCrop;
  final bool apiOnline;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Container(
      width: double.infinity,
      decoration: FarmerTheme.headerDecoration(),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Brand.greeting(displayName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FarmerOnlineBadge(online: apiOnline),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
              if (district != null && district!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Text(
                      district!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FarmerTheme.accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'RW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  _kpiChip(
                    Icons.assignment_rounded,
                    '$evaluationCount',
                    evaluationCount == 1 ? 'Evaluation' : 'Evaluations',
                  ),
                  const SizedBox(width: 8),
                  _kpiChip(
                    Icons.favorite_rounded,
                    avgSoilHealth != null && avgSoilHealth! > 0 ? avgSoilHealth!.toStringAsFixed(0) : '—',
                    'Soil health',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kpiChip(
                      Icons.grass_rounded,
                      lastCrop != null ? lastCrop!.toUpperCase() : '—',
                      'Latest crop',
                      expand: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiChip(IconData icon, String value, String label, {bool expand = false}) {
    return Expanded(
      flex: expand ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: FarmerTheme.accent),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
