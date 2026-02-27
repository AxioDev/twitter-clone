import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (result == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await result.readAsBytes();
      await ref.read(profileRepositoryProvider).uploadAvatar(bytes);
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        ref.invalidate(profileProvider(userId));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            displayName: _displayNameController.text.trim(),
            bio: _bioController.text.trim(),
          );
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        ref.invalidate(profileProvider(userId));
        ref.invalidate(currentUserProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox();

    final profileAsync = ref.watch(profileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _loading ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(80, 36)),
              child: _loading
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(profileProvider(userId)),
        ),
        data: (profile) {
          if (!_initialized) {
            _displayNameController.text = profile.user.displayName;
            _bioController.text = profile.user.bio;
            _initialized = true;
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      AvatarWidget(
                        imageUrl: profile.user.avatarUrl,
                        fallbackText: profile.user.displayName,
                        radius: 48,
                      ),
                      const CircleAvatar(
                        radius: 16,
                        child: Icon(Icons.camera_alt, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                  maxLength: AppConstants.maxDisplayNameLength,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLength: AppConstants.maxBioLength,
                  maxLines: 3,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
