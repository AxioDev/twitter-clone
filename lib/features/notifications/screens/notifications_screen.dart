import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _markAllAsRead() async {
    try {
      await ref.read(notificationsProvider.notifier).markAllAsRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyStateWidget(
              message: 'No notifications yet',
              icon: Icons.notifications_none,
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(notificationsProvider),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, index) {
                final notif = notifications[index];
                return _NotificationTile(notif: notif);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notif;

  const _NotificationTile({required this.notif});

  String get _message {
    switch (notif.type) {
      case 'like':
        return 'liked your post';
      case 'repost':
        return 'reposted your post';
      case 'reply':
        return 'replied to your post';
      case 'follow':
        return 'followed you';
      default:
        return 'interacted with you';
    }
  }

  IconData get _icon {
    switch (notif.type) {
      case 'like':
        return Icons.favorite;
      case 'repost':
        return Icons.repeat;
      case 'reply':
        return Icons.chat_bubble;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color get _iconColor {
    switch (notif.type) {
      case 'like':
        return Colors.red;
      case 'repost':
        return Colors.green;
      case 'reply':
        return Colors.blue;
      case 'follow':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      tileColor: notif.isRead ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarWidget(
            imageUrl: notif.actorAvatarUrl,
            fallbackText: notif.actorDisplayName,
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 14, color: _iconColor),
            ),
          ),
        ],
      ),
      title: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: notif.actorDisplayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: ' $_message'),
          ],
        ),
      ),
      subtitle: Text(notif.createdAt.timeAgo),
      onTap: () async {
        if (!notif.isRead) {
          try {
            await ref
                .read(notificationsProvider.notifier)
                .markAsRead(notif.id);
          } catch (_) {
            // Non-blocking — navigate anyway
          }
        }
        if (!context.mounted) return;
        if (notif.type == 'follow') {
          context.push('/profile/${notif.actorId}');
        } else if (notif.postId != null) {
          context.push('/post/${notif.postId}');
        }
      },
    );
  }
}
