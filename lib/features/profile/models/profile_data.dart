import 'package:freezed_annotation/freezed_annotation.dart';

import '../../auth/models/app_user.dart';

part 'profile_data.freezed.dart';

@freezed
sealed class ProfileData with _$ProfileData {
  const factory ProfileData({
    required AppUser user,
    required int followersCount,
    required int followingCount,
    required int postsCount,
    required bool isFollowing,
    required bool isOwnProfile,
  }) = _ProfileData;
}
