import 'package:flutter/material.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// 资讯封面图片。
///
/// 等比例缩放逻辑与 [MovieCoverImage] 保持一致：默认 [BoxFit.cover] 填充，
/// 并在 URL 为空或加载失败时显示统一兜底图。
class ArticleCoverImage extends StatelessWidget {
  const ArticleCoverImage(
    this.url, {
    super.key,
    this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? url;
  final String? semanticLabel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;

  static const String _fallbackAsset = 'assets/images/noimage_600x404.jpg';

  @override
  Widget build(BuildContext context) {
    final coverUrl = url;
    if (coverUrl == null || coverUrl.isEmpty) {
      return Image.asset(
        _fallbackAsset,
        width: width,
        height: height,
        fit: fit,
      );
    }

    return CachedImage(
      coverUrl,
      width: width,
      height: height,
      fit: fit,
      fallbackAsset: _fallbackAsset,
      semanticLabel: semanticLabel,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
    );
  }
}
