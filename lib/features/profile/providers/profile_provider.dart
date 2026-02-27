import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/models/app_user.dart';
import '../models/profile_data.dart';
import '../repositories/profile_repository.dart';

part 'profile_provider.g.dart';

@riverpod
ProfileRepository profileRepository(Ref ref) => ProfileRepository();

@riverpod
Future<ProfileData> profile(Ref ref, String userId) {
  return ref.watch(profileRepositoryProvider).getProfile(userId);
}

@riverpod
Future<List<AppUser>> followers(Ref ref, String userId) {
  return ref.watch(profileRepositoryProvider).getFollowers(userId);
}

@riverpod
Future<List<AppUser>> following(Ref ref, String userId) {
  return ref.watch(profileRepositoryProvider).getFollowing(userId);
}
