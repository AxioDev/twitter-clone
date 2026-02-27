import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/supabase_client.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final sb.SupabaseClient _client;

  NotificationRepository([sb.SupabaseClient? client])
      : _client = client ?? supabase;

  Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client
          .from('notifications')
          .select('*, actor:users!notifications_actor_id_fkey(username, display_name, avatar_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => notificationFromRow(row))
          .toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }
}
