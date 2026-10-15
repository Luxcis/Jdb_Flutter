import 'package:flutter/material.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// 资讯封面图片。
///
/// 按图片真实宽高比等比例完整显示：宽度撑满父容器，高度自适应；
/// 等比高度超过 [ArticleCoverImage.maxHeightFactor] 倍容器宽度时，
/// 显示高度固定为该上限，图片仍等比例覆盖宽度并以顶部对齐裁剪
/// （保留图片顶部主体）。URL 为空或加载失败时显示统一兜底图。
class ArticleCoverImage extends StatefulWidget {
  const ArticleCoverImage(
    this.url, {
    super.key,
    this.semanticLabel,
    this.width,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? url;
  final String? semanticLabel;
  final double? width;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;

  static const String _fallbackAsset = 'assets/images/noimage_600x404.jpg';

  /// 等比显示高度的上限因子：高度超过「容器宽度 × [maxHeightFactor]」
  /// 即视为超高封面，固定显示高度并顶部对齐裁剪。
  @visibleForTesting
  static const double maxHeightFactor = 1.0;

  /// 由封面宽度与图片真实尺寸推导显示高度：
  /// 等比自然高度不超过正方形上限时原样显示，否则截断为上限。
  @visibleForTesting
  static double resolveDisplayHeight({
    required double coverWidth,
    required Size imageSize,
  }) {
    final naturalHeight = coverWidth * imageSize.height / imageSize.width;
    final maxSquarishHeight = coverWidth * maxHeightFactor;
    return naturalHeight > maxSquarishHeight ? maxSquarishHeight : naturalHeight;
  }

  @override
  State<ArticleCoverImage> createState() => _ArticleCoverImageState();
}

class _ArticleCoverImageState extends State<ArticleCoverImage> {
  Size? _imageSize;

  bool get _isEmptyUrl => widget.url == null || widget.url!.isEmpty;

  void _onImageSize(Size size) {
    if (!mounted) return;
    setState(() => _imageSize = size);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmptyUrl) {
      // 尚未确定图片尺寸，兜底图按 16:9 占位填满。
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(ArticleCoverImage._fallbackAsset, fit: widget.fit),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverWidth = widget.width ?? constraints.maxWidth;
        final imageSize = _imageSize;
        if (imageSize == null) {
          // 图片真实尺寸解锁前以 16:9 占位，避免塌陷或按原始尺寸溢出。
          final placeholderHeight = coverWidth * 9 / 16;
          return SizedBox(
            width: coverWidth,
            height: placeholderHeight,
            child: CachedImage(
              widget.url!,
              width: coverWidth,
              height: placeholderHeight,
              fit: widget.fit,
              fallbackAsset: ArticleCoverImage._fallbackAsset,
              semanticLabel: widget.semanticLabel,
              memCacheWidth: widget.memCacheWidth,
              memCacheHeight: widget.memCacheHeight,
              onImageSize: _onImageSize,
            ),
          );
        }
        final displayHeight = ArticleCoverImage.resolveDisplayHeight(
          coverWidth: coverWidth,
          imageSize: imageSize,
        );
        // 超高限高裁剪时取图顶部（人物主体通常位于上部）。
        final alignment =
            _isClipped(imageSize, coverWidth)
            ? Alignment.topCenter
            : Alignment.center;
        return SizedBox(
          width: coverWidth,
          height: displayHeight,
          child: CachedImage(
            widget.url!,
            width: coverWidth,
            height: displayHeight,
            fit: widget.fit,
            alignment: alignment,
            fallbackAsset: ArticleCoverImage._fallbackAsset,
            semanticLabel: widget.semanticLabel,
            memCacheWidth: widget.memCacheWidth,
            memCacheHeight: widget.memCacheHeight,
            onImageSize: _onImageSize,
          ),
        );
      },
    );
  }

  bool _isClipped(Size imageSize, double coverWidth) {
    final naturalHeight = coverWidth * imageSize.height / imageSize.width;
    final maxHeight = coverWidth * ArticleCoverImage.maxHeightFactor;
    return naturalHeight > maxHeight;
  }
}
