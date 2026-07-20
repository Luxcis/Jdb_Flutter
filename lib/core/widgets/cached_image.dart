import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/constants/app_constants.dart';

class CachedImage extends StatelessWidget {
  const CachedImage(
    this.url, {
    super.key,
    this.aspect,
    this.width,
    this.height,
  });

  final String url;
  final double? aspect;
  final double? width;
  final double? height;

  String get _fullUrl =>
      url.startsWith('http') ? url : '${AppConstants.imageCdnBase}$url';

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _fullUrl,
      fit: BoxFit.cover,
      width: width,
      height: height,
      placeholder: (_, _) => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image)),
    );
  }
}
