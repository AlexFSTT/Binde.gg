import 'dart:async';
import 'package:binde_gg/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/repositories/matchmaking_repository.dart';
import '../../../../shared/widgets/app_button.dart';

/// Accept-match dialog — 15s countdown with Accept/Decline.
///
/// Returns:
///   true  → accepted AND all players accepted (match went to veto)
///   false → declined or timed out (penalty applied by caller)
///
/// Key behaviour: after the user clicks Accept, we keep the dialog open
/// and listen on `matches` realtime for the transition to 'veto'. That's
/// the signal that EVERYONE accepted — at which point we pop(true).
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
  int _acceptedCount = 0;
  int _totalCount = 2;

  // Realtime listener for the match row
  RealtimeChannel? _matchChannel;

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

    _subscribeMatch();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _matchChannel?.unsubscribe();
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Realtime subscription on the match row ─────────────
  void _subscribeMatch() {
    _matchChannel = SupabaseConfig.client
        .channel('accept_dialog:${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.matchId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newStatus = payload.newRecord['status'] as String?;
            Log.d('AcceptDialog: match status → $newStatus');

            if (newStatus == 'veto') {
              // Everyone accepted. Close dialog with success.
              _countdown?.cancel();
              Navigator.of(context).pop(true);
            } else if (newStatus == 'cancelled') {
              // Someone declined. Close dialog with failure.
              _countdown?.cancel();
              Navigator.of(context).pop(false);
            }
          },
        )
        .subscribe();
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
    Log.d('AcceptDialog: timeout — treating as decline');
    // Only decline if we haven't already accepted.
    // If we accepted and are waiting, the cron will handle expiry
    // and trigger a cancelled status via realtime — but to be safe,
    // pop with false only if not accepted.
    if (!_hasAccepted && mounted) {
      Navigator.of(context).pop(false);
    }
    // If accepted, we just stop the countdown and keep waiting on realtime.
    // The accept_expires_at deadline on the server side will cancel if needed.
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
      final data = result.data!;
      setState(() {
        _hasAccepted = true;
        _isSubmitting = false;
        _acceptedCount = (data['accepted_count'] as int?) ?? 1;
        _totalCount = (data['total_count'] as int?) ?? _totalCount;
      });

      // If all accepted → close immediately.
      // Otherwise → keep dialog open and let realtime signal the veto transition.
      if (data['all_accepted'] == true) {
        _countdown?.cancel();
        Navigator.of(context).pop(true);
      }
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
              colors: [AppColors.bgSurface, AppColors.bgElevated],
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
              _CountdownBar(
                seconds: _secondsLeft.clamp(0, 15),
                totalSeconds: 15,
              ),
              const SizedBox(height: 28),
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
