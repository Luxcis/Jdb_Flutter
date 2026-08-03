# Search Entry Points Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在首页豆腐块上方以及排行榜、类别、演员页顶部增加可返回来源页的搜索入口。

**Architecture:** 在 `lib/core/widgets/search_entry.dart` 提供首页整行搜索栏和 AppBar 搜索按钮，两者统一通过 `context.push(AppRoutes.search)` 导航。四个业务页面只组合共享组件，保留现有筛选按钮、Tab 和数据加载逻辑。

**Tech Stack:** Flutter Material 3、Dart、go_router、flutter_test

## Global Constraints

- 首页搜索栏内部顺序必须是 `Icons.search` 和“输入演员或番号等关键字”。
- 首页搜索栏位于 `TofuScroll` 之前，并随首页内容滚动。
- 排行榜、类别、演员页的搜索按钮必须位于 `AppBar.actions` 最右侧。
- 所有入口必须使用 `context.push(AppRoutes.search)`，不得切换底部导航分支。
- 保留排行榜和类别现有筛选入口及其行为。
- 不修改搜索页内部行为，不新增第三方依赖，不增加本地化资源。

---

### Task 1: 共享搜索入口组件

**Files:**
- Create: `lib/core/widgets/search_entry.dart`
- Create: `test/core/widgets/search_entry_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.search`、`BuildContext.push`、Material 3 `ColorScheme`
- Produces: `HomeSearchBar({Key? key})` 与 `SearchIconButton({Key? key})`

- [x] **Step 1: 写共享组件的失败测试**

```dart
testWidgets('首页搜索栏显示图标和文案并进入搜索路由', (tester) async {
  final router = GoRouter(
    initialLocation: '/source',
    routes: [
      GoRoute(path: '/source', builder: (_, _) => const Scaffold(body: HomeSearchBar())),
      GoRoute(path: AppRoutes.search, builder: (_, _) => const Scaffold(body: Text('搜索页'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));

  expect(find.byIcon(Icons.search), findsOneWidget);
  expect(find.text('输入演员或番号等关键字'), findsOneWidget);
  await tester.tap(find.byType(HomeSearchBar));
  await tester.pumpAndSettle();

  expect(router.state.uri.path, AppRoutes.search);
});

testWidgets('顶部搜索按钮显示 tooltip 并进入搜索路由', (tester) async {
  final router = GoRouter(
    initialLocation: '/source',
    routes: [
      GoRoute(
        path: '/source',
        builder: (_, _) => const Scaffold(
          appBar: AppBar(actions: [SearchIconButton()]),
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, _) => const Scaffold(body: Text('搜索页')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));

  expect(find.byTooltip('搜索'), findsOneWidget);
  await tester.tap(find.byTooltip('搜索'));
  await tester.pumpAndSettle();
  expect(router.state.uri.path, AppRoutes.search);
});
```

- [x] **Step 2: 运行测试并确认因组件不存在而失败**

Run: `flutter test test/core/widgets/search_entry_test.dart`

Expected: FAIL，错误指出 `HomeSearchBar` 或 `SearchIconButton` 未定义。

- [x] **Step 3: 编写最小共享组件实现**

```dart
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Semantics(
      button: true,
      label: '搜索',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.search),
          child: const SizedBox(
            height: 52,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                spacing: 12,
                children: [
                  Icon(Icons.search),
                  Expanded(child: Text('输入演员或番号等关键字')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SearchIconButton extends StatelessWidget {
  const SearchIconButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '搜索',
    onPressed: () => context.push(AppRoutes.search),
    icon: const Icon(Icons.search),
  );
}
```

- [x] **Step 4: 格式化并运行共享组件测试**

Run: `dart format lib/core/widgets/search_entry.dart test/core/widgets/search_entry_test.dart`

Run: `flutter test test/core/widgets/search_entry_test.dart`

Expected: PASS。

