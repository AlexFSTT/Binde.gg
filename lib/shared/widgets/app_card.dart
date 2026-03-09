import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Reusable styled card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );

    return onTap != null
        ? InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: card)
        : card;
  }
}
