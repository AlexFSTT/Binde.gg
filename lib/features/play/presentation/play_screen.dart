import 'dart:async';
import 'package:binde_gg/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/matchmaking_queue_model.dart';
import '../../../data/repositories/matchmaking_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_button.dart';
import 'widgets/mode_selector.dart';
import 'widgets/fee_selector.dart';
import 'widgets/searching_state.dart';
import 'widgets/accept_match_dialog.dart';

/// Play screen — FACEIT-style matchmaking entry.
///
/// Flow:
///   1. Pick mode (1v1/2v2/5v5)
///   2. Pick entry fee (presets)
///   3. Find match → enqueue + listen realtime
///   4. When matched → accept dialog
///   5. When all accept → redirect to /match/:id (veto phase)
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final _repo = MatchmakingRepository();

  // Selection state
  String _mode = '5v5';
  int _entryFee = 0;

  // Queue state
  MatchmakingQueueModel? _queue;
  bool _isEnqueueing = false;
  String? _error;

  // Realtime
  RealtimeChannel? _channel;
  Timer? _pollTimer;

  // Accept dialog
  bool _acceptDialogShown = false;

  String get _userId => SupabaseConfig.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _checkExistingQueue();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Startup: check if user is already in queue ──────────
  Future<void> _checkExistingQueue() async {
    final result = await _repo.getActiveQueue(_userId);
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() => _queue = result.data);
      _subscribeQueue();
      _handleQueueState();
    }
  }

  // ── Enqueue ─────────────────────────────────────────────
  Future<void> _findMatch() async {
    setState(() {
      _isEnqueueing = true;
      _error = null;
    });

    final result = await _repo.enqueue(
      userId: _userId,
      mode: _mode,
      entryFee: _entryFee,
    );

    if (!mounted) return;

    if (result.isFailure) {
      setState(() {
        _isEnqueueing = false;
        _error = result.error;
      });
      return;
    }

    // Fetch the freshly-created row so we have full state
    final queueResult = await _repo.getActiveQueue(_userId);
    if (!mounted) return;

    if (queueResult.isSuccess && queueResult.data != null) {
      setState(() {
        _queue = queueResult.data;
        _isEnqueueing = false;
      });
      _subscribeQueue();
    } else {
      setState(() {
        _isEnqueueing = false;
        _error = 'Failed to load queue entry';
      });
    }
  }

  // ── Cancel ──────────────────────────────────────────────
  Future<void> _cancelSearch() async {
    final result = await _repo.cancel(_userId);
    if (!mounted) return;

    if (result.isSuccess) {
      _channel?.unsubscribe();
      _channel = null;
      setState(() => _queue = null);
    } else {
      _showSnack(result.error ?? 'Failed to cancel', isError: true);
    }
  }

  // ── Realtime subscription ───────────────────────────────
  void _subscribeQueue() {
    if (_queue == null) return;

    _channel?.unsubscribe();
    _channel = SupabaseConfig.client
        .channel('mmq:${_queue!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matchmaking_queue',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _queue!.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final updated = MatchmakingQueueModel.fromJson(payload.newRecord);
            Log.d(
                'mmq update: ${updated.status} (match_id=${updated.matchId})');
            setState(() => _queue = updated);
            _handleQueueState();
          },
        )
        .subscribe();

    // Tick timer to update the "searching for 0:23" counter
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _queue != null && _queue!.isSearching) {
        setState(() {}); // rebuild the wait timer display
      }
    });
  }

  // ── Handle state transitions from realtime ──────────────
  void _handleQueueState() {
    if (_queue == null) return;

    if (_queue!.isMatched && !_acceptDialogShown && _queue!.matchId != null) {
      _acceptDialogShown = true;
      _showAcceptDialog(_queue!.matchId!);
    }

    if (_queue!.isExpired) {
      _showSnack('No match found. Try again later.', isError: false);
      _channel?.unsubscribe();
      _channel = null;
      setState(() => _queue = null);
    }

    if (_queue!.isDeclined || _queue!.isCancelled) {
      _channel?.unsubscribe();
      _channel = null;
      setState(() => _queue = null);
    }
  }

  // ── Accept dialog ───────────────────────────────────────
  Future<void> _showAcceptDialog(String matchId) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AcceptMatchDialog(matchId: matchId),
    );

    _acceptDialogShown = false;

    if (!mounted) return;

    if (accepted == true) {
      // Accepted — now wait for either all-accept (redirect to veto)
      // or someone declining (back to search).
      // Poll the match status for up to 20s.
      _waitForMatchTransition(matchId);
    } else {
      // Declined (or closed by user)
      await _repo.declineMatch(userId: _userId, matchId: matchId);
      _showSnack('Match declined. 2 min penalty applied.', isError: true);
    }
  }

  Future<void> _waitForMatchTransition(String matchId) async {
    for (int i = 0; i < 30; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 1));

      try {
        final data = await SupabaseConfig.client
            .from('matches')
            .select('status')
            .eq('id', matchId)
            .single();
        final status = data['status'] as String;

        if (status == 'veto') {
          if (mounted) context.go('/match/$matchId');
          return;
        }
        if (status == 'cancelled') {
          if (mounted) {
            _showSnack('Match cancelled (someone declined).', isError: true);
          }
          return;
        }
      } catch (_) {}
    }
  }

  // ── Helpers ─────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.info,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GlassPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // ── Title ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_esports_rounded,
                        size: 28, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text('Quick Match',
                        style: AppTextStyles.h1.copyWith(fontSize: 32)),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Find opponents of your skill level instantly.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 36),

                // ── State machine ─────────────────────
                if (_queue != null && _queue!.isSearching)
                  SearchingState(
                    queue: _queue!,
                    onCancel: _cancelSearch,
                  )
                else if (_queue != null && _queue!.isMatched)
                  // Accept dialog shown as overlay; fallback UI here
                  const _MatchFoundPlaceholder()
                else
                  _buildSelectionUI(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Mode selector ────────────────────────
        Text('MODE',
            style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 1.0,
                fontSize: 11)),
        const SizedBox(height: 10),
        ModeSelector(
          selected: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),

        const SizedBox(height: 32),

        // ── Entry fee selector ───────────────────
        Text('ENTRY FEE',
            style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 1.0,
                fontSize: 11)),
        const SizedBox(height: 10),
        FeeSelector(
          selected: _entryFee,
          onChanged: (f) => setState(() => _entryFee = f),
        ),

        const SizedBox(height: 32),

        // ── Error ─────────────────────────────────
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerMuted,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.danger)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Find Match button ─────────────────────
        SizedBox(
          height: 56,
          child: AppButton(
            label: 'FIND MATCH',
            icon: Icons.play_arrow_rounded,
            isLoading: _isEnqueueing,
            onPressed: _isEnqueueing ? null : _findMatch,
          ),
        ),
      ],
    );
  }
}

/// Placeholder shown briefly when queue status is 'matched' but
/// accept dialog hasn't opened yet (race condition safety).
class _MatchFoundPlaceholder extends StatelessWidget {
  const _MatchFoundPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 48, color: AppColors.success),
          const SizedBox(height: 16),
          Text('Match found!', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text('Opening accept dialog...',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
