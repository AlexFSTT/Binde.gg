import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Left sidebar navigation — desktop layout.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('BINDE.GG', style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(height: 24),

          // Nav items — TODO: wire up with GoRouter
          _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
          _NavItem(icon: Icons.groups_rounded, label: 'Lobbies', route: '/lobbies'),
          _NavItem(icon: Icons.leaderboard_rounded, label: 'Leaderboard', route: '/leaderboard'),
          _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', route: '/wallet'),

          const Spacer(),

          // Bottom nav
          _NavItem(icon: Icons.person_rounded, label: 'Profile', route: '/profile/me'),
          _NavItem(icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    // TODO: Highlight active route
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: AppColors.textSecondary),
        title: Text(label, style: AppTextStyles.bodyMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        hoverColor: AppColors.bgSurfaceHover,
        onTap: () {
          // TODO: GoRouter navigation
        },
      ),
    );
  }
}
