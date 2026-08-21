# ListSummaryTile 内置清单页跳转设计

日期：2026-08-21
状态：已批准

## 背景

`ListSummaryTile`（清单摘要条目）的 4 处使用点中：

- 影片详情-相关清单（`movie_detail_screen.dart`）**没有点击事件**，点击无响应；
- 其余 3 处（搜索-清单 tab、我的清单、收藏的清单）各自重复编写了**完全相同**的跳转代码。

## 目标

1. 影片详情-相关清单点击后打开清单页（common-list）。
2. 将清单页跳转内聚到 `ListSummaryTile` 组件内，4 处统一默认行为，删除重复代码。
3. 保留 `onTap` 参数作为覆盖入口（外部传入时优先），保持组件灵活性。

## 设计

### 1. `lib/core/widgets/list_summary_tile.dart`

- `onTap` 参数保留（`VoidCallback?`）。
- `build` 中 `ListTile.onTap` 改为：`onTap ?? () => _openListPage(context)`。
- 新增私有方法 `_openListPage`：

```dart
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
```

- 新增 import：`package:go_router/go_router.dart`、`package:jade/core/router/routes.dart`。
- 依赖方向安全：`core/widgets` 已有 6 个组件直接 import go_router；`core/router/routes.dart` 仅常量，无循环依赖。

### 2. 删除 3 处重复跳转

| 文件 | 改动 |
|---|---|
| `search_results_screen.dart` | 删除 `onTap`（约 11 行），保留 `showViewCount: false` |
| `my_lists_page.dart` | 删除 `_openListMovies` 方法与其调用 |
| `collected_entities_page.dart` | 删除 `onTap`（约 11 行） |

行为不变：query 与现有完全一致（`title=清单 - name`、`type=0`、`category=l`、`id`）。

### 3. 测试更新

- `test/core/widgets/list_summary_tile_test.dart`：
  - "未提供点击回调时保持不可点击" 改为 "未提供点击回调时默认跳转 common-list"（装配 GoRouter 断言跳转）。
  - 已有"触发点击"用例保持（外部 onTap 覆盖优先）。
- `test/features/movie_detail/movie_detail_screen_test.dart`：
  - 在相关清单渲染用例后追加：点击 `ListSummaryTile` → 断言路由为 common-list 且 query 正确 → 返回后仍在详情页。
- 其余测试（search/profile）无需改动：跳转目标与参数不变。

### 4. 验证

- `dart analyze`
- `flutter test test/core/widgets/list_summary_tile_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/features/search/search_screen_test.dart test/features/profile/`
