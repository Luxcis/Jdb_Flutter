import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/movie_still_thumbnail.dart';

Future<void> _pumpThumbnail(
  WidgetTester tester, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 92,
            child: MovieStillThumbnail('screenshots/test.jpg', onTap: onTap),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _pumpedAspect(WidgetTester tester) =>
    tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;

void main() {
  test('宽高比钳制：占位与常规比例保持不变', () {
    expect(clampStillThumbnailAspect(16 / 9), closeTo(16 / 9, 0.0001));
    expect(clampStillThumbnailAspect(4 / 3), closeTo(4 / 3, 0.0001));
  });

  test('宽高比钳制：竖图与超宽图限制在 [1.0, 21/9]', () {
    expect(clampStillThumbnailAspect(0.6), 1.0);
    expect(clampStillThumbnailAspect(3.5), closeTo(21 / 9, 0.0001));
  });

  testWidgets('加载完成前按 16:9 占位', (tester) async {
    await _pumpThumbnail(tester);
    expect(_pumpedAspect(tester), closeTo(16 / 9, 0.0001));
  });

  testWidgets('图片解码后按真实宽高比自适应', (tester) async {
    await _pumpThumbnail(tester);

    tester
        .widget<CachedImage>(find.byType(CachedImage))
        .onImageSize!(const Size(240, 160));
    await tester.pump();

    expect(_pumpedAspect(tester), closeTo(1.5, 0.0001));
  });

  testWidgets('竖图解码后钳制到下限 1.0', (tester) async {
    await _pumpThumbnail(tester);

    tester
        .widget<CachedImage>(find.byType(CachedImage))
        .onImageSize!(const Size(90, 200));
    await tester.pump();

    expect(_pumpedAspect(tester), 1.0);
  });

  testWidgets('超宽图解码后钳制到上限 21:9', (tester) async {
    await _pumpThumbnail(tester);

    tester
        .widget<CachedImage>(find.byType(CachedImage))
        .onImageSize!(const Size(700, 200));
    await tester.pump();

    expect(_pumpedAspect(tester), closeTo(21 / 9, 0.0001));
  });

  testWidgets('点击缩略图触发 onTap', (tester) async {
    var tapped = false;
    await _pumpThumbnail(tester, onTap: () => tapped = true);

    await tester.tap(find.byType(MovieStillThumbnail));

    expect(tapped, isTrue);
  });
}
