import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/articles/screens/articles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FakeAdapter> _pumpArticles(WidgetTester tester) async {
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
  adapter.enqueue(Endpoints.articles, {
    'success': 1,
    'data': {
      'articles': [
        {
          'id': 1,
          'title': '资讯一',
          'author': {'name': '作者A'},
          'category': '业界',
          'released_at': '2026-08-05',
          'cover_url': 'cover1.jpg',
        },
      ],
      'current_page': 1,
    },
  });

  await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('渲染 AppBar 标题与资讯卡片', (tester) async {
    await _pumpArticles(tester);

    expect(find.text('AV资讯'), findsOneWidget);
    expect(find.text('资讯一'), findsOneWidget);
    expect(find.text('作者A'), findsOneWidget);
    expect(find.text('业界'), findsOneWidget);
  });

  testWidgets('首屏加载失败显示重试并可恢复', (tester) async {
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
    adapter.enqueueSequence(Endpoints.articles, [
      {'success': 0, 'message': 'boom'},
      {
        'success': 1,
        'data': {
          'articles': [
            {'id': 1, 'title': '恢复成功'},
          ],
          'current_page': 1,
        },
      },
    ]);

    await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('恢复成功'), findsOneWidget);
  });

  testWidgets('滚动到底部触发分页加载下一页', (tester) async {
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
    adapter.enqueueSequence(Endpoints.articles, [
      {
        'success': 1,
        'data': {
          'articles': [
            for (var i = 0; i < 48; i++)
              {'id': i, 'title': '第1页-$i'},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'articles': [
            {'id': 48, 'title': '第2页-0'},
          ],
          'current_page': 2,
        },
      },
    ]);

    await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // 循环滚动到接近底部，直到第二页请求发出
    for (var i = 0; i < 12 && adapter.requests.length < 2; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -1600),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('第2页-0'), findsOneWidget);
  });
}
