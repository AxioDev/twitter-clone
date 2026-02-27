import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/post/repositories/post_repository.dart';
import 'package:twitter_clone/features/profile/repositories/profile_repository.dart';

import 'supabase_test_client.dart';

void main() {
  group('Database Trigger Tests', () {
    group('likes_count trigger', () {
      test('increments on like', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final before = await repo.getPostById(bobPost2);
        final beforeCount = before.likesCount;

        await repo.likePost(bobPost2);
        final after = await repo.getPostById(bobPost2);

        expect(after.likesCount, beforeCount + 1);

        // Cleanup
        await repo.unlikePost(bobPost2);
      });

      test('decrements on unlike', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        await repo.likePost(bobPost2);
        final afterLike = await repo.getPostById(bobPost2);

        await repo.unlikePost(bobPost2);
        final afterUnlike = await repo.getPostById(bobPost2);

        expect(afterUnlike.likesCount, afterLike.likesCount - 1);
      });
    });

    group('reposts_count trigger', () {
      test('increments on repost', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final before = await repo.getPostById(bobPost2);
        final beforeCount = before.repostsCount;

        await repo.repost(bobPost2);
        final after = await repo.getPostById(bobPost2);

        expect(after.repostsCount, beforeCount + 1);

        // Cleanup
        await repo.removeRepost(bobPost2);
      });

      test('decrements on remove repost', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        await repo.repost(bobPost2);
        final afterRepost = await repo.getPostById(bobPost2);

        await repo.removeRepost(bobPost2);
        final afterRemove = await repo.getPostById(bobPost2);

        expect(afterRemove.repostsCount, afterRepost.repostsCount - 1);
      });
    });

    group('replies_count trigger', () {
      test('increments when reply is created', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final before = await repo.getPostById(bobPost2);
        final beforeCount = before.repliesCount;

        final reply = await repo.createPost(
          content: '[TEST] reply for count test',
          replyToId: bobPost2,
        );

        final after = await repo.getPostById(bobPost2);
        expect(after.repliesCount, beforeCount + 1);

        // Cleanup
        await cleanupPosts([reply.id]);
      });

      test('decrements when reply is deleted', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final reply = await repo.createPost(
          content: '[TEST] reply to be deleted',
          replyToId: bobPost2,
        );

        final afterCreate = await repo.getPostById(bobPost2);
        await repo.deletePost(reply.id);
        final afterDelete = await repo.getPostById(bobPost2);

        expect(afterDelete.repliesCount, afterCreate.repliesCount - 1);

        // Cleanup notifications from the reply
        final admin = createAdminClient();
        await admin.from('notifications').delete().eq('post_id', reply.id);
      });
    });

    group('updated_at trigger', () {
      test('updated_at changes on profile update', () async {
        final admin = createAdminClient();

        // Get henry's current updated_at
        final beforeRow = await admin
            .from('users')
            .select('updated_at')
            .eq('id', henryId)
            .single();
        final beforeUpdatedAt = DateTime.parse(beforeRow['updated_at']);

        // Wait a bit to ensure timestamp difference
        await Future.delayed(const Duration(seconds: 1));

        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);
        await repo.updateProfile(bio: 'Trigger test bio');

        final afterRow = await admin
            .from('users')
            .select('updated_at')
            .eq('id', henryId)
            .single();
        final afterUpdatedAt = DateTime.parse(afterRow['updated_at']);

        expect(afterUpdatedAt.isAfter(beforeUpdatedAt), true);

        // Restore
        await repo.updateProfile(
            bio: 'Startup founder | Full-stack dev | Building the future');
      });
    });
  });
}
