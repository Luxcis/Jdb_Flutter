import 'package:flutter/material.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// 剧照缩略图加载完成前的默认占位宽高比。
const double kStillThumbnailPlaceholderAspect = 16 / 9;

/// 缩略图宽高比下限，防止竖图把格子压得过窄。
const double kStillThumbnailMinAspect = 1.0;

/// 缩略图宽高比上限，防止超宽图把格子拉得过长。
const double kStillThumbnailMaxAspect = 21 / 9;

/// 将图片实际宽高比限制在缩略图安全比例范围内。
double clampStillThumbnailAspect(double aspect) =>
    aspect.clamp(kStillThumbnailMinAspect, kStillThumbnailMaxAspect);

/// 剧照缩略图：高度由父级（横向列表）约束，宽度按图片实际宽高比自适应，
/// 完整显示图片；加载完成前按 16:9 占位。
class MovieStillThumbnail extends StatefulWidget {
  const MovieStillThumbnail(this.url, {super.key, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  State<MovieStillThumbnail> createState() => _MovieStillThumbnailState();
}

class _MovieStillThumbnailState extends State<MovieStillThumbnail> {
  double _aspect = kStillThumbnailPlaceholderAspect;

  void _handleImageSize(Size size) {
    if (!mounted || size.height <= 0) return;
    final aspect = clampStillThumbnailAspect(size.width / size.height);
    if ((aspect - _aspect).abs() < 0.0001) return;
    setState(() => _aspect = aspect);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _aspect,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: widget.onTap,
          child: CachedImage(widget.url, onImageSize: _handleImageSize),
        ),
      ),
    );
  }
}
