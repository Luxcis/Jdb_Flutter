import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/movie_still_thumbnail.dart';

Future<void> _pumpThumbnail(
  WidgetTester tester, {
  required String url,
  VoidCallback? onTap,
}) async {
  resetStillThumbnailAspectMemo();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 92,
            child: MovieStillThumbnail(url, onTap: onTap),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _pumpedAspect(WidgetTester tester) =>
    tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;

Finder _thumbnailFinder(String url) => find.byWidgetPredicate(
      (w) => w is MovieStillThumbnail && w.url == url,
      skipOffstage: false,
    );

double _aspectByUrl(String url, WidgetTester tester) => tester
    .widget<AspectRatio>(
      find
          .descendant(
            of: _thumbnailFinder(url),
            matching: find.byType(AspectRatio),
          )
          .first,
    )
    .aspectRatio;

var _urlSeed = 0;
String _randomUrl() => 'screenshots/memo-${_urlSeed++}.jpg';

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
    await _pumpThumbnail(tester, url: _randomUrl());
    expect(_pumpedAspect(tester), closeTo(16 / 9, 0.0001));
  });

  testWidgets('图片解码后按真实宽高比自适应', (tester) async {
    await _pumpThumbnail(tester, url: _randomUrl());

    tester
        .widget<CachedImage>(find.byType(CachedImage))
        .onImageSize!(const Size(240, 160));
    await tester.pump();

    expect(_pumpedAspect(tester), closeTo(1.5, 0.0001));
  });

  testWidgets('竖图解码后钳制到下限 1.0', (tester) async {
    await _pumpThumbnail(tester, url: _randomUrl());

    tester
        .widget<CachedImage>(find.byType(CachedImage))
        .onImageSize!(const Size(90, 200));
    await tester.pump();

    expect(_pumpedAspect(tester), 1.0);
  });

  testWidgets('超宽图解码后钳制到上限 21:9', (tester) async {
    await _pumpThumbnail(tester, url: _randomUrl());

    tester
        .widget<CachedImage>(find.byType(CachedImage))
        .onImageSize!(const Size(700, 200));
    await tester.pump();

    expect(_pumpedAspect(tester), closeTo(21 / 9, 0.0001));
  });

  testWidgets('点击缩略图触发 onTap', (tester) async {
    var tapped = false;
    await _pumpThumbnail(tester, url: _randomUrl(), onTap: () => tapped = true);

    await tester.tap(find.byType(MovieStillThumbnail));

    expect(tapped, isTrue);
  });

  // 长列表回滑场景公用的横向剧照列表。
  final rowController = ScrollController();
  Widget longStillsRow() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 92,
            child: ListView.separated(
              controller: rowController,
              scrollDirection: Axis.horizontal,
              itemCount: 60,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => MovieStillThumbnail(
                'screenshots/item-$index.jpg',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

  CachedImage cachedImageOf(String url, WidgetTester tester) =>
      tester.widget<CachedImage>(
        find.descendant(
          of: _thumbnailFinder(url),
          matching: find.byType(CachedImage),
        ),
      );

  testWidgets('长列表：解码后滚出可见区域再滚回，第一帧恢复记忆比例', (tester) async {
    const targetUrl = 'screenshots/item-2.jpg';
    await tester.pumpWidget(longStillsRow());
    await tester.pump();
    resetStillThumbnailAspectMemo();

    // 目标缩略图解码回调更新比例并写入记忆。
    cachedImageOf(targetUrl, tester).onImageSize!(const Size(240, 160));
    await tester.pump();
    expect(_aspectByUrl(targetUrl, tester), closeTo(1.5, 0.0001));

    // 滑到最右，目标滑出缓存范围、State 销毁。
    final controller = rowController;
    final maxScroll = controller.position.maxScrollExtent;
    controller.jumpTo(maxScroll);
    await tester.pump();
    await tester.pump();
    expect(
      _thumbnailFinder(targetUrl),
      findsNothing,
      reason: '目标应已滑出缓存范围',
    );

    // 滚回：不触发任何解码回调，第一帧即恢复记忆中的比例。
    controller.jumpTo(0);
    await tester.pump();
    expect(_thumbnailFinder(targetUrl), findsOneWidget);
    expect(_aspectByUrl(targetUrl, tester), closeTo(1.5, 0.0001));
  });

  testWidgets('长列表：同一 URL 重挂载后宽度与首次展示一致', (tester) async {
    const targetUrl = 'screenshots/item-2.jpg';
    await tester.pumpWidget(longStillsRow());
    await tester.pump();
    cachedImageOf(targetUrl, tester).onImageSize!(const Size(240, 160));    await tester.pump();
    expect(_aspectByUrl(targetUrl, tester), closeTo(1.5, 0.0001));
    final firstSize = tester.getSize(_thumbnailFinder(targetUrl));

    // 销毁整棵树再重建同一列表：新 State 不经解码回调即应有相同宽度。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(longStillsRow());
    await tester.pump();

    expect(rememberedStillThumbnailAspect(targetUrl), closeTo(1.5, 0.0001));
    expect(tester.getSize(_thumbnailFinder(targetUrl)), firstSize);
  });
}
