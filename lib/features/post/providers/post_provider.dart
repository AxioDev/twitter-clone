import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/post_model.dart';
import '../repositories/post_repository.dart';

part 'post_provider.g.dart';

@riverpod
PostRepository postRepository(Ref ref) => PostRepository();

@riverpod
Future<PostModel> postDetail(Ref ref, String postId) {
  return ref.watch(postRepositoryProvider).getPostById(postId);
}

@riverpod
Future<List<PostModel>> postReplies(Ref ref, String postId) {
  return ref.watch(postRepositoryProvider).getReplies(postId);
}

@riverpod
Future<List<PostModel>> userPosts(Ref ref, String userId) {
  return ref.watch(postRepositoryProvider).getUserPosts(userId);
}

