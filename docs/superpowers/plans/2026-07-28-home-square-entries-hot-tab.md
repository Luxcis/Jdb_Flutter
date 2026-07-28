# Home Square Entries and Hot Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将首页豆腐块调整为紧凑的 `72×72` 方形，并让“看热播”直接进入排行榜的“看热播”Tab。

**Architecture:** `TofuScroll` 负责方形入口视觉，并仅对跨底部导航分支的“看热播”使用 `context.go('/rankings?tab=hot')`；其他入口继续使用 `context.push`。`AppRouter` 将稳定查询参数映射为 `RankingsPage.initialTabIndex`；`RankingsPage` 继续使用现有 `TabController`，仅开放初始索引注入。

**Tech Stack:** Flutter, Dart, Material 3, GoRouter, flutter_test

## Global Constraints

- 豆腐块视觉尺寸固定为 `72×72` 逻辑像素，Card 自身 `margin` 为 0。
- 入口栏高度为 88，水平和垂直内边距为 8，相邻卡片间距为 8。
- 图标尺寸为 24，图标与文案间距为 4，文案使用主题 `bodySmall`。
- “看热播”目标 URI 固定为 `/rankings?tab=hot`。
- “看热播”使用 `context.go` 切换 StatefulShell 分支，其他豆腐块继续使用 `context.push`。
- `tab=hot` 映射到排行榜索引 1；普通或未知参数映射到索引 0。
- 不新增全局状态，不新增路由，不改变其他豆腐块目标。
- 所有行为变更先写失败测试并确认 RED，再写最小实现并确认 GREEN。

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/features/home/widgets/tofu_scroll.dart` | Modify | 紧凑方形入口及看热播 URI |
| `test/features/home/tofu_scroll_test.dart` | Modify | 验证尺寸、间距和目标 URI |
| `lib/features/rankings/screens/rankings_screen.dart` | Modify | 接收并应用初始 Tab 索引 |
| `test/features/rankings/rankings_screen_test.dart` | Modify | 验证直接打开看热播 Tab |
| `lib/core/router/app_router.dart` | Modify | 将 `tab=hot` 查询参数映射到索引 1 |
| `test/core/router/app_router_auth_test.dart` | Modify | 验证 hot、默认及未知参数映射 |

## Task 1: Make Tofu Entries Compact Squares

**Files:**

- Modify: `test/features/home/tofu_scroll_test.dart`
- Modify: `lib/features/home/widgets/tofu_scroll.dart`

**Interfaces:**

- Produces key: `tofu-<label>` on each Card.
- Changes `TofuItem.route` for “看热播” to `/rankings?tab=hot`.

- [ ] **Step 1: Strengthen the existing widget test**

After pumping `TofuScroll`, replace the loose shape assertion with:

```dart
final hotCard = find.byKey(const Key('tofu-看热播'));
final articleCard = find.byKey(const Key('tofu-AV资讯'));
expect(tester.getSize(hotCard), const Size.square(72));
expect(tester.getSize(articleCard), const Size.square(72));
expect(
  tester.getTopLeft(articleCard).dx - tester.getTopRight(hotCard).dx,
  8,
);

final card = tester.widget<Card>(hotCard);
expect(card.margin, EdgeInsets.zero);
expect(card.shape, isA<RoundedRectangleBorder>());
```

Update the route assertion:

```dart
await tester.tap(find.text('看热播'));
await tester.pumpAndSettle();
expect(router.state.uri.path, '/rankings');
expect(router.state.uri.queryParameters['tab'], 'hot');
```

- [ ] **Step 2: Run the tofu test and confirm RED**

Run:

```bash
flutter test test/features/home/tofu_scroll_test.dart
```

Expected: size is not `72×72`, spacing is not 8, Card margin is not zero, and the URI lacks `tab=hot`.

- [ ] **Step 3: Implement the compact square layout**

Change the first route:

```dart
route: '/rankings?tab=hot',
```

Update the list and card dimensions:

```dart
return SizedBox(
  height: 88,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.all(8),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(width: 8),
    itemBuilder: (context, i) {
      final item = items[i];
      return SizedBox.square(
        dimension: 72,
        child: Card(
          key: Key('tofu-${item.label}'),
          margin: EdgeInsets.zero,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (item.route == '/rankings?tab=hot') {
                context.go(item.route);
                return;
              }
              context.push(item.route);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Icon(item.icon, size: 24, color: item.color),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/features/home/widgets/tofu_scroll.dart \
  test/features/home/tofu_scroll_test.dart
flutter test test/features/home/tofu_scroll_test.dart \
  test/features/home/home_screen_test.dart
```

Expected: tofu and home tests pass.

## Task 2: Allow RankingsPage to Start on the Hot Tab

**Files:**

- Modify: `test/features/rankings/rankings_screen_test.dart`
- Modify: `lib/features/rankings/screens/rankings_screen.dart`

**Interfaces:**

- Produces: `const RankingsPage({super.key, this.initialTabIndex = 0})`.
- Valid indices: 0 through 5.

- [ ] **Step 1: Extend the test fixture and add the failing initial-tab test**

Add `int initialTabIndex = 0` to `_pumpRankings`. Use it in the optional GoRouter builder and both app variants:

```dart
RankingsPage(initialTabIndex: initialTabIndex)
```

Add:

```dart
testWidgets('指定 initialTabIndex 1 时首帧打开看热播', (tester) async {
  final fixture = await _pumpRankings(tester, initialTabIndex: 1);
  await _pumpRankingFrame(tester);

  final tabBar = tester.widget<TabBar>(find.byType(TabBar));
  expect(tabBar.controller!.index, 1);
  expect(
    fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankingsPlayback),
    isNotEmpty,
  );
  expect(find.byTooltip('筛选 Top250'), findsNothing);
});
```

- [ ] **Step 2: Run the new test and confirm RED**

Run:

```bash
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "指定 initialTabIndex 1 时首帧打开看热播"
```

Expected: compile failure because `RankingsPage` has no `initialTabIndex`.

- [ ] **Step 3: Implement initial index injection**

Update the widget:

```dart
class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key, this.initialTabIndex = 0})
    : assert(initialTabIndex >= 0 && initialTabIndex < 6);

  final int initialTabIndex;
```

Initialize state and controller from it:

```dart
late final TabController _tabController;
late int _selectedTabIndex;

@override
void initState() {
  super.initState();
  _selectedTabIndex = widget.initialTabIndex;
  _tabController = TabController(
    length: tabs.length,
    initialIndex: widget.initialTabIndex,
    vsync: this,
  );
  _tabController.addListener(_handleTabChanged);
}

@override
void didUpdateWidget(covariant RankingsPage oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.initialTabIndex == widget.initialTabIndex ||
      _tabController.index == widget.initialTabIndex) {
    return;
  }
  _tabController.index = widget.initialTabIndex;
}
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/features/rankings/screens/rankings_screen.dart \
  test/features/rankings/rankings_screen_test.dart
