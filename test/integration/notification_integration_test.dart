import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/notifications/repositories/notification_repository.dart';
import 'package:twitter_clone/features/post/repositories/post_repository.dart';
import 'package:twitter_clone/features/profile/repositories/profile_repository.dart';

import 'supabase_test_client.dart';

void main() {
  group('NotificationRepository Integration Tests', () {
    group('getNotifications', () {
      test('returns notifications with actor data', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = NotificationRepository(client);

        final notifications = await repo.getNotifications();

        expect(notifications, isNotEmpty);
        for (final n in notifications) {
          expect(n.userId, aliceId);
          expect(n.actorUsername, isNotNull);
          expect(n.actorDisplayName, isNotNull);
          expect(
            ['like', 'repost', 'reply', 'follow'].contains(n.type),
            true,
          );
        }
      });

      test('only returns own notifications (RLS)', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = NotificationRepository(client);

        final notifications = await repo.getNotifications();
        for (final n in notifications) {
          expect(n.userId, aliceId);
        }
      });
    });

    group('markAsRead', () {
      test('marks single notification as read', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = NotificationRepository(client);

        final notifications = await repo.getNotifications();
        final unread = notifications.where((n) => !n.isRead).toList();

        if (unread.isNotEmpty) {
          final targetId = unread.first.id;
          await repo.markAsRead(targetId);

          final updated = await repo.getNotifications();
          final target = updated.firstWhere((n) => n.id == targetId);
          expect(target.isRead, true);

          // Restore: admin set back to unread
          final admin = createAdminClient();
          await admin
              .from('notifications')
              .update({'is_read': false}).eq('id', targetId);
        }
      });
    });

    group('markAllAsRead', () {
      test('marks all unread notifications as read', () async {
        // Use grace to avoid corrupting alice's notification state
        final client = await authenticatedClient('grace@demo.com');
        final repo = NotificationRepository(client);

        await repo.markAllAsRead();

        final notifications = await repo.getNotifications();
        final unread = notifications.where((n) => !n.isRead).toList();
        expect(unread, isEmpty);

        // Restore: admin set some back to unread
        final admin = createAdminClient();
        for (final n in notifications.take(3)) {
          await admin
              .from('notifications')
              .update({'is_read': false}).eq('id', n.id);
        }
      });
    });

    group('Notification Triggers', () {
      test('like triggers notification for post owner', () async {
        // Henry likes alice's post that he hasn't liked
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryPostRepo = PostRepository(henryClient);

        // Get alice's notification count before
        final aliceClient = await authenticatedClient('alice@demo.com');
        final aliceNotifRepo = NotificationRepository(aliceClient);
        final beforeNotifs = await aliceNotifRepo.getNotifications();
        final beforeCount = beforeNotifs.length;

        // Henry likes alice's post 1
        // First check if henry already liked it
        final admin = createAdminClient();
        final existingLike = await admin
            .from('likes')
            .select()
            .eq('user_id', henryId)
            .eq('post_id', alicePost1)
            .maybeSingle();

        if (existingLike == null) {
          await henryPostRepo.likePost(alicePost1);

          final afterNotifs = await aliceNotifRepo.getNotifications();
          final newNotif = afterNotifs.firstWhere(
            (n) =>
                n.actorId == henryId &&
                n.type == 'like' &&
                n.postId == alicePost1 &&
                !beforeNotifs.any((b) => b.id == n.id),
            orElse: () => throw Exception('Like notification not found'),
          );
          expect(newNotif.type, 'like');

          // Cleanup
          await henryPostRepo.unlikePost(alicePost1);
          await admin.from('notifications').delete().eq('id', newNotif.id);
        }
      });

      test('repost triggers notification for post owner', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryPostRepo = PostRepository(henryClient);

        final aliceClient = await authenticatedClient('alice@demo.com');
        final aliceNotifRepo = NotificationRepository(aliceClient);
        final beforeNotifs = await aliceNotifRepo.getNotifications();

        // Check if henry already reposted it
        final admin = createAdminClient();
        final existing = await admin
            .from('reposts')
            .select()
            .eq('user_id', henryId)
            .eq('post_id', alicePost1)
            .maybeSingle();

        if (existing == null) {
          await henryPostRepo.repost(alicePost1);

          final afterNotifs = await aliceNotifRepo.getNotifications();
          final newNotif = afterNotifs.firstWhere(
            (n) =>
                n.actorId == henryId &&
                n.type == 'repost' &&
                n.postId == alicePost1 &&
                !beforeNotifs.any((b) => b.id == n.id),
            orElse: () => throw Exception('Repost notification not found'),
          );
          expect(newNotif.type, 'repost');

          // Cleanup
          await henryPostRepo.removeRepost(alicePost1);
          await admin.from('notifications').delete().eq('id', newNotif.id);
        }
      });

      test('reply triggers notification for parent post owner', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryPostRepo = PostRepository(henryClient);

        final aliceClient = await authenticatedClient('alice@demo.com');
        final aliceNotifRepo = NotificationRepository(aliceClient);
        final beforeNotifs = await aliceNotifRepo.getNotifications();

        final reply = await henryPostRepo.createPost(
          content: '[TEST] reply for notification test',
          replyToId: alicePost1,
        );

        final afterNotifs = await aliceNotifRepo.getNotifications();
        final newNotif = afterNotifs.firstWhere(
          (n) =>
              n.actorId == henryId &&
              n.type == 'reply' &&
              !beforeNotifs.any((b) => b.id == n.id),
          orElse: () => throw Exception('Reply notification not found'),
        );
        expect(newNotif.type, 'reply');

        // Cleanup
        final admin = createAdminClient();
        await admin.from('notifications').delete().eq('id', newNotif.id);
        await cleanupPosts([reply.id]);
      });

      test('follow triggers notification', () async {
        final aliceClient = await authenticatedClient('alice@demo.com');
        final aliceProfileRepo = ProfileRepository(aliceClient);

        final frankClient = await authenticatedClient('frank@demo.com');
        final frankNotifRepo = NotificationRepository(frankClient);
        final beforeNotifs = await frankNotifRepo.getNotifications();

        // Alice follows frank
        await aliceProfileRepo.followUser(frankId);

        final afterNotifs = await frankNotifRepo.getNotifications();
        final newNotif = afterNotifs.firstWhere(
          (n) =>
              n.actorId == aliceId &&
              n.type == 'follow' &&
              !beforeNotifs.any((b) => b.id == n.id),
          orElse: () => throw Exception('Follow notification not found'),
        );
        expect(newNotif.type, 'follow');

        // Cleanup
        await aliceProfileRepo.unfollowUser(frankId);
        final admin = createAdminClient();
        await admin.from('notifications').delete().eq('id', newNotif.id);
      });

      test('self-like does NOT create notification', () async {
        final aliceClient = await authenticatedClient('alice@demo.com');
        final alicePostRepo = PostRepository(aliceClient);
        final aliceNotifRepo = NotificationRepository(aliceClient);

        final beforeNotifs = await aliceNotifRepo.getNotifications();

        // Alice likes her own post 1
        // First check she hasn't already liked it
        final admin = createAdminClient();
        final existing = await admin
            .from('likes')
            .select()
            .eq('user_id', aliceId)
            .eq('post_id', alicePost1)
            .maybeSingle();

        if (existing == null) {
          await alicePostRepo.likePost(alicePost1);

          final afterNotifs = await aliceNotifRepo.getNotifications();
          // Should not have a new self-like notification
          final selfLikeNotifs = afterNotifs.where(
            (n) =>
                n.actorId == aliceId &&
                n.type == 'like' &&
                n.postId == alicePost1 &&
                !beforeNotifs.any((b) => b.id == n.id),
          );
          expect(selfLikeNotifs, isEmpty,
              reason: 'Self-like should not generate notification');

          // Cleanup
          await alicePostRepo.unlikePost(alicePost1);
        }
      });
    });
  });
}
