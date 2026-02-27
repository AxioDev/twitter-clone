import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/supabase_client.dart';
import '../models/post_model.dart';

class PostRepository {
  final sb.SupabaseClient _client;

  PostRepository([sb.SupabaseClient? client]) : _client = client ?? supabase;

  Future<PostModel> createPost({
    required String content,
    Uint8List? mediaBytes,
    String? mediaExtension,
    String? replyToId,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      String? mediaUrl;

      if (mediaBytes != null) {
        final ext = mediaExtension ?? 'jpg';
        final path = '$userId/${const Uuid().v4()}.$ext';
        await _client.storage.from('post-media').uploadBinary(path, mediaBytes);
        mediaUrl = _client.storage.from('post-media').getPublicUrl(path);
      }

      final data = await _client
          .from('posts')
          .insert({
            'user_id': userId,
            'content': content,
            if (mediaUrl != null) 'media_url': mediaUrl,
            if (replyToId != null) 'reply_to_id': replyToId,
          })
          .select(_postSelect)
          .single();

      return _mapPostRow(data, userId);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _client.from('posts').delete().eq('id', postId);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> likePost(String postId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('likes').insert({
        'user_id': userId,
        'post_id': postId,
      });
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> unlikePost(String postId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client
          .from('likes')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> repost(String postId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('reposts').insert({
        'user_id': userId,
        'post_id': postId,
      });
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> removeRepost(String postId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client
          .from('reposts')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  static const _postSelect = '''
    *,
    users!posts_user_id_fkey(username, display_name, avatar_url),
    likes(user_id),
    reposts(user_id)
  ''';

  Future<PostModel> getPostById(String postId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final data = await _client
          .from('posts')
          .select(_postSelect)
          .eq('id', postId)
          .single();

      return _mapPostRow(data, userId);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<List<PostModel>> getReplies(String postId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final data = await _client
          .from('posts')
          .select(_postSelect)
          .eq('reply_to_id', postId)
          .order('created_at');

      return (data as List).map((row) => _mapPostRow(row, userId)).toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final currentUserId = _client.auth.currentUser!.id;
      final data = await _client
          .from('posts')
          .select(_postSelect)
          .eq('user_id', userId)
          .isFilter('reply_to_id', null)
          .order('created_at', ascending: false);

      return (data as List)
          .map((row) => _mapPostRow(row, currentUserId))
          .toList();
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  PostModel _mapPostRow(Map<String, dynamic> row, String currentUserId) {
    final user = row['users'] as Map<String, dynamic>;

    // Check is_liked/is_reposted from joined data or RPC result
    bool isLiked = row['is_liked'] ?? false;
    bool isReposted = row['is_reposted'] ?? false;

    // When using _postSelect with left joins, likes/reposts are arrays
    if (row['likes'] is List) {
      isLiked = (row['likes'] as List)
          .any((l) => l['user_id'] == currentUserId);
    }
    if (row['reposts'] is List) {
      isReposted = (row['reposts'] as List)
          .any((r) => r['user_id'] == currentUserId);
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
  }
}
