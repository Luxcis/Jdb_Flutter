// test/core/widgets/image_gallery_viewer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/image_gallery_viewer.dart';
import 'package:photo_view/photo_view_gallery.dart';

Future<void> _openViewer(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-viewer'),
              onPressed: () => showDialog<void>(
                context: context,
                useSafeArea: false,
                builder: (_) => const ImageGalleryViewer(
                  urls: [
                    'https://img.example.com/a.jpg',
                    'https://img.example.com/b.jpg',
                  ],
                  initialIndex: 1,
                ),
              ),
              child: const Text('打开预览'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('open-viewer')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('显示黑底图库与计数标题，初始定位到指定页', (tester) async {
    await _openViewer(tester);

    expect(find.byKey(const Key('image-gallery-viewer')), findsOneWidget);
    expect(find.byType(PhotoViewGallery), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('默认页内图片为 CachedImage 且 contain 适配', (tester) async {
    await _openViewer(tester);

    final page = find.byKey(const Key('image-gallery-page-1'));
    expect(page, findsOneWidget);
    final image = tester.widget<CachedImage>(
      page,
    );
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('左右滑动切换并更新计数，关闭按钮可退出', (tester) async {
    await _openViewer(tester);

    await tester.drag(find.byType(PhotoViewGallery), const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('image-gallery-viewer')), findsNothing);
  });
}
