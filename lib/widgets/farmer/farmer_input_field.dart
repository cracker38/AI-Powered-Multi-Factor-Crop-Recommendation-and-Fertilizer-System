import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class FarmerInputField extends StatelessWidget {
  const FarmerInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    required this.min,
    required this.max,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final double min;
  final double max;
  final String? hint;

  String? _validate(String? s) {
    if (s == null || s.trim().isEmpty) return 'Required';
    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null) return 'Invalid number';
    if (v < min || v > max) return '$min – $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => _validate(v),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}
