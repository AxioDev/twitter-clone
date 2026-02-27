import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory storage for GoTrue PKCE flow in tests.
class InMemoryAsyncStorage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

const supabaseUrl = 'http://127.0.0.1:54321';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const supabaseServiceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const demoPassword = 'password123';

// Demo user IDs
const aliceId = 'a1111111-1111-1111-1111-111111111111';
const bobId = 'b2222222-2222-2222-2222-222222222222';
const carolId = 'c3333333-3333-3333-3333-333333333333';
const daveId = 'd4444444-4444-4444-4444-444444444444';
const emmaId = 'e5555555-5555-5555-5555-555555555555';
const frankId = 'f6666666-6666-6666-6666-666666666666';
const graceId = 'a7777777-7777-7777-7777-777777777777';
const henryId = 'b8888888-8888-8888-8888-888888888888';

// Seed post IDs (main posts, not replies)
const alicePost1 = '10000000-0000-0000-0000-000000000001'; // 5 likes, 2 replies
const bobPost1 = '10000000-0000-0000-0000-000000000002'; // 4 likes, 3 replies
const carolPost1 = '10000000-0000-0000-0000-000000000003'; // 3 likes, 0 replies
const davePost1 = '10000000-0000-0000-0000-000000000004'; // 6 likes, 2 replies
const bobPost2 = '10000000-0000-0000-0000-000000000007'; // 0 likes, 0 replies (good for testing)
const frankPost1 = '10000000-0000-0000-0000-000000000008'; // 7 likes, 3 replies

SupabaseClient createClient() => SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: AuthClientOptions(
        pkceAsyncStorage: InMemoryAsyncStorage(),
      ),
    );

SupabaseClient createAdminClient() => SupabaseClient(
      supabaseUrl,
      supabaseServiceRoleKey,
      authOptions: AuthClientOptions(
        pkceAsyncStorage: InMemoryAsyncStorage(),
      ),
    );

Future<SupabaseClient> authenticatedClient(String email) async {
  final client = createClient();
  await client.auth.signInWithPassword(
    email: email,
    password: demoPassword,
  );
  return client;
}

Future<void> cleanupPosts(List<String> postIds) async {
  if (postIds.isEmpty) return;
  final admin = createAdminClient();
  for (final id in postIds) {
    await admin.from('likes').delete().eq('post_id', id);
    await admin.from('reposts').delete().eq('post_id', id);
    await admin.from('notifications').delete().eq('post_id', id);
    await admin.from('posts').delete().eq('reply_to_id', id);
    await admin.from('posts').delete().eq('id', id);
  }
}

Future<void> cleanupUser(String userId) async {
  final admin = createAdminClient();
  await admin.from('users').delete().eq('id', userId);
  await admin.auth.admin.deleteUser(userId);
}
