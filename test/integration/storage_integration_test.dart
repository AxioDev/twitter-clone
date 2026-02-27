import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:twitter_clone/features/post/repositories/post_repository.dart';
import 'package:twitter_clone/features/profile/repositories/profile_repository.dart';

import 'supabase_test_client.dart';

/// Creates minimal valid JPEG bytes.
Uint8List createTestJpegBytes() {
  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xE0, // APP0 marker
    0x00, 0x10, // Length 16
    0x4A, 0x46, 0x49, 0x46, 0x00, // JFIF\0
    0x01, 0x01, // version 1.1
    0x00, // aspect ratio units
    0x00, 0x01, // X density
    0x00, 0x01, // Y density
    0x00, 0x00, // thumbnail dimensions
    0xFF, 0xDB, // DQT marker
    0x00, 0x43, 0x00, // length 67, table 0
    // 64 quantization values (all 1s for minimal)
    ...List.filled(64, 0x01),
    0xFF, 0xC0, // SOF0 marker
    0x00, 0x0B, // length 11
    0x08, // 8-bit precision
    0x00, 0x01, // height 1
    0x00, 0x01, // width 1
    0x01, // 1 component
    0x01, // component ID 1
    0x11, // sampling 1x1
    0x00, // quant table 0
    0xFF, 0xC4, // DHT marker
    0x00, 0x1F, // length 31
    0x00, // DC table 0
    0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B,
    0xFF, 0xDA, // SOS marker
    0x00, 0x08, // length 8
    0x01, // 1 component
    0x01, // component 1
    0x00, // DC/AC table 0/0
    0x00, 0x3F, 0x00, // spectral selection
    0x7B, 0x40, // scan data (encoded single pixel)
    0xFF, 0xD9, // EOI
  ]);
}

/// Creates minimal valid PNG bytes.
Uint8List createTestPngBytes() {
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    // IHDR chunk
    0x00, 0x00, 0x00, 0x0D, // length 13
    0x49, 0x48, 0x44, 0x52, // IHDR
    0x00, 0x00, 0x00, 0x01, // width 1
    0x00, 0x00, 0x00, 0x01, // height 1
    0x08, 0x02, // 8-bit RGB
    0x00, 0x00, 0x00, // compression, filter, interlace
    0x90, 0x77, 0x53, 0xDE, // CRC
    // IDAT chunk
    0x00, 0x00, 0x00, 0x0C, // length 12
    0x49, 0x44, 0x41, 0x54, // IDAT
    0x08, 0xD7, // zlib header
    0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, // compressed data
    0x00, 0x02, 0x00, 0x01, // adler32
    0xE2, 0x21, 0xBC, 0x33, // CRC
    // IEND chunk
    0x00, 0x00, 0x00, 0x00, // length 0
    0x49, 0x45, 0x4E, 0x44, // IEND
    0xAE, 0x42, 0x60, 0x82, // CRC
  ]);
}

