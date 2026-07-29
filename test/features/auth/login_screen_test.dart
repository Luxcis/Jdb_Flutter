import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/device/login_device_info_service.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/features/auth/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoginPage 使用官方 multipart 参数并保存成功登录凭据', (tester) async {
    final store = _MemoryLoginCredentialStore();
    final subject = await _pumpLogin(tester, credentialStore: store);

    await _submitCredentials(
      tester,
      '  masked-user@example.invalid  ',
      '  ********  ',
    );

    expect(subject.adapter.requests.last.path, Endpoints.sessions);
    expect(subject.adapter.requests.last.data, isA<FormData>());
    final fieldsMap = {
      for (final entry
          in (subject.adapter.requests.last.data as FormData).fields)
        entry.key: entry.value,
    };
    expect(fieldsMap, {
      'device_uuid': 'device-uuid',
      'device_name': 'Google',
      'device_model': 'Pixel 9/tokay',
      'platform': 'android',
      'system_version': '15',
      'app_channel': 'official',
      'app_version': 'official',
      'app_version_number': '1.9.35',
      'username': 'masked-user@example.invalid',
      'password': '  ********  ',
    });
    expect(store.saveCalls, 1);
    expect(store.credentials.username, 'masked-user@example.invalid');
    expect(store.credentials.password, '  ********  ');
  });

  testWidgets('进入登录页自动填充已保存的用户名和密码但不自动登录', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'masked-user@example.invalid',
        password: 'test-password',
      ),
    );
    final subject = await _pumpLogin(tester, credentialStore: store);

    final fields = find.byType(TextField);
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'masked-user@example.invalid',
    );
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      'test-password',
    );
    expect(subject.adapter.requests, isEmpty);
  });

  testWidgets('仅保存用户名时密码框保持为空', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'masked-user@example.invalid',
      ),
    );
    await _pumpLogin(tester, credentialStore: store);

    final fields = find.byType(TextField);
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'masked-user@example.invalid',
    );
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
  });

  testWidgets('异步恢复完成时不覆盖用户已编辑的输入', (tester) async {
    final completer = Completer<SavedLoginCredentials>();
    final store = _MemoryLoginCredentialStore(readFuture: completer.future);
    await _pumpLogin(tester, credentialStore: store, settle: false);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'typed-user');
    await tester.enterText(fields.at(1), 'typed-password');
    completer.complete(
      const SavedLoginCredentials(
        username: 'cached-user',
        password: 'cached-password',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'typed-user',
    );
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      'typed-password',
    );
  });

  testWidgets('安全存储读取失败时仍允许手动登录', (tester) async {
    final store = _MemoryLoginCredentialStore(
      readError: StateError('secure read failed'),
    );
    final subject = await _pumpLogin(tester, credentialStore: store);

    await _submitCredentials(tester, 'typed-user', 'typed-password');

    expect(subject.adapter.requests, hasLength(1));
    expect(subject.auth.isLogged, isTrue);
    expect(subject.router.state.uri.path, '/home');
  });

  testWidgets('登录失败不覆盖已保存凭据', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'cached-user',
        password: 'cached-password',
      ),
    );
    final subject = await _pumpLogin(
      tester,
      credentialStore: store,
      response: {'success': 0, 'message': '登录失败'},
    );

    await _submitCredentials(tester, 'new-user', 'new-password');

    expect(store.saveCalls, 0);
    expect(store.credentials.username, 'cached-user');
    expect(store.credentials.password, 'cached-password');
    expect(subject.auth.isLogged, isFalse);
  });

  testWidgets('凭据保存失败不回滚登录或阻止成功跳转', (tester) async {
    final store = _MemoryLoginCredentialStore(
      saveError: StateError('secure write failed'),
    );
    final subject = await _pumpLogin(tester, credentialStore: store);

    await _submitCredentials(
      tester,
      'masked-user@example.invalid',
      'test-password',
    );

    expect(store.saveCalls, 1);
    expect(subject.auth.isLogged, isTrue);
    expect(subject.router.state.uri.path, '/home');
  });
}

Future<({AuthProvider auth, FakeAdapter adapter, GoRouter router})> _pumpLogin(
  WidgetTester tester, {
  required LoginCredentialStore credentialStore,
  Map<String, dynamic>? response,
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: () {},
  );
  final adapter = FakeAdapter();
  adapter.enqueue(
    Endpoints.sessions,
    response ??
        {
          'success': 1,
          'data': {
            'token': 'jwt-token',
            'user': {'id': 1, 'username': 'test'},
          },
        },
  );
  api.setAdapterForTest(adapter);

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          deviceParametersProvider: _FakeLoginDeviceParametersProvider(),
          credentialStore: credentialStore,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  return (auth: auth, adapter: adapter, router: router);
}

Future<void> _submitCredentials(
  WidgetTester tester,
  String username,
  String password,
) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), username);
  await tester.enterText(fields.at(1), password);
  await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
  await tester.pumpAndSettle();
}

final class _FakeLoginDeviceParametersProvider
    implements LoginDeviceParametersProvider {
  @override
  Future<LoginDeviceParameters> load() async {
    return const LoginDeviceParameters(
      deviceUuid: 'device-uuid',
      deviceName: 'Google',
      deviceModel: 'Pixel 9/tokay',
      systemVersion: '15',
    );
  }
}

final class _MemoryLoginCredentialStore implements LoginCredentialStore {
  _MemoryLoginCredentialStore({
    this.credentials = const SavedLoginCredentials(),
    this.readFuture,
    this.readError,
    this.saveError,
  });

  SavedLoginCredentials credentials;
  final Future<SavedLoginCredentials>? readFuture;
  final Object? readError;
  final Object? saveError;
  var saveCalls = 0;

  @override
  Future<SavedLoginCredentials> read() async {
    if (readError case final error?) throw error;
    if (readFuture != null) return readFuture!;
    return credentials;
  }

  @override
  Future<void> save({
    required String username,
    required String password,
  }) async {
    saveCalls++;
    if (saveError case final error?) throw error;
    credentials = SavedLoginCredentials(username: username, password: password);
  }

  @override
  Future<void> clearPassword() async {
    credentials = SavedLoginCredentials(username: credentials.username);
  }
}
