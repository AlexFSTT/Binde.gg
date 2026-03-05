import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../core/utils/logger.dart';

/// Centralized Supabase Realtime subscription manager.
class RealtimeService {
  final _client = SupabaseConfig.client;
  final Map<String, RealtimeChannel> _channels = {};

  /// Subscribe to lobby changes (players joining/leaving/ready)
  RealtimeChannel subscribeLobby({
    required String lobbyId,
    void Function(Map<String, dynamic>)? onPlayerJoin,
    void Function(Map<String, dynamic>)? onPlayerLeave,
    void Function(Map<String, dynamic>)? onPlayerUpdate,
    void Function(Map<String, dynamic>)? onLobbyUpdate,
  }) {
    final channelName = 'lobby:$lobbyId';
    _unsubscribe(channelName);

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lobby_players',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'lobby_id', value: lobbyId),
          callback: (payload) {
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                onPlayerJoin?.call(payload.newRecord);
              case PostgresChangeEvent.delete:
                onPlayerLeave?.call(payload.oldRecord);
              case PostgresChangeEvent.update:
                onPlayerUpdate?.call(payload.newRecord);
              default:
                break;
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'lobbies',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: lobbyId),
          callback: (payload) => onLobbyUpdate?.call(payload.newRecord),
        )
        .subscribe();

    _channels[channelName] = channel;
    Log.d('Subscribed to $channelName');
    return channel;
  }

  /// Subscribe to match updates (scores, status, vetoes)
  RealtimeChannel subscribeMatch({
    required String matchId,
    void Function(Map<String, dynamic>)? onMatchUpdate,
    void Function(Map<String, dynamic>)? onVeto,
  }) {
    final channelName = 'match:$matchId';
    _unsubscribe(channelName);

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: matchId),
          callback: (payload) => onMatchUpdate?.call(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'map_vetoes',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'match_id', value: matchId),
          callback: (payload) => onVeto?.call(payload.newRecord),
        )
        .subscribe();

    _channels[channelName] = channel;
    Log.d('Subscribed to $channelName');
    return channel;
  }

  /// Subscribe to user notifications
  RealtimeChannel subscribeNotifications({
    required String userId,
    required void Function(Map<String, dynamic>) onNotification,
  }) {
    final channelName = 'notifications:$userId';
    _unsubscribe(channelName);

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) => onNotification(payload.newRecord),
        )
        .subscribe();

    _channels[channelName] = channel;
    Log.d('Subscribed to $channelName');
    return channel;
  }

  /// Unsubscribe from a specific channel
  void unsubscribe(String channelName) => _unsubscribe(channelName);

  /// Unsubscribe all channels (call on logout)
  void disposeAll() {
    for (final entry in _channels.entries) {
      _client.removeChannel(entry.value);
      Log.d('Unsubscribed from ${entry.key}');
    }
    _channels.clear();
  }

  void _unsubscribe(String name) {
    if (_channels.containsKey(name)) {
      _client.removeChannel(_channels[name]!);
      _channels.remove(name);
    }
  }
}
