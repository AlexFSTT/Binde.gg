import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/profile_model.dart';

class FriendsRepository {
  final _client = SupabaseConfig.client;
  String get _userId => SupabaseConfig.auth.currentUser!.id;

  // ── Friends List ───────────────────────────────────

  Future<Result<List<ProfileModel>>> getFriends() async {
    try {
      // Get friendship rows where I'm user_a or user_b
      final rows = await _client
          .from('friendships')
          .select('user_a, user_b')
          .or('user_a.eq.$_userId,user_b.eq.$_userId');

      if ((rows as List).isEmpty) return const Success([]);

      // Extract friend IDs
      final friendIds = rows.map((r) {
        final a = r['user_a'] as String;
        final b = r['user_b'] as String;
        return a == _userId ? b : a;
      }).toSet().toList();

      final profiles = await _client
          .from('profiles')
          .select()
          .inFilter('id', friendIds)
          .order('username');

      return Success(profiles.map((p) => ProfileModel.fromJson(p)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // ── Friend Requests ────────────────────────────────

  Future<Result<List<Map<String, dynamic>>>> getIncomingRequests() async {
    try {
      final rows = await _client
          .from('friend_requests')
          .select('*, sender:profiles!friend_requests_sender_id_fkey(id, username, steam_avatar_url, elo_rating)')
          .eq('receiver_id', _userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return Success(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<Map<String, dynamic>>>> getOutgoingRequests() async {
    try {
      final rows = await _client
          .from('friend_requests')
          .select('*, receiver:profiles!friend_requests_receiver_id_fkey(id, username, steam_avatar_url, elo_rating)')
          .eq('sender_id', _userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return Success(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> sendFriendRequest(String receiverId) async {
    try {
      // Check not already friends
      final existing = await _isFriendWith(receiverId);
      if (existing) return const Failure('Already friends');

      // Check not already pending
      final pending = await _client
          .from('friend_requests')
          .select('id')
          .or('and(sender_id.eq.$_userId,receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.$_userId)')
          .eq('status', 'pending')
          .maybeSingle();

      if (pending != null) return const Failure('Request already pending');

      await _client.from('friend_requests').insert({
        'sender_id': _userId,
        'receiver_id': receiverId,
      });
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> acceptRequest(String requestId) async {
    try {
      final result = await _client.rpc('fn_accept_friend_request', params: {
        'p_request_id': requestId,
      });
      final data = result as Map<String, dynamic>;
      if (data['success'] == true) return const Success(null);
      return Failure(data['error'] ?? 'Failed');
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> declineRequest(String requestId) async {
    try {
      await _client.from('friend_requests')
          .update({'status': 'declined', 'responded_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', requestId)
          .eq('receiver_id', _userId);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> cancelRequest(String requestId) async {
    try {
      await _client.from('friend_requests')
          .delete()
          .eq('id', requestId)
          .eq('sender_id', _userId);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // ── Unfriend ───────────────────────────────────────

  Future<Result<void>> removeFriend(String friendId) async {
    try {
      final a = _userId.compareTo(friendId) < 0 ? _userId : friendId;
      final b = _userId.compareTo(friendId) < 0 ? friendId : _userId;
      await _client.from('friendships')
          .delete()
          .eq('user_a', a)
          .eq('user_b', b);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // ── Block ──────────────────────────────────────────

  Future<Result<List<ProfileModel>>> getBlockedUsers() async {
    try {
      final rows = await _client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', _userId);

      if ((rows as List).isEmpty) return const Success([]);

      final ids = rows.map((r) => r['blocked_id'] as String).toList();
      final profiles = await _client.from('profiles').select().inFilter('id', ids);
      return Success(profiles.map((p) => ProfileModel.fromJson(p)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> blockUser(String userId, {String? reason}) async {
    try {
      await _client.from('blocked_users').upsert({
        'blocker_id': _userId,
        'blocked_id': userId,
        'reason': reason,
      });
      // Also remove friendship if exists
      await removeFriend(userId);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> unblockUser(String userId) async {
    try {
      await _client.from('blocked_users')
          .delete()
          .eq('blocker_id', _userId)
          .eq('blocked_id', userId);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // ── Report ─────────────────────────────────────────

  Future<Result<void>> reportUser(String userId, String reason, {String? description}) async {
    try {
      await _client.from('user_reports').insert({
        'reporter_id': _userId,
        'reported_id': userId,
        'reason': reason,
        'description': description,
      });
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // ── Search ─────────────────────────────────────────

  Future<Result<List<ProfileModel>>> searchUsers(String query) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,first_name.ilike.%$query%,last_name.ilike.%$query%,steam_username.ilike.%$query%')
          .neq('id', _userId)
          .limit(20);
      return Success(data.map((p) => ProfileModel.fromJson(p)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  // ── Helpers ────────────────────────────────────────

  Future<bool> _isFriendWith(String otherId) async {
    final a = _userId.compareTo(otherId) < 0 ? _userId : otherId;
    final b = _userId.compareTo(otherId) < 0 ? otherId : _userId;
    final row = await _client.from('friendships')
        .select('id').eq('user_a', a).eq('user_b', b).maybeSingle();
    return row != null;
  }

  Future<String?> getFriendshipStatus(String otherId) async {
    // Check friendship
    if (await _isFriendWith(otherId)) return 'friends';
    // Check pending request
    final pending = await _client.from('friend_requests')
        .select('id, sender_id')
        .or('and(sender_id.eq.$_userId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$_userId)')
        .eq('status', 'pending')
        .maybeSingle();
    if (pending != null) {
      return pending['sender_id'] == _userId ? 'request_sent' : 'request_received';
    }
    // Check blocked
    final blocked = await _client.from('blocked_users')
        .select('id').eq('blocker_id', _userId).eq('blocked_id', otherId).maybeSingle();
    if (blocked != null) return 'blocked';
    return null;
  }

  Future<int> getPendingRequestCount() async {
    try {
      final rows = await _client.from('friend_requests')
          .select('id').eq('receiver_id', _userId).eq('status', 'pending');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }
}
