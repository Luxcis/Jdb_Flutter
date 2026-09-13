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

/// 缩略图 URL → 已解码宽高比记忆。
///
/// 横向懒构建列表会销毁滑出缓存范围的缩略图；重新挂载时若无此记忆会先按
/// 16:9 占位再被异步解码回调改宽，造成回滑时列表项宽度二次变化、滚动被
/// 反复修正（闪回）。同一 URL 的图片比例恒定，按 URL 只增不改地共享。
final _stillThumbnailAspectMemo = <String, double>{};

/// 取该 URL 已记住的宽高比；从未解码过时为 null。
double? rememberedStillThumbnailAspect(String url) =>
    _stillThumbnailAspectMemo[url];

@visibleForTesting
void resetStillThumbnailAspectMemo() => _stillThumbnailAspectMemo.clear();

class _MovieStillThumbnailState extends State<MovieStillThumbnail> {
  double _aspect = kStillThumbnailPlaceholderAspect;

  @override
  void initState() {
    super.initState();
    _aspect =
        rememberedStillThumbnailAspect(widget.url) ??
        kStillThumbnailPlaceholderAspect;
  }

  void _handleImageSize(Size size) {
    if (!mounted || size.height <= 0) return;
    final aspect = clampStillThumbnailAspect(size.width / size.height);
    _stillThumbnailAspectMemo[widget.url] = aspect;
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
