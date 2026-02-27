import 'package:twitter_clone/features/auth/models/app_user.dart';
import 'package:twitter_clone/features/notifications/models/notification_model.dart';
import 'package:twitter_clone/features/post/models/post_model.dart';
import 'package:twitter_clone/features/profile/models/profile_data.dart';

final testUser = AppUser(
  id: 'user-1',
  username: 'testuser',
  displayName: 'Test User',
  bio: 'A test bio',
  avatarUrl: null,
  createdAt: DateTime(2025, 1, 1),
);

final testUser2 = AppUser(
  id: 'user-2',
  username: 'otheruser',
  displayName: 'Other User',
  bio: '',
  avatarUrl: null,
  createdAt: DateTime(2025, 1, 2),
);

final testPost = PostModel(
  id: 'post-1',
  userId: 'user-1',
  content: 'Hello world!',
  mediaUrl: null,
  replyToId: null,
  createdAt: DateTime(2025, 6, 1, 12, 0),
  likesCount: 5,
  repostsCount: 2,
  repliesCount: 1,
  username: 'testuser',
  displayName: 'Test User',
  avatarUrl: null,
  isLiked: false,
  isReposted: false,
);

final testPostLiked = testPost.copyWith(isLiked: true, likesCount: 6);

final testReply = PostModel(
  id: 'post-2',
  userId: 'user-2',
  content: 'Nice post!',
  mediaUrl: null,
  replyToId: 'post-1',
  createdAt: DateTime(2025, 6, 1, 12, 30),
  likesCount: 0,
  repostsCount: 0,
  repliesCount: 0,
  username: 'otheruser',
  displayName: 'Other User',
  avatarUrl: null,
);

final testProfileData = ProfileData(
  user: testUser,
  followersCount: 10,
  followingCount: 5,
  postsCount: 42,
  isFollowing: false,
  isOwnProfile: true,
);

final testNotification = NotificationModel(
  id: 'notif-1',
  userId: 'user-1',
  actorId: 'user-2',
  type: 'like',
  postId: 'post-1',
  isRead: false,
  createdAt: DateTime(2025, 6, 1, 13, 0),
  actorUsername: 'otheruser',
  actorDisplayName: 'Other User',
  actorAvatarUrl: null,
);

final testNotificationRead = testNotification.copyWith(isRead: true);
