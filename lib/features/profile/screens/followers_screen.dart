import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../providers/profile_provider.dart';

class FollowersScreen extends ConsumerWidget {
  final String userId;
  final bool showFollowers;

  const FollowersScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = showFollowers
        ? ref.watch(followersProvider(userId))
        : ref.watch(followingProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(showFollowers ? 'Followers' : 'Following')),
      body: listAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () {
            if (showFollowers) {
              ref.invalidate(followersProvider(userId));
            } else {
              ref.invalidate(followingProvider(userId));
            }
          },
        ),
        data: (users) {
          if (users.isEmpty) {
            return EmptyStateWidget(
              message: showFollowers ? 'No followers yet' : 'Not following anyone yet',
              icon: Icons.people_outline,
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
      ),
    );
  }
}
