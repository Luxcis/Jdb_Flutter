### Task 12: Router Shell + MainShell + 5 占位 Tab

**Files:**
- Create: `lib/core/router/routes.dart`
- Create: `lib/core/router/app_router.dart`
- Create: `lib/core/widgets/main_shell.dart`
- Modify: `lib/features/home/screens/home_screen.dart`（替换为占位页）
- Create: `lib/features/rankings/screens/rankings_screen.dart`、`lib/features/categories/screens/categories_screen.dart`、`lib/features/actors/screens/actors_screen.dart`、`lib/features/profile/screens/profile_screen.dart`（占位）
- 各 feature 新增 `index.dart` 导出 Page
- Test: `test/app_router_test.dart`

**Interfaces:**
- Produces: `AppRouter`（`GoRouter`）、`MainShell`、5 个占位 `Screen`、`routes.dart` 路径常量。

- [ ] **Step 1: 写失败测试（路由到 /home 渲染首页占位）**

```dart
// test/app_router_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/app_router.dart';

void main() {
  testWidgets('AppRouter 默认渲染首页占位', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: AppRouter.buildForTest(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('点击排行榜 Tab 切换', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: AppRouter.buildForTest(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排行榜'));
    await tester.pumpAndSettle();
    expect(find.text('排行榜占位'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/app_router_test.dart`
Expected: FAIL（`AppRouter` 未定义）。

- [ ] **Step 3: 实现 routes.dart**

```dart
// lib/core/router/routes.dart
class AppRoutes {
  const AppRoutes._();
  static const String home = '/home';
  static const String rankings = '/rankings';
  static const String categories = '/categories';
  static const String actors = '/actors';
  static const String profile = '/profile';
  static const String login = '/login';

  /// 需登录的路径集合（Phase 0 仅留接口，auth redirect 后续阶段填充）。
  static const Set<String> protectedRoutes = {};
}
```

- [ ] **Step 4: 实现占位 Screen（home 替换，其余新建）**

```dart
// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('首页')));
}
```
```dart
// lib/features/rankings/screens/rankings_screen.dart
import 'package:flutter/material.dart';
class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('排行榜占位')));
}
```
（categories/actors/profile 同构，文案分别为"类别占位"、"演员占位"、"我的占位"。）

各 `index.dart`：
```dart
// lib/features/home/index.dart
export 'screens/home_screen.dart';
```
（其余 feature 同构。）

- [ ] **Step 5: 实现 MainShell**

```dart
// lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '排行榜'),
          NavigationDestination(icon: Icon(Icons.category), label: '类别'),
          NavigationDestination(icon: Icon(Icons.people), label: '演员'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 实现 app_router**

```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/main_shell.dart';
import 'package:jade/features/home/index.dart';
import 'package:jade/features/rankings/index.dart';
import 'package:jade/features/categories/index.dart';
import 'package:jade/features/actors/index.dart';
import 'package:jade/features/profile/index.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter buildForTest() => GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (c, s) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.rankings, builder: (c, s) => const RankingsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.categories, builder: (c, s) => const CategoriesPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.actors, builder: (c, s) => const ActorsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.profile, builder: (c, s) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 7: 运行测试通过**

Run: `flutter test test/app_router_test.dart`
Expected: PASS（2 个用例）。

- [ ] **Step 8: Commit**

```bash
git add lib/core/router/routes.dart lib/core/router/app_router.dart lib/core/widgets/main_shell.dart lib/features/ test/app_router_test.dart
git commit -m "feat(core/router): add go_router StatefulShellRoute with 5 placeholder tabs"
```

---

