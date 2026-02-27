import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/supabase_client.dart';
import '../../auth/models/app_user.dart';
import '../models/profile_data.dart';

class ProfileRepository {
  final sb.SupabaseClient _client;

  ProfileRepository([sb.SupabaseClient? client]) : _client = client ?? supabase;

  Future<ProfileData> getProfile(String userId) async {
    try {
      final currentUserId = _client.auth.currentUser!.id;

      final userData =
          await _client.from('users').select().eq('id', userId).single();

      final followersCount = await _client
          .from('followers')
          .select()
          .eq('following_id', userId)
          .count(sb.CountOption.exact);

      final followingCount = await _client
          .from('followers')
          .select()
          .eq('follower_id', userId)
          .count(sb.CountOption.exact);

      final postsCount = await _client
          .from('posts')
          .select()
          .eq('user_id', userId)
          .isFilter('reply_to_id', null)
          .count(sb.CountOption.exact);

      bool isFollowing = false;
      if (currentUserId != userId) {
        final followRow = await _client
            .from('followers')
            .select()
            .eq('follower_id', currentUserId)
            .eq('following_id', userId)
            .maybeSingle();
        isFollowing = followRow != null;
      }

      return ProfileData(
        user: AppUser.fromJson(userData),
        followersCount: followersCount.count,
        followingCount: followingCount.count,
        postsCount: postsCount.count,
        isFollowing: isFollowing,
        isOwnProfile: currentUserId == userId,
      );
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (bio != null) updates['bio'] = bio;

      if (updates.isNotEmpty) {
        await _client.from('users').update(updates).eq('id', userId);
      }
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<String> uploadAvatar(Uint8List imageBytes) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final path = '$userId/avatar.jpg';

      await _client.storage.from('avatars').uploadBinary(
            path,
            imageBytes,
            fileOptions: const sb.FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

      // Add cache-bust param
      final url = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await _client.from('users').update({'avatar_url': url}).eq('id', userId);

      return url;
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  Future<void> followUser(String targetUserId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('followers').insert({
        'follower_id': userId,
        'following_id': targetUserId,
      });
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> unfollowUser(String targetUserId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client
          .from('followers')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', targetUserId);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<List<AppUser>> getFollowers(String userId) async {
    try {
      final data = await _client
          .from('followers')
          .select('users!followers_follower_id_fkey(*)')
          .eq('following_id', userId);

      return (data as List)
          .map((row) => AppUser.fromJson(row['users']))
          .toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<List<AppUser>> getFollowing(String userId) async {
    try {
      final data = await _client
          .from('followers')
          .select('users!followers_following_id_fkey(*)')
          .eq('follower_id', userId);

      return (data as List)
          .map((row) => AppUser.fromJson(row['users']))
          .toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }
}
