import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

@freezed
sealed class PostModel with _$PostModel {
  const factory PostModel({
    required String id,
    required String userId,
    required String content,
    String? mediaUrl,
    String? replyToId,
    required DateTime createdAt,
    @Default(0) int likesCount,
    @Default(0) int repostsCount,
    @Default(0) int repliesCount,
    required String username,
    required String displayName,
    String? avatarUrl,
    @Default(false) bool isLiked,
    @Default(false) bool isReposted,
  }) = _PostModel;

  factory PostModel.fromJson(Map<String, dynamic> json) =>
      _$PostModelFromJson(json);
}
