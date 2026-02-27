import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/post/models/post_model.dart';

void main() {
  group('PostModel', () {
    test('fromJson creates correct model', () {
      final json = {
        'id': 'post-1',
        'user_id': 'user-1',
        'content': 'Hello world!',
        'media_url': null,
        'reply_to_id': null,
        'created_at': '2025-06-01T12:00:00.000Z',
        'likes_count': 5,
        'reposts_count': 2,
        'replies_count': 1,
        'username': 'testuser',
        'display_name': 'Test User',
        'avatar_url': null,
        'is_liked': true,
        'is_reposted': false,
      };

      final post = PostModel.fromJson(json);

      expect(post.id, 'post-1');
      expect(post.content, 'Hello world!');
      expect(post.likesCount, 5);
      expect(post.isLiked, true);
      expect(post.isReposted, false);
    });

    test('defaults are applied when fields missing', () {
      final json = {
        'id': 'post-1',
        'user_id': 'user-1',
        'content': 'Test',
        'created_at': '2025-06-01T12:00:00.000Z',
        'username': 'test',
        'display_name': 'Test',
      };

      final post = PostModel.fromJson(json);

      expect(post.likesCount, 0);
      expect(post.repostsCount, 0);
      expect(post.repliesCount, 0);
      expect(post.isLiked, false);
      expect(post.isReposted, false);
      expect(post.mediaUrl, isNull);
      expect(post.replyToId, isNull);
    });

    test('copyWith toggles isLiked', () {
      final post = PostModel(
        id: 'p1',
        userId: 'u1',
        content: 'Test',
        createdAt: DateTime.utc(2025),
        username: 'test',
        displayName: 'Test',
      );

      final liked = post.copyWith(isLiked: true, likesCount: 1);

      expect(liked.isLiked, true);
      expect(liked.likesCount, 1);
      expect(liked.content, 'Test');
    });

    test('equality works for identical posts', () {
      final post1 = PostModel(
        id: 'p1',
        userId: 'u1',
        content: 'Hello',
        createdAt: DateTime.utc(2025, 6, 1),
        username: 'test',
        displayName: 'Test',
      );
      final post2 = PostModel(
        id: 'p1',
        userId: 'u1',
        content: 'Hello',
        createdAt: DateTime.utc(2025, 6, 1),
        username: 'test',
        displayName: 'Test',
      );

      expect(post1, equals(post2));
    });
  });
}
