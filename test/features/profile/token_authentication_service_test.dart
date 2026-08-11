import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _TokenProvider implements TokenProvider {
  @override
  String? token = 'old-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('authenticate 调用 users 并返回内层 user', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter()
      ..enqueue(Endpoints.users, {
        'success': 1,
        'data': {
          'user': {
            'id': 9,
            'username': 'token-user',
            'email': 'token-user@example.invalid',
            'want_watch_count': 2,
            'watched_count': 3,
          },
          'banner_type': 'none',
        },
      });
    api.setAdapterForTest(adapter);
    final service = ApiTokenAuthenticationService(api);

    final user = await service.authenticate('candidate-token');

    expect(user, {
      'id': 9,
      'username': 'token-user',
      'email': 'token-user@example.invalid',
      'want_watch_count': 2,
      'watched_count': 3,
    });
    expect(adapter.requests.single.path, Endpoints.users);
  });

  test('authenticate 拒绝缺少 user 的成功响应', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter()
      ..enqueue(Endpoints.users, {
        'success': 1,
        'data': {'banner_type': 'none'},
      });
    api.setAdapterForTest(adapter);

    await expectLater(
      () => ApiTokenAuthenticationService(api).authenticate('candidate-token'),
      throwsA(isA<FormatException>()),
    );
  });
}
