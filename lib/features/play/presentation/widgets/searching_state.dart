import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/matchmaking_queue_model.dart';
import '../../../../shared/widgets/app_button.dart';

/// Searching state — pulsing radar, wait timer, tier escalation info.
class SearchingState extends StatefulWidget {
  final MatchmakingQueueModel queue;
  final VoidCallback onCancel;

  const SearchingState({
    super.key,
    required this.queue,
    required this.onCancel,
  });

  @override
  State<SearchingState> createState() => _SearchingStateState();
}

class _SearchingStateState extends State<SearchingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatWait(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.queue;
    final waitSec = q.waitSeconds;
    final expiresSec = q.secondsUntilExpiry;

    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.bgSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // ── Pulsing radar ──────────────────────────
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (int i = 0; i < 3; i++)
                      _PulseRing(
                        progress: (_pulseCtrl.value + i * 0.33) % 1.0,
                      ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary, width: 2),
                      ),
                      child: const Icon(Icons.radar_rounded,
                          color: AppColors.primary, size: 28),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Wait timer ─────────────────────────────
          Text(
            _formatWait(waitSec),
            style: AppTextStyles.mono.copyWith(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Searching for ${q.mode} match',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textTertiary),
          ),

          const SizedBox(height: 28),

          // ── Info row ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoPill(
                icon: Icons.paid_rounded,
                label: q.entryFee == 0 ? 'Free' : '${q.entryFee} B',
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              _InfoPill(
                icon: Icons.trending_up_rounded,
                label: '${q.eloRating} ELO',
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              _InfoPill(
                icon: Icons.filter_alt_rounded,
                label: q.searchTierLabel,
                color: q.searchTier == 2
                    ? AppColors.accent
                    : q.searchTier == 1
                        ? AppColors.primary
                        : AppColors.textTertiary,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Expiry warning ─────────────────────────
          if (expiresSec < 120)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Expires in ${_formatWait(expiresSec)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Cancel button ──────────────────────────
          SizedBox(
            width: 220,
            height: 48,
            child: AppButton(
              label: 'CANCEL SEARCH',
              variant: AppButtonVariant.danger,
              icon: Icons.close_rounded,
              onPressed: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double progress;
  const _PulseRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final size = 56.0 + (120.0 - 56.0) * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: opacity * 0.6),
          width: 2,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
