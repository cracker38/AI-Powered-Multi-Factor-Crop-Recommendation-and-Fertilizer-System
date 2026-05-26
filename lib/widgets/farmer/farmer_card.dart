import 'package:flutter/material.dart';

import '../../core/farmer_theme.dart';

class FarmerCard extends StatelessWidget {
  const FarmerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: FarmerTheme.cardDecoration().copyWith(
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card),
    );
  }
}
