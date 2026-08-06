// test/features/articles/cached_image_html_extension_test.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/features/articles/widgets/cached_image_html_extension.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Future<void> _pumpHtml(WidgetTester tester, String data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Html(
            data: data,
            extensions: const [CachedImageHtmlExtension()],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('网络图片使用 CachedImage 渲染', (tester) async {
    await _pumpHtml(tester, '<p>正文</p><img src="https://img.example.com/a.jpg">');
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('base64 图片不渲染为 CachedImage', (tester) async {
    await _pumpHtml(tester, '<img src="data:image/png;base64,$_onePixelPngBase64">');
    expect(find.byType(CachedImage), findsNothing);
  });

  testWidgets('asset 图片不渲染为 CachedImage', (tester) async {
    await _pumpHtml(tester, '<img src="asset:assets/images/noimage_147x200.jpg">');
    expect(find.byType(CachedImage), findsNothing);
  });

  testWidgets('svg 图片不渲染为 CachedImage', (tester) async {
    await _pumpHtml(tester, '<img src="https://img.example.com/a.svg">');
    expect(find.byType(CachedImage), findsNothing);
  });

  testWidgets('带查询参数的 svg 不渲染为 CachedImage', (tester) async {
    await _pumpHtml(
      tester,
      '<img src="https://img.example.com/a.svg?v=1">',
    );
    expect(find.byType(CachedImage), findsNothing);
  });

  testWidgets('正文图片跟随全局模糊开关', (tester) async {
    SharedPreferences.setMockInitialValues({StorageKeys.blurMovieImages: false});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Html(
                data: '<img src="https://img.example.com/a.jpg">',
                extensions: const [CachedImageHtmlExtension()],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageBuilder, isNull);

    await settings.setBlurMovieImages(true);
    await tester.pump();
    networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageBuilder, isNotNull);
  });
}
