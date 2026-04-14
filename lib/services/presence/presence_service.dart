import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../core/utils/logger.dart';
import '../../data/models/active_presence.dart';
import '../sound/sound_service.dart';

/// Global singleton that tracks the user's currently-active state
/// across the app: searching for match, in lobby, or in match.
///
/// Usage:
///   - Call `start(userId)` on login / dock mount
///   - Listen to `presenceStream` in the status bar widget
///   - Call `stop()` on logout / dock unmount
///
/// Subscribes to realtime on 5 tables:
///   - matchmaking_queue (filter: user_id)
///   - lobby_players     (filter: player_id)
///   - match_players     (filter: player_id)
///   - lobbies           (no filter — refresh on any change)
///   - matches           (no filter — refresh on any change)
///
/// The last two are unfiltered because Postgres realtime doesn't support
/// "id IN (...)" dynamic filters. We debounce refresh to avoid spam.
class PresenceService {
  PresenceService._();
  static final PresenceService _instance = PresenceService._();
  factory PresenceService() => _instance;

  final _client = SupabaseConfig.client;

  // ── Current state ────────────────────────────────────
  String? _userId;
  ActivePresence? _current;
  final _controller = StreamController<ActivePresence?>.broadcast();

  /// Set of match_ids the current user is participating in.
  /// Used to filter the unfiltered `matches` realtime channel.
  final Set<String> _myMatchIds = {};

  /// Set of lobby_ids the current user is a member of.
  final Set<String> _myLobbyIds = {};

  /// Listen to presence changes. Emits null when nothing active.
  Stream<ActivePresence?> get presenceStream => _controller.stream;

  ActivePresence? get current => _current;

  // ── Realtime channels ────────────────────────────────
  RealtimeChannel? _queueChannel;
  RealtimeChannel? _lobbyPlayerChannel;
  RealtimeChannel? _matchPlayerChannel;
  RealtimeChannel? _lobbiesChannel;
  RealtimeChannel? _matchesChannel;

  // ── Debounce ────────────────────────────────────────
  Timer? _refreshDebounce;

  // ── Match found sound dedup ──────────────────────────
  String? _lastMatchFoundQueueId;

  bool _started = false;

  // ═══════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════

  Future<void> start(String userId) async {
    if (_started && _userId == userId) return;
    if (_started) await stop();

    _userId = userId;
    _started = true;

    Log.d('PresenceService: starting for $userId');

    await _refresh();
    _subscribeAll();
  }

  Future<void> stop() async {
    Log.d('PresenceService: stopping');
    _refreshDebounce?.cancel();
    _queueChannel?.unsubscribe();
    _lobbyPlayerChannel?.unsubscribe();
    _matchPlayerChannel?.unsubscribe();
    _lobbiesChannel?.unsubscribe();
    _matchesChannel?.unsubscribe();
    _queueChannel = null;
    _lobbyPlayerChannel = null;
    _matchPlayerChannel = null;
    _lobbiesChannel = null;
    _matchesChannel = null;

    _myMatchIds.clear();
    _myLobbyIds.clear();
    _userId = null;
    _started = false;
    _lastMatchFoundQueueId = null;
    _setPresence(null);
  }

  Future<void> refresh() => _refresh();

  void dispose() {
    stop();
    _controller.close();
  }

  // ═══════════════════════════════════════════════════════
  // Debounced refresh — coalesces bursts of realtime events
  // ═══════════════════════════════════════════════════════

