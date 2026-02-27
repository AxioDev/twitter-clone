import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/supabase_client.dart';
import '../../post/models/post_model.dart';

class FeedRepository {
  final sb.SupabaseClient _client;

  FeedRepository([sb.SupabaseClient? client]) : _client = client ?? supabase;

  Future<List<PostModel>> getFeed({
    DateTime? cursor,
    int pageSize = 20,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client.rpc('get_feed', params: {
        'requesting_user_id': userId,
        'cursor_timestamp':
            (cursor ?? DateTime.now().add(const Duration(seconds: 1)))
                .toUtc()
                .toIso8601String(),
        'page_size': pageSize,
      });

      return (response as List).map((row) {
        final map = Map<String, dynamic>.from(row);
        return PostModel(
          id: map['id'],
          userId: map['user_id'],
          content: map['content'],
          mediaUrl: map['media_url'],
          replyToId: map['reply_to_id'],
          createdAt: DateTime.parse(map['created_at']),
          likesCount: map['likes_count'] ?? 0,
          repostsCount: map['reposts_count'] ?? 0,
          repliesCount: map['replies_count'] ?? 0,
          username: map['username'],
          displayName: map['display_name'],
          avatarUrl: map['avatar_url'],
          isLiked: map['is_liked'] ?? false,
          isReposted: map['is_reposted'] ?? false,
        );
      }).toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }
}
