import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/active_presence.dart';

/// Compact pill shown in the status bar when user has an active presence
/// (matchmaking, in lobby, in match, match found).
///
/// Click → navigate to the target route.
/// Hides automatically when user is already on that route.
class PresencePill extends StatefulWidget {
  final ActivePresence presence;
  final String currentRoute;

  const PresencePill({
    super.key,
    required this.presence,
    required this.currentRoute,
  });

  @override
  State<PresencePill> createState() => _PresencePillState();
}

class _PresencePillState extends State<PresencePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  Timer? _clockTimer;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Tick every second to update the elapsed time display
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  String? _elapsedLabel() {
    final started = widget.presence.startedAt;
    if (started == null) return null;
    final diff = DateTime.now().difference(started);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Styling based on presence type ───────────────────
  Color get _color => switch (widget.presence.type) {
        PresenceType.matchFound => AppColors.success,
        PresenceType.matchLive => AppColors.danger,
        PresenceType.lobbyActive => AppColors.primary,
        PresenceType.matchmaking => AppColors.info,
      };

  IconData get _icon => switch (widget.presence.type) {
        PresenceType.matchFound => Icons.check_circle_rounded,
        PresenceType.matchLive => Icons.sports_esports_rounded,
        PresenceType.lobbyActive => Icons.groups_rounded,
        PresenceType.matchmaking => Icons.radar_rounded,
      };

  @override
  Widget build(BuildContext context) {
    // Hide if user is already on the target route
    if (widget.currentRoute.startsWith(widget.presence.targetRoute) &&
        widget.presence.type != PresenceType.matchFound) {
      return const SizedBox.shrink();
    }

    final elapsed = _elapsedLabel();
    final urgent = widget.presence.isUrgent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.presence.targetRoute),
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, _) {
            // Urgent presences pulse; others have subtle hover
            final pulseAlpha =
                urgent ? (0.15 + _pulseCtrl.value * 0.2) : 0.1;
            final borderAlpha =
                urgent ? (0.4 + _pulseCtrl.value * 0.4) : 0.35;
            final glowBlur = urgent ? (8.0 + _pulseCtrl.value * 6.0) : 0.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _color.withValues(
                    alpha: _hovered ? pulseAlpha + 0.05 : pulseAlpha),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _color.withValues(alpha: borderAlpha),
                  width: 1,
                ),
                boxShadow: urgent
                    ? [
                        BoxShadow(
                          color: _color.withValues(alpha: 0.3),
                          blurRadius: glowBlur,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing dot for urgent states
                  if (urgent) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _color.withValues(
                            alpha: 0.6 + _pulseCtrl.value * 0.4),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _color.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                  ] else ...[
                    Icon(_icon, size: 12, color: _color),
                    const SizedBox(width: 6),
                  ],

                  // Label
                  Text(
                    widget.presence.label,
                    style: AppTextStyles.caption.copyWith(
                      color: _color,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),

                  // Subtitle (mode / name)
                  if (widget.presence.subtitle != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 1,
                      height: 10,
                      color: _color.withValues(alpha: 0.25),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.presence.subtitle!,
                      style: AppTextStyles.caption.copyWith(
                        color: _color.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  // Elapsed time (for searching / live match)
                  if (elapsed != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 1,
                      height: 10,
                      color: _color.withValues(alpha: 0.25),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      elapsed,
                      style: AppTextStyles.mono.copyWith(
                        color: _color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
