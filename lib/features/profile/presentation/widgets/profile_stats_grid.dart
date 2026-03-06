import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/profile_model.dart';

/// Grid of performance stats shown on profile page.
class ProfileStatsGrid extends StatelessWidget {
  final ProfileModel profile;
  const ProfileStatsGrid({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat('Matches', '${profile.matchesPlayed}', Icons.sports_esports_rounded, AppColors.info),
      _Stat('Wins', '${profile.matchesWon}', Icons.emoji_events_rounded, AppColors.success),
      _Stat('Losses', '${profile.matchesLost}', Icons.close_rounded, AppColors.danger),
      _Stat('Win Rate', Formatters.winRate(profile.matchesWon, profile.matchesPlayed), Icons.percent_rounded, AppColors.warning),
      _Stat('ELO Rating', '${profile.eloRating}', Icons.trending_up_rounded, AppColors.primary),
      _Stat('Peak ELO', '${profile.eloPeak}', Icons.star_rounded, Color(0xFFF39C12)),
      _Stat('Win Streak', '${profile.winStreak}', Icons.local_fire_department_rounded, AppColors.accent),
      _Stat('Best Streak', '${profile.bestWinStreak}', Icons.military_tech_rounded, Color(0xFFE74C3C)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 500
                ? 3
                : 2;
        final spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats.map((s) => _StatTile(stat: s, width: cardWidth)).toList(),
        );
      },
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

class _StatTile extends StatelessWidget {
  final _Stat stat;
  final double width;
  const _StatTile({required this.stat, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(stat.icon, size: 16, color: stat.color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.value,
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  stat.label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