flutter test test/features/rankings/rankings_screen_test.dart
```

Expected: all rankings tests pass.

## Task 3: Map the Query Parameter in AppRouter

**Files:**

- Modify: `test/core/router/app_router_auth_test.dart`
- Modify: `lib/core/router/app_router.dart`

**Interfaces:**

- Consumes: `GoRouterState.uri.queryParameters['tab']`.
- Produces: `RankingsPage(initialTabIndex: tab == 'hot' ? 1 : 0)`.

- [ ] **Step 1: Add failing route mapping tests**

Add a helper that pumps `AppRouter.buildForTest` with an unauthenticated `AuthProvider`, then add:

```dart
testWidgets('从首页进入 rankings tab=hot 打开看热播 Tab', (tester) async {
  final auth = await createAuth(false);
  final router = AppRouter.buildForTest(initialLocation: '/rankings');
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));

  router.go('/home');
  await tester.pump(const Duration(milliseconds: 100));
  router.go('/rankings?tab=hot');
  await tester.pump(const Duration(milliseconds: 100));

  expect(router.state.uri.path, '/rankings');
  expect(router.state.uri.queryParameters['tab'], 'hot');
  final tabBar = tester.widget<TabBar>(find.byType(TabBar));
  expect(tabBar.controller!.index, 1);
});

testWidgets('rankings 未知参数仍打开 Top250', (tester) async {
  final auth = await createAuth(false);
  final router = AppRouter.buildForTest(
    initialLocation: '/rankings?tab=unknown',
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));

  final tabBar = tester.widget<TabBar>(find.byType(TabBar));
  expect(tabBar.controller!.index, 0);
});
```

- [ ] **Step 2: Run both tests and confirm RED**

Run:

```bash
flutter test test/core/router/app_router_auth_test.dart \
  --plain-name "从首页进入 rankings tab=hot 打开看热播 Tab"
flutter test test/core/router/app_router_auth_test.dart \
  --plain-name "rankings 未知参数仍打开 Top250"
```

Expected: the hot test reports index 0 because the route ignores the query parameter.

- [ ] **Step 3: Implement the router mapping**

Replace the rankings route builder:

```dart
GoRoute(
  path: AppRoutes.rankings,
  builder: (context, state) => RankingsPage(
    initialTabIndex: state.uri.queryParameters['tab'] == 'hot' ? 1 : 0,
  ),
),
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/core/router/app_router.dart \
  test/core/router/app_router_auth_test.dart
flutter test test/core/router/app_router_auth_test.dart \
  test/features/rankings/rankings_screen_test.dart \
  test/features/home/tofu_scroll_test.dart
```

Expected: all route, ranking and tofu tests pass.

## Task 4: Final Verification and Commit

**Files:**

- Verify all six files above.
- Preserve unchanged: `docs/main/api/jdb_api_openapi.json`.

- [ ] **Step 1: Run focused regression tests**

Run:

```bash
flutter test \
  test/features/home/tofu_scroll_test.dart \
  test/features/home/home_screen_test.dart \
  test/features/rankings/rankings_screen_test.dart \
  test/core/router/app_router_auth_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 2: Run repository verification**

Run:

```bash
flutter test
flutter analyze
```

Expected: full suite passes and analysis reports no issues.

- [ ] **Step 3: Verify scope**

Run:

```bash
git diff --check
git status --short
git diff --name-status HEAD
```

Confirm only the six implementation/test files changed and the OpenAPI file is unchanged.

- [ ] **Step 4: Commit the follow-up**

Run:

```bash
git add \
  lib/features/home/widgets/tofu_scroll.dart \
  lib/features/rankings/screens/rankings_screen.dart \
  lib/core/router/app_router.dart \
  test/features/home/tofu_scroll_test.dart \
  test/features/rankings/rankings_screen_test.dart \
  test/core/router/app_router_auth_test.dart
git commit -m "feat: open hot rankings from compact home entry"
```