  void _scheduleRefresh({String reason = 'unknown'}) {
    Log.d('PresenceService: scheduleRefresh ($reason)');
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 150), () {
      _refresh();
    });
  }

  // ═══════════════════════════════════════════════════════
  // Core state computation
  // ═══════════════════════════════════════════════════════

  Future<void> _refresh() async {
    if (_userId == null) return;

    try {
      final candidates = <ActivePresence>[];

      // Load all three in parallel, also update _myMatchIds / _myLobbyIds caches
      final matchPresence = await _loadMatchPresence();
      if (matchPresence != null) candidates.add(matchPresence);

      final lobbyPresence = await _loadLobbyPresence();
      if (lobbyPresence != null) candidates.add(lobbyPresence);

      final queuePresence = await _loadQueuePresence();
      if (queuePresence != null) candidates.add(queuePresence);

      if (candidates.isEmpty) {
        _setPresence(null);
        return;
      }

      candidates.sort((a, b) => b.priority.compareTo(a.priority));
      _setPresence(candidates.first);
    } catch (e) {
      Log.e('PresenceService._refresh failed', error: e);
    }
  }

  Future<ActivePresence?> _loadMatchPresence() async {
    try {
      final row = await _client
          .from('match_players')
          .select('match_id')
          .eq('player_id', _userId!);

      if ((row as List).isEmpty) {
        _myMatchIds.clear();
        return null;
      }

      final matchIds = row.map((r) => r['match_id'] as String).toList();

      // Update cache of my match ids (used for realtime filtering)
      _myMatchIds
        ..clear()
        ..addAll(matchIds);

      final matchRow = await _client
          .from('matches')
          .select('id, mode, status, started_at, created_at')
          .inFilter('id', matchIds)
          .inFilter('status', ['veto', 'ready_check', 'live', 'accept_pending'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (matchRow == null) return null;

      final status = matchRow['status'] as String;
      final mode = matchRow['mode'] as String;
      final id = matchRow['id'] as String;

      final label = switch (status) {
        'live' => 'LIVE MATCH',
        'ready_check' => 'MATCH STARTING',
        'veto' => 'MAP VETO',
        'accept_pending' => 'ACCEPT MATCH',
        _ => 'IN MATCH',
      };

      final startedAt = matchRow['started_at'] != null
          ? DateTime.parse(matchRow['started_at'])
          : null;

      return ActivePresence(
        type: PresenceType.matchLive,
        targetId: id,
        targetRoute: '/match/$id',
        label: label,
        subtitle: mode,
        startedAt: startedAt,
      );
    } catch (e) {
      Log.e('_loadMatchPresence failed', error: e);
      return null;
    }
  }

  Future<ActivePresence?> _loadLobbyPresence() async {
    try {
      final row = await _client
          .from('lobby_players')
          .select('lobby_id')
          .eq('player_id', _userId!);

      if ((row as List).isEmpty) {
        _myLobbyIds.clear();
        return null;
      }

      final lobbyIds = row.map((r) => r['lobby_id'] as String).toList();

      _myLobbyIds
        ..clear()
        ..addAll(lobbyIds);

      final lobbyRow = await _client
          .from('lobbies')
          .select('id, name, mode, status')
          .inFilter('id', lobbyIds)
          .inFilter('status', ['open', 'in_match'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lobbyRow == null) return null;

      return ActivePresence(
        type: PresenceType.lobbyActive,
        targetId: lobbyRow['id'] as String,
        targetRoute: '/lobby/${lobbyRow['id']}',
        label: 'IN LOBBY',
        subtitle: '${lobbyRow['mode']} · ${lobbyRow['name']}',
      );
    } catch (e) {
      Log.e('_loadLobbyPresence failed', error: e);
      return null;
    }
  }

  Future<ActivePresence?> _loadQueuePresence() async {
    try {
      final row = await _client
          .from('matchmaking_queue')
          .select('id, mode, entry_fee, status, match_id, joined_at')
          .eq('user_id', _userId!)
          .inFilter('status', ['searching', 'matched'])
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;

      final status = row['status'] as String;
      final mode = row['mode'] as String;
      final fee = row['entry_fee'] as int;
      final joinedAt = DateTime.parse(row['joined_at']);
      final id = row['id'] as String;

      if (status == 'matched') {
        if (_lastMatchFoundQueueId != id) {
          _lastMatchFoundQueueId = id;
          Log.d('PresenceService: playing match_found sound');
          SoundService.playMatchFound();
        }

        return ActivePresence(
          type: PresenceType.matchFound,
          targetId: id,
          targetRoute: '/play',
          label: 'MATCH FOUND',
          subtitle: mode,
          startedAt: joinedAt,
        );
      }

      return ActivePresence(
        type: PresenceType.matchmaking,
        targetId: id,
        targetRoute: '/play',
        label: 'SEARCHING',
        subtitle: fee > 0 ? '$mode · $fee B' : '$mode · Free',
        startedAt: joinedAt,
      );
    } catch (e) {
      Log.e('_loadQueuePresence failed', error: e);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // Realtime subscriptions
  // ═══════════════════════════════════════════════════════

  void _subscribeAll() {
    if (_userId == null) return;

    // ── matchmaking_queue: filtered by user_id ───────────
    _queueChannel = _client
        .channel('presence_queue:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matchmaking_queue',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (_) => _scheduleRefresh(reason: 'queue'),
        )
        .subscribe();

    // ── lobby_players: filtered by player_id ─────────────
    _lobbyPlayerChannel = _client
        .channel('presence_lobby_players:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lobby_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_id',
            value: _userId!,
          ),
          callback: (_) => _scheduleRefresh(reason: 'lobby_players'),
        )
        .subscribe();

    // ── match_players: filtered by player_id ─────────────
    _matchPlayerChannel = _client
        .channel('presence_match_players:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'match_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_id',
            value: _userId!,
          ),
          callback: (_) => _scheduleRefresh(reason: 'match_players'),
        )
        .subscribe();

    // ── matches: unfiltered, local check against _myMatchIds ─
    _matchesChannel = _client
        .channel('presence_matches:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matches',
          callback: (payload) {
            final matchId = payload.newRecord['id'] as String?;
            if (matchId == null) return;
            // Only refresh if this match concerns us
            if (_myMatchIds.contains(matchId)) {
              _scheduleRefresh(reason: 'matches:$matchId');
            }
          },
        )
        .subscribe();

    // ── lobbies: unfiltered, local check against _myLobbyIds ─
    _lobbiesChannel = _client
        .channel('presence_lobbies:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'lobbies',
          callback: (payload) {
            final lobbyId = payload.newRecord['id'] as String?;
            if (lobbyId == null) return;
            if (_myLobbyIds.contains(lobbyId)) {
              _scheduleRefresh(reason: 'lobbies:$lobbyId');
            }
          },
        )
        .subscribe();

    Log.d('PresenceService: subscribed to 5 channels');
  }

  // ═══════════════════════════════════════════════════════
  // State emission
  // ═══════════════════════════════════════════════════════

  void _setPresence(ActivePresence? presence) {
    if (_current == presence) return;
    _current = presence;
    _controller.add(presence);
    Log.d('PresenceService: emit ${presence?.label ?? "null"}');
  }
}
