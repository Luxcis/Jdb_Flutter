# ListSummaryTile 内置清单页跳转 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将清单页（common-list）跳转内聚进 `ListSummaryTile`，使影片详情-相关清单点击即跳转，并删除 3 处重复跳转代码。

**架构：** `ListSummaryTile` 内部默认跳转 `/common-list`（query: `title=清单 - name`、`type=0`、`category=l`、`id`），`onTap` 参数保留为覆盖入口。core/widgets 已有 6 个组件直接使用 go_router，模式一致。

**技术栈：** Flutter / Dart / go_router

**文件结构：**
- `lib/core/widgets/list_summary_tile.dart` — 核心改造：内置默认跳转
- `lib/features/movie_detail/screens/movie_detail_screen.dart` — 相关清单使用点（无改动需求，测试验证即可）
- `lib/features/search/screens/search_results_screen.dart` — 删除重复 onTap
- `lib/features/profile/screens/my_lists_page.dart` — 删除 `_openListMovies` 及 onTap 传参
- `lib/features/profile/screens/collected_entities_page.dart` — 删除重复 onTap
- `test/core/widgets/list_summary_tile_test.dart` — 更新默认跳转用例
- `test/features/movie_detail/movie_detail_screen_test.dart` — 新增相关清单点击跳转断言

---

### 任务 1：ListSummaryTile 内置默认跳转（TDD）

**文件：**
- 修改：`lib/core/widgets/list_summary_tile.dart`
- 修改：`test/core/widgets/list_summary_tile_test.dart`

- [ ] **步骤 1：改写组件测试**

将 `test/core/widgets/list_summary_tile_test.dart` 全文替换为（"未提供点击回调时保持不可点击"用例改为默认跳转断言）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';

void main() {
  testWidgets('显示加粗名称影片数查看数箭头并触发点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListSummaryTile(
            list: const ListModel(
              id: 'l1',
              name: '收藏精选',
              movieCount: 12,
              viewedCount: 34,
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('收藏精选'), findsOneWidget);
    expect(find.text('12 部影片，被查看 34 次'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('收藏精选')).style?.fontWeight,
      FontWeight.w600,
    );
    await tester.tap(find.byType(ListSummaryTile));
    expect(tapped, isTrue);
  });

  testWidgets('未提供 onTap 时默认跳转 common-list', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: ListSummaryTile(
              list: ListModel(
                id: 'l1',
                name: '收藏精选',
                movieCount: 12,
                viewedCount: 34,
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (_, state) => Scaffold(
            body: Text('common-list ${state.uri.queryParameters}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byType(ListSummaryTile));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters, {
      'title': '清单 - 收藏精选',
      'type': '0',
      'category': 'l',
      'id': 'l1',
    });
  });

  testWidgets('showViewCount 为 false 时副标题不显示被查看次数', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListSummaryTile(
            list: ListModel(
              id: 'l1',
              name: '收藏精选',
              movieCount: 12,
              viewedCount: 34,
            ),
            showViewCount: false,
          ),
        ),
      ),
    );

    expect(find.text('12 部影片'), findsOneWidget);
    expect(find.text('12 部影片，被查看 34 次'), findsNothing);
    expect(find.textContaining('被查看'), findsNothing);
  });
}
```

注意：`MaterialApp.router` 下首页由 `initialLocation` 决定，因此 `ListSummaryTile` 放在 `/` 路由的 builder 中（如上），而不是 `home:` 参数。

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/core/widgets/list_summary_tile_test.dart`
预期：新用例 FAIL（tile 无默认跳转，点击后仍在首页，`router.state.uri.path` 不为 common-list）

- [ ] **步骤 3：实现组件内置跳转**

