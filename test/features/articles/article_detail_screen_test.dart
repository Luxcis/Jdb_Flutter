import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/features/articles/screens/article_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FakeAdapter> _pumpDetail(
  WidgetTester tester, {
  String content = '<p>正文第一段</p><p>正文第二段</p>',
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'key_baseurl': 'https://jdforrepam.com',
    'key_api_domains': ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: auth.logout,
  );
  final adapter = FakeAdapter();
  api.setAdapterForTest(adapter);
  adapter.enqueue('${Endpoints.articles}/1', {
    'success': 1,
    'data': {
      'id': 1,
      'title': '详情标题',
      'author': {'name': '作者D'},
      'category': '新作',
      'image_domain': 'https://img.example.com',
      'content': content,
      'released_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2))
          .toIso8601String(),
    },
  });

  await tester.pumpWidget(const MaterialApp(home: ArticleDetailPage(id: '1')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('渲染标题、作者、分类、发布日期', (tester) async {
    await _pumpDetail(tester);

    expect(find.text('详情标题'), findsOneWidget);
    expect(find.text('作者D'), findsOneWidget);
    expect(find.text('新作'), findsOneWidget);
    expect(find.textContaining('天前'), findsOneWidget);
  });

  testWidgets('渲染正文 HTML', (tester) async {
    await _pumpDetail(tester);

    expect(find.text('正文第一段'), findsOneWidget);
    expect(find.text('正文第二段'), findsOneWidget);
  });

  testWidgets('正文网络图片使用 CachedImage 渲染', (tester) async {
    await _pumpDetail(
      tester,
      content: '<p>正文</p><img src="https://img.example.com/a.jpg">',
    );

    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('加载失败显示重试并可恢复', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'key_baseurl': 'https://jdforrepam.com',
      'key_api_domains': ['https://jdforrepam.com'],
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: auth,
      onAuthError: auth.logout,
    );
    final adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    adapter.enqueueSequence('${Endpoints.articles}/1', [
      {'success': 0, 'message': 'boom'},
      {
        'success': 1,
        'data': {
          'id': 1,
          'title': '恢复标题',
          'content': '<p>恢复正文</p>',
        },
      },
    ]);

    await tester.pumpWidget(const MaterialApp(home: ArticleDetailPage(id: '1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('恢复标题'), findsOneWidget);
    expect(find.text('恢复正文'), findsOneWidget);
  });

  test('resolveArticleImageUrls 拼接相对图片地址', () {
    expect(
      resolveArticleImageUrls(
        '<img src="https://img.example.com/a.jpg">',
        'https://img.example.com',
      ),
      '<img src="https://img.example.com/a.jpg">',
    );
    expect(
      resolveArticleImageUrls(
        '<img src="/images/a.jpg">',
        'https://img.example.com',
      ),
      '<img src="https://img.example.com/images/a.jpg">',
    );
    expect(
      resolveArticleImageUrls(
        '<img src="a.jpg">',
        '//img.example.com',
      ),
      '<img src="https://img.example.com/a.jpg">',
    );
    expect(
      resolveArticleImageUrls('<img src="/a.jpg">', null),
      '<img src="/a.jpg">',
    );
    expect(
      resolveArticleImageUrls(
        '<img src="//cdn.x.com/a.jpg">',
        'https://img.example.com',
      ),
      '<img src="https://cdn.x.com/a.jpg">',
    );
    expect(
      resolveArticleImageUrls(
        '<img src="data:image/png;base64,abc">',
        'https://img.example.com',
      ),
      '<img src="data:image/png;base64,abc">',
    );
    expect(
      resolveArticleImageUrls(
        '<img src="HTTPS://img.example.com/a.jpg">',
        'https://img.example.com',
      ),
      '<img src="HTTPS://img.example.com/a.jpg">',
    );
  });
}
