import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/feed/repositories/feed_repository.dart';

import 'supabase_test_client.dart';

void main() {
  group('FeedRepository Integration Tests', () {
    // Alice follows: bob, carol, dave, emma, grace
    // Alice does NOT follow: frank, henry

    late FeedRepository repo;

    setUpAll(() async {
      final client = await authenticatedClient('alice@demo.com');
      repo = FeedRepository(client);
    });

    test('returns posts from followed users and own', () async {
      final feed = await repo.getFeed();

      expect(feed, isNotEmpty);

      final userIds = feed.map((p) => p.userId).toSet();
      // Should include alice and her followed users
      expect(userIds, contains(aliceId));
    });

    test('excludes posts from non-followed users', () async {
      final feed = await repo.getFeed(pageSize: 100);

      final userIds = feed.map((p) => p.userId).toSet();
      // Frank and henry are not followed by alice
      expect(userIds, isNot(contains(frankId)));
      expect(userIds, isNot(contains(henryId)));
    });

    test('excludes replies', () async {
      final feed = await repo.getFeed(pageSize: 100);

      for (final post in feed) {
        expect(post.replyToId, isNull,
            reason: 'Feed should not contain replies');
      }
    });

    test('includes is_liked and is_reposted flags', () async {
      final feed = await repo.getFeed(pageSize: 100);

      // Alice liked bob's K8s post (10000000-...-02)
      final bobK8sPost =
          feed.where((p) => p.id == bobPost1).toList();
      if (bobK8sPost.isNotEmpty) {
        expect(bobK8sPost.first.isLiked, true);
      }

      // Check at least some isLiked=true exists
      final likedPosts = feed.where((p) => p.isLiked).toList();
      expect(likedPosts, isNotEmpty, reason: 'Alice should have liked posts');
    });

    test('pagination with cursor returns older posts', () async {
      final page1 = await repo.getFeed(pageSize: 3);
      expect(page1.length, 3);

      final cursor = page1.last.createdAt;
      final page2 = await repo.getFeed(cursor: cursor, pageSize: 3);

      // Page 2 posts should all be older than cursor
      for (final post in page2) {
        expect(post.createdAt.isBefore(cursor), true,
            reason: 'Page 2 posts should be older than cursor');
      }

      // No overlap
      final page1Ids = page1.map((p) => p.id).toSet();
      for (final post in page2) {
        expect(page1Ids.contains(post.id), false,
            reason: 'Pages should not overlap');
      }
    });

    test('respects pageSize', () async {
      final feed = await repo.getFeed(pageSize: 2);
      expect(feed.length, lessThanOrEqualTo(2));
    });
  });
}
