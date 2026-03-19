import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teams', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text('Manage your teams', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
