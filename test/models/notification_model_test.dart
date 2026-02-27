import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/notifications/models/notification_model.dart';

void main() {
  group('NotificationModel', () {
    test('fromJson creates correct model', () {
      final json = {
        'id': 'notif-1',
        'user_id': 'user-1',
        'actor_id': 'user-2',
        'type': 'like',
        'post_id': 'post-1',
        'is_read': false,
        'created_at': '2025-06-01T13:00:00.000Z',
        'actor_username': 'other',
        'actor_display_name': 'Other User',
        'actor_avatar_url': null,
      };

      final notif = NotificationModel.fromJson(json);

      expect(notif.id, 'notif-1');
      expect(notif.type, 'like');
      expect(notif.isRead, false);
      expect(notif.actorUsername, 'other');
    });

    test('notificationFromRow parses nested actor', () {
      final row = {
        'id': 'notif-1',
        'user_id': 'user-1',
        'actor_id': 'user-2',
        'type': 'follow',
        'post_id': null,
        'is_read': true,
        'created_at': '2025-06-01T13:00:00.000Z',
        'actor': {
          'username': 'follower',
          'display_name': 'Follower User',
          'avatar_url': 'https://example.com/pic.jpg',
        },
      };

      final notif = notificationFromRow(row);

      expect(notif.type, 'follow');
      expect(notif.isRead, true);
      expect(notif.actorUsername, 'follower');
      expect(notif.actorDisplayName, 'Follower User');
      expect(notif.actorAvatarUrl, 'https://example.com/pic.jpg');
      expect(notif.postId, isNull);
    });

    test('notificationFromRow handles null actor', () {
      final row = {
        'id': 'notif-2',
        'user_id': 'user-1',
        'actor_id': 'user-3',
        'type': 'like',
        'post_id': 'post-1',
        'is_read': false,
        'created_at': '2025-06-01T14:00:00.000Z',
        'actor': null,
      };

      final notif = notificationFromRow(row);

      expect(notif.actorUsername, '');
      expect(notif.actorDisplayName, '');
      expect(notif.actorAvatarUrl, isNull);
    });
  });
}
