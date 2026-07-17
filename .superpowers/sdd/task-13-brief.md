### Task 13: app.dart + main.dart 装配启动

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`
- Test: `test/app_test.dart`

**Interfaces:**
- Produces：`MyApp`（`MaterialApp.router` + Provider 注册 + 主题）。
- 启动顺序：SP → AuthProvider → DomainManager.load → ApiClient.create → StartupProvider → `fetchStartup`（fire-and-forget）→ runApp。

- [ ] **Step 1: 写失败测试**

```dart
// test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('App 启动渲染底导与首页', (tester) async {
    await app_main.mainForTest();
    await tester.pumpAndSettle();
    expect(find.byType(app_main.MyApp), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/app_test.dart`
Expected: FAIL（`mainForTest`/`MyApp` 未定义或现有 main.dart 无 router）。

- [ ] **Step 3: 实现 app.dart**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'Jade',
          theme: lightDynamic != null
              ? ThemeData(colorScheme: lightDynamic)
              : AppTheme.light(),
          darkTheme: darkDynamic != null
              ? ThemeData(colorScheme: darkDynamic)
              : AppTheme.dark(),
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter.buildForTest(),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 改造 main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/app.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';

export 'package:jade/app.dart' show MyApp;

Future<void> mainForTest() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

Future<Widget> _buildEntry() async {
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = await ThemeProvider.create();
  final authProvider = await AuthProvider.create(prefs);
  final settingsProvider = await SettingsProvider.create(prefs);
  final apiClient = await ApiClient.create(
    prefs: prefs,
    tokenProvider: authProvider,
    onAuthError: authProvider.logout,
  );
  final startupProvider = StartupProvider.create(
    apiClient,
    apiClient.domainManager,
  );
  // fire-and-forget 域名刷新
  startupProvider.fetchStartup();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: startupProvider),
    ],
    child: const MyApp(),
  );
}
```

- [ ] **Step 5: 运行测试通过**

Run: `flutter test test/app_test.dart`
Expected: PASS。如 `StartupProvider.create` 签名与 Task 11 不符，以 Task 11 `StartupProvider.create(api, dm)` 为准修正 main.dart 调用。

- [ ] **Step 6: 运行全量测试**

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 7: Commit**

```bash
git add lib/app.dart lib/main.dart test/app_test.dart
git commit -m "feat(app): wire providers, ApiClient and router into bootstrap"
```

---