修改 `lib/core/widgets/list_summary_tile.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/router/routes.dart';

class ListSummaryTile extends StatelessWidget {
  const ListSummaryTile({
    super.key,
    required this.list,
    this.onTap,
    this.showViewCount = true,
  });

  final ListModel list;

  /// 覆盖默认的清单页跳转；为 null 时点击默认打开该清单的影片列表页。
  final VoidCallback? onTap;
  final bool showViewCount;

  void _openListPage(BuildContext context) {
    context.push(
      Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '清单 - ${list.name}',
          'type': '0',
          'category': 'l',
          'id': list.id,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap ?? () => _openListPage(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    title: Text(
      list.name,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        showViewCount
            ? '${list.movieCount} 部影片，被查看 ${list.viewedCount} 次'
            : '${list.movieCount} 部影片',
      ),
    ),
    trailing: const Icon(Icons.chevron_right),
  );
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/core/widgets/list_summary_tile_test.dart`
预期：PASS（3 个用例）

- [ ] **步骤 5：Commit**

```bash
git add lib/core/widgets/list_summary_tile.dart test/core/widgets/list_summary_tile_test.dart
git commit -m "feat(widgets): 内置 ListSummaryTile 默认跳转清单页"
```

---

### 任务 2：新增影片详情-相关清单点击跳转断言

**文件：**
- 修改：`test/features/movie_detail/movie_detail_screen_test.dart`

- [ ] **步骤 1：在相关清单渲染用例后追加点击断言**

在 `test/features/movie_detail/movie_detail_screen_test.dart` 的"相关清单"渲染用例（约 2007-2023 行，`await tester.tap(find.text('相关清单'))` 所在用例）末尾追加：

```dart
    // 点击相关清单条目经内置跳转打开 common-list 并可返回。
    await tester.tap(find.byType(ListSummaryTile).first);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters, {
      'title': '清单 - 测试相关清单',
      'type': '0',
      'category': 'l',
      'id': 'list-1',
    });
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.movieDetail);
    expect(find.text('测试相关清单'), findsOneWidget);
```

先阅读该用例上下文（约 1940-2023 行），确认其中已有 `router` 变量与相关清单的 mock id（`list-1`），若 mock 数据 id 不同则改用实际值。

- [ ] **步骤 2：运行测试确认通过**

运行：`flutter test test/features/movie_detail/movie_detail_screen_test.dart --plain-name "相关清单"`
预期：PASS（含新增断言）

- [ ] **步骤 3：Commit**

```bash
git add test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "test(movie-detail): 相关清单点击跳转清单页断言"
```

---

### 任务 3：删除 3 处重复跳转代码

**文件：**
- 修改：`lib/features/search/screens/search_results_screen.dart:220-234`
- 修改：`lib/features/profile/screens/my_lists_page.dart:149-161,206-209`
- 修改：`lib/features/profile/screens/collected_entities_page.dart:369-382`

- [ ] **步骤 1：删除 search_results_screen 的 onTap**

将 `search_results_screen.dart` 220-234 行的 itemBuilder 改为：

```dart
itemBuilder: (context, item) => ListSummaryTile(
  list: item,
  showViewCount: false,
),
```

- [ ] **步骤 2：删除 my_lists_page 的 _openListMovies**

删除 `my_lists_page.dart` 149-161 行的 `_openListMovies` 方法，并将 206-209 行改为：

```dart
child: ListSummaryTile(list: list),
```

- [ ] **步骤 3：删除 collected_entities_page 的 onTap**

将 `collected_entities_page.dart` 369-382 行改为：

```dart
child: ListSummaryTile(list: list),
```

- [ ] **步骤 4：运行相关测试**

运行：`flutter test test/features/search/search_screen_test.dart test/features/profile/my_lists_page_test.dart test/features/profile/collected_lists_page_test.dart`
预期：PASS（行为不变，仅位置迁移）

- [ ] **步骤 5：Commit**

```bash
git add lib/features/search/screens/search_results_screen.dart lib/features/profile/screens/my_lists_page.dart lib/features/profile/screens/collected_entities_page.dart
git commit -m "refactor: 移除 ListSummaryTile 外部重复跳转代码"
```

---

### 任务 4：全量验证

- [ ] **步骤 1：静态分析**

运行：`dart analyze`
预期：No issues found

- [ ] **步骤 2：全量测试**

运行：`flutter test`
预期：全部 PASS

- [ ] **步骤 3：收尾检查**

确认无残留：`grep -rn "_openListMovies" lib/` 无结果；`ListSummaryTile` 的 4 处使用点均不再传 onTap（或仅有测试中覆盖用）。
