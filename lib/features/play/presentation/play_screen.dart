import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_rounded, size: 64, color: AppColors.success.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text('Find a Match', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text('Select mode and stake to start matchmaking', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