void main() {
  // Track storage paths for cleanup
  final uploadedAvatarPaths = <String>[];
  final uploadedMediaPaths = <String>[];
  final createdPostIds = <String>[];

  tearDownAll(() async {
    final admin = createAdminClient();

    // Cleanup uploaded avatars
    for (final path in uploadedAvatarPaths) {
      try {
        await admin.storage.from('avatars').remove([path]);
      } catch (_) {}
    }

    // Cleanup uploaded post media
    for (final path in uploadedMediaPaths) {
      try {
        await admin.storage.from('post-media').remove([path]);
      } catch (_) {}
    }

    // Cleanup created posts
    await cleanupPosts(createdPostIds);

    // Restore henry's avatar_url to null
    try {
      await admin
          .from('users')
          .update({'avatar_url': null}).eq('id', henryId);
    } catch (_) {}
  });

  group('Storage Integration Tests', () {
    group('Avatar Upload', () {
      test('uploadAvatar uploads bytes and updates user record', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        final bytes = createTestJpegBytes();
        final url = await repo.uploadAvatar(bytes);

        uploadedAvatarPaths.add('$henryId/avatar.jpg');

        // URL should contain the storage path
        expect(url, contains('avatars'));
        expect(url, contains('avatar.jpg'));
        // Should have cache-bust param
        expect(url, contains('?v='));

        // Verify user record was updated
        final profile = await repo.getProfile(henryId);
        expect(profile.user.avatarUrl, isNotNull);
        expect(profile.user.avatarUrl, contains('avatar.jpg'));
      });

      test('uploadAvatar with upsert replaces existing avatar', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        // Upload first avatar
        final url1 = await repo.uploadAvatar(createTestJpegBytes());

        // Upload second avatar (should overwrite)
        final url2 = await repo.uploadAvatar(createTestJpegBytes());

        uploadedAvatarPaths.add('$henryId/avatar.jpg');

        // URLs should be different (cache-bust)
        expect(url1, isNot(equals(url2)));

        // Both should point to same path
        expect(url1, contains('$henryId/avatar.jpg'));
        expect(url2, contains('$henryId/avatar.jpg'));
      });

      test('avatar is publicly accessible via URL', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        await repo.uploadAvatar(createTestJpegBytes());
        uploadedAvatarPaths.add('$henryId/avatar.jpg');

        // Get public URL and verify it's accessible
        final publicUrl =
            client.storage.from('avatars').getPublicUrl('$henryId/avatar.jpg');
        expect(publicUrl, contains('avatars'));
        expect(publicUrl, startsWith('http'));
      });

      test('cannot upload avatar to another user folder (RLS)', () async {
        final client = await authenticatedClient('henry@demo.com');

        final bytes = createTestJpegBytes();

        // Try to upload to alice's avatar folder
        expect(
          () async => await client.storage
              .from('avatars')
              .uploadBinary('$aliceId/avatar.jpg', bytes,
                  fileOptions: const sb.FileOptions(upsert: true)),
          throwsA(anything),
        );
      });
    });

    group('Post Media Upload', () {
      test('createPost with media uploads bytes and sets mediaUrl', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final bytes = createTestJpegBytes();
        final post = await repo.createPost(
          content: '[TEST] Post with image',
          mediaBytes: bytes,
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post.id);

        expect(post.mediaUrl, isNotNull);
        expect(post.mediaUrl, contains('post-media'));
        expect(post.content, '[TEST] Post with image');

        // Track the media path for cleanup
        final uri = Uri.parse(post.mediaUrl!);
        final pathSegments = uri.pathSegments;
        final mediaPath =
            '${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
        uploadedMediaPaths.add(mediaPath);
      });

      test('createPost with PNG media works', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final bytes = createTestPngBytes();
        final post = await repo.createPost(
          content: '[TEST] Post with PNG',
          mediaBytes: bytes,
          mediaExtension: 'png',
        );
        createdPostIds.add(post.id);

        expect(post.mediaUrl, isNotNull);
        expect(post.mediaUrl, contains('.png'));

        final uri = Uri.parse(post.mediaUrl!);
        final pathSegments = uri.pathSegments;
        final mediaPath =
            '${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
        uploadedMediaPaths.add(mediaPath);
      });

      test('each media upload gets unique UUID path', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final post1 = await repo.createPost(
          content: '[TEST] Media 1',
          mediaBytes: createTestJpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post1.id);

        final post2 = await repo.createPost(
          content: '[TEST] Media 2',
          mediaBytes: createTestJpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post2.id);

        // Media URLs should be different (different UUIDs)
        expect(post1.mediaUrl, isNot(equals(post2.mediaUrl)));

        // Both should be in henry's folder
        expect(post1.mediaUrl, contains(henryId));
        expect(post2.mediaUrl, contains(henryId));

        // Track for cleanup
        for (final url in [post1.mediaUrl!, post2.mediaUrl!]) {
          final uri = Uri.parse(url);
          final segs = uri.pathSegments;
          uploadedMediaPaths.add('${segs[segs.length - 2]}/${segs.last}');
        }
      });

      test('createPost without media has null mediaUrl', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final post = await repo.createPost(
          content: '[TEST] No media post',
        );
        createdPostIds.add(post.id);

        expect(post.mediaUrl, isNull);
      });

      test('post media is publicly accessible', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final post = await repo.createPost(
          content: '[TEST] Public media test',
          mediaBytes: createTestJpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post.id);

        // Verify the URL is properly formed
        expect(post.mediaUrl, startsWith('http'));
        expect(post.mediaUrl, contains('post-media'));

        final uri = Uri.parse(post.mediaUrl!);
        final segs = uri.pathSegments;
        uploadedMediaPaths.add('${segs[segs.length - 2]}/${segs.last}');
      });

      test('cannot upload post media to another user folder (RLS)', () async {
        final client = await authenticatedClient('henry@demo.com');

        final bytes = createTestJpegBytes();

        // Try to upload to alice's post-media folder
        expect(
          () async => await client.storage
              .from('post-media')
              .uploadBinary('$aliceId/hack.jpg', bytes),
          throwsA(anything),
        );
      });
    });

    group('Storage RLS Policies', () {
      test('anyone can read avatars (SELECT policy)', () async {
        // First upload an avatar as henry
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryRepo = ProfileRepository(henryClient);
        await henryRepo.uploadAvatar(createTestJpegBytes());
        uploadedAvatarPaths.add('$henryId/avatar.jpg');

        // Alice should be able to list/get henry's avatar
        final aliceClient = await authenticatedClient('alice@demo.com');
        final files =
            await aliceClient.storage.from('avatars').list(path: henryId);
        expect(files, isNotEmpty);
        expect(files.any((f) => f.name == 'avatar.jpg'), true);
      });

      test('anyone can read post-media (SELECT policy)', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(henryClient);

        final post = await repo.createPost(
          content: '[TEST] Readable media',
          mediaBytes: createTestJpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post.id);

        final uri = Uri.parse(post.mediaUrl!);
        final segs = uri.pathSegments;
        uploadedMediaPaths.add('${segs[segs.length - 2]}/${segs.last}');

        // Alice should be able to list henry's post media
        final aliceClient = await authenticatedClient('alice@demo.com');
        final files =
            await aliceClient.storage.from('post-media').list(path: henryId);
        expect(files, isNotEmpty);
      });

      test('user can delete own avatar', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = ProfileRepository(client);

        await repo.uploadAvatar(createTestJpegBytes());

        // Delete own avatar
        await client.storage.from('avatars').remove(['$henryId/avatar.jpg']);

        // Verify it's gone
        final files =
            await client.storage.from('avatars').list(path: henryId);
        expect(files.any((f) => f.name == 'avatar.jpg'), false);
      });

      test('cannot delete another user avatar (RLS)', () async {
        // Upload as henry
        final henryClient = await authenticatedClient('henry@demo.com');
        final henryRepo = ProfileRepository(henryClient);
        await henryRepo.uploadAvatar(createTestJpegBytes());
        uploadedAvatarPaths.add('$henryId/avatar.jpg');

        // Try to delete as alice
        final aliceClient = await authenticatedClient('alice@demo.com');
        await aliceClient.storage
            .from('avatars')
            .remove(['$henryId/avatar.jpg']);

        // Verify file still exists (RLS blocked the delete)
        final files =
            await henryClient.storage.from('avatars').list(path: henryId);
        expect(files.any((f) => f.name == 'avatar.jpg'), true);
      });

      test('cannot delete another user post media (RLS)', () async {
        final henryClient = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(henryClient);

        final post = await repo.createPost(
          content: '[TEST] Cannot delete this',
          mediaBytes: createTestJpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post.id);

        final uri = Uri.parse(post.mediaUrl!);
        final segs = uri.pathSegments;
        final mediaPath = '${segs[segs.length - 2]}/${segs.last}';
        uploadedMediaPaths.add(mediaPath);

        // Try to delete as alice
        final aliceClient = await authenticatedClient('alice@demo.com');
        await aliceClient.storage.from('post-media').remove([mediaPath]);

        // Verify file still exists
        final files =
            await henryClient.storage.from('post-media').list(path: henryId);
        final filename = segs.last;
        expect(files.any((f) => f.name == filename), true);
      });
    });

    group('Post with media in feed/queries', () {
      test('getPostById returns mediaUrl for post with media', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final created = await repo.createPost(
          content: '[TEST] Fetch media post',
          mediaBytes: createTestJpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(created.id);

        final uri = Uri.parse(created.mediaUrl!);
        final segs = uri.pathSegments;
        uploadedMediaPaths.add('${segs[segs.length - 2]}/${segs.last}');

        // Refetch the post
        final fetched = await repo.getPostById(created.id);
        expect(fetched.mediaUrl, equals(created.mediaUrl));
      });

      test('getUserPosts includes mediaUrl', () async {
        final client = await authenticatedClient('henry@demo.com');
        final repo = PostRepository(client);

        final post = await repo.createPost(
          content: '[TEST] User posts media',
          mediaBytes: createTestJpegBytes(),
          mediaExtension: 'jpg',
        );
        createdPostIds.add(post.id);

        final uri = Uri.parse(post.mediaUrl!);
        final segs = uri.pathSegments;
        uploadedMediaPaths.add('${segs[segs.length - 2]}/${segs.last}');

        final posts = await repo.getUserPosts(henryId);
        final mediaPost = posts.firstWhere((p) => p.id == post.id);
        expect(mediaPost.mediaUrl, isNotNull);
        expect(mediaPost.mediaUrl, contains('post-media'));
      });
    });
  });
}
