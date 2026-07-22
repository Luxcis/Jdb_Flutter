import 'package:flutter/material.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:provider/provider.dart';

enum MovieImageVariant { thumbnail, cover }

class MovieCoverImage extends StatelessWidget {
  const MovieCoverImage(
    this.url, {
    super.key,
    required this.variant,
    this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final MovieImageVariant variant;
  final String? semanticLabel;
  final double? width;
  final double? height;
  final BoxFit fit;

  String get fallbackAsset => switch (variant) {
    MovieImageVariant.thumbnail => 'assets/images/noimage_147x200.jpg',
    MovieImageVariant.cover => 'assets/images/noimage_600x404.jpg',
  };

  @override
  Widget build(BuildContext context) {
    final blur = context.watch<SettingsProvider?>()?.blurMovieImages ?? true;
    return CachedImage(
      url,
      width: width,
      height: height,
      fit: fit,
      fallbackAsset: fallbackAsset,
      semanticLabel: semanticLabel,
      blur: blur,
    );
  }
}
