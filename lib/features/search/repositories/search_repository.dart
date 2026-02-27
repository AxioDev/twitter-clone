import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/supabase_client.dart';
import '../../auth/models/app_user.dart';
import '../../post/models/post_model.dart';

class SearchRepository {
  final sb.SupabaseClient _client;

  SearchRepository([sb.SupabaseClient? client]) : _client = client ?? supabase;

  Future<List<AppUser>> searchUsers(String query) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);

      return (response as List).map((e) => AppUser.fromJson(e)).toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<List<PostModel>> searchPosts(String query) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final data = await _client
          .from('posts')
          .select('''
            *,
            users!posts_user_id_fkey(username, display_name, avatar_url),
            likes(user_id),
            reposts(user_id)
          ''')
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      return (data as List).map((row) {
        final user = row['users'] as Map<String, dynamic>;

        bool isLiked = false;
        bool isReposted = false;
        if (row['likes'] is List) {
          isLiked = (row['likes'] as List)
              .any((l) => l['user_id'] == userId);
        }
        if (row['reposts'] is List) {
          isReposted = (row['reposts'] as List)
              .any((r) => r['user_id'] == userId);
        }

        return PostModel(
          id: row['id'],
          userId: row['user_id'],
          content: row['content'],
          mediaUrl: row['media_url'],
          replyToId: row['reply_to_id'],
          createdAt: DateTime.parse(row['created_at']),
          likesCount: row['likes_count'] ?? 0,
          repostsCount: row['reposts_count'] ?? 0,
          repliesCount: row['replies_count'] ?? 0,
          username: user['username'],
          displayName: user['display_name'],
          avatarUrl: user['avatar_url'],
          isLiked: isLiked,
          isReposted: isReposted,
        );
      }).toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }
}
