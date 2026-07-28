import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/startup_provider.dart';
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
  StartupProvider provider,
) async {
  final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('测试首页')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return router;
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
    final router = await _pumpSubject(tester, provider);

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
}
