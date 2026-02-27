import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/utils/supabase_client.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

part 'notification_provider.g.dart';

@riverpod
NotificationRepository notificationRepository(Ref ref) =>
    NotificationRepository();

@riverpod
class NotificationsNotifier extends _$NotificationsNotifier {
  @override
  Future<List<NotificationModel>> build() async {
    final notifications =
        await ref.watch(notificationRepositoryProvider).getNotifications();

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      final channel = supabase
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: sb.PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: sb.PostgresChangeFilter(
              type: sb.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();

      ref.onDispose(() => supabase.removeChannel(channel));
    }

    return notifications;
  }

  Future<void> markAsRead(String notificationId) async {
    await ref.read(notificationRepositoryProvider).markAsRead(notificationId);
    ref.invalidateSelf();
  }

  Future<void> markAllAsRead() async {
    await ref.read(notificationRepositoryProvider).markAllAsRead();
    ref.invalidateSelf();
  }
}

@riverpod
int unreadNotificationCount(Ref ref) {
  final notifs = ref.watch(notificationsProvider).value ?? [];
  return notifs.where((n) => !n.isRead).length;
}
