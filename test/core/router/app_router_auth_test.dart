import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';

Widget _buildApp(AuthProvider auth) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp.router(routerConfig: AppRouter.build()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('未登录访问 protectedRoutes 重定向到 /login',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await tester.pumpWidget(_buildApp(auth));
    await tester.pump(const Duration(milliseconds: 500));

    final router =
        GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.profileWantWatch);
    await tester.pump();

    final loc = router.state.uri.toString();
    expect(loc, contains('/login'));
    expect(loc, contains('from='));
  });

  testWidgets('已登录访问 /login 重定向到 /home', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(token: 'tok', user: {'id': 1});
    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();

    final router =
        GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go('/login');
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.state.matchedLocation, AppRoutes.home);
  });

  testWidgets('已登录访问 protectedRoutes 正常放行', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(token: 'tok', user: {'id': 1});
    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();

    final router =
        GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.profileWantWatch);
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.state.matchedLocation, AppRoutes.profileWantWatch);
  });

  testWidgets('未登录访问非受保护路由正常放行', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();

    final router =
        GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.home);
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.state.matchedLocation, AppRoutes.home);
  });
}
