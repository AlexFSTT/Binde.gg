import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Small colored badge for match/lobby status.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool pulse;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.pulse = false,
  });

  // Named constructors for common statuses
  factory StatusBadge.live() => const StatusBadge(
      label: 'LIVE', color: AppColors.statusLive, pulse: true);
  factory StatusBadge.open() =>
      const StatusBadge(label: 'Open', color: AppColors.success);
  factory StatusBadge.full() =>
      const StatusBadge(label: 'Full', color: AppColors.warning);
  factory StatusBadge.finished() =>
      const StatusBadge(label: 'Finished', color: AppColors.textTertiary);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            _PulseDot(color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}
