import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/features/common/screens/common_list_page.dart';

class _FakeAuth extends ChangeNotifier implements TokenProvider {
  final String _token = 'tok';
  @override
  String? get token => _token;
  bool get isLogged => true;
  Map<String, dynamic>? get user => null;
  Future<void> login({
    required String token,
    required Map<String, dynamic> user,
  }) async {}
  Future<void> logout() async {}
  static _FakeAuth create() => _FakeAuth();
}

Widget _buildApp({String initialLocation = AppRoutes.home}) {
  return ChangeNotifierProvider<_FakeAuth>(
    create: (_) => _FakeAuth.create(),
    child: MaterialApp.router(
      routerConfig: AppRouter.buildForTest(initialLocation: initialLocation),
    ),
  );
}

void main() {
  testWidgets('AppRouter 渲染底导和首页', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('首页'), findsAtLeastNWidgets(1));
    expect(find.byType(NavigationBar), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('搜索结果路由缺少关键词时返回搜索入口页', (tester) async {
    final router = AppRouter.buildForTest(
      initialLocation: AppRoutes.searchResults,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeAuth>(
        create: (_) => _FakeAuth.create(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.search);
    expect(find.text('历史搜索'), findsNothing);
    expect(find.text('近期热搜'), findsNothing);
  });

  testWidgets('磁链搜索路由渲染搜索首页', (tester) async {
    final router = AppRouter.buildForTest(
      initialLocation: AppRoutes.magnetSearch,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeAuth>(
        create: (_) => _FakeAuth.create(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '搜索磁链...'), findsOneWidget);
  });

  testWidgets('磁链结果路由空查询时返回磁链搜索首页', (tester) async {
    final router = AppRouter.buildForTest(
      initialLocation: '/search/magnet/results?q=%20',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeAuth>(
        create: (_) => _FakeAuth.create(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.magnetSearch);
    expect(find.widgetWithText(TextField, '搜索磁链...'), findsOneWidget);
  });

  testWidgets('/reviews 渲染短评页面', (tester) async {
    await tester.pumpWidget(_buildApp(initialLocation: AppRoutes.reviews));
    await tester.pump();

    expect(find.text('看短评'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('/common-list 路由带参数渲染 CommonListPage', (tester) async {
    final router = AppRouter.buildForTest(
      initialLocation: Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '导演 - K太郎',
          'type': '0',
          'category': 'd',
          'id': 'AqK',
        },
      ).toString(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeAuth>(
        create: (_) => _FakeAuth.create(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<CommonListPage>(find.byType(CommonListPage));
    expect(page.title, '导演 - K太郎');
    expect(page.type, 0);
    expect(page.category, 'd');
    expect(page.id, 'AqK');
  });

  testWidgets('/common-list 路由缺参或非法 type 时走兜底', (tester) async {
    final router = AppRouter.buildForTest(
      initialLocation: Uri(
        path: AppRoutes.commonList,
        queryParameters: {'type': 'abc', 'title': '测试&系列#1'},
      ).toString(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeAuth>(
        create: (_) => _FakeAuth.create(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<CommonListPage>(find.byType(CommonListPage));
    expect(page.title, '测试&系列#1');
    expect(page.type, 0);
    expect(page.category, '');
    expect(page.id, '');
  });

  testWidgets('预告片路由缺少参数时显示安全错误页', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_buildApp(initialLocation: '/movie/m1/preview'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
  });
}
