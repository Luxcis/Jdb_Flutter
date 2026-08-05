import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/cache_service.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/features/profile/screens/profile_sub_pages.dart';
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

void main() {
  testWidgets('个人资料页展示资料与账号操作 cell', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileInfoPage()));

    expect(find.text('电子邮箱'), findsOneWidget);
    expect(find.text('短评被举报次数'), findsOneWidget);
    expect(find.text('短评被删次数'), findsOneWidget);
    expect(find.text('禁言次数'), findsOneWidget);
    expect(find.text('待审核/已通过订正数'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('修改用户名'), findsOneWidget);
  });

  testWidgets('我的收藏页展示六类收藏入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileFavoritesPage()));

    expect(find.text('收藏的演员'), findsOneWidget);
    expect(find.text('收藏的片商'), findsOneWidget);
    expect(find.text('收藏的系列'), findsOneWidget);
    expect(find.text('收藏的导演'), findsOneWidget);
    expect(find.text('收藏的番号'), findsOneWidget);
    expect(find.text('清单'), findsOneWidget);
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
        child: const MaterialApp(home: ProfileSettingsPage()),
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
        child: const MaterialApp(home: ProfileSettingsPage()),
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
        child: const MaterialApp(home: ProfileSettingsPage()),
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
        child: const MaterialApp(home: ProfileSettingsPage()),
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
        child: const MaterialApp(home: ProfileSettingsPage()),
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
}
