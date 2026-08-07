# CommonListPage 路由化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `/common-list` 路由，把 4 个页面共 9 处 `CommonListPage` 入口从 `Navigator.push(MaterialPageRoute(...))` 改为 `context.push` 路由传参，删除 4 个私有 `_openCommonList` 函数。

**Architecture:** core 层新增路由常量与 GoRoute（query 参数 title/type/category/id，路由内解析 type 为 int）；4 个 feature 页面的 onTap 统一改为 `context.push(Uri(path: AppRoutes.commonList, queryParameters: {...}).toString())`；`CommonListPage` 本身与 `dataSource` 注入逻辑不改。

**Tech Stack:** Flutter / Dart，go_router。测试用 `flutter_test` + 项目自有 GoRouter 测试模式（`AppRouter.buildForTest` / 局部 GoRouter）。

## Global Constraints

- 文案全部中文硬编码，不使用 ARB/l10n（RULES.md）。
- 路由参数经 `Uri(...queryParameters: ...)` 传输，由 Uri 自动 URL 编码（标题含中文/特殊字符如「导演 - K太郎」「［Jo］Style」必须安全）。
- 路由 builder 内 `type` 用 `int.tryParse(q['type'] ?? '') ?? 0` 兜底；`title/category/id` 缺失时兜底空字符串。
- `CommonListPage` 的可选 `dataSource` 不通过路由传，页面走既有默认回退（`ApiClient.instanceOrNull` → `TagMoviesService` / `UnavailableTagMoviesDataSource`）。
- 不改 `CommonListPage` 本身（构造参数、过滤/排序/分页逻辑）。
- 各页面删除私有 `_openCommonList` 后，同步清理不再使用的 `common_list_page.dart` import；新增 `go_router` 与 `core/router/routes.dart` import（若尚未引入）。
- 单条提交：每个任务独立 commit，commit message 遵循仓库 `feat(scope): 描述` / `refactor(scope): 描述` 风格。

### Task 1: 新增 /common-list 路由

**Files:**
- Modify: `lib/core/router/routes.dart`（新增 `AppRoutes.commonList` 常量）
- Modify: `lib/core/router/app_router.dart`（import `CommonListPage` + 注册 `GoRoute`）
- Test: `test/app_router_test.dart`（新增 1 个用例）

**Interfaces:**
- Consumes: `CommonListPage`（`lib/features/common/screens/common_list_page.dart`，构造参数 title/type/category/id）。
- Produces: `AppRoutes.commonList == '/common-list'`；`GoRoute(path: AppRoutes.commonList, builder: ...)` 从 `state.uri.queryParameters` 解析 title/type/category/id 构建 `CommonListPage`。供 Task 2-5 的页面 `context.push` 使用。

- [ ] **Step 1: 写失败测试**

在 `test/app_router_test.dart` 的 `main()` 内追加（文件已 import `common_list_page.dart` 不需要，先补 import）：

```dart
import 'package:jade/features/common/screens/common_list_page.dart';
```

```dart
  testWidgets('/common-list 路由带参数渲染 CommonListPage', (tester) async {
    final router = AppRouter.buildForTest(
      initialLocation: Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '导演 - K太郎',
          'type': '0',
          'category': 'd',
          'id': 'AqK',
        },
      ).toString(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeAuth>(
        create: (_) => _FakeAuth.create(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<CommonListPage>(find.byType(CommonListPage));
    expect(page.title, '导演 - K太郎');
    expect(page.type, 0);
    expect(page.category, 'd');
    expect(page.id, 'AqK');
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/app_router_test.dart`
Expected: FAIL（`/common-list` 未注册，GoRouter 报 route not found 或渲染失败）。

- [ ] **Step 3: 实现路由**

`lib/core/router/routes.dart` 的 `AppRoutes` 类中（`directors` 常量附近）新增：

```dart
  static const String commonList = '/common-list';
```

`lib/core/router/app_router.dart` import 区新增：

```dart
import 'package:jade/features/common/screens/common_list_page.dart';
```

在 `/directors` 的 `GoRoute` 之后注册：

```dart
    GoRoute(
      path: AppRoutes.commonList,
      builder: (c, s) {
        final q = s.uri.queryParameters;
        return CommonListPage(
          title: q['title'] ?? '',
          type: int.tryParse(q['type'] ?? '') ?? 0,
          category: q['category'] ?? '',
          id: q['id'] ?? '',
        );
      },
    ),
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/app_router_test.dart`
Expected: 新增用例 PASS，既有用例不回归。

- [ ] **Step 5: 提交**

