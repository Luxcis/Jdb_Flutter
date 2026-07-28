# Rankings Movie Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让排行榜全部六个 Tab 中的影片点击后通过现有 `/movie/:id` 路由进入对应影片详情页。

**Architecture:** 排行榜页面在 Top250 的 `MovieListTile.onTap` 和网格榜单的 `MovieGridView.onMovieTap` 上显式注入 GoRouter 导航回调。共享影片组件的默认行为保持不变；Widget 测试使用实际 GoRouter 路由状态验证 Top250、看热播和四榜共享入口。

**Tech Stack:** Flutter, Dart, GoRouter, Provider, flutter_test

## Global Constraints

- 覆盖 Top250、看热播、有码、无码、欧美、FC2 全部排行榜 Tab。
- 统一导航到 `/movie/${movie.id}`，使用 `context.push`，不替换当前底部导航栈。
- 不修改 `MovieGridView`、`MovieListTile`、`MovieCard` 的共享默认行为。
- 不改变排行榜筛选、接口参数、分页、加载态、错误态、Tab 保活或卡片样式。
- 按用户明确决定保留紧凑筛选的 `MaterialTapTargetSize.shrinkWrap`，不实施最终审查提出的 48dp 点击区建议。
- 先写失败 Widget 测试并确认 RED，再写最小实现并确认 GREEN。
- 只暂存本计划列出的文件；不重置或清理已有工作树内容。

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/features/rankings/screens/rankings_screen.dart` | Modify | 为排行榜列表与网格影片注入详情导航回调 |
| `test/features/rankings/rankings_screen_test.dart` | Modify | 提供实际 GoRouter 测试环境并验证三种排行榜入口 |

## Task 1: Add Detail Navigation to Every Ranking Movie

**Files:**

- Modify: `test/features/rankings/rankings_screen_test.dart`
- Modify: `lib/features/rankings/screens/rankings_screen.dart`

**Interfaces:**

- Consumes: `MovieListTile.onTap: VoidCallback?`
- Consumes: `MovieGridView.onMovieTap: void Function(MovieSummary)?`
- Consumes: existing GoRouter route `/movie/:id`
- Produces: every ranking movie tap pushes `/movie/${movie.id}`

- [ ] **Step 1: Add a real router option to the rankings test fixture**

Import GoRouter:

```dart
import 'package:go_router/go_router.dart';
```

Extend `_RankingFixture`:

```dart
class _RankingFixture {
  const _RankingFixture(this.adapter, this.auth, {this.router});

  final FakeAdapter adapter;
  final AuthProvider auth;
  final GoRouter? router;
}
```

Add `bool withRouter = false` to `_pumpRankings`. Replace endpoint-derived IDs with stable path-safe IDs:

```dart
final movieId = switch (path) {
  Endpoints.moviesTop => 'top-movie',
  Endpoints.rankingsPlayback => 'hot-movie',
  _ => 'ranked-movie',
};
```

Use `movieId` in the response:

```dart
'id': movieId,
```

Before pumping the app, create the optional router:

```dart
final router = withRouter
    ? GoRouter(
        initialLocation: '/rankings',
        routes: [
          GoRoute(
            path: '/rankings',
            builder: (_, _) => const RankingsPage(),
          ),
          GoRoute(
            path: '/movie/:id',
            builder: (_, state) => Scaffold(
              body: Text(
                '影片 ${state.pathParameters['id']}',
                key: const Key('movie-detail-placeholder'),
              ),
            ),
          ),
        ],
      )
    : null;
if (router != null) addTearDown(router.dispose);
```

Keep the existing `MediaQueryData(size: Size(320, 640), textScaler: ...)`. Select the app variant without duplicating provider setup:

```dart
final app = router == null
    ? MaterialApp(
        home: MediaQuery(
          data: mediaQueryData,
          child: const RankingsPage(),
        ),
      )
    : MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => MediaQuery(
          data: mediaQueryData,
          child: child!,
        ),
      );

await tester.pumpWidget(
  ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: app,
  ),
);
return _RankingFixture(adapter, auth, router: router);
```

- [ ] **Step 2: Write the three failing navigation tests**

Add:

```dart
testWidgets('Top250 列表影片点击进入详情页', (tester) async {
  final fixture = await _pumpRankings(tester, withRouter: true);
  await _pumpRankingFrame(tester);

  await tester.tap(find.text('Ranked Movie'));
  await tester.pumpAndSettle();

  expect(fixture.router!.state.uri.path, '/movie/top-movie');
  expect(find.byKey(const Key('movie-detail-placeholder')), findsOneWidget);
});

testWidgets('看热播网格影片点击进入详情页', (tester) async {
  final fixture = await _pumpRankings(tester, withRouter: true);
  await _showTab(tester, 1);

  await tester.tap(find.text('Hot Movie'));
  await tester.pumpAndSettle();

  expect(fixture.router!.state.uri.path, '/movie/hot-movie');
  expect(find.byKey(const Key('movie-detail-placeholder')), findsOneWidget);
});

