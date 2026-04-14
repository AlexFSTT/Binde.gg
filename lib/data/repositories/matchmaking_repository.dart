import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/matchmaking_queue_model.dart';

/// Matchmaking queue operations.
class MatchmakingRepository {
  final _client = SupabaseConfig.client;

  /// Enqueue the user for matchmaking.
  /// Returns the new queue_id or a typed error.
  Future<Result<String>> enqueue({
    required String userId,
    required String mode,
    required int entryFee,
  }) async {
    try {
      final result = await _client.rpc('fn_enqueue_matchmaking', params: {
        'p_user_id': userId,
        'p_mode': mode,
        'p_entry_fee': entryFee,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] == true) {
        return Success(data['queue_id'] as String);
      }

      return Failure(_translateError(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Cancel the user's active search.
  Future<Result<void>> cancel(String userId) async {
    try {
      final result = await _client.rpc('fn_cancel_matchmaking', params: {
        'p_user_id': userId,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] == true) return const Success(null);

      return Failure(data['error'] as String? ?? 'Failed to cancel');
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Accept a pending match.
  Future<Result<Map<String, dynamic>>> acceptMatch({
    required String userId,
    required String matchId,
  }) async {
    try {
      final result = await _client.rpc('fn_accept_match', params: {
        'p_user_id': userId,
        'p_match_id': matchId,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] == true) return Success(data);

      return Failure(data['error'] as String? ?? 'Failed to accept');
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Decline a pending match (penalty applies).
  Future<Result<int>> declineMatch({
    required String userId,
    required String matchId,
  }) async {
    try {
      final result = await _client.rpc('fn_decline_match', params: {
        'p_user_id': userId,
        'p_match_id': matchId,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] == true) {
        return Success(data['penalty_minutes'] as int? ?? 2);
      }

      return Failure(data['error'] as String? ?? 'Failed to decline');
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Fetch the user's current active queue entry (searching or matched).
  Future<Result<MatchmakingQueueModel?>> getActiveQueue(String userId) async {
    try {
      final data = await _client
          .from('matchmaking_queue')
          .select()
          .eq('user_id', userId)
          .inFilter('status', ['searching', 'matched'])
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return const Success(null);
      return Success(MatchmakingQueueModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // ── Error translation ─────────────────────────────────────

  String _translateError(Map<String, dynamic> data) {
    final err = data['error'] as String?;
    switch (err) {
      case 'INVALID_MODE':
        return 'Invalid match mode.';
      case 'INVALID_ENTRY_FEE':
        return 'Invalid entry fee. Choose a preset value.';
      case 'STEAM_REQUIRED':
        return 'Link your Steam account before playing.';
      case 'VAC_BANNED':
        return 'VAC-banned accounts cannot play.';
      case 'PENALTY_ACTIVE':
        final until = data['penalty_until'] as String?;
        if (until != null) {
          final dt = DateTime.parse(until);
          final secs = dt.difference(DateTime.now()).inSeconds;
          return 'Matchmaking penalty active. Try again in ${secs}s.';
        }
        return 'Matchmaking penalty active.';
      case 'IN_ACTIVE_LOBBY':
        return 'You are already in a lobby. Leave it first.';
      case 'IN_ACTIVE_MATCH':
        return 'You are already in a match.';
      case 'ALREADY_IN_QUEUE':
        return 'You are already searching for a match.';
      case 'INSUFFICIENT_BCOINS':
        final balance = data['balance'];
        final required = data['required'];
        return 'Not enough Bcoins. You have $balance, need $required.';
      case 'PROFILE_NOT_FOUND':
        return 'Profile not found.';
      default:
        return err ?? 'Matchmaking failed.';
    }
  }
}
