import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../post/providers/post_provider.dart';
import '../../post/widgets/post_card.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search users or posts...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Posts'),
          ],
        ),
      ),
      body: _query.isEmpty
          ? const EmptyStateWidget(
              message: 'Search for users or posts',
              icon: Icons.search,
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _UsersTab(query: _query),
                _PostsTab(query: _query),
              ],
            ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  final String query;
  const _UsersTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(searchUsersProvider(query));
    return usersAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(searchUsersProvider(query)),
      ),
      data: (users) {
        if (users.isEmpty) {
          return const EmptyStateWidget(
            message: 'No users found',
            icon: Icons.person_off_outlined,
          );
        }
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, index) {
            final user = users[index];
            return ListTile(
              leading: AvatarWidget(
                imageUrl: user.avatarUrl,
                fallbackText: user.displayName,
              ),
              title: Text(user.displayName),
              subtitle: Text('@${user.username}'),
              onTap: () => context.push('/profile/${user.id}'),
            );
          },
        );
      },
    );
  }
}

class _PostsTab extends ConsumerStatefulWidget {
  final String query;
  const _PostsTab({required this.query});

  @override
  ConsumerState<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends ConsumerState<_PostsTab> {
  Future<void> _handleAction(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(searchPostsProvider(widget.query));
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
    final postsAsync = ref.watch(searchPostsProvider(widget.query));
    return postsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(searchPostsProvider(widget.query)),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const EmptyStateWidget(
            message: 'No posts found',
            icon: Icons.article_outlined,
          );
        }
        return ListView.separated(
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
                ref.invalidate(searchPostsProvider(widget.query));
              },
            );
          },
        );
      },
    );
  }
}
