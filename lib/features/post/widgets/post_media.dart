import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PostMedia extends StatelessWidget {
  final String url;

  const PostMedia({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (_, __) => Container(
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }
}
