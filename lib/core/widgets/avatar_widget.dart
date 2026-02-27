import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(imageUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      child: Text(
        (fallbackText ?? '?').substring(0, 1).toUpperCase(),
        style: TextStyle(fontSize: radius * 0.8),
      ),
    );
  }
}
