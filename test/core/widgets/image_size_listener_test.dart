import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/image_size_listener.dart';

Future<ui.Image> _createImage(int width, int height) {
  final completer = Completer<ui.Image>();
  final pixels = Uint8List(width * height * 4)
    ..fillRange(0, width * height * 4, 255);
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// 在真实事件循环中解码图片，避免原生异步解码被 FakeAsync 挂起。
Future<ui.Image> _createTestImage(
  WidgetTester tester,
  int width,
  int height,
) async {
  final imageOrNull = await tester.runAsync(() => _createImage(width, height));
  return imageOrNull!;
}

class _FixedSizeImageProvider extends ImageProvider<Object> {
  const _FixedSizeImageProvider(this.image, {this.synchronous = false});

  final ui.Image image;

  /// true 时以同步 Future 交付，模拟缓存同步命中。
  final bool synchronous;

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      synchronous
          ? SynchronousFuture<ImageInfo>(ImageInfo(image: image))
          : Future<ImageInfo>.delayed(
              const Duration(milliseconds: 1),
              () => ImageInfo(image: image),
            ),
    );
  }
}

Future<void> _pumpListener(
  WidgetTester tester, {
  required ImageProvider<Object> imageProvider,
  required ValueChanged<Size> onImageSize,
  Size mediaQuerySize = const Size(400, 300),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: mediaQuerySize),
        child: ImageSizeListener(
          imageProvider: imageProvider,
          onImageSize: onImageSize,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('图片异步解码完成后回调真实尺寸', (tester) async {
    final image = await _createTestImage(tester, 320, 200);
    final sizes = <Size>[];
    await _pumpListener(
      tester,
      imageProvider: _FixedSizeImageProvider(image),
      onImageSize: sizes.add,
    );
    await tester.pumpAndSettle();

    expect(sizes, [const Size(320, 200)]);
    image.dispose();
  });

  testWidgets('缓存同步命中时帧末回调，不在 build 中触发异常', (tester) async {
    final image = await _createTestImage(tester, 80, 80);
    final sizes = <Size>[];
    await _pumpListener(
      tester,
      imageProvider: _FixedSizeImageProvider(image, synchronous: true),
      onImageSize: sizes.add,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(sizes, [const Size(80, 80)]);
    image.dispose();
  });

  testWidgets('provider 变化时重新订阅并回调新尺寸', (tester) async {
    final image1 = await _createTestImage(tester, 100, 100);
    final image2 = await _createTestImage(tester, 400, 100);
    final sizes = <Size>[];
    await _pumpListener(
      tester,
      imageProvider: _FixedSizeImageProvider(image1),
      onImageSize: sizes.add,
    );
    await tester.pumpAndSettle();

    await _pumpListener(
      tester,
      imageProvider: _FixedSizeImageProvider(image2),
      onImageSize: sizes.add,
    );
    await tester.pumpAndSettle();

    expect(sizes, const [Size(100, 100), Size(400, 100)]);
    image1.dispose();
    image2.dispose();
  });

  testWidgets('重新订阅时尺寸未变不重复回调', (tester) async {
    final image = await _createTestImage(tester, 100, 100);
    final provider = _FixedSizeImageProvider(image, synchronous: true);
    final sizes = <Size>[];
    await _pumpListener(tester, imageProvider: provider, onImageSize: sizes.add);
    expect(sizes, [const Size(100, 100)]);

    // MediaQuery 变化触发 didChangeDependencies 重新订阅，同一尺寸不应重复回调。
    await _pumpListener(
      tester,
      imageProvider: provider,
      onImageSize: sizes.add,
      mediaQuerySize: const Size(800, 600),
    );
    await tester.pump();

    expect(sizes, [const Size(100, 100)]);
    image.dispose();
  });
}
