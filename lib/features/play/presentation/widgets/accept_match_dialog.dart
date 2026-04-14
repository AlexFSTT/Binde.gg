import 'dart:async';
import 'package:binde_gg/core/errors/result.dart';
import 'package:flutter/material.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/repositories/matchmaking_repository.dart';
import '../../../../shared/widgets/app_button.dart';

/// Accept-match dialog — 15s countdown with Accept/Decline.
/// Returns `true` if accepted, `false` if declined (or auto-declined on timeout).
class AcceptMatchDialog extends StatefulWidget {
  final String matchId;
  const AcceptMatchDialog({super.key, required this.matchId});

  @override
  State<AcceptMatchDialog> createState() => _AcceptMatchDialogState();
}

class _AcceptMatchDialogState extends State<AcceptMatchDialog>
    with SingleTickerProviderStateMixin {
  final _repo = MatchmakingRepository();

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  Timer? _countdown;
  int _secondsLeft = 15;
  bool _isSubmitting = false;
  bool _hasAccepted = false;
  int _acceptedCount = 1; // Assume self on accept
  int _totalCount = 2;

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnim =
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut);
    _bounceCtrl.forward();

    _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    // Auto-decline on timeout
    Log.d('AcceptDialog: timeout — treating as decline');
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _accept() async {
    if (_isSubmitting || _hasAccepted) return;
    setState(() => _isSubmitting = true);

    final result = await _repo.acceptMatch(
      userId: _userId,
      matchId: widget.matchId,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _hasAccepted = true;
        _isSubmitting = false;
        _acceptedCount =
            (result.data!['accepted_count'] as int?) ?? _acceptedCount;
        _totalCount = (result.data!['total_count'] as int?) ?? _totalCount;
      });

      // If all accepted, close immediately
      if (result.data!['all_accepted'] == true) {
        if (mounted) Navigator.of(context).pop(true);
      }
      // Otherwise stay open — we've accepted, wait for others
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to accept'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _decline() {
    if (_isSubmitting) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: _bounceAnim,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bgSurface,
                AppColors.bgElevated,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.2),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ─────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────
              Text('MATCH FOUND',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.success,
                    letterSpacing: 2,
                    fontSize: 24,
                  )),
              const SizedBox(height: 8),

              if (_hasAccepted) ...[
                Text(
                  'Waiting for other players...',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_acceptedCount / $_totalCount accepted',
                  style: AppTextStyles.mono.copyWith(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                Text(
                  'Your match is ready. Accept to continue.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // ── Countdown ────────────────────────
              _CountdownBar(
                seconds: _secondsLeft,
                totalSeconds: 15,
              ),

              const SizedBox(height: 28),

              // ── Buttons ──────────────────────────
              if (!_hasAccepted) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: AppButton(
                          label: 'DECLINE',
                          variant: AppButtonVariant.secondary,
                          onPressed: _isSubmitting ? null : _decline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: AppButton(
                          label: 'ACCEPT',
                          icon: Icons.check_rounded,
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _accept,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Declining will apply a 2-minute penalty.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary, fontSize: 10),
                ),
              ] else ...[
                // After acceptance, show loading
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Preparing match...',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownBar extends StatelessWidget {
  final int seconds;
  final int totalSeconds;

  const _CountdownBar({required this.seconds, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final progress = (seconds / totalSeconds).clamp(0.0, 1.0);
    final color = seconds <= 5
        ? AppColors.danger
        : seconds <= 10
            ? AppColors.warning
            : AppColors.success;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '${seconds}s',
              style: AppTextStyles.mono.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.bgSurfaceActive,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