```bash
git add lib/core/router/routes.dart lib/core/router/app_router.dart test/app_router_test.dart
git commit -m "feat(router): add /common-list route with query params"
```

### Task 2: 导演页改用路由

**Files:**
- Modify: `lib/features/directors/screens/directors_page.dart`
- Test: `test/features/directors/directors_page_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.commonList`（Task 1）、`CommonListPage`、`go_router` 的 `context.push`。
- Produces: 导演条目 onTap 经 `/common-list` 路由进入 `CommonListPage`（title「导演 - 名称」、category 'd'）。

- [ ] **Step 1: 改测试（失败）**

将 `test/features/directors/directors_page_test.dart` 的「点击导演条目进入与搜索结果一致的 CommonListPage」用例整体替换为：

```dart
  testWidgets('点击导演条目经 /common-list 路由进入 CommonListPage', (tester) async {
    final source = _RecordingDirectorDataSource();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => DirectorsPage(dataSource: source)),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (c, s) {
            final q = s.uri.queryParameters;
            return CommonListPage(
              title: q['title'] ?? '',
              type: int.tryParse(q['type'] ?? '') ?? 0,
              category: q['category'] ?? '',
              id: q['id'] ?? '',
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('K太郎'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters, {
      'title': '导演 - K太郎',
      'type': '0',
      'category': 'd',
      'id': 'AqK',
    });
    expect(find.byType(CommonListPage), findsOneWidget);
    expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
    expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
  });
```

文件头部 import 区调整：新增 `package:go_router/go_router.dart` 与 `package:jade/core/router/routes.dart`；保留 `common_list_page.dart`（测试路由 builder 用到）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/directors/directors_page_test.dart`
Expected: 该用例 FAIL（页面仍用 `Navigator.push`，`router.state.uri` 不变）。

- [ ] **Step 3: 实现页面改造**

`lib/features/directors/screens/directors_page.dart`：

- import 区：删除 `package:jade/features/common/screens/common_list_page.dart`；新增 `package:go_router/go_router.dart` 与 `package:jade/core/router/routes.dart`。
- 将条目 onTap（约 70 行）改为：

```dart
              itemBuilder: (context, item) => EntityListTile(
                name: item.name,
                count: item.movieCount,
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.commonList,
                    queryParameters: {
                      'title': '导演 - ${item.name}',
                      'type': '${item.type}',
                      'category': 'd',
                      'id': item.id,
                    },
                  ).toString(),
                ),
              ),
```

- 删除文件末尾的私有 `_openCommonList` 函数（约 131-145 行）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/directors/directors_page_test.dart`
Expected: 4 个用例全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/directors/screens/directors_page.dart test/features/directors/directors_page_test.dart
git commit -m "refactor(directors): navigate to common list via router"
```

### Task 3: 片商页改用路由

**Files:**
- Modify: `lib/features/makers/screens/makers_page.dart`
- Test: `test/features/makers/makers_page_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.commonList`（Task 1）、`CommonListPage`、`context.push`。
- Produces: 片商条目 onTap 经 `/common-list` 路由进入 `CommonListPage`（title「片商 - 名称」、category 'm'）。

- [ ] **Step 1: 改测试（失败）**

将 `test/features/makers/makers_page_test.dart` 的「点击片商条目进入与搜索结果一致的 CommonListPage」用例整体替换为：

```dart
  testWidgets('点击片商条目经 /common-list 路由进入 CommonListPage', (tester) async {
    final source = _RecordingMakerDataSource();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => MakersPage(dataSource: source)),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (c, s) {
            final q = s.uri.queryParameters;
            return CommonListPage(
              title: q['title'] ?? '',
              type: int.tryParse(q['type'] ?? '') ?? 0,
              category: q['category'] ?? '',
              id: q['id'] ?? '',
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Heydouga'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters, {
      'title': '片商 - Heydouga',
      'type': '0',
      'category': 'm',
      'id': 'xZyO',
    });
    expect(find.byType(CommonListPage), findsOneWidget);
    expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
    expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
  });
```

文件头部 import 区：新增 `package:go_router/go_router.dart` 与 `package:jade/core/router/routes.dart`。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/makers/makers_page_test.dart`
Expected: 该用例 FAIL。

- [ ] **Step 3: 实现页面改造**

`lib/features/makers/screens/makers_page.dart`：

- import 区：删除 `package:jade/features/common/screens/common_list_page.dart`；新增 `package:go_router/go_router.dart` 与 `package:jade/core/router/routes.dart`。
- 将条目 onTap（约 70 行）改为：

