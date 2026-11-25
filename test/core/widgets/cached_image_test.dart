import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/image_decryptor.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/image_size_listener.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> _createSettings({bool blur = true}) async {
  SharedPreferences.setMockInitialValues({StorageKeys.blurMovieImages: blur});
  final prefs = await SharedPreferences.getInstance();
  return SettingsProvider.create(prefs);
}

Future<void> _pumpWithSettings(
  WidgetTester tester,
  SettingsProvider settings,
  Widget child,
) {
  return tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(home: child),
    ),
  );
}

void main() {
  testWidgets('相对路径自动拼接 CDN 前缀', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CachedImage('covers/test.jpg')),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, '${AppConstants.fallbackImageCdn}covers/test.jpg');
  });

  testWidgets('http 开头的 URL 不拼接 CDN', (tester) async {
    const url = 'https://other.cdn/covers/test.jpg';
    await tester.pumpWidget(const MaterialApp(home: CachedImage(url)));
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, url);
  });

  testWidgets('支持 width/height 参数并透传给 CachedNetworkImage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('covers/test.jpg', width: 100, height: 100),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.width, 100);
    expect(image.height, 100);
  });

  testWidgets('memCache 尺寸透传，尺寸监听复用同一有界 provider', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CachedImage(
          'screenshots/test.jpg',
          memCacheHeight: 492,
          onImageSize: (_) {},
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheHeight, 492);

    final listener = tester.widget<ImageSizeListener>(
      find.byType(ImageSizeListener),
    );
    final provider = listener.imageProvider;
    expect(provider, isA<ResizeImage>());
    final resized = provider as ResizeImage;
    expect(resized.height, 492);
    expect(resized.width, isNull);
    expect(resized.imageProvider, isA<CachedNetworkImageProvider>());
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

  testWidgets('blur 开启时成功加载的网络图片使用模糊层', (tester) async {
    final settings = await _createSettings(blur: true);
    await _pumpWithSettings(
      tester,
      settings,
      const CachedImage(
        'covers/test.jpg',
        fallbackAsset: 'assets/images/noimage_600x404.jpg',
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
    final settings = await _createSettings(blur: false);
    await _pumpWithSettings(
      tester,
      settings,
      const CachedImage('covers/test.jpg'),
    );

    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageBuilder, isNull);
  });

  testWidgets('blur 开启时普通图片也配置模糊构建器', (tester) async {
    final settings = await _createSettings(blur: true);
    await _pumpWithSettings(
      tester,
      settings,
      const CachedImage('covers/test.jpg'),
    );

    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageBuilder, isNotNull);
  });

  // 该用例会写入 ApiClient 单例，必须放在文件末尾，避免影响其他用例。
  testWidgets('配置了自定义 imageEndpoint 时使用该域名前缀', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _FakeTokenProvider(),
      onAuthError: () {},
    );
    await api.domainManager.applyStartup(
      const BackupDomains(
        apiDomains: ['https://api.example.com'],
        imageEndpoint: 'https://custom.cdn/img/',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: CachedImage('covers/test.jpg')),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://custom.cdn/img/covers/test.jpg');
  });
}

class _FakeTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}
