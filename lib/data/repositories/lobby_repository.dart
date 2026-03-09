import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/lobby_model.dart';

/// Lobby CRUD and player management.
class LobbyRepository {
  final _client = SupabaseConfig.client;

  Future<Result<List<LobbyModel>>> getOpenLobbies(
      {String? mode, String? region}) async {
    try {
      var query = _client.from('lobbies').select().eq('status', 'open');
      if (mode != null) query = query.eq('mode', mode);
      if (region != null) query = query.eq('region', region);
      final data = await query.order('created_at', ascending: false);
      return Success(data.map((j) => LobbyModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<LobbyModel>> getLobby(String lobbyId) async {
    try {
      final data =
          await _client.from('lobbies').select().eq('id', lobbyId).single();
      return Success(LobbyModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<LobbyModel>> createLobby(Map<String, dynamic> lobbyData) async {
    try {
      final data =
          await _client.from('lobbies').insert(lobbyData).select().single();
      return Success(LobbyModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> joinLobby(String lobbyId, String playerId,
      {String? team}) async {
    try {
      // Check if already in lobby
      final existing = await _client
          .from('lobby_players')
          .select('id')
          .eq('lobby_id', lobbyId)
          .eq('player_id', playerId)
          .maybeSingle();

      if (existing != null) {
        return const Success(null);
      }

      // Auto-assign team if not specified
      if (team == null) {
        final lobby = await _client
            .from('lobbies')
            .select('max_players')
            .eq('id', lobbyId)
            .single();

        final playersPerTeam = (lobby['max_players'] as int) ~/ 2;

        final teamACounts = await _client
            .from('lobby_players')
            .select('id')
            .eq('lobby_id', lobbyId)
            .eq('team', 'team_a');

        team = (teamACounts.length < playersPerTeam) ? 'team_a' : 'team_b';
      }

      await _client.from('lobby_players').insert({
        'lobby_id': lobbyId,
        'player_id': playerId,
        'team': team,
      });
      return const Success(null);
    } catch (e) {
      if (e.toString().contains('23505')) {
        return const Success(null);
      }
      return Failure(e.toString());
    }
  }

  Future<Result<void>> leaveLobby(String lobbyId, String playerId) async {
    try {
      await _client
          .from('lobby_players')
          .delete()
          .eq('lobby_id', lobbyId)
          .eq('player_id', playerId);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> setReady(
      String lobbyId, String playerId, bool ready) async {
    try {
      await _client
          .from('lobby_players')
          .update({'is_ready': ready})
          .eq('lobby_id', lobbyId)
          .eq('player_id', playerId);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
