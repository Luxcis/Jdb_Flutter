import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/services/session_refresh_service.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:jade/features/startup/screens/startup_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStartupApi2 implements StartupApi {
  @override
  Future<StartupData> fetchStartup() async =>
      const StartupData(backupDomainsData: 'ciphertext');
}

final class _SuccessRefresh implements SessionRefreshService {
  @override
  Future<SessionRefreshStatus> refresh() async => SessionRefreshStatus.success;
}

class _PushRemoteSource implements FollowingTagsDataSource {
  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async => FollowTagItem(id: 'n', name: name, value: value);

  @override
  Future<void> unfollow(String id) async {}

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async =>
      const [FollowTagItem(id: '99', name: '远程', value: 'remote-1')];
}

class _MemoryStore2 implements FollowingTagsStore {
  @override
  Future<void> clear() async {}

  @override
  Future<List<FollowTagItem>> load() async => const [];

  @override
  Future<void> save(List<FollowTagItem> tags) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('启动校验成功后 batch_push 用远程标签覆盖本地缓存', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final domainManager = await DomainManager.load(prefs);
    final apiClient = ApiClient.forTest(
      dio: Dio(BaseOptions(baseUrl: domainManager.currentUrl)),
      domainManager: domainManager,
    );
    final startupProvider = StartupProvider.create(
      startupApi: _FakeStartupApi2(),
      apiClient: apiClient,
      domainManager: domainManager,
      decoder: (_) =>
          const BackupDomains(apiDomains: ['https://backup.example']),
    );
    final auth = await AuthProvider.create(prefs);
    await auth.login(token: 't', user: {'id': 1, 'username': 'u'});
    final provider = FollowingTagsProvider(
      store: _MemoryStore2(),
      dataSource: _PushRemoteSource(),
    );
    await provider.initialize();

    final router = GoRouter(
      initialLocation: '/startup',
      routes: [
        GoRoute(
          path: '/startup',
          builder: (context, state) =>
              StartupPage(sessionRefreshService: _SuccessRefresh()),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('首页')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: startupProvider),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(provider.tags.single.id, '99');
    expect(provider.tags.single.value, 'remote-1');
    expect(router.state.uri.path, '/home');
  });
}
