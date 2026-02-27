import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../post/providers/post_provider.dart';
import '../../post/widgets/post_card.dart';
import '../providers/feed_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  Future<void> _handleAction(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(feedProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: feedAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(feedProvider),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyStateWidget(
              message: 'No posts yet. Follow someone or create your first post!',
              icon: Icons.dynamic_feed_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(feedProvider),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: posts.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onLike: () => _handleAction(() async {
                    final repo = ref.read(postRepositoryProvider);
                    if (post.isLiked) {
                      await repo.unlikePost(post.id);
                    } else {
                      await repo.likePost(post.id);
                    }
                  }),
                  onRepost: () => _handleAction(() async {
                    final repo = ref.read(postRepositoryProvider);
                    if (post.isReposted) {
                      await repo.removeRepost(post.id);
                    } else {
                      await repo.repost(post.id);
                    }
                  }),
                  onReply: () async {
                    await context.push('/post/create?replyTo=${post.id}');
                    ref.invalidate(feedProvider);
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/post/create');
          ref.invalidate(feedProvider);
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}
