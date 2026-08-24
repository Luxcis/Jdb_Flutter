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
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpSource implements FollowingTagsDataSource {
  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async => FollowTagItem(id: 'n', name: name, value: value);

  @override
  Future<void> unfollow(String id) async {}

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
}

class _MemoryStore1 implements FollowingTagsStore {
  @override
  Future<void> clear() async {}

  @override
  Future<List<FollowTagItem>> load() async => const [];

  @override
  Future<void> save(List<FollowTagItem> tags) async {}
}

/// 登录成功后解析 following_tags 并写入 FollowingTagsProvider。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登录响应含 following_tags 时写入 provider 缓存', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final provider = FollowingTagsProvider(
      store: _MemoryStore1(),
      dataSource: _NoOpSource(),
    );
    await provider.initialize();

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
        'following_tags': [
          {
            'id': 13384922,
            'name': '有碼,森螢',
            'value': '0:a:g1Q',
            'priority': 6.0,
          },
        ],
      },
    });
    api.setAdapterForTest(adapter);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginPage(
            deviceParametersProvider: _FakeDeviceParametersProvider(),
            credentialStore: _MemoryCredentialStore(),
          ),
        ),
        GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'user@example.invalid');
    await tester.enterText(fields.at(1), 'password');
    await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    expect(provider.tags, hasLength(1));
    expect(provider.tags.single.id, '13384922');
    expect(provider.tags.single.name, '有碼,森螢');
    expect(provider.tags.single.value, '0:a:g1Q');
    expect(provider.isFollowing('0:a:g1Q'), isTrue);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('登录响应 following_tags 含非 Map 元素时登录仍成功且按空列表处理', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final provider = FollowingTagsProvider(
      store: _MemoryStore1(),
      dataSource: _NoOpSource(),
    );
    await provider.initialize();

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
        'following_tags': [
          {'id': 1},
          'not-a-map',
        ],
      },
    });
    api.setAdapterForTest(adapter);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginPage(
            deviceParametersProvider: _FakeDeviceParametersProvider(),
            credentialStore: _MemoryCredentialStore(),
          ),
        ),
        GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'user@example.invalid');
    await tester.enterText(fields.at(1), 'password');
    await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
    await tester.pumpAndSettle();

    // 解析失败不破坏已成功的登录：仍登录成功、保持空列表并跳转到首页。
    expect(auth.isLogged, isTrue);
    expect(provider.tags, isEmpty);
    expect(router.state.uri.path, '/home');
  });
}

final class _FakeDeviceParametersProvider
    implements LoginDeviceParametersProvider {
  @override
  Future<LoginDeviceParameters> load() async => const LoginDeviceParameters(
    deviceUuid: 'device-uuid',
    deviceName: 'Google',
    deviceModel: 'Pixel 9/tokay',
    systemVersion: '15',
  );
}

final class _MemoryCredentialStore implements LoginCredentialStore {
  SavedLoginCredentials credentials = const SavedLoginCredentials();

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
  Future<void> clearPassword() async {}
}
