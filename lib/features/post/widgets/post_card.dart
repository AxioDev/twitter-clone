import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../models/post_model.dart';
import 'post_actions.dart';
import 'post_media.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onRepost;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onRepost,
    this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/post/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.push('/profile/${post.userId}'),
              child: AvatarWidget(
                imageUrl: post.avatarUrl,
                fallbackText: post.displayName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '@${post.username}',
                          style: TextStyle(color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        ' · ${post.createdAt.timeAgo}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(post.content),
                  if (post.mediaUrl != null) ...[
                    const SizedBox(height: 8),
                    PostMedia(url: post.mediaUrl!),
                  ],
                  const SizedBox(height: 8),
                  PostActions(
                    post: post,
                    onLike: onLike,
                    onRepost: onRepost,
                    onReply: onReply,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
