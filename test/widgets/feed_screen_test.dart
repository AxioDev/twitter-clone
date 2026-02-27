import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/features/feed/providers/feed_provider.dart';
import 'package:twitter_clone/features/feed/screens/feed_screen.dart';
import 'package:twitter_clone/features/post/models/post_model.dart';

import '../helpers/test_data.dart';

void main() {
  group('FeedScreen', () {
    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _LoadingFeedNotifier()),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows posts when data loaded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _DataFeedNotifier([testPost])),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello world!'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows empty state when no posts', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _DataFeedNotifier([])),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No posts yet'), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _ErrorFeedNotifier()),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows FAB for creating posts', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _DataFeedNotifier([testPost])),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('shows multiple posts', (tester) async {
      final posts = [testPost, testReply];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _DataFeedNotifier(posts)),
          ],
          child: const MaterialApp(home: FeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello world!'), findsOneWidget);
      expect(find.text('Nice post!'), findsOneWidget);
    });
  });
}

class _LoadingFeedNotifier extends FeedNotifier {
  @override
  Future<List<PostModel>> build() {
    // Use a completer that never completes to stay in loading state
    return Completer<List<PostModel>>().future;
  }
}

class _DataFeedNotifier extends FeedNotifier {
  final List<PostModel> _data;
  _DataFeedNotifier(this._data);

  @override
  Future<List<PostModel>> build() async => _data;
}

class _ErrorFeedNotifier extends FeedNotifier {
  @override
  Future<List<PostModel>> build() async {
    throw Exception('Something went wrong');
  }
}
