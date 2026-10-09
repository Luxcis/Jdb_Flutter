import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jade/core/network/cache_service.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/storage/testing/in_memory_secure_store.dart';
import 'package:jade/features/profile/screens/profile_settings_screen.dart';
import 'package:jade/features/profile/services/app_version_service.dart';
import 'package:jade/features/profile/services/update_check_session.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeCacheService implements CacheService {
  @override
  Future<int> getCacheSizeBytes() async => 0;

  @override
  Future<void> clearAll() async {}
}

final class _FixedAppVersionService implements AppVersionService {
  const _FixedAppVersionService(this.version);

  final String version;

  @override
  Future<String> loadVersion() async => version;
}

http.Client _httpClient(http.Response Function(Uri url) respond) {
  return MockClient((request) async => respond(request.url));
}

http.Response _releaseResponse({required String tagName, int status = 200}) {
  final body = jsonEncode({
    'tag_name': tagName,
    'name': tagName,
    'body': 'release notes',
    'assets': [
      {
        'name': 'app-arm64-v8a-release.apk',
        'size': 1,
        'browser_download_url':
            'https://github.com/Luxcis/Jdb_Flutter/releases/download/$tagName/app.apk',
      },
    ],
  });
  return http.Response(
    body,
    status,
    headers: {'content-type': 'application/json'},
  );
}

class _Harness {
  _Harness({
    required this.session,
    required this.buildApp,
    required this.dispose,
  });

  /// 注入设置页的会话容器；重挂载页面时复用同一实例。
  final UpdateCheckSession session;
  final Widget Function() buildApp;
  final void Function() dispose;
}

Future<_Harness> _createHarness({
  required http.Response Function(Uri url) respond,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = await SettingsProvider.create(prefs);
  final theme = await ThemeProvider.create();
  final dm = await DomainManager.load(prefs);
  final auth = await AuthProvider.create(
    prefs,
    secure: InMemorySecureValueStore(),
  );
  final session = UpdateCheckSession();

  Widget buildApp() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider.value(value: dm),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp(
      home: ProfileSettingsScreen(
        cacheService: _FakeCacheService(),
        appVersionService: const _FixedAppVersionService('0.7.1'),
        updateCheckSession: session,
        updateHttpClient: _httpClient(respond),
      ),
    ),
  );

  return _Harness(
    session: session,
    buildApp: buildApp,
    dispose: () {
      settings.dispose();
      theme.dispose();
      dm.dispose();
      auth.dispose();
    },
  );
}

Future<void> _mount(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(harness.buildApp());
  await tester.pumpAndSettle();
}

/// 返回「当前版本」行 trailing 的 TextButton。
TextButton _trailingButton(WidgetTester tester) {
  final tile = find.ancestor(
    of: find.text('当前版本'),
    matching: find.byType(ListTile),
  );
  return tester.widget<TextButton>(
    find.descendant(of: tile, matching: find.byType(TextButton)),
  );
}

void main() {
  testWidgets('无更新结论：按钮变「暂无更新」且禁用，SnackBar 保留', (tester) async {
    final harness = await _createHarness(
      respond: (_) => _releaseResponse(tagName: 'v0.7.1'),
    );
    addTearDown(harness.dispose);
    await _mount(tester, harness);

    var button = _trailingButton(tester);
    expect(button.onPressed, isNotNull);
    expect((button.child as Text).data, '检查更新');

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(harness.session.status, UpdateCheckStatus.upToDate);
    expect(find.text('已是最新版本'), findsOneWidget);

    button = _trailingButton(tester);
    expect(button.onPressed, isNull);
    expect((button.child as Text).data, '暂无更新');
  });

  testWidgets('有更新结论：弹出既有更新弹窗，关闭后按钮保持「检查更新」可点击', (tester) async {
    final harness = await _createHarness(
      respond: (_) => _releaseResponse(tagName: 'v0.8.0'),
    );
    addTearDown(harness.dispose);
    await _mount(tester, harness);

    await tester.tap(find.text('检查更新'));
    // 弹窗打开期间按钮处于检查中加载态（不确定式进度圈是持续动画），
    // pumpAndSettle 不会静止；用有限 pump 推进检查与弹窗出现动画。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(harness.session.status, UpdateCheckStatus.hasUpdate);
    expect(find.textContaining('发现新版本'), findsOneWidget);

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(find.textContaining('发现新版本'), findsNothing);

    final button = _trailingButton(tester);
    expect(button.onPressed, isNotNull);
    expect((button.child as Text).data, '检查更新');
  });

  testWidgets('检查失败：按钮保持「检查更新」且可立即重试，提示不变', (tester) async {
    var calls = 0;
    final harness = await _createHarness(
      respond: (_) {
        calls++;
        return http.Response('server error', 500);
      },
    );
    addTearDown(harness.dispose);
    await _mount(tester, harness);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(harness.session.status, UpdateCheckStatus.none);
    expect(find.text('检查更新失败，请稍后重试'), findsOneWidget);

    var button = _trailingButton(tester);
    expect(button.onPressed, isNotNull);
    expect((button.child as Text).data, '检查更新');

    // 失败后可立即重试：再次触发检查发出新请求；失败不记录结论。
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(harness.session.status, UpdateCheckStatus.none);

    button = _trailingButton(tester);
    expect(button.onPressed, isNotNull);
    expect((button.child as Text).data, '检查更新');
  });

  testWidgets('同一次运行内重进设置页：无更新结论保持且不发新请求', (tester) async {
    var calls = 0;
    final harness = await _createHarness(
      respond: (_) {
        calls++;
        return _releaseResponse(tagName: 'v0.7.1');
      },
    );
    addTearDown(harness.dispose);
    await _mount(tester, harness);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    var button = _trailingButton(tester);
    expect(button.onPressed, isNull);
    expect((button.child as Text).data, '暂无更新');
    expect(calls, 1);

    // 移除再重新挂载设置页（模拟离开页面后重进，页面 State 重建）：
    // 同一会话容器仍持有结论，重进后按钮保持「暂无更新」禁用。
    await tester.pumpWidget(const SizedBox.shrink());
    await _mount(tester, harness);

    expect(harness.session.status, UpdateCheckStatus.upToDate);
    expect(calls, 1, reason: '重进设置页不应再次发起检查请求');

    button = _trailingButton(tester);
    expect(button.onPressed, isNull);
    expect((button.child as Text).data, '暂无更新');
  });

  testWidgets('新结论覆盖旧结论：无更新禁用态被有更新结论解除', (tester) async {
    final harness = await _createHarness(
      respond: (_) => _releaseResponse(tagName: 'v0.7.1'),
    );
    addTearDown(harness.dispose);
    await _mount(tester, harness);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    var button = _trailingButton(tester);
    expect((button.child as Text).data, '暂无更新');
    expect(button.onPressed, isNull);

    // 下一次成功检查得到「有更新」结论覆盖旧结论（禁用按钮已无法点击，
    // 由会话容器直接记录模拟），按钮恢复「检查更新」可点击。
    harness.session.record(true);
    await tester.pump();

    button = _trailingButton(tester);
    expect(button.onPressed, isNotNull);
    expect((button.child as Text).data, '检查更新');
  });
}
