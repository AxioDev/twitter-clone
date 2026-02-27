import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/core/exceptions/app_exception.dart';
import 'package:twitter_clone/features/profile/repositories/profile_repository.dart';

import 'supabase_test_client.dart';

void main() {
  group('ProfileRepository Integration Tests', () {
    group('getProfile', () {
      test('own profile has isOwnProfile=true', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        final profile = await repo.getProfile(aliceId);

        expect(profile.isOwnProfile, true);
        expect(profile.isFollowing, false);
        expect(profile.user.username, 'alice');
        expect(profile.user.displayName, 'Alice Johnson');
      });

      test('followed user has isFollowing=true', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        // Alice follows bob
        final profile = await repo.getProfile(bobId);

        expect(profile.isOwnProfile, false);
        expect(profile.isFollowing, true);
      });

      test('non-followed user has isFollowing=false', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        // Alice does NOT follow frank
        final profile = await repo.getProfile(frankId);

        expect(profile.isOwnProfile, false);
        expect(profile.isFollowing, false);
      });

      test('returns correct follower/following/post counts', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        final profile = await repo.getProfile(aliceId);

        // Alice: 6 followers (bob, carol, dave, emma, grace, henry)
        expect(profile.followersCount, 6);
        // Alice follows: bob, carol, dave, emma, grace = 5
        expect(profile.followingCount, 5);
        // Alice has 4 main posts (excluding replies)
        expect(profile.postsCount, 4);
      });
    });

    group('updateProfile', () {
      test('updates displayName', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        await repo.updateProfile(displayName: 'Henry Updated');
        final profile = await repo.getProfile(henryId);
        expect(profile.user.displayName, 'Henry Updated');

        // Restore
        await repo.updateProfile(displayName: 'Henry Park');
      });

      test('updates bio', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        await repo.updateProfile(bio: 'Updated bio for test');
        final profile = await repo.getProfile(henryId);
        expect(profile.user.bio, 'Updated bio for test');

        // Restore
        await repo.updateProfile(
            bio: 'Startup founder | Full-stack dev | Building the future');
      });
    });

    group('followUser / unfollowUser', () {
      test('followUser creates relationship', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        // Alice doesn't follow frank in seed
        await repo.followUser(frankId);
        final profile = await repo.getProfile(frankId);
        expect(profile.isFollowing, true);

        // Cleanup
        await repo.unfollowUser(frankId);
      });

      test('unfollowUser removes relationship', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        await repo.followUser(frankId);
        await repo.unfollowUser(frankId);
        final profile = await repo.getProfile(frankId);
        expect(profile.isFollowing, false);
      });

      test('cannot follow self (CHECK constraint)', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        expect(
          () => repo.followUser(aliceId),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('duplicate follow throws (unique constraint)', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        // Alice already follows bob in seed
        expect(
          () => repo.followUser(bobId),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('getFollowers', () {
      test('returns list of followers', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        final followers = await repo.getFollowers(aliceId);

        expect(followers.length, 6);
        final followerUsernames =
            followers.map((u) => u.username).toSet();
        expect(followerUsernames, contains('bob'));
        expect(followerUsernames, contains('carol'));
        expect(followerUsernames, contains('henry'));
      });
    });

    group('getFollowing', () {
      test('returns list of users being followed', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = ProfileRepository(client);

        final following = await repo.getFollowing(aliceId);

        expect(following.length, 5);
        final followingUsernames =
            following.map((u) => u.username).toSet();
        expect(followingUsernames, contains('bob'));
        expect(followingUsernames, contains('carol'));
        expect(followingUsernames, contains('dave'));
        expect(followingUsernames, contains('emma'));
        expect(followingUsernames, contains('grace'));
      });
    });
  });
}
