import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/core/exceptions/app_exception.dart';
import 'package:twitter_clone/features/auth/repositories/auth_repository.dart';

import 'supabase_test_client.dart';

void main() {
  group('AuthRepository Integration Tests', () {
    group('signIn', () {
      test('signs in with valid credentials and returns AppUser', () async {
        final client = createClient();
        final repo = AuthRepository(client);

        final user = await repo.signIn(
          email: 'alice@demo.com',
          password: demoPassword,
        );

        expect(user.id, aliceId);
        expect(user.username, 'alice');
        expect(user.displayName, 'Alice Johnson');
      });

      test('throws AuthException for wrong password', () async {
        final client = createClient();
        final repo = AuthRepository(client);

        expect(
          () => repo.signIn(email: 'alice@demo.com', password: 'wrongpass'),
          throwsA(isA<AuthException>()),
        );
      });

      test('throws AuthException for non-existent email', () async {
        final client = createClient();
        final repo = AuthRepository(client);

        expect(
          () => repo.signIn(
            email: 'nobody@demo.com',
            password: demoPassword,
          ),
          throwsA(isA<AuthException>()),
        );
      });
    });

    group('signUp', () {
      String? createdUserId;

      tearDownAll(() async {
        if (createdUserId != null) {
          await cleanupUser(createdUserId!);
        }
      });

      test('creates new auth user and public users row', () async {
        final client = createClient();
        final repo = AuthRepository(client);
        final ts = DateTime.now().millisecondsSinceEpoch;

        final user = await repo.signUp(
          email: 'test_signup_$ts@test.com',
          password: demoPassword,
          username: 'testuser_$ts',
          displayName: 'Test User',
        );

        createdUserId = user.id;
        expect(user.username, 'testuser_$ts');
        expect(user.displayName, 'Test User');

        // Verify user exists in DB via admin
        final admin = createAdminClient();
        final row = await admin
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        expect(row, isNotNull);
        expect(row!['username'], 'testuser_$ts');
      });

      test('throws for duplicate email', () async {
        final client = createClient();
        final repo = AuthRepository(client);

        // alice@demo.com already exists
        expect(
          () => repo.signUp(
            email: 'alice@demo.com',
            password: demoPassword,
            username: 'alice_dup',
            displayName: 'Dup',
          ),
          throwsA(isA<AuthException>()),
        );
      });
    });

    group('signOut', () {
      test('clears current session', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = AuthRepository(client);

        expect(client.auth.currentUser, isNotNull);
        await repo.signOut();
        expect(client.auth.currentUser, isNull);
      });
    });

    group('getCurrentUser', () {
      test('returns AppUser when signed in', () async {
        final client = await authenticatedClient('bob@demo.com');
        final repo = AuthRepository(client);

        final user = await repo.getCurrentUser();
        expect(user, isNotNull);
        expect(user!.username, 'bob');
      });

      test('returns null when not signed in', () async {
        final client = createClient();
        final repo = AuthRepository(client);

        final user = await repo.getCurrentUser();
        expect(user, isNull);
      });
    });

    group('currentUserId', () {
      test('returns correct ID when signed in', () async {
        final client = await authenticatedClient('alice@demo.com');
        final repo = AuthRepository(client);

        expect(repo.currentUserId, aliceId);
      });

      test('returns null when not signed in', () async {
        final client = createClient();
        final repo = AuthRepository(client);

        expect(repo.currentUserId, isNull);
      });
    });
  });
}
