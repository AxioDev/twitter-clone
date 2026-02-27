import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/search/repositories/search_repository.dart';

import 'supabase_test_client.dart';

void main() {
  group('SearchRepository Integration Tests', () {
    late SearchRepository repo;

    setUpAll(() async {
      final client = await authenticatedClient('alice@demo.com');
      repo = SearchRepository(client);
    });

    group('searchUsers', () {
      test('finds user by partial username match', () async {
        final results = await repo.searchUsers('ali');

        expect(results, isNotEmpty);
        expect(results.any((u) => u.username == 'alice'), true);
      });

      test('finds user by partial display_name match', () async {
        final results = await repo.searchUsers('Johnson');

        expect(results, isNotEmpty);
        expect(results.any((u) => u.displayName == 'Alice Johnson'), true);
      });

      test('case-insensitive search', () async {
        final results = await repo.searchUsers('ALICE');

        expect(results, isNotEmpty);
        expect(results.any((u) => u.username == 'alice'), true);
      });

      test('no match returns empty list', () async {
        final results = await repo.searchUsers('zzzznonexistent');
        expect(results, isEmpty);
      });
    });

    group('searchPosts', () {
      test('finds posts by content match', () async {
        final results = await repo.searchPosts('Flutter');

        expect(results, isNotEmpty);
        for (final post in results) {
          expect(
            post.content.toLowerCase().contains('flutter'),
            true,
            reason: 'Each result should contain the search term',
          );
        }
      });

      test('ordered by created_at descending', () async {
        final results = await repo.searchPosts('the');

        if (results.length > 1) {
          for (int i = 0; i < results.length - 1; i++) {
            expect(
              results[i].createdAt.isAfter(results[i + 1].createdAt) ||
                  results[i].createdAt == results[i + 1].createdAt,
              true,
              reason: 'Results should be ordered by created_at desc',
            );
          }
        }
      });

      test('no match returns empty list', () async {
        final results = await repo.searchPosts('zzzznonexistent');
        expect(results, isEmpty);
      });
    });
  });
}
