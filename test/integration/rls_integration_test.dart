import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_test_client.dart';

void main() {
  group('RLS Policy Tests', () {
    group('Users table', () {
      test('anyone can SELECT users', () async {
        final client = await authenticatedClient('alice@demo.com');
        final users = await client.from('users').select('id, username');

        expect(users.length, greaterThanOrEqualTo(8));
      });

      test('cannot UPDATE another user\'s profile', () async {
        final client = await authenticatedClient('alice@demo.com');

        // Alice tries to update bob's bio
        await client
            .from('users')
            .update({'bio': 'hacked by alice'}).eq('id', bobId);

        // Verify bob's bio unchanged via admin
        final admin = createAdminClient();
        final row =
            await admin.from('users').select('bio').eq('id', bobId).single();
        expect(row['bio'], isNot('hacked by alice'));
      });
    });

    group('Posts table', () {
      test('anyone can SELECT posts', () async {
        final client = await authenticatedClient('alice@demo.com');
        final posts = await client.from('posts').select('id').limit(50);

        expect(posts.length, greaterThanOrEqualTo(25));
      });

      test('cannot INSERT post with other user_id', () async {
        final client = await authenticatedClient('alice@demo.com');

        // Alice tries to insert a post as bob
        try {
          await client.from('posts').insert({
            'user_id': bobId,
            'content': '[TEST-RLS] fake post as bob',
          });
          fail('Should have thrown');
        } on PostgrestException catch (e) {
          // RLS violation
          expect(e.code, isNotNull);
        }
      });

      test('cannot DELETE another user\'s post', () async {
        final client = await authenticatedClient('alice@demo.com');

        // Alice tries to delete bob's post
        await client.from('posts').delete().eq('id', bobPost2);

        // Verify post still exists
        final admin = createAdminClient();
        final row = await admin
            .from('posts')
            .select()
            .eq('id', bobPost2)
            .maybeSingle();
        expect(row, isNotNull);
      });
    });

    group('Likes table', () {
      test('cannot INSERT like with other user_id', () async {
        final client = await authenticatedClient('alice@demo.com');

        try {
          await client.from('likes').insert({
            'user_id': bobId, // alice pretends to be bob
            'post_id': carolPost1,
          });
          fail('Should have thrown');
        } on PostgrestException catch (e) {
          expect(e.code, isNotNull);
        }
      });

      test('cannot DELETE another user\'s like', () async {
        // Bob liked bobPost1 (post 2) in seed? Let's check a known like.
        // Alice liked bobPost1 (10000000-...-02).
        // Bob also liked alice's post. Let's use: alice tries to delete bob's like on alice's post.
        final client = await authenticatedClient('alice@demo.com');

        // Alice tries to delete bob's like
        await client
            .from('likes')
            .delete()
            .eq('user_id', bobId)
            .eq('post_id', alicePost1);

        // Verify bob's like still exists
        final admin = createAdminClient();
        final row = await admin
            .from('likes')
            .select()
            .eq('user_id', bobId)
            .eq('post_id', alicePost1)
            .maybeSingle();
        expect(row, isNotNull);
      });
    });

    group('Reposts table', () {
      test('cannot INSERT repost with other user_id', () async {
        final client = await authenticatedClient('alice@demo.com');

        try {
          await client.from('reposts').insert({
            'user_id': bobId,
            'post_id': carolPost1,
          });
          fail('Should have thrown');
        } on PostgrestException catch (e) {
          expect(e.code, isNotNull);
        }
      });

      test('cannot DELETE another user\'s repost', () async {
        // Find a known repost — alice reposted davePost1 (10000000-...-04)
        // Bob tries to delete alice's repost
        final client = await authenticatedClient('bob@demo.com');

        await client
            .from('reposts')
            .delete()
            .eq('user_id', aliceId)
            .eq('post_id', davePost1);

        // Verify alice's repost still exists
        final admin = createAdminClient();
        final row = await admin
            .from('reposts')
            .select()
            .eq('user_id', aliceId)
            .eq('post_id', davePost1)
            .maybeSingle();
        expect(row, isNotNull);
      });
    });

    group('Followers table', () {
      test('cannot INSERT follow as different follower', () async {
        final client = await authenticatedClient('alice@demo.com');

        try {
          // Alice pretends to make bob follow frank
          await client.from('followers').insert({
            'follower_id': bobId,
            'following_id': frankId,
          });
          fail('Should have thrown');
        } on PostgrestException catch (e) {
          expect(e.code, isNotNull);
        }
      });

      test('cannot DELETE another user\'s follow', () async {
        // Alice follows bob in seed. Carol tries to delete alice's follow.
        final client = await authenticatedClient('carol@demo.com');

        await client
            .from('followers')
            .delete()
            .eq('follower_id', aliceId)
            .eq('following_id', bobId);

        // Verify alice still follows bob
        final admin = createAdminClient();
        final row = await admin
            .from('followers')
            .select()
            .eq('follower_id', aliceId)
            .eq('following_id', bobId)
            .maybeSingle();
        expect(row, isNotNull);
      });
    });

    group('Notifications table', () {
      test('can only SELECT own notifications', () async {
        final client = await authenticatedClient('alice@demo.com');
        final notifs =
            await client.from('notifications').select('id, user_id');

        for (final n in notifs) {
          expect(n['user_id'], aliceId,
              reason: 'Should only see own notifications');
        }
      });

      test('cannot UPDATE another user\'s notification', () async {
        // Get a notification belonging to bob via admin
        final admin = createAdminClient();
        final bobNotif = await admin
            .from('notifications')
            .select('id, is_read')
            .eq('user_id', bobId)
            .eq('is_read', false)
            .limit(1)
            .maybeSingle();

        if (bobNotif != null) {
          // Alice tries to mark bob's notification as read
          final client = await authenticatedClient('alice@demo.com');
          await client
              .from('notifications')
              .update({'is_read': true}).eq('id', bobNotif['id']);

          // Verify it's still unread
          final check = await admin
              .from('notifications')
              .select('is_read')
              .eq('id', bobNotif['id'])
              .single();
          expect(check['is_read'], false);
        }
      });

      test('unauthenticated user cannot INSERT posts', () async {
        final client = createClient(); // no auth

        try {
          await client.from('posts').insert({
            'user_id': aliceId,
            'content': '[TEST-RLS] unauthenticated post',
          });
          fail('Should have thrown');
        } on PostgrestException catch (e) {
          expect(e.code, isNotNull);
        }
      });
    });
  });
}
