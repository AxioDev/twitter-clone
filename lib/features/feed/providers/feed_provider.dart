import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/utils/supabase_client.dart';
import '../../post/models/post_model.dart';
import '../repositories/feed_repository.dart';

part 'feed_provider.g.dart';

@riverpod
FeedRepository feedRepository(Ref ref) => FeedRepository();

@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  Future<List<PostModel>> build() async {
    final posts = await ref.watch(feedRepositoryProvider).getFeed();

    final channel = supabase
        .channel('public:posts')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            ref.invalidateSelf();
          },
        )
        .subscribe();

    ref.onDispose(() => supabase.removeChannel(channel));

    return posts;
  }

  bool _loadingMore = false;
  bool get isLoadingMore => _loadingMore;

  Future<void> loadMore() async {
    if (_loadingMore) return;
    final currentPosts = state.value;
    if (currentPosts == null || currentPosts.isEmpty) return;

    _loadingMore = true;
    try {
      final cursor = currentPosts.last.createdAt;
      final morePosts =
          await ref.read(feedRepositoryProvider).getFeed(cursor: cursor);

      if (!ref.mounted) return;
      if (morePosts.isNotEmpty) {
        state = AsyncData([...currentPosts, ...morePosts]);
      }
    } catch (e) {
      // Don't replace state — keep existing posts, just stop loading
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
