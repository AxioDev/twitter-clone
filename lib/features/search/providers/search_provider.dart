import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/models/app_user.dart';
import '../../post/models/post_model.dart';
import '../repositories/search_repository.dart';

part 'search_provider.g.dart';

@riverpod
SearchRepository searchRepository(Ref ref) => SearchRepository();

@riverpod
Future<List<AppUser>> searchUsers(Ref ref, String query) {
  if (query.trim().isEmpty) return Future.value([]);
  return ref.watch(searchRepositoryProvider).searchUsers(query.trim());
}

@riverpod
Future<List<PostModel>> searchPosts(Ref ref, String query) {
  if (query.trim().isEmpty) return Future.value([]);
  return ref.watch(searchRepositoryProvider).searchPosts(query.trim());
}
