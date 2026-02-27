import 'package:mocktail/mocktail.dart';
import 'package:twitter_clone/features/auth/repositories/auth_repository.dart';
import 'package:twitter_clone/features/feed/repositories/feed_repository.dart';
import 'package:twitter_clone/features/notifications/repositories/notification_repository.dart';
import 'package:twitter_clone/features/post/repositories/post_repository.dart';
import 'package:twitter_clone/features/profile/repositories/profile_repository.dart';
import 'package:twitter_clone/features/search/repositories/search_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPostRepository extends Mock implements PostRepository {}

class MockFeedRepository extends Mock implements FeedRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockSearchRepository extends Mock implements SearchRepository {}
