import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
sealed class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String username,
    required String displayName,
    @Default('') String bio,
    String? avatarUrl,
    required DateTime createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
