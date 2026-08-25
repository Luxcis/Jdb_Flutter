import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/cache_service.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/features/profile/screens/profile_sub_pages.dart';
import 'package:jade/features/profile/services/app_version_service.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:jade/features/profile/widgets/token_authentication_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCacheService implements CacheService {
  _FakeCacheService({this.size = 0});

  int size;
  int clearAllCalls = 0;

  @override
  Future<int> getCacheSizeBytes() async => size;

  @override
  Future<void> clearAll() async {
    clearAllCalls++;
    size = 0;
  }
}

final class _FixedAppVersionService implements AppVersionService {
  const _FixedAppVersionService(this.version);

  final String version;

  @override
  Future<String> loadVersion() async => version;
}

final class _FailingAppVersionService implements AppVersionService {
  const _FailingAppVersionService();

  @override
  Future<String> loadVersion() => Future.error(StateError('unavailable'));
}

final class _FakeTokenAuthenticationService
    implements TokenAuthenticationService {
  _FakeTokenAuthenticationService({this.user, this.error});

  final Map<String, dynamic>? user;
  final Object? error;
  var calls = 0;
  String? lastToken;

  @override
  Future<Map<String, dynamic>> authenticate(String token) async {
    calls++;
    lastToken = token;
    if (error case final error?) throw error;
    return user!;
  }
}

final class _CompletingTokenAuthenticationService
    implements TokenAuthenticationService {
  final completer = Completer<Map<String, dynamic>>();
  var calls = 0;

  @override
  Future<Map<String, dynamic>> authenticate(String token) {
    calls++;
    return completer.future;
  }
}

Future<({AuthProvider auth, SharedPreferences prefs, void Function() dispose})>
_pumpSettings(
  WidgetTester tester, {
  required AppVersionService appVersionService,
  TokenAuthenticationService? tokenAuthenticationService,
  String? initialToken,
  Map<String, dynamic>? initialUser,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = await SettingsProvider.create(prefs);
  final theme = await ThemeProvider.create();
  final domainManager = await DomainManager.load(prefs);
  final auth = await AuthProvider.create(prefs);
  if (initialToken != null && initialUser != null) {
    await auth.login(token: initialToken, user: initialUser);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: domainManager),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        home: ProfileSettingsPage(
          cacheService: _FakeCacheService(),
          appVersionService: appVersionService,
          tokenAuthenticationService: tokenAuthenticationService,
        ),
      ),
    ),
  );

  return (
    auth: auth,
    prefs: prefs,
    dispose: () {
      settings.dispose();
      theme.dispose();
      domainManager.dispose();
      auth.dispose();
    },
  );
}

