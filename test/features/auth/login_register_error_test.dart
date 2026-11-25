// test/features/auth/login_register_error_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/device/login_device_info_service.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/core/storage/testing/in_memory_secure_store.dart';
import 'package:jade/features/auth/screens/login_screen.dart';
import 'package:jade/features/auth/screens/register_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements LoginCredentialStore {
  SavedLoginCredentials credentials = const SavedLoginCredentials();
  var saveCalls = 0;

  @override
  Future<SavedLoginCredentials> read() async => credentials;

  @override
  Future<void> save({
    required String username,
    required String password,
  }) async {
    saveCalls++;
    credentials = SavedLoginCredentials(username: username, password: password);
  }

  @override
  Future<void> clearPassword() async {
    credentials = SavedLoginCredentials(username: credentials.username);
  }
}

final class _FakeDeviceParametersProvider
    implements LoginDeviceParametersProvider {
  @override
  Future<LoginDeviceParameters> load() async => const LoginDeviceParameters(
    deviceUuid: 'device-uuid',
    deviceName: 'Google',
    deviceModel: 'Pixel 9',
    systemVersion: '15',
  );
}

String _renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join('\n');

Future<({AuthProvider auth, FakeAdapter adapter, GoRouter router})>
_pumpLoginWithResponse(
  WidgetTester tester,
  Map<String, dynamic> response, {
  int statusCode = 200,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(
    prefs,
    secure: InMemorySecureValueStore(),
  );
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: () {},
  );
  final adapter = FakeAdapter();
  adapter.enqueue(Endpoints.sessions, response, statusCode: statusCode);
  api.setAdapterForTest(adapter);

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          deviceParametersProvider: _FakeDeviceParametersProvider(),
          credentialStore: _MemoryCredentialStore(),
        ),
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

  return (auth: auth, adapter: adapter, router: router);
}

Future<void> _submitLogin(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'user@example.invalid');
  await tester.enterText(fields.at(1), 'wrong-password');
  await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
  await tester.pumpAndSettle();
}

Future<void> _pumpRegister(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _NullTokenProvider(),
    onAuthError: () {},
  );
  final adapter = FakeAdapter();
  adapter.enqueue(Endpoints.users, {
    'success': 0,
    'action': 'ParameterInvalid',
    'message': '该邮箱已被注册',
  });
  api.setAdapterForTest(adapter);

  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登录服务端错误展示中文 message 而非 DioException 技术串', (tester) async {
    final subject = await _pumpLoginWithResponse(tester, {
      'success': 0,
      'action': 'ParameterInvalid',
      'message': '用户名或密码错误',
    });

    await _submitLogin(tester);

    expect(find.text('用户名或密码错误'), findsOneWidget);
    final rendered = _renderedText(tester);
    expect(rendered, isNot(contains('DioException')));
    expect(rendered, isNot(contains('ApiException')));
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/login');
  });

  testWidgets('登录成功响应缺少 token 时给出明确中文提示且不抛 TypeError', (tester) async {
    final subject = await _pumpLoginWithResponse(tester, {
      'success': 1,
      'data': {
        'user': {'id': 1, 'username': 'test'},
      },
    });

    await _submitLogin(tester);

    expect(find.text('登录响应缺少登录凭证，请稍后重试'), findsOneWidget);
    final rendered = _renderedText(tester);
    expect(rendered, isNot(contains('TypeError')));
    expect(rendered, isNot(contains('DioException')));
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/login');
  });

  testWidgets('登录成功响应缺少 user 时给出明确中文提示', (tester) async {
    await _pumpLoginWithResponse(tester, {
      'success': 1,
      'data': {'token': 'jwt-token'},
    });

    await _submitLogin(tester);

    expect(find.text('登录响应缺少登录凭证，请稍后重试'), findsOneWidget);
    expect(_renderedText(tester), isNot(contains('TypeError')));
  });

  testWidgets('登录成功响应缺少 data 时给出明确中文提示', (tester) async {
    await _pumpLoginWithResponse(tester, {'success': 1});

    await _submitLogin(tester);

    expect(find.text('登录响应缺少登录凭证，请稍后重试'), findsOneWidget);
    expect(_renderedText(tester), isNot(contains('TypeError')));
  });

  testWidgets('注册服务端错误展示中文 message 而非 DioException 技术串', (tester) async {
    await _pumpRegister(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'user@example.invalid');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, '注册'));
    await tester.pumpAndSettle();

    expect(find.text('该邮箱已被注册'), findsOneWidget);
    final rendered = _renderedText(tester);
    expect(rendered, isNot(contains('DioException')));
    expect(rendered, isNot(contains('ApiException')));
  });
}

final class _NullTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}
