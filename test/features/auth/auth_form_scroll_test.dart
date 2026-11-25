// test/features/auth/auth_form_scroll_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/features/auth/screens/login_screen.dart';
import 'package:jade/features/auth/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _NullTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

class _MemoryCredentialStore implements LoginCredentialStore {
  @override
  Future<SavedLoginCredentials> read() async => const SavedLoginCredentials();

  @override
  Future<void> save({
    required String username,
    required String password,
  }) async {}

  @override
  Future<void> clearPassword() async {}
}

Widget _scaledApp(GoRouter router) => MaterialApp.router(
  routerConfig: router,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child ?? const SizedBox.shrink(),
  ),
);

void _applyTightViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = const FakeViewPadding(bottom: 200);
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ApiClient.create(
      prefs: prefs,
      tokenProvider: _NullTokenProvider(),
      onAuthError: () {},
    );
  });

  testWidgets('登录页在大字号与键盘弹起时可滚动到提交按钮且不溢出', (tester) async {
    _applyTightViewport(tester);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              LoginScreen(credentialStore: _MemoryCredentialStore()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_scaledApp(router));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final buttonRect = tester.getRect(
      find.widgetWithText(ElevatedButton, '登录'),
    );
    expect(buttonRect.bottom, lessThanOrEqualTo(480));
  });

  testWidgets('注册页在键盘弹起与大字号时错误提示可滚动到达且不溢出', (tester) async {
    _applyTightViewport(tester);
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_scaledApp(router));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'user@example.invalid');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'different-password');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '注册'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('两次密码不一致'), findsOneWidget);

    await tester.ensureVisible(find.text('两次密码不一致'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final errorRect = tester.getRect(find.text('两次密码不一致'));
    expect(errorRect.bottom, lessThanOrEqualTo(480));
  });
}