```dart
              itemBuilder: (context, item) => EntityListTile(
                name: item.name,
                count: item.movieCount,
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.commonList,
                    queryParameters: {
                      'title': '片商 - ${item.name}',
                      'type': '${item.type}',
                      'category': 'm',
                      'id': item.id,
                    },
                  ).toString(),
                ),
              ),
```

- 删除文件末尾的私有 `_openCommonList` 函数（约 131-145 行）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/makers/makers_page_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/makers/screens/makers_page.dart test/features/makers/makers_page_test.dart
git commit -m "refactor(makers): navigate to common list via router"
```

### Task 4: 系列页改用路由（2 处入口）

**Files:**
- Modify: `lib/features/series/screens/series_page.dart`
- Test: `test/features/series/series_page_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.commonList`（Task 1）、`CommonListPage`、`context.push`。
- Produces: 番号条目（category 'c'）与系列条目（category 's'）均经 `/common-list` 路由进入 `CommonListPage`。

- [ ] **Step 1: 改测试（失败）**

将 `test/features/series/series_page_test.dart` 的「点击系列条目进入 CommonListPage，番号条目进入番号公共页」用例整体替换为：

```dart
  testWidgets('番号与系列条目均经 /common-list 路由进入 CommonListPage', (tester) async {
    final source = _RecordingSeriesDataSource();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => SeriesPage(dataSource: source)),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (c, s) {
            final q = s.uri.queryParameters;
            return CommonListPage(
              title: q['title'] ?? '',
              type: int.tryParse(q['type'] ?? '') ?? 0,
              category: q['category'] ?? '',
              id: q['id'] ?? '',
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('IPX'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters['title'], '番号 - IPX');
    expect(router.state.uri.queryParameters['category'], 'c');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试系列'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters['title'], '系列 - 测试系列');
    expect(router.state.uri.queryParameters['category'], 's');
    expect(find.text('系列 - 测试系列'), findsOneWidget);
  });
```

文件头部 import 区：新增 `package:go_router/go_router.dart` 与 `package:jade/core/router/routes.dart`（如尚未引入）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/series/series_page_test.dart`
Expected: 该用例 FAIL。

- [ ] **Step 3: 实现页面改造**

`lib/features/series/screens/series_page.dart`：

- import 区：删除 `package:jade/features/common/screens/common_list_page.dart`；新增 `package:go_router/go_router.dart` 与 `package:jade/core/router/routes.dart`。
- 番号条目 onTap（约 68 行）改为：

```dart
              onTap: () => context.push(
                Uri(
                  path: AppRoutes.commonList,
                  queryParameters: {
                    'title': '番号 - ${item.letter}',
                    'type': '${item.type}',
                    'category': 'c',
                    'id': item.id,
                  },
                ).toString(),
              ),
```

- 系列条目 onTap（约 86 行）改为：

```dart
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.commonList,
                    queryParameters: {
                      'title': '系列 - ${item.name}',
                      'type': '${item.type}',
                      'category': 's',
                      'id': item.id,
                    },
                  ).toString(),
                ),
```

- 删除文件末尾的私有 `_openCommonList` 函数（约 147-160 行）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/series/series_page_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/series/screens/series_page.dart test/features/series/series_page_test.dart
git commit -m "refactor(series): navigate to common list via router"
```

### Task 5: 搜索结果页改用路由（5 处入口）

**Files:**
- Modify: `lib/features/search/screens/search_results_screen.dart`
- Test: `test/features/search/search_screen_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.commonList`（Task 1）、`CommonListPage`、`context.push`（search 文件已 import go_router 与 routes.dart）。
- Produces: 系列('s')/片商('m')/导演('d')/清单('l', type 恒为 0)/番号('c') 五类条目均经 `/common-list` 路由进入 `CommonListPage`。

- [ ] **Step 1: 改测试（失败）**

`test/features/search/search_screen_test.dart`：

- 新增一个路由 helper（放在 `_buildSearchResultsRouter` 附近）：

```dart
GoRouter _buildNamedResultsRouter(SearchEntityDataSource entityDataSource) =>
    GoRouter(
      initialLocation: '/search/results',
      routes: [
        GoRoute(
          path: '/search/results',
          builder: (_, _) => SearchResultsPage(
            query: 'test',
            entityDataSource: entityDataSource,
            movieDataSource: _RecordingSearchMovieDataSource(),
          ),
        ),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (c, s) {
            final q = s.uri.queryParameters;
            return CommonListPage(
              title: q['title'] ?? '',
              type: int.tryParse(q['type'] ?? '') ?? 0,
              category: q['category'] ?? '',
              id: q['id'] ?? '',
            );
          },
        ),
      ],
    );