### Task 2: 首页搜索栏接入

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`
- Modify: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `const HomeSearchBar()`
- Produces: 首页首个 Sliver 中可见且位于 `TofuScroll` 上方的搜索入口

- [x] **Step 1: 写首页布局失败测试**

```dart
testWidgets('首页豆腐块上方显示整行搜索入口', (tester) async {
  await _pumpHome(tester);

  expect(find.byType(HomeSearchBar), findsOneWidget);
  expect(find.text('输入演员或番号等关键字'), findsOneWidget);
  final searchTop = tester.getTopLeft(find.byType(HomeSearchBar)).dy;
  final tofuTop = tester.getTopLeft(find.byType(TofuScroll)).dy;
  expect(searchTop, lessThan(tofuTop));
});
```

- [x] **Step 2: 运行测试并确认因首页未接入而失败**

Run: `flutter test test/features/home/home_screen_test.dart --plain-name '首页豆腐块上方显示整行搜索入口'`

Expected: FAIL，`HomeSearchBar` 在首页中不存在。

- [x] **Step 3: 在首页首个 Sliver 接入搜索栏**

```dart
slivers: [
  const SliverToBoxAdapter(child: HomeSearchBar()),
  const SliverToBoxAdapter(child: TofuScroll()),
  // 保留后续内容
],
```

- [x] **Step 4: 格式化并运行首页测试**

Run: `dart format lib/features/home/screens/home_screen.dart test/features/home/home_screen_test.dart`

Run: `flutter test test/features/home/home_screen_test.dart`

Expected: PASS，现有首页分页与换一组测试保持通过。

### Task 3: 排行榜、类别、演员顶部搜索按钮接入

**Files:**
- Modify: `lib/features/rankings/screens/rankings_screen.dart`
- Modify: `lib/features/categories/screens/categories_screen.dart`
- Modify: `lib/features/actors/screens/actors_screen.dart`
- Modify: `test/features/rankings/rankings_screen_test.dart`
- Modify: `test/features/categories/categories_screen_test.dart`
- Modify: `test/features/actors/actors_screen_test.dart`

**Interfaces:**
- Consumes: `const SearchIconButton()`
- Produces: 三个页面 AppBar 最右侧的搜索按钮；原筛选按钮保持在其左侧

- [x] **Step 1: 为三个页面写失败测试**

```dart
testWidgets('排行榜顶部搜索按钮进入搜索页且位于筛选按钮右侧', (tester) async {
  final fixture = await _pumpRankings(tester, withRouter: true, initialTabIndex: 0);
  expect(find.byTooltip('筛选 Top250'), findsOneWidget);
  expect(find.byTooltip('搜索'), findsOneWidget);
  expect(
    tester.getCenter(find.byTooltip('搜索')).dx,
    greaterThan(tester.getCenter(find.byTooltip('筛选 Top250')).dx),
  );
  await tester.tap(find.byTooltip('搜索'));
  await tester.pumpAndSettle();
  expect(fixture.router!.state.uri.path, AppRoutes.search);
});
```

类别页与演员页分别使用以下真实路由结构，传入已有 `_FakeSource` 或 `ActorService` 测试替身，避免外部网络请求：

```dart
final router = GoRouter(
  initialLocation: '/categories',
  routes: [
    GoRoute(
      path: '/categories',
      builder: (_, _) => CategoriesPage(dataSource: source),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (_, _) => const Scaffold(body: Text('搜索页')),
    ),
  ],
);
await tester.pumpWidget(MaterialApp.router(routerConfig: router));
expect(
  tester.getCenter(find.byTooltip('搜索')).dx,
  greaterThan(
    tester.getCenter(find.byKey(const Key('categories-filter-button'))).dx,
  ),
);
await tester.tap(find.byTooltip('搜索'));
await tester.pumpAndSettle();
expect(router.state.uri.path, AppRoutes.search);
```

演员测试将初始路径替换为 `/actors`，来源 builder 返回 `ActorsPage(service: fixture.service)`，并执行相同的点击和 URI 断言。

- [x] **Step 2: 运行三个定向测试并确认因按钮缺失而失败**

Run: `flutter test test/features/rankings/rankings_screen_test.dart test/features/categories/categories_screen_test.dart test/features/actors/actors_screen_test.dart --plain-name '搜索'`

Expected: FAIL，三个页面均找不到 tooltip 为“搜索”的按钮。

- [x] **Step 3: 将共享按钮追加到三个 AppBar actions 末尾**

```dart
actions: [
  // 保留页面已有筛选按钮
  const SearchIconButton(),
],
```

演员页新增 `actions: const [SearchIconButton()]`。排行榜和类别页确保搜索按钮写在现有条件筛选按钮之后。

- [x] **Step 4: 格式化并运行三个页面测试**

Run: `dart format lib/features/rankings/screens/rankings_screen.dart lib/features/categories/screens/categories_screen.dart lib/features/actors/screens/actors_screen.dart test/features/rankings/rankings_screen_test.dart test/features/categories/categories_screen_test.dart test/features/actors/actors_screen_test.dart`

Run: `flutter test test/features/rankings/rankings_screen_test.dart test/features/categories/categories_screen_test.dart test/features/actors/actors_screen_test.dart`

Expected: PASS，原有筛选、Tab、分页和演员推荐测试保持通过。

### Task 4: 全量验证与交付检查

**Files:**
- Verify: `lib/core/widgets/search_entry.dart`
- Verify: `lib/features/home/screens/home_screen.dart`
- Verify: `lib/features/rankings/screens/rankings_screen.dart`
- Verify: `lib/features/categories/screens/categories_screen.dart`
- Verify: `lib/features/actors/screens/actors_screen.dart`
- Verify: all modified tests

**Interfaces:**
- Consumes: Tasks 1-3 的完整实现
- Produces: 可交付且无静态分析错误的搜索入口功能

- [x] **Step 1: 运行全部相关测试**

Run: `flutter test test/core/widgets/search_entry_test.dart test/features/home/home_screen_test.dart test/features/rankings/rankings_screen_test.dart test/features/categories/categories_screen_test.dart test/features/actors/actors_screen_test.dart`

Expected: PASS。

- [x] **Step 2: 运行完整测试套件**

Run: `flutter test`

Expected: PASS，0 failures。

- [x] **Step 3: 运行静态分析和差异检查**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `git diff --check`

Expected: 无输出，退出码 0。

- [x] **Step 4: 对照规格逐项复核并检查提交范围**

Run: `git status --short && git diff --stat && git diff`

Expected: 仅包含计划列出的共享组件、四个页面、对应测试和本计划文件；无无关变更。
