import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/lobby_model.dart';

/// Lobby CRUD and player management.
class LobbyRepository {
  final _client = SupabaseConfig.client;

  /// Get all open lobbies (for browsing).
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

  /// Get lobbies where the user is currently an active participant.
  /// Active = lobby status is 'open' or 'in_match'.
  Future<Result<List<LobbyModel>>> getMyActiveLobbies(String userId) async {
    try {
      // First get lobby IDs where this user is a player
      final playerRows = await _client
          .from('lobby_players')
          .select('lobby_id')
          .eq('player_id', userId);

      if (playerRows.isEmpty) return const Success([]);

      final lobbyIds =
          playerRows.map((r) => r['lobby_id'] as String).toList();

      // Then get those lobbies that are active
      final data = await _client
          .from('lobbies')
          .select()
          .inFilter('id', lobbyIds)
          .inFilter('status', ['open', 'in_match'])
          .order('created_at', ascending: false);

      return Success(data.map((j) => LobbyModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Get user's past lobbies (finished/cancelled).
  Future<Result<List<LobbyModel>>> getMyPastLobbies(String userId,
      {int limit = 20}) async {
    try {
      final playerRows = await _client
          .from('lobby_players')
          .select('lobby_id')
          .eq('player_id', userId);

      if (playerRows.isEmpty) return const Success([]);

      final lobbyIds =
          playerRows.map((r) => r['lobby_id'] as String).toList();

      final data = await _client
          .from('lobbies')
          .select()
          .inFilter('id', lobbyIds)
          .inFilter('status', ['finished', 'cancelled', 'closed'])
          .order('created_at', ascending: false)
          .limit(limit);

      return Success(data.map((j) => LobbyModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Check if the user is currently in any active lobby.
  /// Returns the lobby if found, null otherwise.
  Future<LobbyModel?> getActiveLobbyForUser(String userId) async {
    try {
      final playerRows = await _client
          .from('lobby_players')
          .select('lobby_id')
          .eq('player_id', userId);

      if (playerRows.isEmpty) return null;

      final lobbyIds =
          playerRows.map((r) => r['lobby_id'] as String).toList();

      final data = await _client
          .from('lobbies')
          .select()
          .inFilter('id', lobbyIds)
          .inFilter('status', ['open', 'in_match'])
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return LobbyModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Check if the user is in an ongoing match (live or ready_check).
  /// Returns the match_id if found, null otherwise.
  Future<String?> getActiveMatchForUser(String userId) async {
    try {
      final row = await _client
          .from('match_players')
          .select('match_id, match:matches!inner(id, status)')
          .eq('player_id', userId)
          .inFilter('match.status', ['live', 'ready_check'])
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final match = row['match'] as Map<String, dynamic>?;
      return match?['id'] as String?;
    } catch (_) {
      // Fallback: query separately if join fails
      try {
        final playerRows = await _client
            .from('match_players')
            .select('match_id')
            .eq('player_id', userId);

        if (playerRows.isEmpty) return null;

        final matchIds =
            playerRows.map((r) => r['match_id'] as String).toList();

        final matchRow = await _client
            .from('matches')
            .select('id')
            .inFilter('id', matchIds)
            .inFilter('status', ['live', 'ready_check'])
            .limit(1)
            .maybeSingle();

        return matchRow?['id'] as String?;
      } catch (_) {
        return null;
      }
    }
  }

  /// Pre-check: fails if user is in active lobby OR active match.
  Future<String?> _checkUserLocked(String userId) async {
    // Check Steam linked
    try {
      final profile = await _client
          .from('profiles')
          .select('steam_id')
          .eq('id', userId)
          .single();
      if (profile['steam_id'] == null) {
        return 'You must link your Steam account before playing. Go to Settings to connect Steam.';
      }
    } catch (_) {}

    // Check active match first (higher priority)
    final activeMatchId = await getActiveMatchForUser(userId);
    if (activeMatchId != null) {
      return 'You are in an ongoing match. Finish it before joining a lobby.';
    }

    // Check active lobby
    final activeLobby = await getActiveLobbyForUser(userId);
    if (activeLobby != null) {
      return 'You are already in an active lobby ("${activeLobby.name}"). Leave it first.';
    }

    return null; // Not locked
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

  /// Create a lobby — fails if user is in active lobby or match.
  Future<Result<LobbyModel>> createLobby(Map<String, dynamic> lobbyData) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        final lockMsg = await _checkUserLocked(userId);
        if (lockMsg != null) return Failure(lockMsg);
      }

      final data =
          await _client.from('lobbies').insert(lobbyData).select().single();
      return Success(LobbyModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Join a lobby — fails if user is in another active lobby or match.
  Future<Result<void>> joinLobby(String lobbyId, String playerId,
      {String? team}) async {
    try {
      // Check if already in THIS lobby
      final existing = await _client
          .from('lobby_players')
          .select('id')
          .eq('lobby_id', lobbyId)
          .eq('player_id', playerId)
          .maybeSingle();

      if (existing != null) {
        return const Success(null);
      }

      // Check if locked (active match or another lobby)
      final activeMatchId = await getActiveMatchForUser(playerId);
      if (activeMatchId != null) {
        return const Failure(
            'You are in an ongoing match. Finish it before joining a lobby.');
      }

      final activeLobby = await getActiveLobbyForUser(playerId);
      if (activeLobby != null && activeLobby.id != lobbyId) {
        return Failure(
            'You are already in an active lobby ("${activeLobby.name}"). Leave it first before joining another.');
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
