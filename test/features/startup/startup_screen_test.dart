import 'dart:async';

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

class _FakeStartupApi implements StartupApi {
  _FakeStartupApi(this.responses);

  final List<FutureOr<StartupData> Function()> responses;
  int calls = 0;

  @override
  Future<StartupData> fetchStartup() async {
    final response = responses[calls];
    calls += 1;
    return response();
  }
}

final class _FakeSessionRefreshService implements SessionRefreshService {
  _FakeSessionRefreshService(this._result);

  final Future<SessionRefreshStatus> Function() _result;
  int calls = 0;

  @override
  Future<SessionRefreshStatus> refresh() {
    calls++;
    return _result();
  }
}

Future<StartupProvider> _createProvider(StartupApi startupApi) async {
  final prefs = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(prefs);
  final apiClient = ApiClient.forTest(
    dio: Dio(BaseOptions(baseUrl: domainManager.currentUrl)),
    domainManager: domainManager,
  );
  return StartupProvider.create(
    startupApi: startupApi,
    apiClient: apiClient,
    domainManager: domainManager,
    decoder: (_) => const BackupDomains(apiDomains: ['https://backup.example']),
  );
}

Future<GoRouter> _pumpSubject(
  WidgetTester tester,
  StartupProvider provider, {
  AuthProvider? auth,
  SessionRefreshService? sessionRefreshService,
  FollowingTagsProvider? followingTagsProvider,
}) async {
  final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) =>
            StartupPage(sessionRefreshService: sessionRefreshService),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('测试首页')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('测试登录页')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        if (auth != null) ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(
          value: followingTagsProvider ??
              FollowingTagsProvider(
                store: _MemoryFollowingStore(),
                dataSource: const UnavailableFollowingTagsDataSource(),
              ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return router;
}

final class _MemoryFollowingStore implements FollowingTagsStore {
  List<FollowTagItem> stored = [];
  int clearCalls = 0;
  @override
  Future<void> clear() async {
    clearCalls++;
    stored = [];
  }
  @override
  Future<List<FollowTagItem>> load() async => stored;
  @override
  Future<void> save(List<FollowTagItem> tags) async => stored = List.of(tags);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('首次显示只发起一次请求并展示加载指示器', (tester) async {
    final completer = Completer<StartupData>();
    final api = _FakeStartupApi([() => completer.future]);
    final provider = await _createProvider(api);

    await _pumpSubject(tester, provider);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('测试首页'), findsNothing);
    expect(api.calls, 1);
  });

  testWidgets('失败后显示提示和重试按钮，重试成功后 go 到首页', (tester) async {
    final api = _FakeStartupApi([
      () => throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/startup'),
      ),
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    // 注入未登录的 AuthProvider：重试成功后 _refreshSessionThenNavigate
    // 会 context.read<AuthProvider>()，未登录分支直接 go 首页。
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final router = await _pumpSubject(tester, provider, auth: auth);

    await tester.pumpAndSettle();
    expect(find.text('启动失败，请检查网络后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(router.state.uri.path, '/startup');

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(api.calls, 2);
    expect(router.state.uri.path, '/home');
    expect(find.text('测试首页'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('已登录且校验成功时 go 首页', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.success,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 1);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('校验过期时 go 登录页并带 reason=expired', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.expired,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 1);
    expect(router.state.uri.path, '/login');
    expect(router.state.uri.queryParameters['reason'], 'expired');
    expect(router.state.uri.queryParameters['from'], '/home');
  });

  testWidgets('校验过期时清空 FollowingTags 本地缓存', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.expired,
    );

    final followingStore = _MemoryFollowingStore();
    final followingProvider = FollowingTagsProvider(
      store: followingStore,
      dataSource: const UnavailableFollowingTagsDataSource(),
    );
    await followingProvider.initialize();
    await followingProvider.syncFromLogin(const [
      FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
    ]);
    expect(followingProvider.tags, hasLength(1));

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
      followingTagsProvider: followingProvider,
    );
    await tester.pumpAndSettle();

    // 过期时清空关注标签缓存，保持与 onAuthError 清空一致。
    expect(router.state.uri.path, '/login');
    expect(followingProvider.tags, isEmpty);
    expect(followingStore.clearCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('校验网络失败时保留会话并 go 首页', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.failure,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 1);
    expect(auth.isLogged, isTrue);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('未登录时不调用校验直接 go 首页', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.skipped,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 0);
    expect(router.state.uri.path, '/home');
  });
}
