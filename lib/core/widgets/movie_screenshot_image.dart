import 'package:flutter/material.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:provider/provider.dart';

class MovieScreenshotImage extends StatelessWidget {
  const MovieScreenshotImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final blur = context.watch<SettingsProvider?>()?.blurMovieImages ?? true;
    return CachedImage(url, width: width, height: height, fit: fit, blur: blur);
  }
}
