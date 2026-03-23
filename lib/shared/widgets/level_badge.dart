import 'package:flutter/material.dart';
import '../../core/constants/level_system.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Compact level badge showing level number, tier color, and prestige.
class LevelBadge extends StatelessWidget {
  final int elo;
  final bool showProgress;
  final bool showElo;
  final double scale;

  const LevelBadge({
    super.key,
    required this.elo,
    this.showProgress = false,
    this.showElo = false,
    this.scale = 1.0,
  });

  /// Inline small badge for lists, leaderboards etc.
  const LevelBadge.compact({super.key, required this.elo})
      : showProgress = false, showElo = false, scale = 0.85;

  /// Full badge for profile header.
  const LevelBadge.full({super.key, required this.elo})
      : showProgress = true, showElo = true, scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final level = LevelSystem.levelFromElo(elo);
    final prestige = LevelSystem.prestigeFromElo(elo);
    final tier = LevelSystem.tierForLevel(level);
    final progress = LevelSystem.progressInLevel(elo);
    final toNext = LevelSystem.eloToNextLevel(elo);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prestige star (if any)
        if (prestige > 0) ...[
          _PrestigeStar(count: prestige, scale: scale),
          SizedBox(width: 4 * scale),
        ],

        // Level hex
        _LevelHex(level: level, tier: tier, scale: scale),

        if (showProgress || showElo) ...[
          SizedBox(width: 8 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tier.name, style: AppTextStyles.caption.copyWith(
                      color: tier.color, fontWeight: FontWeight.w700, fontSize: 10 * scale)),
                  if (showElo) ...[
                    SizedBox(width: 6 * scale),
                    Text('$elo ELO', style: AppTextStyles.mono.copyWith(
                        color: AppColors.textTertiary, fontSize: 10 * scale)),
                  ],
                ],
              ),
              if (showProgress) ...[
                SizedBox(height: 3 * scale),
                SizedBox(
                  width: 100 * scale,
                  height: 4 * scale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2 * scale),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.bgSurfaceActive,
                      valueColor: AlwaysStoppedAnimation(tier.color),
                    ),
                  ),
                ),
                SizedBox(height: 1 * scale),
                Text('$toNext to Lv ${level < 50 ? level + 1 : "MAX"}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary, fontSize: 8 * scale)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _LevelHex extends StatelessWidget {
  final int level;
  final LevelTier tier;
  final double scale;
  const _LevelHex({required this.level, required this.tier, required this.scale});

  @override
  Widget build(BuildContext context) {
    final size = 32.0 * scale;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: tier.color.withValues(alpha: 0.5), width: 1.5 * scale),
        boxShadow: [BoxShadow(color: tier.color.withValues(alpha: 0.15), blurRadius: 6 * scale)],
      ),
      child: Center(
        child: Text('$level', style: AppTextStyles.mono.copyWith(
            color: tier.color, fontSize: 13 * scale, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _PrestigeStar extends StatelessWidget {
  final int count;
  final double scale;
  const _PrestigeStar({required this.count, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
        borderRadius: BorderRadius.circular(4 * scale),
        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 6 * scale)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12 * scale, color: Colors.white),
          SizedBox(width: 2 * scale),
          Text('$count', style: TextStyle(color: Colors.white, fontSize: 10 * scale, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
