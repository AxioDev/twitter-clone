import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
sealed class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    required String userId,
    required String actorId,
    required String type,
    String? postId,
    required bool isRead,
    required DateTime createdAt,
    @Default('') String actorUsername,
    @Default('') String actorDisplayName,
    String? actorAvatarUrl,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}

/// Parse from Supabase row with nested actor data
NotificationModel notificationFromRow(Map<String, dynamic> row) {
  final actor = row['actor'] as Map<String, dynamic>?;
  return NotificationModel(
    id: row['id'],
    userId: row['user_id'],
    actorId: row['actor_id'],
    type: row['type'],
    postId: row['post_id'],
    isRead: row['is_read'] ?? false,
    createdAt: DateTime.parse(row['created_at']),
    actorUsername: actor?['username'] ?? '',
    actorDisplayName: actor?['display_name'] ?? '',
    actorAvatarUrl: actor?['avatar_url'],
  );
}
