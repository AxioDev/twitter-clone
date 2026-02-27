import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/auth/models/app_user.dart';

void main() {
  group('AppUser', () {
    test('fromJson creates correct model', () {
      final json = {
        'id': 'user-1',
        'username': 'john',
        'display_name': 'John Doe',
        'bio': 'Hello',
        'avatar_url': 'https://example.com/avatar.jpg',
        'created_at': '2025-01-01T00:00:00.000Z',
      };

      final user = AppUser.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.username, 'john');
      expect(user.displayName, 'John Doe');
      expect(user.bio, 'Hello');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('fromJson handles null avatar and empty bio', () {
      final json = {
        'id': 'user-2',
        'username': 'jane',
        'display_name': 'Jane',
        'created_at': '2025-01-01T00:00:00.000Z',
      };

      final user = AppUser.fromJson(json);

      expect(user.avatarUrl, isNull);
      expect(user.bio, '');
    });

    test('toJson produces correct output', () {
      final user = AppUser(
        id: 'user-1',
        username: 'john',
        displayName: 'John Doe',
        bio: 'Hello',
        createdAt: DateTime.utc(2025, 1, 1),
      );

      final json = user.toJson();

      expect(json['id'], 'user-1');
      expect(json['username'], 'john');
      expect(json['display_name'], 'John Doe');
      expect(json['bio'], 'Hello');
    });

    test('copyWith creates modified copy', () {
      final user = AppUser(
        id: 'user-1',
        username: 'john',
        displayName: 'John Doe',
        createdAt: DateTime.utc(2025, 1, 1),
      );

      final updated = user.copyWith(displayName: 'John Updated');

      expect(updated.displayName, 'John Updated');
      expect(updated.username, 'john');
    });

    test('equality works', () {
      final user1 = AppUser(
        id: 'user-1',
        username: 'john',
        displayName: 'John',
        createdAt: DateTime.utc(2025, 1, 1),
      );
      final user2 = AppUser(
        id: 'user-1',
        username: 'john',
        displayName: 'John',
        createdAt: DateTime.utc(2025, 1, 1),
      );

      expect(user1, equals(user2));
    });
  });
}
