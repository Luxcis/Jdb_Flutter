import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/features/profile/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('主动退出清除密码但保留用户名', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'cached-user',
        password: 'cached-password',
      ),
    );
    final subject = await _pumpProfile(tester, credentialStore: store);

    await tester.scrollUntilVisible(
      find.text('退出登录'),
      200,
      scrollable: find.byType(Scrollable),
    );
    // 删除"个人资料"cell 后，ensureVisible 的滚动量可能不足以让
    // 列表尾部完全进入视口，这里补一次显式滚动确保可点击。
    await tester.drag(
      find.byType(Scrollable),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(store.clearPasswordCalls, 1);
    expect(store.credentials.username, 'cached-user');
    expect(store.credentials.password, isNull);
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/home');
  });

  testWidgets('清除密码失败时仍完成主动退出', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'cached-user',
        password: 'cached-password',
      ),
      clearPasswordError: StateError('secure delete failed'),
    );
    final subject = await _pumpProfile(tester, credentialStore: store);

    await tester.scrollUntilVisible(
      find.text('退出登录'),
      200,
      scrollable: find.byType(Scrollable),
    );
    // 同上：补一次显式滚动确保列表尾部完全进入视口。
    await tester.drag(
      find.byType(Scrollable),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(store.clearPasswordCalls, 1);
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/home');
  });
}

Future<({AuthProvider auth, GoRouter router})> _pumpProfile(
  WidgetTester tester, {
  required LoginCredentialStore credentialStore,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  await auth.login(
    token: 'test-token',
    user: {'id': 1, 'username': 'test-user'},
  );

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            ProfilePage(credentialStore: credentialStore),
      ),
      GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return (auth: auth, router: router);
}

final class _MemoryLoginCredentialStore implements LoginCredentialStore {
  _MemoryLoginCredentialStore({
    required this.credentials,
    this.clearPasswordError,
  });

  SavedLoginCredentials credentials;
  final Object? clearPasswordError;
  var clearPasswordCalls = 0;

  @override
  Future<SavedLoginCredentials> read() async => credentials;

  @override
  Future<void> save({
    required String username,
    required String password,
  }) async {
    credentials = SavedLoginCredentials(username: username, password: password);
  }

  @override
  Future<void> clearPassword() async {
    clearPasswordCalls++;
    if (clearPasswordError case final error?) throw error;
    credentials = SavedLoginCredentials(username: credentials.username);
  }
}
