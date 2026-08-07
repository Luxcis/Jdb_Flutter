# CommonListPage 路由化设计

## 背景

`CommonListPage`（通用作品列表页）当前由 4 个 feature 页面通过私有
`_openCommonList` 函数用 `Navigator.of(context).push(MaterialPageRoute(...))`
手动构建跳转。共 9 处点击入口、4 份重复的跳转代码。本次改为 GoRouter
路由传参跳转，消除重复，统一导航行为。

## 目标

- 新增 `/common-list` 路由，用 query 参数传输 `title/type/category/id`。
- 4 个页面（导演/片商/系列/搜索结果）9 处入口全部改为 `context.push(...)`。
- 删除 4 个私有 `_openCommonList` 函数。
- 页面本身不改：`CommonListPage` 构造参数、dataSource 默认回退逻辑均保持。

## 路由设计

### AppRoutes（lib/core/router/routes.dart）

新增常量：

```dart
static const String commonList = '/common-list';
```

### 路由注册（lib/core/router/app_router.dart）

在 `/directors` 路由附近注册：

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

`CommonListPage` 构造参数中的可选 `dataSource` 不通过路由传（测试注入用），
页面走既有默认回退：`ApiClient.instanceOrNull` 非空用 `TagMoviesService`，
为空用 `UnavailableTagMoviesDataSource`。

## 调用点改造（9 处）

4 个 feature 页面各自的 `onTap` 从调用私有 `_openCommonList` 改为：

```dart
onTap: () => context.push(
  Uri(
    path: AppRoutes.commonList,
    queryParameters: {
      'title': '$typeLabel - $name',
      'type': '$type',
      'category': category,
      'id': id,
    },
  ).toString(),
),
```

涉及文件与入口数：

- `lib/features/directors/screens/directors_page.dart`：1 处。
- `lib/features/makers/screens/makers_page.dart`：1 处。
- `lib/features/series/screens/series_page.dart`：2 处（番号、系列）。
- `lib/features/search/screens/search_results_screen.dart`：5 处（系列/片商/导演/清单/番号）。

删除上述 4 个文件中的私有 `_openCommonList` 函数，并清理不再使用的
`CommonListPage`/`Navigator` 相关 import。

## 测试计划

1. `test/features/directors/directors_page_test.dart`：点击导演条目用例改为提供
   GoRouter（注册 `/common-list` → 真实 `CommonListPage`），断言
   `router.state.uri.path == '/common-list'` 且 queryParameters 的
   `title/type/category/id` 正确。
2. `test/features/makers/makers_page_test.dart`：同 1，片商条目。
3. `test/features/series/series_page_test.dart`：同 1，番号与系列条目。
4. `test/app_router_test.dart`：新增用例——以 `AppRouter.buildForTest` 导航到
   `/common-list` 带参数，断言渲染 `CommonListPage` 且 title/type/category/id 正确。
5. `test/features/common/common_list_page_test.dart`：不改（直接 pump 页面）。

## 不做的事（YAGNI）

- 不改 `CommonListPage` 本身（构造参数、过滤/排序/分页逻辑）。
- 不改其它路由与页面。
- 不抽象共享跳转 helper（各页面直接 `context.push`，代码量小且清晰）。
