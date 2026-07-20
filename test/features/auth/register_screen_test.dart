import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('RegisterPage 渲染邮箱、密码、确认密码输入框和注册按钮',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (c, s) => const RegisterPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('注册'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('已有账号？去登录'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('邮箱和密码输入框可交互', (tester) async {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (c, s) => const RegisterPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@test.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'password123');

    expect(find.text('test@test.com'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
