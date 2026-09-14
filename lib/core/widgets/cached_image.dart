import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/image_decryptor.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/widgets/image_size_listener.dart';
import 'package:provider/provider.dart';

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
    this.onImageSize,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String url;
  final double? aspect;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? fallbackAsset;
  final String? semanticLabel;

  /// 图片真实尺寸解码后回调；加载失败或未提供时不回调。
  final ValueChanged<Size>? onImageSize;

  /// 内存缓存位图的目标尺寸；小槽位应传入以避免解码整张原图。
  final int? memCacheWidth;
  final int? memCacheHeight;

  String get _fullUrl {
    if (url.startsWith('http')) return url;
    final endpoint =
        ApiClient.instanceOrNull?.domainManager.imageEndpoint ??
        AppConstants.fallbackImageCdn;
    return '$endpoint$url';
  }

  @override
  Widget build(BuildContext context) {
    // select 精确订阅：仅模糊开关变化时才重建。
    final blurEnabled = context.select<SettingsProvider?, bool>(
      (s) => s?.blurMovieImages ?? true,
    );
    Widget image = CachedNetworkImage(
      imageUrl: _fullUrl,
      cacheManager: JdbImageCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      imageBuilder: blurEnabled
          ? (_, imageProvider) => ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Image(
                  image: imageProvider,
                  width: width,
                  height: height,
                  fit: fit,
                ),
              ),
            )
          : null,
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
    if (label != null) {
      image = Semantics(
        image: true,
        label: label,
        excludeSemantics: true,
        child: image,
      );
    }
    final onSize = onImageSize;
    if (onSize == null) return image;
    return ImageSizeListener(
      imageProvider: CachedNetworkImageProvider(
        _fullUrl,
        cacheManager: JdbImageCacheManager.instance,
      ),
      onImageSize: onSize,
      child: image,
    );
  }
}
