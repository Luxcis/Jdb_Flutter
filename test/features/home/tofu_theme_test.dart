// 回归测试：首页豆腐块必须实时跟随深浅色切换，无需重启应用。
//
// 走真实应用启动链路（mainForTest → 启动完成 → 首页），覆盖元素复用后
// 主题依赖丢失的场景：修复前豆腐块 Card.color 在切换后保持旧色不变。
// 全部场景合并进同一次应用启动，避免多个 mainForTest 之间的测试时钟污染。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/theme/app_theme.dart';
import 'package:jade/main.dart' as app_main;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StartupApi implements StartupApi {
  final Completer<StartupData> completer = Completer<StartupData>();

  @override
  Future<StartupData> fetchStartup() => completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A1/A2/A3: 豆腐块实时跟随深浅色切换（应用内与跟随系统）',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'key_baseurl': 'https://jdforrepam.com',
      'key_api_domains': ['https://jdforrepam.com'],
    });
    final startupApi = _StartupApi();
    await app_main.mainForTest(
      startupApi: startupApi,
      decoder: (_) =>
          const BackupDomains(apiDomains: ['https://jdforrepam.com']),
    );
    await tester.pump();
    await tester.pump();

    startupApi.completer.complete(
      const StartupData(backupDomainsData: 'ciphertext'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final appContext = tester.element(find.byType(app_main.MyApp));
    final themeProvider = appContext.read<ThemeProvider>();
    Color? tofuCardColor() =>
        tester.widget<Card>(find.byKey(const Key('tofu-看热播'))).color;

    addTearDown(() {
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    // 初始（system + 测试平台亮色）：浅色 surface
    expect(
      tofuCardColor(),
      AppTheme.light().colorScheme.surface,
      reason: '测试平台默认亮色，初始应为浅色 surface',
    );

    // A1: 应用内浅 → 深，实时生效
    themeProvider.setThemeMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tofuCardColor(),
      AppTheme.dark().colorScheme.surface,
      reason: '切深色后豆腐块必须实时变为深色 surface',
    );

    // A2: 应用内深 → 浅，实时恢复
    themeProvider.setThemeMode(ThemeMode.light);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tofuCardColor(),
      AppTheme.light().colorScheme.surface,
      reason: '切浅色后豆腐块必须实时恢复浅色 surface',
    );

    // A3: 跟随系统模式下，系统亮度切换实时生效
    themeProvider.setThemeMode(ThemeMode.system);
    await tester.pump();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tofuCardColor(),
      AppTheme.dark().colorScheme.surface,
      reason: 'system 模式下系统切深色，豆腐块必须实时跟随',
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tofuCardColor(),
      AppTheme.light().colorScheme.surface,
      reason: 'system 模式下系统切回浅色，豆腐块必须实时跟随',
    );
  });
}
