import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Displays ELO rating with color based on rank tier.
class EloBadge extends StatelessWidget {
  final int elo;
  const EloBadge({super.key, required this.elo});

  Color get _color {
    if (elo >= 2500) return const Color(0xFFE74C3C); // Legendary
    if (elo >= 2000) return const Color(0xFFF39C12); // Master
    if (elo >= 1500) return const Color(0xFF9B59B6); // Diamond
    if (elo >= 1200) return const Color(0xFF3498DB); // Platinum
    if (elo >= 1000) return AppColors.success; // Gold
    if (elo >= 800) return AppColors.textSecondary; // Silver
    return AppColors.textTertiary; // Bronze
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$elo',
        style: AppTextStyles.mono
            .copyWith(color: _color, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
