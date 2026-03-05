import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/match_model.dart';
import '../models/match_player_model.dart';

/// Match data operations.
class MatchRepository {
  final _client = SupabaseConfig.client;

  Future<Result<MatchModel>> getMatch(String matchId) async {
    try {
      final data = await _client.from('matches').select().eq('id', matchId).single();
      return Success(MatchModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<MatchPlayerModel>>> getMatchPlayers(String matchId) async {
    try {
      final data = await _client.from('match_players').select().eq('match_id', matchId);
      return Success(data.map((j) => MatchPlayerModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<MatchModel>>> getPlayerMatches(String playerId, {int limit = 20, int offset = 0}) async {
    try {
      final matchIds = await _client
          .from('match_players')
          .select('match_id')
          .eq('player_id', playerId)
          .order('joined_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (matchIds.isEmpty) return const Success([]);

      final ids = matchIds.map((r) => r['match_id'] as String).toList();
      final data = await _client.from('matches').select().inFilter('id', ids).order('created_at', ascending: false);
      return Success(data.map((j) => MatchModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
