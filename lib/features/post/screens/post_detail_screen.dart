import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../widgets/post_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/post_media.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  String get postId => widget.postId;

  Future<void> _handleAction(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(postDetailProvider(postId));
      ref.invalidate(postRepliesProvider(postId));
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
    final postAsync = ref.watch(postDetailProvider(postId));
    final repliesAsync = ref.watch(postRepliesProvider(postId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: postAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(postDetailProvider(postId)),
        ),
        data: (post) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(postDetailProvider(postId));
            ref.invalidate(postRepliesProvider(postId));
          },
          child: ListView(
            children: [
              // Main post (expanded view)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/profile/${post.userId}'),
                          child: AvatarWidget(
                            imageUrl: post.avatarUrl,
                            fallbackText: post.displayName,
                            radius: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '@${post.username}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        if (currentUserId == post.userId)
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete post?'),
                                    content: const Text('This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  try {
                                    await ref.read(postRepositoryProvider).deletePost(post.id);
                                    if (context.mounted) context.pop();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to delete: $e')),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(post.content, style: const TextStyle(fontSize: 18)),
                    if (post.mediaUrl != null) ...[
                      const SizedBox(height: 12),
                      PostMedia(url: post.mediaUrl!),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      post.createdAt.timeAgo,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('${post.likesCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(' Likes', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 16),
                        Text('${post.repostsCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(' Reposts', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 16),
                        Text('${post.repliesCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(' Replies', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    PostActions(
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
                        ref.invalidate(postDetailProvider(postId));
                        ref.invalidate(postRepliesProvider(postId));
                      },
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 8),
              // Replies
              repliesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: LoadingWidget(),
                ),
                error: (e, _) => AppErrorWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(postRepliesProvider(postId)),
                ),
                data: (replies) => Column(
                  children: replies.map((reply) => Column(
                    children: [
                      PostCard(
                        post: reply,
                        onLike: () => _handleAction(() async {
                          final repo = ref.read(postRepositoryProvider);
                          if (reply.isLiked) {
                            await repo.unlikePost(reply.id);
                          } else {
                            await repo.likePost(reply.id);
                          }
                        }),
                        onRepost: () => _handleAction(() async {
                          final repo = ref.read(postRepositoryProvider);
                          if (reply.isReposted) {
                            await repo.removeRepost(reply.id);
                          } else {
                            await repo.repost(reply.id);
                          }
                        }),
                        onReply: () async {
                          await context.push('/post/create?replyTo=${reply.id}');
                          ref.invalidate(postDetailProvider(postId));
                          ref.invalidate(postRepliesProvider(postId));
                        },
                      ),
                      const Divider(),
                    ],
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/post/create?replyTo=$postId');
          ref.invalidate(postDetailProvider(postId));
          ref.invalidate(postRepliesProvider(postId));
        },
        child: const Icon(Icons.reply),
      ),
    );
  }
}