testWidgets('综合排行榜网格影片点击进入详情页', (tester) async {
  final fixture = await _pumpRankings(tester, withRouter: true);
  await _showTab(tester, 2);

  await tester.tap(find.text('Ranked Movie'));
  await tester.pumpAndSettle();

  expect(fixture.router!.state.uri.path, '/movie/ranked-movie');
  expect(find.byKey(const Key('movie-detail-placeholder')), findsOneWidget);
});
```

The third test covers 有码 directly; 无码、欧美、FC2 share the same `_RankTab` build implementation and remain covered by the existing type-mapping and layout tests.

- [ ] **Step 3: Run the navigation tests and confirm RED**

Run:

```bash
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "Top250 列表影片点击进入详情页"
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "看热播网格影片点击进入详情页"
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "综合排行榜网格影片点击进入详情页"
```

Expected: each test fails because the route remains `/rankings` and the detail placeholder is not rendered.

- [ ] **Step 4: Add explicit navigation callbacks in the rankings page**

Import GoRouter in `rankings_screen.dart`:

```dart
import 'package:go_router/go_router.dart';
```

Update the Top250 item builder:

```dart
itemBuilder: (context, index) {
  final movie = _controller.items[index];
  return MovieListTile(
    movie: movie,
    rank: widget.filter.startRank + index,
    onTap: () => context.push('/movie/${movie.id}'),
  );
},
```

Update `_HotPlayTabState.build`:

```dart
Expanded(
  child: MovieGridView(
    controller: _controller,
    onMovieTap: (movie) => context.push('/movie/${movie.id}'),
  ),
),
```

Update `_RankTabState.build` with the same callback:

```dart
Expanded(
  child: MovieGridView(
    controller: _controller,
    onMovieTap: (movie) => context.push('/movie/${movie.id}'),
  ),
),
```

- [ ] **Step 5: Format and verify GREEN**

Run:

```bash
dart format \
  lib/features/rankings/screens/rankings_screen.dart \
  test/features/rankings/rankings_screen_test.dart
flutter test test/features/rankings/rankings_screen_test.dart
flutter test test/api_integration_test.dart --plain-name RankingService
dart analyze \
  lib/features/rankings/screens/rankings_screen.dart \
  test/features/rankings/rankings_screen_test.dart
```

Expected:

- all rankings Widget tests pass, including the three navigation tests;
- four `RankingService` tests pass;
- focused analysis reports no issues.

- [ ] **Step 6: Commit the navigation change**

Run:

```bash
git status --short
git add \
  lib/features/rankings/screens/rankings_screen.dart \
  test/features/rankings/rankings_screen_test.dart
git commit -m "feat: open ranking movies in detail"
```

## Task 2: Full and Android Navigation Verification

**Files:**

- Verify: `lib/features/rankings/screens/rankings_screen.dart`
- Verify: `test/features/rankings/rankings_screen_test.dart`
- Save screenshots only under `/tmp`

**Interfaces:**

- Consumes: Task 1 navigation callbacks
- Produces: automated and Android evidence that all ranking entry types reach `/movie/:id`

- [ ] **Step 1: Run repository-wide verification**

Run:

```bash
dart format --output=none --set-exit-if-changed \
  lib/features/rankings/screens/rankings_screen.dart \
  test/features/rankings/rankings_screen_test.dart
flutter analyze
flutter test
```

Record the exact full-test pass count.

- [ ] **Step 2: Build and install the APK**

Run:

```bash
flutter build apk --debug
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Use the mounted `mcp__adb_tool` for UI hierarchy and screenshots. Use local `adb` only for install, launch, tap, back, and other actions that the connector does not expose.

- [ ] **Step 3: Verify Top250 navigation**

Launch `xxx.porn.jdb`, open 排行榜 > Top250, tap a visible list item, and verify the destination displays the tapped movie title/number rather than the rankings page.

Capture:

```bash
adb exec-out screencap -p > /tmp/rankings-top250-detail-navigation.png
```

Return to rankings and verify the selected Top250 filter and loaded list remain present.

- [ ] **Step 4: Verify grid navigation**

Open 看热播, tap a visible movie card, and verify the detail page. Return and repeat with one representative comprehensive tab such as 有码.

Capture:

```bash
adb exec-out screencap -p > /tmp/rankings-grid-detail-navigation.png
```

Confirm via `mcp__adb_tool.get_uilayout` that the destination is a movie detail page. Because 无码、欧美、FC2 share `_RankTab`, automated tests and the representative device action cover their common callback.

- [ ] **Step 5: Check scope and repository state**

Run:

```bash
git status --short
git log --oneline -5
```

The final report must include:

- three focused navigation tests and full-test result;
- analyze and APK build/install result;
- ADB device identifier and connector/local-ADB division;
- Top250, 看热播, and representative comprehensive-tab navigation results;
- screenshot paths;
- navigation commit hash;
- confirmation that compact filters still use `shrinkWrap` per user decision.
