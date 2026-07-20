import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AuthProvider> _createAuth(bool logged) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    if (logged) {
      await auth.login(token: 'tok', user: {'id': 1});
    }
    return auth;
  }

  testWidgets('未登录访问 protectedRoutes 重定向到 /login',
      (tester) async {
    final auth = await _createAuth(false);
    final router = AppRouter.build();
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
    final auth = await _createAuth(true);
    final router = AppRouter.build();
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
    final auth = await _createAuth(true);
    final router = AppRouter.build();
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
    final auth = await _createAuth(false);
    final router = AppRouter.build();
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
}
