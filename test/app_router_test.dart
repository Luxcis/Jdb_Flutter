import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';

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
}
