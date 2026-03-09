import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/models/wallet_model.dart';

/// Row of 4 stat cards: ELO, Win Rate, Matches Played, Balance.
class StatsCardsRow extends StatelessWidget {
  final ProfileModel profile;
  final WalletModel? wallet;

  const StatsCardsRow({
    super.key,
    required this.profile,
    this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 500
                ? 2
                : 1;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              width: _cardWidth(constraints.maxWidth, crossAxisCount),
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.primary,
              label: 'ELO Rating',
              value: profile.eloRating.toString(),
              subtitle: 'Peak: ${profile.eloPeak}',
              accentColor: AppColors.primary,
            ),
            _StatCard(
              width: _cardWidth(constraints.maxWidth, crossAxisCount),
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.warning,
              label: 'Win Rate',
              value: Formatters.winRate(profile.matchesWon, profile.matchesPlayed),
              subtitle: '${profile.matchesWon}W - ${profile.matchesLost}L',
              accentColor: AppColors.warning,
            ),
            _StatCard(
              width: _cardWidth(constraints.maxWidth, crossAxisCount),
              icon: Icons.sports_esports_rounded,
              iconColor: AppColors.info,
              label: 'Matches',
              value: profile.matchesPlayed.toString(),
              subtitle: profile.winStreak > 0
                  ? '${profile.winStreak} win streak'
                  : 'Best: ${profile.bestWinStreak} streak',
              accentColor: AppColors.info,
            ),
            _StatCard(
              width: _cardWidth(constraints.maxWidth, crossAxisCount),
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.success,
              label: 'Balance',
              value: Formatters.currency(wallet?.balance ?? 0),
              subtitle: wallet != null
                  ? 'Locked: ${Formatters.currency(wallet!.lockedBalance)}'
                  : 'Wallet loading...',
              accentColor: AppColors.success,
            ),
          ],
        );
      },
    );
  }

  double _cardWidth(double totalWidth, int count) {
    final spacing = 16.0 * (count - 1);
    return (totalWidth - spacing) / count;
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _StatCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + Label row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Value
            Text(
              value,
              style: AppTextStyles.monoLarge.copyWith(
                color: AppColors.textPrimary,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
