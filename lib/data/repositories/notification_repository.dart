import '../../config/supabase_config.dart';
import '../../core/errors/result.dart';
import '../models/notification_model.dart';

/// Notification operations.
class NotificationRepository {
  final _client = SupabaseConfig.client;

  Future<Result<List<NotificationModel>>> getNotifications(String userId, {int limit = 50}) async {
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return Success(data.map((j) => NotificationModel.fromJson(j)).toList());
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<int>> getUnreadCount(String userId) async {
    try {
      final data = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return Success(data.length);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> markAsRead(String notificationId) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('id', notificationId);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> markAllAsRead(String userId) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('user_id', userId).eq('is_read', false);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
