import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/device/login_device_info_service.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/auth/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoginPage 使用 OpenAPI 要求的 multipart 设备信息登录', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: auth,
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.sessions, {
      'success': 1,
      'data': {
        'token': 'jwt-token',
        'user': {'id': 1, 'username': 'test'},
      },
    });
    api.setAdapterForTest(adapter);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (c, s) => LoginPage(
            deviceParametersProvider: _FakeLoginDeviceParametersProvider(),
          ),
        ),
        GoRoute(path: '/home', builder: (c, s) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '  masked-user@example.invalid  ');
    await tester.enterText(fields.at(1), '  ********  ');
    await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    expect(adapter.requests.last.path, Endpoints.sessions);
    expect(adapter.requests.last.data, isA<FormData>());
    final fieldsMap = {
      for (final entry in (adapter.requests.last.data as FormData).fields)
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
  });
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
