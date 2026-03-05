import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/route_paths.dart';
import '../../data/repositories/auth_repository.dart';

/// Left sidebar navigation — desktop layout.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 240,
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // ── Logo ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'B',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'BINDE.GG',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Main nav items ───────────────────────────
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            route: Routes.dashboard,
            isActive: currentPath == Routes.dashboard,
          ),
          _NavItem(
            icon: Icons.groups_rounded,
            label: 'Lobbies',
            route: Routes.lobbies,
            isActive: currentPath == Routes.lobbies ||
                currentPath.startsWith('/lobby/'),
          ),
          _NavItem(
            icon: Icons.leaderboard_rounded,
            label: 'Leaderboard',
            route: Routes.leaderboard,
            isActive: currentPath == Routes.leaderboard,
          ),
          _NavItem(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
            route: Routes.wallet,
            isActive: currentPath == Routes.wallet,
          ),

          const Spacer(),

          // ── Bottom nav items ─────────────────────────
          const Divider(
            color: AppColors.border,
            indent: 20,
            endIndent: 20,
            height: 1,
          ),
          const SizedBox(height: 8),

          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            route: Routes.myProfile,
            isActive: currentPath == Routes.myProfile ||
                currentPath.startsWith('/profile/'),
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            route: Routes.settings,
            isActive: currentPath == Routes.settings,
          ),

          const SizedBox(height: 4),

          // ── Logout ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ListTile(
              dense: true,
              leading: const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.danger,
              ),
              title: Text(
                'Logout',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.danger,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hoverColor: AppColors.dangerMuted,
              onTap: () async {
                await AuthRepository().logout();
                if (context.mounted) {
                  context.go(Routes.login);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.primary : AppColors.textTertiary,
        ),
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: isActive
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        hoverColor: AppColors.bgSurfaceHover,
        onTap: () => context.go(route),
      ),
    );
  }
}