void main() {
  testWidgets('我的收藏页展示六类收藏入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileFavoritesPage()));

    expect(find.text('收藏的演员'), findsOneWidget);
    expect(find.text('收藏的片商'), findsOneWidget);
    expect(find.text('收藏的系列'), findsOneWidget);
    expect(find.text('收藏的导演'), findsOneWidget);
    expect(find.text('收藏的番号'), findsOneWidget);
    expect(find.text('收藏的清单'), findsOneWidget);
  });

  testWidgets('设置页展示原设置项并切换持久化影片图片模糊', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final dm = await DomainManager.load(prefs);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: _FakeCacheService()),
        ),
      ),
    );

    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('线路选择'), findsOneWidget);
    expect(find.text('清除缓存'), findsOneWidget);
    expect(find.text('影片图片模糊'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(settings.blurMovieImages, isFalse);
    expect(prefs.getBool(StorageKeys.blurMovieImages), isFalse);
  });

  testWidgets('线路选择：点击弹出弹窗，选中域名后 subtitle 更新并提示', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final auth = await AuthProvider.create(prefs);
    await ApiClient.create(
      prefs: prefs,
      tokenProvider: auth,
      onAuthError: () {},
    );
    final dm = ApiClient.instance.domainManager;
    await dm.applyStartup(
      BackupDomains(
        apiDomains: ['https://jdforrepam.com', 'https://backup1.com'],
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: _FakeCacheService()),
        ),
      ),
    );

    expect(find.text('线路选择'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget); // subtitle

    await tester.tap(find.text('线路选择'));
    await tester.pumpAndSettle();

    expect(find.text('自动（推荐）'), findsOneWidget);
    expect(find.text('backup1.com'), findsOneWidget);

    await tester.tap(find.text('backup1.com'));
    await tester.pumpAndSettle();

    expect(dm.lineMode, LineMode.manual);
    expect(dm.currentUrl, 'https://backup1.com');
    expect(find.text('backup1.com'), findsOneWidget); // subtitle 更新
    expect(find.text('已切换到 backup1.com'), findsOneWidget); // SnackBar
  });

  testWidgets('线路选择：切回自动恢复 subtitle 与主域名', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final auth = await AuthProvider.create(prefs);
    await ApiClient.create(
      prefs: prefs,
      tokenProvider: auth,
      onAuthError: () {},
    );
    final dm = ApiClient.instance.domainManager;
    await dm.applyStartup(
      BackupDomains(
        apiDomains: ['https://jdforrepam.com', 'https://backup1.com'],
      ),
    );
    await dm.select('https://backup1.com');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: _FakeCacheService()),
        ),
      ),
    );

    expect(find.text('backup1.com'), findsOneWidget); // subtitle 为手动域名

    await tester.tap(find.text('线路选择'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('自动（推荐）'));
    await tester.pumpAndSettle();

    expect(dm.isAutoMode, isTrue);
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(find.text('自动'), findsOneWidget);
    expect(find.text('已切换到自动线路'), findsOneWidget);
  });

  testWidgets('线路选择：apiDomains 为空时仅显示兜底域名', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final auth = await AuthProvider.create(prefs);
    await ApiClient.create(
      prefs: prefs,
      tokenProvider: auth,
      onAuthError: () {},
    );
    final dm = ApiClient.instance.domainManager;
    // 不调用 applyStartup：apiDomains 保持为空，仅兜底域名可用。

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: _FakeCacheService()),
        ),
      ),
    );

    await tester.tap(find.text('线路选择'));
    await tester.pumpAndSettle();

    // 弹窗仅列出兜底域名一项
    expect(find.text('jdforrepam.com'), findsOneWidget);
    expect(find.text('backup1.com'), findsNothing);

    await tester.tap(find.text('jdforrepam.com'));
    await tester.pumpAndSettle();

    expect(dm.lineMode, LineMode.manual);
    expect(dm.currentUrl, AppConstants.fallbackBaseUrl);
    expect(find.text('jdforrepam.com'), findsOneWidget); // subtitle 更新
    expect(find.text('已切换到 jdforrepam.com'), findsOneWidget);
  });

  testWidgets('外观模式：弹出弹窗选择深色后 themeMode 更新并持久化', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final dm = await DomainManager.load(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: _FakeCacheService()),
        ),
      ),
    );

    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget); // subtitle

    await tester.tap(find.text('外观模式'));
    await tester.pumpAndSettle();

    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);

    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();

    expect(theme.themeMode, ThemeMode.dark);
    expect(prefs.getInt('theme-mode-index'), ThemeMode.dark.index);
    expect(find.text('深色模式'), findsOneWidget); // subtitle 更新
  });

  testWidgets('清除缓存：显示大小，确认后调用 clearAll 并归零提示', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final dm = await DomainManager.load(prefs);
    final cacheService = _FakeCacheService(size: (24 * 1024 + 512) * 1024);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: cacheService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('清除缓存'), findsOneWidget);
    expect(find.text('24.5 MB'), findsOneWidget);

    await tester.tap(find.text('清除缓存'));
    await tester.pumpAndSettle();

    expect(find.text('清除图片缓存？'), findsOneWidget);

    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(cacheService.clearAllCalls, 1);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('缓存已清除'), findsOneWidget);
  });

  testWidgets('当前版本是 settings cells 最后一行且不显示构建号', (tester) async {
    final subject = await _pumpSettings(
      tester,
      appVersionService: const _FixedAppVersionService('0.7.1'),
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();

    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('0.7.1'), findsOneWidget);
    expect(find.textContaining('+701'), findsNothing);
    expect(
      tester.getTopLeft(find.text('当前版本')).dy,
      greaterThan(tester.getTopLeft(find.text('清除缓存')).dy),
    );
  });

  testWidgets('版本读取失败时副标题显示未知', (tester) async {
    final subject = await _pumpSettings(
      tester,
      appVersionService: const _FailingAppVersionService(),
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();

    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('未知'), findsOneWidget);
  });

  testWidgets('2 秒内第五次点击当前版本才打开 Token 弹窗', (tester) async {
    final subject = await _pumpSettings(
      tester,
      appVersionService: const _FixedAppVersionService('0.7.1'),
      tokenAuthenticationService: _FakeTokenAuthenticationService(
        user: {'id': 1},
      ),
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('当前版本'));
    }
    await tester.pump();
    expect(find.text('认证 Token'), findsNothing);

    await tester.tap(find.text('当前版本'));
    await tester.pumpAndSettle();
    expect(find.text('认证 Token'), findsOneWidget);
    expect(find.text('输入新的认证 Token 将覆盖当前登录信息。'), findsOneWidget);
  });

  testWidgets('版本点击超过 2 秒后重新计数', (tester) async {
    final subject = await _pumpSettings(
      tester,
      appVersionService: const _FixedAppVersionService('0.7.1'),
      tokenAuthenticationService: _FakeTokenAuthenticationService(
        user: {'id': 1},
      ),
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('当前版本'));
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('当前版本'));
    await tester.pump();

    expect(find.text('认证 Token'), findsNothing);
  });

  testWidgets('Token 验证成功后覆盖并持久化完整登录状态', (tester) async {
    final service = _FakeTokenAuthenticationService(
      user: {
        'id': 10,
        'username': 'replacement-user',
        'email': 'replacement@example.invalid',
      },
    );
    final subject = await _pumpSettings(
      tester,
      initialToken: 'old-token',
      initialUser: {'id': 1, 'username': 'old-user'},
      appVersionService: const _FixedAppVersionService('0.7.1'),
      tokenAuthenticationService: service,
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('当前版本'));
    }
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  replacement-token  ');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(service.lastToken, 'replacement-token');
    expect(subject.auth.token, 'replacement-token');
    expect(subject.auth.user?['username'], 'replacement-user');
    expect(jsonDecode(subject.prefs.getString(StorageKeys.authSession)!), {
      'token': 'replacement-token',
      'user': {
        'id': 10,
        'username': 'replacement-user',
        'email': 'replacement@example.invalid',
      },
    });
    expect(find.text('认证 Token'), findsNothing);
    expect(find.text('认证 Token 已更新'), findsOneWidget);
  });

  testWidgets('DioException 服务端 message 回显候选 Token 时逐次脱敏并允许重试', (tester) async {
    const candidateToken = 'candidate-ui-secret-93c';
    final service = _FakeTokenAuthenticationService(
      error: DioException(
        requestOptions: RequestOptions(path: Endpoints.users),
        error: const ApiException(
          action: ApiErrorActions.jwtVerificationError,
          message:
              '服务端拒绝 candidate-ui-secret-93c；'
              '请替换 candidate-ui-secret-93c',
        ),
      ),
    );
    final subject = await _pumpSettings(
      tester,
      initialToken: 'old-token',
      initialUser: {'id': 1, 'username': 'old-user'},
      appVersionService: const _FixedAppVersionService('0.7.1'),
      tokenAuthenticationService: service,
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('当前版本'));
    }
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), candidateToken);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('认证 Token'), findsOneWidget);
    expect(
      find.text(
        '服务端拒绝 [REDACTED_SECRET]；'
        '请替换 [REDACTED_SECRET]',
      ),
      findsOneWidget,
    );
    final renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join('\n');
    expect(renderedText, isNot(contains(candidateToken)));
    expect(subject.auth.token, 'old-token');
    expect(subject.auth.user?['username'], 'old-user');
    expect(jsonDecode(subject.prefs.getString(StorageKeys.authSession)!), {
      'token': 'old-token',
      'user': {'id': 1, 'username': 'old-user'},
    });

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(service.calls, 2);
    expect(
      find.text(
        '服务端拒绝 [REDACTED_SECRET]；'
        '请替换 [REDACTED_SECRET]',
      ),
      findsOneWidget,
    );
    expect(subject.auth.token, 'old-token');
  });

  testWidgets('空 Token 不发起验证', (tester) async {
    final service = _FakeTokenAuthenticationService(user: {'id': 1});
    final subject = await _pumpSettings(
      tester,
      appVersionService: const _FixedAppVersionService('0.7.1'),
      tokenAuthenticationService: service,
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('当前版本'));
    }
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('确定'));
    await tester.pump();

    expect(service.calls, 0);
    expect(find.text('认证 Token'), findsOneWidget);
  });

  testWidgets('会话保存失败时弹窗保留且不显示成功状态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TokenAuthenticationDialog(
          authenticate: (_) async => {'id': 1, 'username': 'token-user'},
          saveSession: ({required token, required user}) async {
            throw StateError('storage unavailable');
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'candidate-token');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('认证 Token'), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('认证 Token 已更新'), findsNothing);
  });

  testWidgets('验证期间阻止重复提交', (tester) async {
    final service = _CompletingTokenAuthenticationService();
    final subject = await _pumpSettings(
      tester,
      appVersionService: const _FixedAppVersionService('0.7.1'),
      tokenAuthenticationService: service,
    );
    addTearDown(subject.dispose);
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('当前版本'));
    }
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'candidate-token');

    await tester.tap(find.text('确定'));
    await tester.tap(find.text('确定'));
    await tester.pump();

    expect(service.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.completer.complete({'id': 1, 'username': 'token-user'});
    await tester.pumpAndSettle();
  });

  testWidgets('GitHub 代理：默认不使用代理，点击弹出弹窗选择后保存', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final dm = await DomainManager.load(prefs);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: _FakeCacheService()),
        ),
      ),
    );

    expect(find.text('GitHub 代理'), findsOneWidget);
    expect(find.text('不使用代理'), findsOneWidget);

    await tester.tap(find.text('GitHub 代理'));
    await tester.pumpAndSettle();

    expect(find.text('https://hub.luxcis.top/'), findsOneWidget);
    expect(find.text('https://gh-proxy.com/'), findsOneWidget);
    expect(find.text('自定义…'), findsOneWidget);

    await tester.tap(find.text('https://hub.luxcis.top/'));
    await tester.pumpAndSettle();

    expect(settings.githubProxy, 'https://hub.luxcis.top/');
    expect(prefs.getString(StorageKeys.githubProxy), 'https://hub.luxcis.top/');
    // subtitle 更新为 host
    expect(find.text('hub.luxcis.top'), findsOneWidget);
  });

  testWidgets('GitHub 代理：自定义地址弹窗输入并规范化保存', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final dm = await DomainManager.load(prefs);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: _FakeCacheService()),
        ),
      ),
    );

    await tester.tap(find.text('GitHub 代理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义…'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://mirror.example.com/proxy',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 自动补齐 / 结尾
    expect(settings.githubProxy, 'https://mirror.example.com/proxy/');
    expect(
      prefs.getString(StorageKeys.githubProxy),
      'https://mirror.example.com/proxy/',
    );
  });
}
