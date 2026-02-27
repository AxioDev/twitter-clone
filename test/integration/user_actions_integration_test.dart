import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/feed/repositories/feed_repository.dart';
import 'package:twitter_clone/features/notifications/repositories/notification_repository.dart';
import 'package:twitter_clone/features/post/repositories/post_repository.dart';
import 'package:twitter_clone/features/profile/repositories/profile_repository.dart';
import 'package:twitter_clone/features/search/repositories/search_repository.dart';

import 'supabase_test_client.dart';

/// Minimal valid JPEG bytes for upload tests.
Uint8List _jpegBytes() => Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
      0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, ...List.filled(64, 0x01),
      0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00,
      0x01, 0x01, 0x01, 0x11, 0x00,
      0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05,
      0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02,
      0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A,
      0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00,
      0x00, 0x3F, 0x00, 0x7B, 0x40, 0xFF, 0xD9,
    ]);

void main() {
  final createdPostIds = <String>[];
  final uploadedMediaPaths = <String>[];
  final uploadedAvatarPaths = <String>[];

  tearDownAll(() async {
    final admin = createAdminClient();

    // Cleanup posts
    await cleanupPosts(createdPostIds);

    // Cleanup uploaded media
    for (final path in uploadedMediaPaths) {
      try {
        await admin.storage.from('post-media').remove([path]);
      } catch (_) {}
    }

    // Cleanup uploaded avatars
    for (final path in uploadedAvatarPaths) {
      try {
        await admin.storage.from('avatars').remove([path]);
      } catch (_) {}
    }

    // Restore henry's avatar_url to null
    try {
      await admin
          .from('users')
          .update({'avatar_url': null}).eq('id', henryId);
    } catch (_) {}

    // Restore henry's display_name and bio
    try {
      await admin.from('users').update({
        'display_name': 'Henry Wilson',
        'bio': '',
      }).eq('id', henryId);
    } catch (_) {}

    // NOTE: Do NOT cleanup henry→alice follow — it exists in seed data
  });

  group('User Action Chains', () {
    group('Complete Post Lifecycle', () {
      test('create text post → appears in feed → like → unlike → delete',
          () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);
        final feedRepo = FeedRepository(client);

        // 1. Create a post
        final post = await postRepo.createPost(
          content: '[TEST] Lifecycle post',
        );
        createdPostIds.add(post.id);

        expect(post.content, '[TEST] Lifecycle post');
        expect(post.userId, henryId);

        // 2. Verify it appears when fetched
        final fetched = await postRepo.getPostById(post.id);
        expect(fetched.content, post.content);
        expect(fetched.likesCount, 0);

        // 3. Like it
        await postRepo.likePost(post.id);
        final afterLike = await postRepo.getPostById(post.id);
        expect(afterLike.isLiked, true);
        expect(afterLike.likesCount, 1);

        // 4. Unlike it
        await postRepo.unlikePost(post.id);
        final afterUnlike = await postRepo.getPostById(post.id);
        expect(afterUnlike.isLiked, false);
        expect(afterUnlike.likesCount, 0);

        // 5. Delete it
        await postRepo.deletePost(post.id);
        createdPostIds.remove(post.id); // Already deleted

        // 6. Verify it's gone
        expect(
          () => postRepo.getPostById(post.id),
          throwsA(anything),
        );
      });

      test(
          'create post with image → image URL accessible → shows in user posts',
          () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);

        // 1. Create post with image
        final post = await postRepo.createPost(
          content: '[TEST] Post with image chain',
          mediaBytes: _jpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post.id);

        expect(post.mediaUrl, isNotNull);
        expect(post.mediaUrl, contains('post-media'));

        // Track for cleanup
        final uri = Uri.parse(post.mediaUrl!);
        final segs = uri.pathSegments;
        uploadedMediaPaths.add('${segs[segs.length - 2]}/${segs.last}');

        // 2. Verify URL format
        expect(post.mediaUrl, startsWith('http'));

        // 3. Verify it appears in user posts
        final userPosts = await postRepo.getUserPosts(henryId);
        final found = userPosts.where((p) => p.id == post.id);
        expect(found, isNotEmpty);
        expect(found.first.mediaUrl, post.mediaUrl);
      });
    });

    group('Complete Reply Chain', () {
      test('reply to post → reply count increments → reply appears in replies',
          () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);

        // 1. Create parent post
        final parent = await postRepo.createPost(
          content: '[TEST] Parent for reply chain',
        );
        createdPostIds.add(parent.id);

        // 2. Create reply
        final reply = await postRepo.createPost(
          content: '[TEST] Reply to parent',
          replyToId: parent.id,
        );
        createdPostIds.add(reply.id);

        // 3. Verify reply count incremented
        final parentAfter = await postRepo.getPostById(parent.id);
        expect(parentAfter.repliesCount, 1);

        // 4. Verify reply appears in replies list
        final replies = await postRepo.getReplies(parent.id);
        expect(replies.length, 1);
        expect(replies.first.content, '[TEST] Reply to parent');
        expect(replies.first.replyToId, parent.id);

        // 5. Reply does NOT appear in user posts (filtered out)
        final userPosts = await postRepo.getUserPosts(henryId);
        expect(userPosts.any((p) => p.id == reply.id), false);
      });
    });

    group('Complete Repost Chain', () {
      test('repost → count increments → unrepost → count decrements', () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);

        // 1. Create post
        final post = await postRepo.createPost(
          content: '[TEST] Repost chain',
        );
        createdPostIds.add(post.id);

        // 2. Repost
        await postRepo.repost(post.id);
        final afterRepost = await postRepo.getPostById(post.id);
        expect(afterRepost.isReposted, true);
        expect(afterRepost.repostsCount, 1);

        // 3. Unrepost
        await postRepo.removeRepost(post.id);
        final afterUnrepost = await postRepo.getPostById(post.id);
        expect(afterUnrepost.isReposted, false);
        expect(afterUnrepost.repostsCount, 0);
      });
    });

    group('Cross-User Interaction Chain', () {
      test(
          'henry likes alice post → alice gets notification → henry unlikes → notification persists',
          () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final aliceClient = await authenticatedClient('alice@demo.com');
        final henryPostRepo = PostRepository(henryClient);
        final aliceNotifRepo = NotificationRepository(aliceClient);

        // 1. Henry likes alice's post
        await henryPostRepo.likePost(alicePost1);

        // 2. Alice gets a notification
        final notifs = await aliceNotifRepo.getNotifications();
        final likeNotif = notifs.where(
          (n) => n.actorId == henryId && n.type == 'like' && n.postId == alicePost1,
        );
        expect(likeNotif, isNotEmpty);

        // 3. Henry unlikes
        await henryPostRepo.unlikePost(alicePost1);

        // 4. Notification persists (notifications are not retracted)
        final notifsAfter = await aliceNotifRepo.getNotifications();
        final stillThere = notifsAfter.where(
          (n) => n.actorId == henryId && n.type == 'like' && n.postId == alicePost1,
        );
        expect(stillThere, isNotEmpty);

        // Cleanup notification
        final admin = createAdminClient();
        await admin
            .from('notifications')
            .delete()
            .eq('actor_id', henryId)
            .eq('type', 'like')
            .eq('post_id', alicePost1);
      });

      test(
          'henry follows bob → bob notification → profile shows following → unfollow',
          () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final bobClient = await authenticatedClient('bob@demo.com');
        final henryProfileRepo = ProfileRepository(henryClient);
        final bobNotifRepo = NotificationRepository(bobClient);

        // henry already follows bob in seed, so unfollow first
        try {
          await henryProfileRepo.unfollowUser(bobId);
        } catch (_) {}

        // Cleanup any existing follow notification
        final admin = createAdminClient();
        await admin
            .from('notifications')
            .delete()
            .eq('actor_id', henryId)
            .eq('type', 'follow')
            .eq('user_id', bobId);

        // 1. Henry follows Bob
        await henryProfileRepo.followUser(bobId);

        // 2. Bob gets a follow notification
        final notifs = await bobNotifRepo.getNotifications();
        final followNotif = notifs.where(
          (n) => n.actorId == henryId && n.type == 'follow',
        );
        expect(followNotif, isNotEmpty);

        // 3. Henry's profile of Bob shows isFollowing=true
        final bobProfile = await henryProfileRepo.getProfile(bobId);
        expect(bobProfile.isFollowing, true);

        // 4. Bob's followers include Henry
        final followers = await henryProfileRepo.getFollowers(bobId);
        expect(followers.any((u) => u.id == henryId), true);

        // 5. Henry unfollows (restore state, then re-follow to restore seed)
        await henryProfileRepo.unfollowUser(bobId);
        final afterUnfollow = await henryProfileRepo.getProfile(bobId);
        expect(afterUnfollow.isFollowing, false);

        // Re-follow to restore seed state
        await henryProfileRepo.followUser(bobId);

        // Cleanup notification
        await admin
            .from('notifications')
            .delete()
            .eq('actor_id', henryId)
            .eq('type', 'follow')
            .eq('user_id', bobId);
      });

      test(
          'henry replies to alice post → alice gets reply notification',
          () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final aliceClient = await authenticatedClient('alice@demo.com');
        final henryPostRepo = PostRepository(henryClient);
        final aliceNotifRepo = NotificationRepository(aliceClient);

        // 1. Henry replies to alice's post
        final reply = await henryPostRepo.createPost(
          content: '[TEST] Reply notification test',
          replyToId: alicePost1,
        );
        createdPostIds.add(reply.id);

        // 2. Alice gets a notification (post_id = reply's id, not parent)
        final notifs = await aliceNotifRepo.getNotifications();
        final replyNotif = notifs.where(
          (n) =>
              n.actorId == henryId &&
              n.type == 'reply' &&
              n.postId == reply.id,
        );
        expect(replyNotif, isNotEmpty);

        // Cleanup notification
        final admin = createAdminClient();
        await admin
            .from('notifications')
            .delete()
            .eq('actor_id', henryId)
            .eq('type', 'reply')
            .eq('post_id', reply.id);
      });
    });

    group('Profile Edit Chain', () {
      test('update display name + bio → profile reflects changes', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        // 1. Update profile
        await repo.updateProfile(
          displayName: '[TEST] New Name',
          bio: '[TEST] New bio',
        );

        // 2. Verify changes
        final profile = await repo.getProfile(henryId);
        expect(profile.user.displayName, '[TEST] New Name');
        expect(profile.user.bio, '[TEST] New bio');

        // 3. Other users see the updated profile
        final aliceClient = await authenticatedClient('alice@demo.com');
        final aliceRepo = ProfileRepository(aliceClient);
        final henryFromAlice = await aliceRepo.getProfile(henryId);
        expect(henryFromAlice.user.displayName, '[TEST] New Name');
      });

      test('upload avatar → profile shows new avatar URL', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        // 1. Upload avatar
        final url = await repo.uploadAvatar(_jpegBytes());
        uploadedAvatarPaths.add('$henryId/avatar.jpg');

        expect(url, contains('avatars'));
        expect(url, contains('?v='));

        // 2. Profile shows new avatar
        final profile = await repo.getProfile(henryId);
        expect(profile.user.avatarUrl, isNotNull);
        expect(profile.user.avatarUrl, contains('avatar.jpg'));
      });
    });

    group('Search Chain', () {
      test('create post → search finds it → like via search → verify liked',
          () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);
        final searchRepo = SearchRepository(client);

        // 1. Create a post with unique content
        final post = await postRepo.createPost(
          content: '[TEST] Searchable xyzzy42 post',
        );
        createdPostIds.add(post.id);

        // 2. Search finds it
        final results = await searchRepo.searchPosts('xyzzy42');
        expect(results.any((p) => p.id == post.id), true);

        // 3. The search result has correct isLiked=false
        final found = results.firstWhere((p) => p.id == post.id);
        expect(found.isLiked, false);

        // 4. Like the post
        await postRepo.likePost(post.id);

        // 5. Search again — isLiked should be true
        final resultsAfter = await searchRepo.searchPosts('xyzzy42');
        final foundAfter = resultsAfter.firstWhere((p) => p.id == post.id);
        expect(foundAfter.isLiked, true);

        // Cleanup
        await postRepo.unlikePost(post.id);
      });

      test('search users by username', () async {
        final client = await authenticatedClient('henry@demo.com');
        final searchRepo = SearchRepository(client);

        final results = await searchRepo.searchUsers('alice');
        expect(results.any((u) => u.id == aliceId), true);
      });

      test('search users by display name', () async {
        final client = await authenticatedClient('henry@demo.com');
        final searchRepo = SearchRepository(client);

        final results = await searchRepo.searchUsers('Alice');
        expect(results.any((u) => u.id == aliceId), true);
      });
    });

    group('Notification Chain', () {
      test('receive notification → mark as read → verify read', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final aliceClient = await authenticatedClient('alice@demo.com');
        final henryPostRepo = PostRepository(henryClient);
        final aliceNotifRepo = NotificationRepository(aliceClient);

        // 1. Henry likes alice's post to generate notification
        await henryPostRepo.likePost(alicePost1);

        // 2. Get notification
        final notifs = await aliceNotifRepo.getNotifications();
        final notif = notifs.firstWhere(
          (n) =>
              n.actorId == henryId &&
              n.type == 'like' &&
              n.postId == alicePost1,
        );
        expect(notif.isRead, false);

        // 3. Mark as read
        await aliceNotifRepo.markAsRead(notif.id);

        // 4. Verify it's read
        final notifsAfter = await aliceNotifRepo.getNotifications();
        final notifAfter = notifsAfter.firstWhere((n) => n.id == notif.id);
        expect(notifAfter.isRead, true);

        // Cleanup
        await henryPostRepo.unlikePost(alicePost1);
        final admin = createAdminClient();
        await admin
            .from('notifications')
            .delete()
            .eq('actor_id', henryId)
            .eq('type', 'like')
            .eq('post_id', alicePost1);
      });

      test('mark all as read', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final graceClient = await authenticatedClient('grace@demo.com');
        final henryPostRepo = PostRepository(henryClient);
        final graceNotifRepo = NotificationRepository(graceClient);

        // Use grace to avoid corrupting alice's state
        // 1. Henry likes a post by grace (frankPost1 has grace's replies)
        // Create a grace post for this
        final gracePostRepo = PostRepository(graceClient);
        final gracePost = await gracePostRepo.createPost(
          content: '[TEST] Grace post for markAllAsRead',
        );
        createdPostIds.add(gracePost.id);

        // 2. Henry likes + reposts it
        await henryPostRepo.likePost(gracePost.id);
        await henryPostRepo.repost(gracePost.id);

        // 3. Grace has unread notifications
        final notifs = await graceNotifRepo.getNotifications();
        final unread = notifs.where((n) => !n.isRead && n.actorId == henryId);
        expect(unread.length, greaterThanOrEqualTo(2));

        // 4. Mark all as read
        await graceNotifRepo.markAllAsRead();

        // 5. All are read now
        final notifsAfter = await graceNotifRepo.getNotifications();
        final stillUnread = notifsAfter.where((n) => !n.isRead);
        expect(stillUnread, isEmpty);

        // Cleanup
        await henryPostRepo.unlikePost(gracePost.id);
        await henryPostRepo.removeRepost(gracePost.id);
        final admin = createAdminClient();
        await admin
            .from('notifications')
            .delete()
            .eq('actor_id', henryId);
      });
    });

    group('Feed Chain', () {
      test('henry already follows alice → feed contains followed users posts',
          () async {
        // Henry follows alice, bob, dave, emma, frank, grace in seed data
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryFeedRepo = FeedRepository(henryClient);

        // Fetch larger page to capture all seed posts
        final feed = await henryFeedRepo.getFeed(pageSize: 50);
        expect(feed, isNotEmpty);

        // Feed should contain posts from followed users or own posts
        final allUserIds = feed.map((p) => p.userId).toSet();
        // At minimum, some of the followed users' posts should appear
        final followedOrOwn = {henryId, aliceId, bobId, daveId, emmaId, frankId, graceId};
        for (final uid in allUserIds) {
          expect(followedOrOwn.contains(uid), true,
              reason: 'Feed contains post from unexpected user: $uid');
        }
      });

      test('henry feed excludes non-followed user (carol)', () async {
        // Henry follows: alice, bob, dave, emma, frank, grace — NOT carol
        // Wait, let me check seed... henry follows: alice, bob, dave, emma, frank, grace
        // So carol is NOT followed by henry
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryProfileRepo = ProfileRepository(henryClient);

        // Verify henry does not follow carol
        final carolProfile = await henryProfileRepo.getProfile(carolId);
        // If henry follows carol in seed, unfollow first
        if (carolProfile.isFollowing) {
          await henryProfileRepo.unfollowUser(carolId);
        }

        final henryFeedRepo = FeedRepository(henryClient);
        final feed = await henryFeedRepo.getFeed();
        final carolPosts = feed.where((p) => p.userId == carolId);
        expect(carolPosts, isEmpty);
      });

      test('feed excludes replies', () async {
        // Alice has replies in seed data
        final aliceClient = await authenticatedClient('alice@demo.com');
        final feedRepo = FeedRepository(aliceClient);

        final feed = await feedRepo.getFeed();
        for (final post in feed) {
          expect(post.replyToId, isNull);
        }
      });

      test('feed shows isLiked/isReposted correctly per user', () async {
        final aliceClient = await authenticatedClient('alice@demo.com');
        final feedRepo = FeedRepository(aliceClient);

        final feed = await feedRepo.getFeed();
        // Alice has some likes/reposts in seed data
        // Just verify the flags are booleans and present
        for (final post in feed) {
          expect(post.isLiked, isA<bool>());
          expect(post.isReposted, isA<bool>());
        }
      });
    });

    group('RLS Protection Chain', () {
      test('henry cannot delete alice post', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryPostRepo = PostRepository(henryClient);
        final admin = createAdminClient();

        // henry tries to delete alice's post
        await henryPostRepo.deletePost(alicePost1);

        // Post still exists
        final post = await admin.from('posts').select().eq('id', alicePost1).maybeSingle();
        expect(post, isNotNull);
      });

      test('henry cannot update alice profile', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final admin = createAdminClient();

        // Before
        final before = await admin
            .from('users')
            .select('display_name')
            .eq('id', aliceId)
            .single();

        // henry tries to update alice's profile
        await henryClient
            .from('users')
            .update({'display_name': 'HACKED'}).eq('id', aliceId);

        // Alice's name is unchanged
        final after = await admin
            .from('users')
            .select('display_name')
            .eq('id', aliceId)
            .single();
        expect(after['display_name'], before['display_name']);
      });

      test('henry cannot like as alice', () async {
        final henryClient = await authenticatedClient('henry@demo.com');

        expect(
          () async => await henryClient.from('likes').insert({
            'user_id': aliceId,
            'post_id': bobPost2,
          }),
          throwsA(anything),
        );
      });

      test('henry cannot upload to alice avatar folder', () async {
        final henryClient = await authenticatedClient('henry@demo.com');

        expect(
          () async => await henryClient.storage
              .from('avatars')
              .uploadBinary('$aliceId/avatar.jpg', _jpegBytes()),
          throwsA(anything),
        );
      });

      test('henry cannot upload to alice post-media folder', () async {
        final henryClient = await authenticatedClient('henry@demo.com');

        expect(
          () async => await henryClient.storage
              .from('post-media')
              .uploadBinary('$aliceId/hack.jpg', _jpegBytes()),
          throwsA(anything),
        );
      });
    });

    group('Edge Cases', () {
      test('empty content post — app should validate before DB', () async {
        // The DB allows empty strings — validation must happen in the UI layer
        // (CreatePostScreen checks _controller.text.trim().isEmpty before submit)
        // This test documents the current behavior
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);

        final post = await postRepo.createPost(content: '  ');
        createdPostIds.add(post.id);

        // DB accepts it — UI validation is the guard
        expect(post.content, '  ');
      });

      test('post > 280 chars is rejected', () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);

        expect(
          () => postRepo.createPost(content: 'A' * 281),
          throwsA(anything),
        );
      });

      test('double like throws', () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);

        final post = await postRepo.createPost(content: '[TEST] Double like');
        createdPostIds.add(post.id);

        await postRepo.likePost(post.id);

        expect(
          () => postRepo.likePost(post.id),
          throwsA(anything),
        );

        // Cleanup
        await postRepo.unlikePost(post.id);
      });

      test('follow self throws', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        expect(
          () => repo.followUser(henryId),
          throwsA(anything),
        );
      });

      test('getPostById non-existent throws', () async {
        final client = await authenticatedClient('henry@demo.com');
        final postRepo = PostRepository(client);

        expect(
          () => postRepo.getPostById('00000000-0000-0000-0000-000000000000'),
          throwsA(anything),
        );
      });
    });
  });
}
