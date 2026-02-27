import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../post/providers/post_provider.dart';
import '../../post/widgets/post_card.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String get userId => widget.userId;

  Future<void> _handleAction(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(profileProvider(userId));
      ref.invalidate(userPostsProvider(userId));
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
    final profileAsync = ref.watch(profileProvider(userId));
    final postsAsync = ref.watch(userPostsProvider(userId));

    return Scaffold(
      body: profileAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(profileProvider(userId)),
        ),
        data: (profile) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider(userId));
            ref.invalidate(userPostsProvider(userId));
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                title: Text(profile.user.displayName),
                actions: [
                  if (profile.isOwnProfile)
                    IconButton(
                      onPressed: () async {
                        try {
                          await ref.read(authRepositoryProvider).signOut();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sign out failed: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: ProfileHeader(
                  profile: profile,
                  onFollow: () => _handleAction(() async {
                    final repo = ref.read(profileRepositoryProvider);
                    if (profile.isFollowing) {
                      await repo.unfollowUser(userId);
                    } else {
                      await repo.followUser(userId);
                    }
                  }),
                  onEdit: () async {
                    await context.push('/profile/$userId/edit');
                    ref.invalidate(profileProvider(userId));
                  },
                  onFollowersTap: () => context.push('/profile/$userId/followers'),
                  onFollowingTap: () => context.push('/profile/$userId/following'),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(thickness: 4)),
              postsAsync.when(
                loading: () => const SliverToBoxAdapter(child: LoadingWidget()),
                error: (e, _) => SliverToBoxAdapter(
                  child: AppErrorWidget(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(userPostsProvider(userId)),
                  ),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No posts yet')),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, index) => Column(
                        children: [
                          PostCard(
                            post: posts[index],
                            onLike: () => _handleAction(() async {
                              final repo = ref.read(postRepositoryProvider);
                              if (posts[index].isLiked) {
                                await repo.unlikePost(posts[index].id);
                              } else {
                                await repo.likePost(posts[index].id);
                              }
                            }),
                            onRepost: () => _handleAction(() async {
                              final repo = ref.read(postRepositoryProvider);
                              if (posts[index].isReposted) {
                                await repo.removeRepost(posts[index].id);
                              } else {
                                await repo.repost(posts[index].id);
                              }
                            }),
                            onReply: () async {
                              await context.push('/post/create?replyTo=${posts[index].id}');
                              ref.invalidate(userPostsProvider(userId));
                            },
                          ),
                          const Divider(),
                        ],
                      ),
                      childCount: posts.length,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
