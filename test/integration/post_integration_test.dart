import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/core/exceptions/app_exception.dart';
import 'package:twitter_clone/features/post/repositories/post_repository.dart';

import 'supabase_test_client.dart';

void main() {
  final createdPostIds = <String>[];

  tearDownAll(() async {
    await cleanupPosts(createdPostIds);
  });

  group('PostRepository Integration Tests', () {
    group('createPost', () {
      test('creates text-only post and returns PostModel', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        final post = await repo.createPost(
          content: '[TEST] Hello from integration test',
        );
        createdPostIds.add(post.id);

        expect(post.content, '[TEST] Hello from integration test');
        expect(post.userId, aliceId);
        expect(post.username, 'alice');
        expect(post.displayName, 'Alice Johnson');
        expect(post.likesCount, 0);
        expect(post.repostsCount, 0);
        expect(post.repliesCount, 0);
        expect(post.mediaUrl, isNull);
        expect(post.replyToId, isNull);
      });

      test('creates reply with replyToId', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        // Use bobPost2 (0 replies) to avoid polluting alicePost1 count
        final reply = await repo.createPost(
          content: '[TEST] This is a reply',
          replyToId: bobPost2,
        );
        createdPostIds.add(reply.id);

        expect(reply.replyToId, bobPost2);
        expect(reply.content, '[TEST] This is a reply');
      });

      test('rejects content over 280 characters', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        expect(
          () => repo.createPost(content: 'x' * 281),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('deletePost', () {
      test('deletes own post successfully', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        final post = await repo.createPost(content: '[TEST] to be deleted');
        await repo.deletePost(post.id);

        // Verify post is gone
        expect(
          () => repo.getPostById(post.id),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('cannot delete another user\'s post (RLS)', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        // Try to delete bob's post
        await repo.deletePost(bobPost2);

        // Verify post still exists via admin
        final admin = createAdminClient();
        final row = await admin
            .from('posts')
            .select()
            .eq('id', bobPost2)
            .maybeSingle();
        expect(row, isNotNull);
      });
    });

    group('likePost / unlikePost', () {
      test('likePost sets isLiked=true on refetch', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        // bob's post 2 has 0 likes — alice hasn't liked it
        await repo.likePost(bobPost2);
        final post = await repo.getPostById(bobPost2);

        expect(post.isLiked, true);

        // Cleanup
        await repo.unlikePost(bobPost2);
      });

      test('unlikePost sets isLiked=false', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        await repo.likePost(bobPost2);
        await repo.unlikePost(bobPost2);
        final post = await repo.getPostById(bobPost2);

        expect(post.isLiked, false);
      });

      test('duplicate like throws', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        await repo.likePost(bobPost2);

        expect(
          () => repo.likePost(bobPost2),
          throwsA(isA<DatabaseException>()),
        );

        // Cleanup
        await repo.unlikePost(bobPost2);
      });
    });

    group('repost / removeRepost', () {
      test('repost sets isReposted=true on refetch', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        // bob's post 2 — alice hasn't reposted it
        await repo.repost(bobPost2);
        final post = await repo.getPostById(bobPost2);

        expect(post.isReposted, true);

        // Cleanup
        await repo.removeRepost(bobPost2);
      });

      test('removeRepost sets isReposted=false', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        await repo.repost(bobPost2);
        await repo.removeRepost(bobPost2);
        final post = await repo.getPostById(bobPost2);

        expect(post.isReposted, false);
      });
    });

    group('getPostById', () {
      test('returns correct fields from seed data', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        final post = await repo.getPostById(alicePost1);

        expect(post.id, alicePost1);
        expect(post.userId, aliceId);
        expect(post.username, 'alice');
        expect(post.displayName, 'Alice Johnson');
        expect(post.likesCount, greaterThanOrEqualTo(5));
        expect(post.repliesCount, greaterThanOrEqualTo(2));
        expect(post.replyToId, isNull);
      });

      test('is_liked flag varies per user', () async {
        // Alice liked carol's post (10000000-...-03)
        final aliceClient = await authenticatedClient('alice@demo.com');
        final aliceRepo = PostRepository(aliceClient);
        final asAlice = await aliceRepo.getPostById(carolPost1);
        expect(asAlice.isLiked, true);

        // Henry did NOT like carol's post
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryRepo = PostRepository(henryClient);
        final asHenry = await henryRepo.getPostById(carolPost1);
        expect(asHenry.isLiked, false);
      });
    });

    group('getReplies', () {
      test('returns replies to a post', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        final replies = await repo.getReplies(alicePost1);

        expect(replies.length, greaterThanOrEqualTo(2));
        for (final reply in replies) {
          expect(reply.replyToId, alicePost1);
        }
      });

      test('returns empty for post with no replies', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        final replies = await repo.getReplies(carolPost1);
        expect(replies, isEmpty);
      });
    });

    group('getUserPosts', () {
      test('excludes replies and orders by created_at desc', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = PostRepository(client);

        final posts = await repo.getUserPosts(aliceId);

        expect(posts.length, greaterThanOrEqualTo(4));
        for (final post in posts) {
          expect(post.replyToId, isNull);
          expect(post.userId, aliceId);
        }

        // Verify descending order
        for (int i = 0; i < posts.length - 1; i++) {
          expect(
            posts[i].createdAt.isAfter(posts[i + 1].createdAt),
            true,
            reason: 'Posts should be ordered by created_at descending',
          );
        }
      });
    });
  });
}
