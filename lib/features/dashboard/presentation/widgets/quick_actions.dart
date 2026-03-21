import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../lobby/presentation/widgets/create_lobby_dialog.dart';
import '../../../../shared/widgets/bounce_dialog.dart';

/// Quick action buttons row on dashboard.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTextStyles.label.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionButton(
              icon: Icons.play_arrow_rounded,
              label: 'Find Match',
              color: AppColors.primary,
              onTap: () => context.go(Routes.play),
            ),
            _ActionButton(
              icon: Icons.add_rounded,
              label: 'Create Lobby',
              color: AppColors.accent,
              onTap: () async {
                final created = await showBounceDialog<dynamic>(
                  context: context,
                  builder: (_) => const CreateLobbyDialog(),
                );
                if (created != null && context.mounted) {
                  context.go('/lobby/${created.id}');
                }
              },
            ),
            _ActionButton(
              icon: Icons.search_rounded,
              label: 'Browse Lobbies',
              color: AppColors.info,
              onTap: () => context.go(Routes.lobbies),
            ),
            _ActionButton(
              icon: Icons.leaderboard_rounded,
              label: 'Leaderboard',
              color: AppColors.warning,
              onTap: () => context.go(Routes.leaderboard),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.12)
                : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 20, color: widget.color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: AppTextStyles.label.copyWith(
                  color: _hovered ? widget.color : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
