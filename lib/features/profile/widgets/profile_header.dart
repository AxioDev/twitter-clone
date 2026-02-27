import 'package:flutter/material.dart';

import '../../../core/widgets/avatar_widget.dart';
import '../models/profile_data.dart';

class ProfileHeader extends StatelessWidget {
  final ProfileData profile;
  final VoidCallback? onFollow;
  final VoidCallback? onEdit;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileHeader({
    super.key,
    required this.profile,
    this.onFollow,
    this.onEdit,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = profile.user;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                imageUrl: user.avatarUrl,
                fallbackText: user.displayName,
                radius: 36,
              ),
              const Spacer(),
              if (profile.isOwnProfile)
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit Profile'),
                )
              else
                FilledButton(
                  onPressed: onFollow,
                  style: profile.isFollowing
                      ? OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        )
                      : null,
                  child: Text(profile.isFollowing ? 'Following' : 'Follow'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            '@${user.username}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(user.bio),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onFollowingTap,
                child: Row(
                  children: [
                    Text(
                      '${profile.followingCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(' Following', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onFollowersTap,
                child: Row(
                  children: [
                    Text(
                      '${profile.followersCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(' Followers', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
