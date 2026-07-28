import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AuthProvider> createAuth(bool logged) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    if (logged) {
      await auth.login(token: 'tok', user: {'id': 1});
    }
    return auth;
  }

  test('生产路由默认从启动页开始', () {
    final router = AppRouter.build();
    addTearDown(router.dispose);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.startup);
  });

  testWidgets('未登录访问 protectedRoutes 重定向到 /login', (tester) async {
    final auth = await createAuth(false);
    final router = AppRouter.build(initialLocation: AppRoutes.home);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    router.go(AppRoutes.profileWantWatch);
    await tester.pump(const Duration(milliseconds: 100));

    final loc = router.state.uri.toString();
    expect(loc, contains('/login'));
    expect(loc, contains('from='));
  });

  testWidgets('已登录访问 /login 重定向到 /home', (tester) async {
    final auth = await createAuth(true);
    final router = AppRouter.build(initialLocation: AppRoutes.home);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    router.go('/login');
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.matchedLocation, AppRoutes.home);
  });

  testWidgets('已登录访问 protectedRoutes 正常放行', (tester) async {
    final auth = await createAuth(true);
    final router = AppRouter.build(initialLocation: AppRoutes.home);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    router.go(AppRoutes.profileWantWatch);
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.matchedLocation, AppRoutes.profileWantWatch);
  });

  testWidgets('未登录访问非受保护路由正常放行', (tester) async {
    final auth = await createAuth(false);
    final router = AppRouter.build(initialLocation: AppRoutes.home);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    router.go(AppRoutes.home);
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.matchedLocation, AppRoutes.home);
  });

  testWidgets('从首页进入 rankings tab=hot 打开看热播 Tab', (tester) async {
    final auth = await createAuth(false);
    final router = AppRouter.buildForTest(initialLocation: '/rankings');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    router.go('/home');
    await tester.pump(const Duration(milliseconds: 100));
    router.go('/rankings?tab=hot');
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.uri.path, '/rankings');
    expect(router.state.uri.queryParameters['tab'], 'hot');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 1);
  });

  testWidgets('rankings 未携带 tab 参数时默认打开有码', (tester) async {
    final auth = await createAuth(false);
    final router = AppRouter.buildForTest(initialLocation: '/rankings');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 2);
  });

  testWidgets('全局认证失效从当前页面跳转登录并携带 from', (tester) async {
    final auth = await createAuth(true);
    final router = AppRouter.build(initialLocation: '/movie/m1');
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    AppRouter.goLoginForAuthError();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.matchedLocation, AppRoutes.login);
    expect(router.state.uri.queryParameters['from'], '/movie/m1');
  });
}
