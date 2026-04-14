import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/lobby_model.dart';

/// Lobby CRUD and player management.
///
/// v2 (security hardening): createLobby and setReady now go through
/// SECURITY DEFINER RPCs so clients cannot bypass validation.
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
  Future<Result<List<LobbyModel>>> getMyActiveLobbies(String userId) async {
    try {
      final playerRows = await _client
          .from('lobby_players')
          .select('lobby_id')
          .eq('player_id', userId);

      if (playerRows.isEmpty) return const Success([]);

      final lobbyIds = playerRows.map((r) => r['lobby_id'] as String).toList();

      final data = await _client
          .from('lobbies')
          .select()
          .inFilter('id', lobbyIds)
          .inFilter('status', ['open', 'in_match']).order('created_at',
              ascending: false);

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

      final lobbyIds = playerRows.map((r) => r['lobby_id'] as String).toList();

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
  Future<LobbyModel?> getActiveLobbyForUser(String userId) async {
    try {
      final playerRows = await _client
          .from('lobby_players')
          .select('lobby_id')
          .eq('player_id', userId);

      if (playerRows.isEmpty) return null;

      final lobbyIds = playerRows.map((r) => r['lobby_id'] as String).toList();

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

  Future<Result<LobbyModel>> getLobby(String lobbyId) async {
    try {
      final data =
          await _client.from('lobbies').select().eq('id', lobbyId).single();
      return Success(LobbyModel.fromJson(data));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Create a lobby via fn_create_lobby RPC.
  /// Server validates everything: name length, mode, region, entry fee,
  /// elo range, Steam linked, not VAC banned, not already in active lobby/match.
  Future<Result<LobbyModel>> createLobby({
    required String name,
    required String mode,
    required String region,
    required int entryFee,
    required int maxPlayers,
    bool isPrivate = false,
    int minElo = 0,
    int maxElo = 15000,
  }) async {
    try {
      final result = await _client.rpc('fn_create_lobby', params: {
        'p_name': name,
        'p_mode': mode,
        'p_region': region,
        'p_entry_fee': entryFee,
        'p_max_players': maxPlayers,
        'p_is_private': isPrivate,
        'p_min_elo': minElo,
        'p_max_elo': maxElo,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] != true) {
        return Failure(_translateCreateError(data));
      }

      final lobbyId = data['lobby_id'] as String;
      final lobbyData =
          await _client.from('lobbies').select().eq('id', lobbyId).single();
      return Success(LobbyModel.fromJson(lobbyData));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  String _translateCreateError(Map<String, dynamic> data) {
    final err = data['error'] as String?;
    switch (err) {
      case 'UNAUTHORIZED':
        return 'Please log in to create a lobby.';
      case 'INVALID_NAME':
        return 'Lobby name must be 3–50 characters.';
      case 'INVALID_MODE':
        return 'Invalid match mode.';
      case 'INVALID_REGION':
        return 'Invalid region.';
      case 'INVALID_ENTRY_FEE':
        return 'Invalid entry fee. Must be 0–10000 Bcoins.';
      case 'INVALID_MAX_PLAYERS':
        return 'Invalid player count.';
      case 'MODE_PLAYER_MISMATCH':
        return 'Player count does not match the selected mode.';
      case 'INVALID_ELO_RANGE':
        return 'Invalid ELO range.';
      case 'STEAM_REQUIRED':
        return 'Link your Steam account to create lobbies.';
      case 'VAC_BANNED':
        return 'VAC-banned accounts cannot create lobbies.';
      case 'ACCOUNT_BANNED':
        return 'Your account is currently banned.';
      case 'INSUFFICIENT_BCOINS':
        final balance = data['balance'];
        final required = data['required'];
        return 'Not enough Bcoins. You have $balance, need $required.';
      case 'IN_ACTIVE_LOBBY':
        return 'You are already in an active lobby.';
      case 'IN_ACTIVE_MATCH':
        return 'You are already in an active match.';
      case 'PROFILE_NOT_FOUND':
        return 'Profile not found.';
      default:
        return err ?? 'Failed to create lobby.';
    }
  }

  /// Join a lobby — atomically deducts Bcoins via fn_join_paid_lobby RPC.
  Future<Result<void>> joinLobby(String lobbyId, String playerId,
      {String? team}) async {
    try {
      final existing = await _client
          .from('lobby_players')
          .select('id')
          .eq('lobby_id', lobbyId)
          .eq('player_id', playerId)
          .maybeSingle();

      if (existing != null) return const Success(null);

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

      final result = await _client.rpc('fn_join_paid_lobby', params: {
        'p_lobby_id': lobbyId,
        'p_player_id': playerId,
        'p_team': team,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] == true) return const Success(null);

      final err = data['error'] as String?;
      if (err == 'INSUFFICIENT_BCOINS') {
        final balance = data['balance'];
        final required = data['required'];
        return Failure(
            'Insufficient Bcoins. You have $balance B, need $required B to join.');
      }
      if (err == 'LOBBY_NOT_OPEN') {
        return const Failure('This lobby is no longer open.');
      }
      if (err == 'LOBBY_NOT_FOUND') {
        return const Failure('Lobby not found.');
      }
      return Failure(err ?? 'Failed to join lobby');
    } catch (e) {
      if (e.toString().contains('23505')) return const Success(null);
      return Failure(e.toString());
    }
  }

  /// Leave a lobby — atomically refunds Bcoins via fn_leave_paid_lobby RPC.
  Future<Result<void>> leaveLobby(String lobbyId, String playerId) async {
    try {
      final result = await _client.rpc('fn_leave_paid_lobby', params: {
        'p_lobby_id': lobbyId,
        'p_player_id': playerId,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] == true) return const Success(null);

      final err = data['error'] as String?;
      if (err == 'MATCH_ALREADY_STARTED') {
        return const Failure('Cannot leave — match has already started.');
      }
      return Failure(err ?? 'Failed to leave lobby');
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Set ready state via fn_set_ready RPC.
  /// Server validates that lobby is 'open' and user is in it.
  Future<Result<void>> setReady(
      String lobbyId, String playerId, bool ready) async {
    try {
      final result = await _client.rpc('fn_set_ready', params: {
        'p_lobby_id': lobbyId,
        'p_ready': ready,
      });

      final data = result as Map<String, dynamic>;
      if (data['success'] == true) return const Success(null);

      final err = data['error'] as String?;
      switch (err) {
        case 'LOBBY_NOT_FOUND':
          return const Failure('Lobby not found.');
        case 'LOBBY_NOT_OPEN':
          return const Failure('Lobby is no longer open.');
        case 'NOT_IN_LOBBY':
          return const Failure('You are not in this lobby.');
        default:
          return Failure(err ?? 'Failed to toggle ready.');
      }
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
