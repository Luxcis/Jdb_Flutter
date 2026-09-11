import 'package:flutter/widgets.dart';

/// 监听 [imageProvider] 解码出的真实图像尺寸，尺寸变化时回调 [onImageSize]。
///
/// 用于按图片实际宽高比自适应布局；图片加载失败时不回调。
class ImageSizeListener extends StatefulWidget {
  const ImageSizeListener({
    super.key,
    required this.imageProvider,
    required this.onImageSize,
    this.child,
  });

  final ImageProvider<Object> imageProvider;
  final ValueChanged<Size> onImageSize;
  final Widget? child;

  @override
  State<ImageSizeListener> createState() => _ImageSizeListenerState();
}

class _ImageSizeListenerState extends State<ImageSizeListener> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _lastSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribe();
  }

  @override
  void didUpdateWidget(ImageSizeListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _lastSize = null;
      _subscribe();
    }
  }

  void _subscribe() {
    _stream?.removeListener(_listener!);
    final listener = ImageStreamListener(_onImage, onError: (_, _) {});
    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    if (_lastSize == size) return;
    _lastSize = size;
    if (synchronousCall) {
      // resolve 可能发生在 build 期间（缓存同步命中），帧末回调避免打断 build。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onImageSize(size);
      });
    } else {
      widget.onImageSize(size);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
