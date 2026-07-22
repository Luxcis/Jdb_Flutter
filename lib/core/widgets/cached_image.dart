import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/image_decryptor.dart';

class CachedImage extends StatelessWidget {
  const CachedImage(
    this.url, {
    super.key,
    this.aspect,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackAsset,
    this.semanticLabel,
  });

  final String url;
  final double? aspect;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? fallbackAsset;
  final String? semanticLabel;

  String get _fullUrl {
    if (url.startsWith('http')) return url;
    final endpoint =
        ApiClient.instanceOrNull?.domainManager.imageEndpoint ??
        AppConstants.fallbackImageCdn;
    return '$endpoint$url';
  }

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: _fullUrl,
      cacheManager: JdbImageCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, _) => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, _, _) => fallbackAsset == null
          ? const Center(child: Icon(Icons.broken_image))
          : Image.asset(fallbackAsset!, width: width, height: height, fit: fit),
    );
    final label = semanticLabel;
    if (label == null) return image;
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: image,
    );
  }
}
