import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../shared/widgets/elo_badge.dart';

/// Top header with greeting, username, and ELO badge.
class DashboardHeader extends StatelessWidget {
  final ProfileModel profile;
  const DashboardHeader({super.key, required this.profile});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              profile.username.isNotEmpty
                  ? profile.username[0].toUpperCase()
                  : '?',
              style: AppTextStyles.h2.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Greeting + Username
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    profile.username,
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(width: 10),
                  EloBadge(elo: profile.eloRating),
                ],
              ),
            ],
          ),
        ),

        // Member since
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Member since',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(profile.createdAt),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
