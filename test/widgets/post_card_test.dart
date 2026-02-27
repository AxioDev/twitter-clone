import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/post/widgets/post_card.dart';

import '../helpers/test_data.dart';

void main() {
  group('PostCard', () {
    testWidgets('displays post content', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: testPost),
            ),
          ),
        ),
      );

      expect(find.text('Hello world!'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('@testuser'), findsOneWidget);
    });

    testWidgets('shows like count', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: testPost),
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget); // likes count
    });

    testWidgets('calls onLike callback', (tester) async {
      bool liked = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(
                post: testPost,
                onLike: () => liked = true,
              ),
            ),
          ),
        ),
      );

      // Find the like button (heart icon)
      final likeButton = find.byIcon(Icons.favorite_border);
      expect(likeButton, findsOneWidget);
      await tester.tap(likeButton);
      expect(liked, true);
    });

    testWidgets('shows filled heart when liked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: testPostLiked),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('shows reply indicator for replies', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: testReply),
            ),
          ),
        ),
      );

      expect(find.text('Nice post!'), findsOneWidget);
      expect(find.text('Other User'), findsOneWidget);
    });
  });
}
