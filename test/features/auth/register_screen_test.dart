import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/auth/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _NullTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

/// 装配带 FakeAdapter 的 ApiClient 并渲染注册页。
///
/// [response] 为空时不入队任何响应；仅用于不应发起请求的校验分支。
Future<({FakeAdapter adapter, GoRouter router})> _pumpRegister(
  WidgetTester tester, {
  String location = '/register',
  Map<String, dynamic>? response,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _NullTokenProvider(),
    onAuthError: () {},
  );
  final adapter = FakeAdapter();
  if (response != null) {
    adapter.enqueue(Endpoints.users, response);
  }
  api.setAdapterForTest(adapter);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/login',
        builder: (c, s) => const Scaffold(body: Text('登录页')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return (adapter: adapter, router: router);
}

Future<void> _fillForm(
  WidgetTester tester, {
  String email = 'test@test.com',
  String password = 'password123',
  String confirm = 'password123',
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  await tester.enterText(fields.at(2), confirm);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'RegisterScreen 渲染邮箱、密码、确认密码输入框和注册按钮',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('注册'), findsWidgets);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('已有账号？去登录'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  testWidgets('邮箱和密码输入框可交互', (tester) async {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@test.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'password123');

    expect(find.text('test@test.com'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('密码少于 6 位时提示且不发起注册请求', (tester) async {
    final subject = await _pumpRegister(tester);

    await _fillForm(tester, password: '12345', confirm: '12345');
    await _submit(tester);

    expect(find.text('密码至少6位'), findsOneWidget);
    expect(subject.adapter.requests, isEmpty);
    expect(subject.router.state.uri.path, '/register');
  });

  testWidgets('注册成功后跳转登录页并保留 from 参数', (tester) async {
    final subject = await _pumpRegister(
      tester,
      location: '/register?from=/profile/favorites',
      response: {
        'success': 1,
        'data': {'id': 1, 'email': 'test@test.com'},
      },
    );

    await _fillForm(tester);
    await _submit(tester);

    expect(subject.adapter.requests.single.path, Endpoints.users);
    expect(subject.router.state.uri.path, '/login');
    expect(
      subject.router.state.uri.queryParameters['from'],
      '/profile/favorites',
    );
    expect(find.text('登录页'), findsOneWidget);
  });
}
