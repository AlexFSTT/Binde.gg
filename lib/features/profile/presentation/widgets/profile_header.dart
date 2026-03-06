import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../shared/widgets/elo_badge.dart';
import '../../../../shared/widgets/status_badge.dart';

/// Profile page header — avatar, name, ELO, Steam link, role badge.
class ProfileHeader extends StatelessWidget {
  final ProfileModel profile;
  final bool isOwnProfile;

  const ProfileHeader({
    super.key,
    required this.profile,
    this.isOwnProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ───────────────────────────────
          _Avatar(profile: profile),
          const SizedBox(width: 24),

          // ── Info Column ──────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username + badges
                Row(
                  children: [
                    Text(profile.username, style: AppTextStyles.h2),
                    const SizedBox(width: 12),
                    EloBadge(elo: profile.eloRating),
                    if (profile.isStaff) ...[
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: profile.role.toUpperCase(),
                        color: profile.isAdmin
                            ? AppColors.danger
                            : AppColors.warning,
                      ),
                    ],
                    if (profile.isKycVerified) ...[
                      const SizedBox(width: 8),
                      const StatusBadge(
                        label: 'VERIFIED',
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Steam + region + member since
                Row(
                  children: [
                    // Steam status
                    _InfoChip(
                      icon: Icons.gamepad_rounded,
                      label: profile.hasSteam
                          ? (profile.steamUsername ?? 'Steam Linked')
                          : 'Steam not linked',
                      color: profile.hasSteam
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 20),

                    // Region
                    _InfoChip(
                      icon: Icons.public_rounded,
                      label: profile.preferredRegion,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 20),

                    // Preferred mode
                    _InfoChip(
                      icon: Icons.groups_rounded,
                      label: profile.preferredMode,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 20),

                    // Member since
                    _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      label: 'Joined ${Formatters.date(profile.createdAt)}',
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Right side: Earnings ─────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Earnings',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.currency(profile.totalEarnings),
                style: AppTextStyles.monoLarge.copyWith(
                  color: profile.totalEarnings > 0
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
              if (isOwnProfile) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceActive,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'YOUR PROFILE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final ProfileModel profile;
  const _Avatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
        image: profile.steamAvatarUrl != null
            ? DecorationImage(
                image: NetworkImage(profile.steamAvatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: profile.steamAvatarUrl == null
          ? Center(
              child: Text(
                profile.username.isNotEmpty
                    ? profile.username[0].toUpperCase()
                    : '?',
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.primary,
                  fontSize: 32,
                ),
              ),
            )
          : null,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}
