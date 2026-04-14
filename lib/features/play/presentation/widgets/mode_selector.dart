import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Three big cards for mode selection: 1v1 / 2v2 / 5v5.
class ModeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const ModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _modes = [
    (value: '1v1', label: '1v1', sub: 'Aim duel', icon: Icons.person_rounded),
    (value: '2v2', label: '2v2', sub: 'Wingman', icon: Icons.people_rounded),
    (value: '5v5', label: '5v5', sub: 'Competitive', icon: Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((m) {
        final isSelected = selected == m.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: m.value != _modes.last.value ? 12 : 0,
            ),
            child: _ModeCard(
              label: m.label,
              subtitle: m.sub,
              icon: m.icon,
              isSelected: isSelected,
              onTap: () => onChanged(m.value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModeCard extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.primary.withValues(alpha: 0.08)
                : _hovered
                    ? AppColors.bgSurfaceHover
                    : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : _hovered
                      ? AppColors.border
                      : AppColors.borderSubtle,
              width: sel ? 1.5 : 1,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                widget.icon,
                size: 32,
                color: sel ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: AppTextStyles.h2.copyWith(
                  color: sel ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
