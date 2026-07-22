import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/image_decryptor.dart';
import 'package:jade/core/widgets/cached_image.dart';

void main() {
  testWidgets('相对路径自动拼接 CDN 前缀', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CachedImage('covers/test.jpg')),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('http 开头的 URL 不拼接 CDN', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CachedImage('https://other.cdn/covers/test.jpg')),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('支持 width/height 参数', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('covers/test.jpg', width: 100, height: 100),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('使用图片解密缓存管理器加载网络图片', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CachedImage('https://cdn/covers/test.jpg')),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.cacheManager, same(JdbImageCacheManager.instance));
  });

  testWidgets('图片加载失败时使用指定本地资源', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage(
          'covers/missing.jpg',
          fallbackAsset: 'assets/images/noimage_600x404.jpg',
          semanticLabel: '测试封面',
        ),
      ),
    );

    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final fallback = networkImage.errorWidget!(
      tester.element(find.byType(CachedNetworkImage)),
      'covers/missing.jpg',
      Exception('load failed'),
    );
    await tester.pumpWidget(MaterialApp(home: fallback));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/noimage_600x404.jpg',
    );
  });

  testWidgets('blur 开启时仅成功加载的网络图片使用模糊层', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage(
          'covers/test.jpg',
          blur: true,
          fallbackAsset: 'assets/images/noimage_600x404.jpg',
        ),
      ),
    );

    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final context = tester.element(find.byType(CachedImage));
    final success = networkImage.imageBuilder!(
      context,
      const AssetImage('assets/images/noimage_600x404.jpg'),
    );
    final error = networkImage.errorWidget!(
      context,
      'covers/test.jpg',
      StateError('load failed'),
    );

    final clip = success as ClipRect;
    expect(clip.child, isA<ImageFiltered>());
    expect(error, isA<Image>());
    expect(error, isNot(isA<ImageFiltered>()));
  });

  testWidgets('blur 关闭时不配置成功图片模糊构建器', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CachedImage('covers/test.jpg')),
    );

    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageBuilder, isNull);
  });
}
