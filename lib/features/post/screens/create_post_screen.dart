import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/post_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? replyToId;

  const CreatePostScreen({super.key, this.replyToId});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _controller = TextEditingController();
  Uint8List? _mediaBytes;
  String? _mediaExtension;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (result != null) {
      final bytes = await result.readAsBytes();
      final ext = result.name.split('.').last.toLowerCase();
      setState(() {
        _mediaBytes = bytes;
        _mediaExtension = ext.isNotEmpty ? ext : 'jpg';
      });
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _submitting = true);

    try {
      await ref.read(createPostProvider.notifier).submit(
            content: content,
            mediaBytes: _mediaBytes,
            mediaExtension: _mediaExtension,
            replyToId: widget.replyToId,
          );
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = AppConstants.maxPostLength - _controller.text.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.replyToId != null ? 'Reply' : 'New Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed:
                  _submitting || _controller.text.trim().isEmpty ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(80, 36),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                maxLength: AppConstants.maxPostLength,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: "What's happening?",
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_mediaBytes != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _mediaBytes!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _mediaBytes = null;
                    _mediaExtension = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                const Spacer(),
                Text(
                  '$remaining',
                  style: TextStyle(
                    color: remaining < 0
                        ? Colors.red
                        : remaining < 20
                            ? Colors.orange
                            : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
