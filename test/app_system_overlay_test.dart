import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/main.dart' as app_main;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingStartupApi implements StartupApi {
  final Completer<StartupData> completer = Completer<StartupData>();

  @override
  Future<StartupData> fetchStartup() => completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await app_main.mainForTest(startupApi: _PendingStartupApi());
    await tester.pump();
    await tester.pump();
  }

  Finder overlayRegionFinder() {
    return find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
  }

  testWidgets('无 AppBar 的启动页也应用全局沉浸式状态栏样式', (tester) async {
    await pumpApp(tester);

    final regionFinder = overlayRegionFinder();
    expect(regionFinder, findsOneWidget);

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      regionFinder,
    );
    expect(overlay.value.statusBarColor, Colors.transparent);
    expect(overlay.value.statusBarIconBrightness, Brightness.dark);
    expect(overlay.value.statusBarBrightness, Brightness.light);
    expect(overlay.value.systemStatusBarContrastEnforced, isFalse);

    // 卸载组件树，避免跨测试复用元素时残留活跃动画。
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('切换深色模式后全局状态栏样式同步更新', (tester) async {
    await pumpApp(tester);

    final appContext = tester.element(find.byType(app_main.MyApp));
    appContext.read<ThemeProvider>().setThemeMode(ThemeMode.dark);
    // AnimatedTheme 有 200ms 过渡，推进到过渡完成后再断言亮度。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      overlayRegionFinder(),
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(overlay.value.statusBarBrightness, Brightness.dark);
    expect(overlay.value.statusBarColor, Colors.transparent);
    expect(overlay.value.systemStatusBarContrastEnforced, isFalse);

    // 卸载组件树，避免跨测试复用元素时残留活跃动画。
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
