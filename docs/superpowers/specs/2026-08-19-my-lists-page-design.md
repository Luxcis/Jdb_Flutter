# 我的清单页面设计

## 背景

「我的-我的清单」（`/profile/lists`）目前是占位页
（`ProfileNamedCollectionPage(title: '我的清单')`，6 行硬编码假数据）。
本设计实现真实功能：清单列表页 + 点击进入清单影片列表页（同搜索-清单），
列表项左滑支持编辑（改名）与删除，导航条右侧排序按钮切换
「更新时间 / 创建时间」。

## 接口

来自 `docs/main/api/jdb_api_openapi.json`（与用户提供的 OpenAPI 一致）：

- `GET /api/v1/lists`：需 BearerAuth + jdsignature；**`sort_by` 必填**
  （可选值 `updated_at`、`created_at`）；`page` 从 1 开始；`limit` 每页条数。
  响应 `data` 为 `MovieListsEntity`：`lists[]` + `current_page`。
- `PUT /api/v1/lists/{list_id}`：需 BearerAuth；body `application/json`
  `{"name": "..."}`；更新片单名称。
- `DELETE /api/v1/lists/{list_id}`：需 BearerAuth；删除片单，返回 BaseEntity。

`MovieListsItem` 字段：`id`、`type`、`name`、`privacy`、`description`、
`movies_count`、`views_count`、`collections_count`、`is_default`、
`share_info`、`created_at`、`has_movie`。

## 数据层

### `lib/features/profile/services/user_lists_service.dart`（新增）

```dart
abstract interface class UserListsDataSource {
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  });

  Future<void> renameList({required String id, required String name});
  Future<void> deleteList(String id);
}
```

- `UserListsService implements UserListsDataSource`（注入 `ApiClient`）：
  - `getMyLists`：GET `/api/v1/lists`，query `{sort_by, page, limit: 48}`；
    用现有 `apiPageResult`（keys: `['lists', 'items']`，pageSize 48）+
    `normalizeListModelJson` 解析。
  - `renameList`：PUT `/api/v1/lists/$id`，body JSON `{'name': name}`。
  - `deleteList`：DELETE `/api/v1/lists/$id`。
- `UnavailableUserListsDataSource implements UserListsDataSource`：
  API 未初始化（`ApiClient.instanceOrNull == null`）时的空实现，
  与 `UnavailableReviewMoviesDataSource` / `UnavailableTagMoviesDataSource`
  同模式。

### `ListModel` 扩展（`lib/core/models/list_model.dart`）

- 增加 `final String? createdAt;`（解析 `created_at`）。
- `normalizeListModelJson`（`lib/core/network/api_data.dart`）已透传
  `created_at`，无需改动；`ListModel.fromJson` 增加字段映射。

### `ApiClient` 扩展（`lib/core/network/api_client.dart`）

- 增加 `put` 方法：`Future<Response> put(String path, {dynamic data}) =>
  dio.put(path, data: data);`，与现有 `post` / `delete` 对齐。

## 页面层

### `lib/features/profile/screens/my_lists_page.dart`（新增）

`MyListsPage`（StatefulWidget，`UserListsDataSource? dataSource` 可注入）：

- AppBar：标题「我的清单」；右侧 `IconButton`（`Icons.sort`）：
  **点击直接在「更新时间」↔「创建时间」间切换**（默认「更新时间」），
  切换后 `PaginationController.reloadWith` 重载；tooltip 显示当前排序。
- 列表：`PaginationController<ListModel>` + `PaginatedListView`（滚动到底
  自动加载下一页，空/加载/错误重试沿用其既有表现）。
- 列表项：`flutter_slidable`（`SlidableAction`，endActionPane）包裹
  `ListSummaryTile`（副标题 `X 部影片，被查看 Y 次`）：
  - **编辑**（`Icons.edit_outlined`）：弹 `AlertDialog` + `TextField`
    预填当前名称 → 确认调 `renameList` → 成功后更新列表项名称；
    失败 SnackBar 提示，不改列表。
  - **删除**（`Icons.delete_outline`，error 色）：弹 `AlertDialog` 确认
    （「删除清单？」+ 名称）→ 确认调 `deleteList` → 成功后从列表移除该条
    并 SnackBar 提示；失败 SnackBar 提示，不移除。
- 点击条目 → `CommonListPage`（`title: '清单 - ${item.name}'`、
  `type: 0`、`category: 'l'`、`id`）——与搜索-清单完全一致的跳转方式。

## 路由

`lib/core/router/app_router.dart`：`/profile/lists` 的
`ProfileNamedCollectionPage(title: '我的清单')` 替换为 `MyListsPage()`，
保留 `_AuthGuard` 登录保护。`/profile/favorites/lists`（收藏的清单）不动。

## 依赖

- 新增 `flutter_slidable`（pub.dev 主流左滑组件，^4.0.3，min Dart SDK 3.6，
  项目 sdk ^3.8.0 满足）。

## 测试

- `test/features/profile/user_lists_service_test.dart`：
  - `getMyLists` 发送 `sort_by` 必填参数与 `page`/`limit`，解析
    `lists` + `current_page`，兼容 `movies_count`/`views_count`/`created_at`。
  - `renameList` 发送 PUT 到 `/api/v1/lists/{id}`，body 为 `{'name': ...}`。
  - `deleteList` 发送 DELETE 到 `/api/v1/lists/{id}`。
- `test/features/profile/my_lists_page_test.dart`（注入 fake dataSource）：
  - 初始加载显示列表，默认「更新时间」排序。
  - 点击排序图标切换排序，dataSource 收到对应 `sortBy`。
  - 左滑出现「编辑」「删除」操作按钮。
  - 编辑流程：弹窗 → 输入新名称 → 确认 → 列表项名称更新。
  - 删除流程：确认弹窗 → 条目移除；取消 → 不移除。

## 不做的事（YAGNI）

- 不做 `/profile/favorites/lists`（收藏的清单）——其接口
  `users/collected_lists` 是服务端 500 bug 接口。
- 不做新建清单——需求未要求（影片详情页已有该能力）。
- 排序不加「影片数」等额外选项，仅需求中的两种。