```

- 将「非演员实体进入类型减名称公共页且不请求搜索或影片接口」用例整体替换为：

```dart
  testWidgets('非演员实体经路由进入类型减名称公共页且不请求搜索或影片接口', (tester) async {
    final cases = <({String tab, String expectedTitle, Type rowType})>[
      (tab: '系列', expectedTitle: '系列 - 测试系列', rowType: EntityListTile),
      (tab: '片商', expectedTitle: '片商 - 测试片商', rowType: EntityListTile),
      (tab: '导演', expectedTitle: '导演 - 测试导演', rowType: EntityListTile),
      (tab: '清单', expectedTitle: '清单 - 测试清单', rowType: ListSummaryTile),
      (tab: '番号', expectedTitle: '番号 - TEST', rowType: EntityListTile),
    ];

    for (final item in cases) {
      final source = _FakeSearchEntityDataSource.singleNamedResults();
      final movieSource = _RecordingSearchMovieDataSource();
      final router = _buildNamedResultsRouter(source);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.tab));
      await tester.pumpAndSettle();
      final entityRequestCount = source.totalCalls;
      final movieRequestCount = movieSource.calls.length;

      await tester.tap(find.byType(item.rowType).first);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.commonList);
      expect(find.text(item.expectedTitle), findsOneWidget);
      expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
      expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
      expect(find.byType(MovieGridView), findsOneWidget);
      expect(source.totalCalls, entityRequestCount);
      expect(movieSource.calls, hasLength(movieRequestCount));

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
```

文件头部 import 区：新增 `package:jade/core/widgets/movie_grid_view.dart`（若未引入）、`package:jade/features/common/screens/common_list_page.dart`（若未引入）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/search/search_screen_test.dart`
Expected: 该用例 FAIL。

- [ ] **Step 3: 实现页面改造**

`lib/features/search/screens/search_results_screen.dart`：

- import 区：删除 `package:jade/features/common/screens/common_list_page.dart`（`go_router` 与 `routes.dart` 已存在，保留）。
- 五处 onTap 逐一改为 `context.push(Uri(path: AppRoutes.commonList, queryParameters: {...}).toString())`：

系列（约 155 行）：

```dart
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '系列 - ${item.name}',
                          'type': '${item.type}',
                          'category': 's',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
```

片商（约 175 行）：

```dart
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '片商 - ${item.name}',
                          'type': '${item.type}',
                          'category': 'm',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
```

导演（约 195 行）：

```dart
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '导演 - ${item.name}',
                          'type': '${item.type}',
                          'category': 'd',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
```

清单（约 215 行，type 恒为 0）：

```dart
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '清单 - ${item.name}',
                          'type': '0',
                          'category': 'l',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
```

番号（约 235 行，用 `item.number`）：

```dart
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '番号 - ${item.number}',
                          'type': '${item.type}',
                          'category': 'c',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
```

- 删除文件末尾的私有 `_openCommonList` 函数（约 405-418 行）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/search/search_screen_test.dart test/features/directors test/features/makers test/features/series`
Expected: 全部 PASS。

- [ ] **Step 5: 全量验证**

Run: `flutter analyze`
Expected: 无新增 error/warning（确认删除 import 后无残留引用）。

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/features/search/screens/search_results_screen.dart test/features/search/search_screen_test.dart
git commit -m "refactor(search): navigate to common list via router"
```

## Self-Review

**1. Spec coverage:**
- 新增 `/common-list` 路由与 query 参数 → Task 1 ✓
- 导演页 1 处 → Task 2 ✓
- 片商页 1 处 → Task 3 ✓
- 系列页 2 处（番号/系列）→ Task 4 ✓
- 搜索结果页 5 处（系列/片商/导演/清单/番号）→ Task 5 ✓
- 删除 4 个私有 `_openCommonList` → Task 2-5 ✓
- 不改 CommonListPage 本身、dataSource 不走路由 → 各 Task 的 import 处理与路由 builder 说明 ✓
- 测试更新（页面测试断言 router.state.uri、app_router_test 补真实路由用例）→ Task 1-5 ✓

**2. Placeholder scan:** 无 TBD/TODO；每个 Task 均含完整测试代码与实现代码（含 import 调整、删除函数说明、commit 命令）。

**3. Type consistency:** `AppRoutes.commonList` Task 1 定义，Task 2-5 使用一致；路由 query 参数键名 `title/type/category/id` 与 `CommonListPage` 构造参数一致；`int.tryParse(q['type'] ?? '') ?? 0` 在所有测试路由 builder 与 app_router 中写法一致；清单条目 type 恒为 0（与 search 原 `_openCommonList(..., 0, 'l', ...)` 一致）。
