import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/auth/services/auth_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _NullTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('register 直接经 AuthSessionService 提交注册契约字段', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _NullTokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.users, {
      'success': 1,
      'data': {'id': 1},
    });
    api.setAdapterForTest(adapter);

    await AuthSessionService(api).register(
      email: 'user@example.invalid',
      password: 'password123',
      deviceUuid: 'device-uuid-1',
    );

    final request = adapter.requests.single;
    expect(request.path, Endpoints.users);
    expect(request.method, 'POST');
    final data = Map<String, dynamic>.from(request.data as Map);
    expect(data, {
      'email': 'user@example.invalid',
      'username': 'user@example.invalid',
      'password': 'password123',
      'device_uuid': 'device-uuid-1',
      'device_name': 'Jade',
      'device_model': 'Flutter',
      'platform': 'android',
      'system_version': '14',
      'app_channel': 'google',
      'app_version': '1.9.29',
      'app_version_number': '35',
    });
  });
}
