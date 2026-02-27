import 'package:flutter/material.dart';

import '../models/post_model.dart';

class PostActions extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onRepost;
  final VoidCallback? onReply;

  const PostActions({
    super.key,
    required this.post,
    this.onLike,
    this.onRepost,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          count: post.repliesCount,
          onTap: onReply,
        ),
        const SizedBox(width: 24),
        _ActionButton(
          icon: post.isReposted ? Icons.repeat_on : Icons.repeat,
          count: post.repostsCount,
          color: post.isReposted ? Colors.green : null,
          onTap: onRepost,
        ),
        const SizedBox(width: 24),
        _ActionButton(
          icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
          count: post.likesCount,
          color: post.isLiked ? Colors.red : null,
          onTap: onLike,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color? color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.count,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? Colors.grey[600]),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: color ?? Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
