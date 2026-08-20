# 「我的收藏」页面 + 收藏按钮设计

## 背景

「我的-我的收藏」（`/profile/favorites`）目前只有入口壳
（`ProfileFavoritesPage`），6 个子页面全是占位：
- 收藏的演员（`ProfileFavoriteActorsPage`）：4 个 Tab 但数据为空
- 片商/系列/导演/番号/清单（`ProfileNamedCollectionPage`）：6 行假数据

本设计实现真实功能：
1. 「我的收藏」6 个子页面全部接入收藏接口，数据展示与点击逻辑
   与搜索结果页（系列/片商/导演/番号/演员/清单）保持一致；
2. 「清单」入口标题改为「收藏的清单」（与其他 5 项「收藏的X」一致）；
3. 演员页导航栏右侧「编辑」→ 选择模式 → 底部确认条批量取关；
4. 清单页导航栏右侧排序按钮切换「更新时间 / 创建时间」；
5. 除演员页外，所有页面列表项左滑展示「取消收藏」（删除）；
6. **新增**：common-list 影片列表页与演员详情页导航栏右侧
   爱心收藏按钮（收藏/取消收藏对应实体）。

## 接口

来自 `docs/main/api/jdb_api_openapi.json` + 用户提供参数说明：

### 我的收藏列表（全部需 BearerAuth，GET，参数 `page`、`limit`）

| 目标 | 路径 | 额外参数 | 响应 data 集合键 |
|------|------|----------|------------------|
| 演员 | `/api/v1/users/collected_actors` | `type`: `all`/`0`/`1`/`2` | `actors` |
| 片商 | `/api/v1/users/collected_makers` | — | `makers` |
| 系列 | `/api/v1/users/collected_series` | — | `series` |
| 导演 | `/api/v1/users/collected_directors` | — | `directors` |
| 番号 | `/api/v1/users/collected_codes` | — | `codes` |
| 清单 | `/api/v1/users/collected_lists` | `sort_by`: `recently`（更新时间）/`release`（创建时间），必填 | `lists`（兜底 `items`） |

> 注：OpenAPI 中 `collected_lists` 标注服务端 Bug（HTTP 500），
> 但用户明确提供该接口（参数 `sort_by` 取值 `recently`/`release`），
> 按用户提供为准实现，测试用 Fake 数据源。

### 收藏/取消收藏（POST，body `{"name":"collect"}` / `{"name":"uncollect"}`）

- `/api/v1/makers/{maker_id}/collect_actions`
- `/api/v1/series/{series_id}/collect_actions`
- `/api/v1/directors/{director_id}/collect_actions`
- `/api/v1/codes/{code_id}/collect_actions`
- `/api/v1/actors/{actor_id}/collect_actions`
- `/api/v1/lists/{list_id}/collect_actions`

### 批量取消收藏演员

- `DELETE /api/v1/actors/batch_uncollection`，body `{"ids": "1,2,3"}`
  （演员 id 列表，逗号隔开）

### 实体详情（取 `has_collected`，爱心按钮状态）

- `GET /api/v1/makers/{maker_id}`、`/series/{series_id}`、
  `/directors/{director_id}`、`/codes/{code_id}`：`MakerInfoEntity`
  含 `has_collected`
- `GET /api/v1/lists/{list_id}`：`MovieListsInfoEntity` 含 `has_collected`
- `GET /api/v1/actors/{actor_id}`：`ActorInfoEntity` 含 `has_collected`

## 数据层

### `lib/features/profile/services/collections_service.dart`（新增）

```dart
abstract interface class FavoritesDataSource {
  Future<PagedResult<ActorSummary>> getCollectedActors({required String type, int page = 1});
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1});
  Future<PagedResult<Series>> getCollectedSeries({int page = 1});
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1});
  Future<PagedResult<Code>> getCollectedCodes({int page = 1});
  Future<PagedResult<ListModel>> getCollectedLists({required String sortBy, int page = 1});

  // 取消收藏（收藏页左滑 / 批量）
  Future<void> uncollectActor(String id);
  Future<void> uncollectMaker(String id);
  Future<void> uncollectSeries(String id);
  Future<void> uncollectDirector(String id);
  Future<void> uncollectCode(String id);
  Future<void> uncollectList(String id);
  Future<void> batchUncollectActors(List<String> ids);

  // 实体收藏状态（爱心按钮）
  Future<bool> getHasCollected(String category, String id);
  Future<void> setCollected(String category, String id, bool collect);
}
```

- `FavoritesService implements FavoritesDataSource`（注入 `ApiClient`）：
  - 列表：GET 对应端点，query `{page, limit: 48}`（演员加 `type`，
    清单加 `sort_by`），用 `apiPageResult`（keys 见上表，兜底 `items`）+
    现有 `normalizeActorSummaryJson` / `normalizeMakerJson` /
    `_namedEntityJson` 等价物 / `normalizeListModelJson` 解析；
  - 单个取消：`POST /{entity}/{id}/collect_actions` body `{'name':'uncollect'}`；
  - 批量取关：`DELETE /api/v1/actors/batch_uncollection` body
    `{'ids': ids.join(',')}`；
  - 详情状态：按 category 映射详情路径（`m`→makers、`s`→series、
    `d`→directors、`c`→codes、`l`→lists、`a`→actors），GET 后取
    `has_collected`（`apiBool`，默认 false；失败返回 null 由页面隐藏按钮）；
  - `setCollected`：POST collect_actions body
    `{'name': collect ? 'collect' : 'uncollect'}`。
- `UnavailableFavoritesDataSource implements FavoritesDataSource`：
  API 未初始化时的空实现（与 `UnavailableUserListsDataSource` 同模式）。

> 实体列表解析器：`search_entity_service.dart` 中的 `_namedEntityJson` /
> `_codeJson` 为私有；本服务内复制等价归一化逻辑（保持同构）。

## 页面设计

### 入口页（`profile_sub_pages.dart` 微调）

`ProfileFavoritesPage` 的「清单」项 title 改为「收藏的清单」，
其余 5 项已是「收藏的X」，标题全部统一。

### 通用实体收藏页（片商/系列/导演/番号）

`lib/features/profile/screens/collected_entities_page.dart` 新增
`CollectedEntitiesPage`（泛型，`category` 参数区分）：

- `PaginatedListView<T>` + 每项 `Slidable`（endActionPane 一个
  `SlidableAction`「取消收藏」，红色 `colorScheme.error`，参照
  `MyListsPage` 模式）+ `EntityListTile(name, count)`；
- 点击跳转 common-list，与搜索页完全一致：
  `title: '片商 - X'`、`category: m/s/d/c`、`type: item.type`、`id`；
- 左滑取消收藏：确认弹窗 → `uncollectXxx` → 成功重载第一页
  （服务器为准，清空语义）+ SnackBar；失败 SnackBar + 条目保留；
- 请求中遮罩（`0x73000000` + 转圈，同 `MyListsPage`）。

### 收藏的清单页

同一文件 `CollectedListsPage`：

- AppBar 右侧排序按钮（`Icons.sort`，tooltip 显示当前排序）
  在 `recently`（更新时间）/`release`（创建时间）间切换并
  `_controller.reloadWith`；
- 列表项 `ListSummaryTile` + 左滑取消收藏（同通用实体页）；
- 点击跳 `common-list?category=l&type=0`。

### 收藏的演员页（`collected_actors_page.dart` 新增）

`CollectedActorsPage`：

- AppBar 底部 4 Tab（全部/有码/无码/欧美 → `type: all/0/1/2`），
  每 Tab 独立 `PaginationController` + `ActorGridView`；
- AppBar 右侧「编辑」按钮（`Icons.edit_outlined` + 文字/图标）：
  - 编辑模式：AppBar 变「完成」按钮；`ActorGridView` 进入选择态
    （卡片右上角叠加勾选圈，点击切换选中）；底部弹出确认条
    「取消收藏(N)」；
  - 点击确认条 → 确认弹窗 → `batchUncollectActors(ids)` →
    成功退出编辑模式、清空选中、重载当前 Tab、SnackBar；
    失败保留选择并 SnackBar；
  - 再次点「完成」退出编辑模式（不清选中）。
- 演员点击：非编辑模式跳 `/actor/{id}`；编辑模式切换选中。

### 共用爱心按钮（`lib/core/widgets/favorite_button.dart` 新增）

```dart
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({required this.hasCollected, this.busy = false, required this.onPressed});
  // Icons.favorite_border（未收藏）/ Icons.favorite（已收藏，红色）
  // busy 时禁用防连点
}
```

### CommonListPage 加爱心按钮

- `category` ∈ {m, s, d, c, l, a} 时显示；`p`（发行商）无收藏接口
  不显示；
- 进入页面后 `getHasCollected(category, id)` 加载状态：
  - 返回 false → 未收藏（空心爱心）；true → 已收藏（实心）；
  - 返回 null/失败 → 隐藏按钮（不影响列表主功能）；
- 点击 → `setCollected(category, id, !hasCollected)` → 成功翻转
  本地状态 + SnackBar「已收藏/已取消收藏」；失败 SnackBar 状态不变；
- 请求中 `busy` 禁用。

### ActorDetailPage 加爱心按钮

- `normalizeActorDetailJson` + `ActorDetail` 增加 `hasCollected` 字段；
- AppBar `actions` 在筛选按钮左侧加爱心按钮，交互同 CommonListPage
  （`category: 'a'`）；
- 未登录（无 token）时按钮点击引导登录或隐藏（与收藏接口需 Bearer
  一致，采用隐藏策略保持简单）。

## 组件改动

- `ActorGridView`：增加可选选择模式参数
  （`selectionMode: bool`、`selectedIds: Set<String>`、
  `onToggleSelect: void Function(ActorSummary)`），默认关闭，现有
  调用与测试不受影响；
- `ActorCard`：增加可选 `selected`（右上角勾选圈叠加），默认不显示；
- `ActorDetail`：新增 `hasCollected`（`bool`，默认 false）。

## 错误处理

与 `MyListsPage` 一致：
- 变更成功但重载失败 → 清空语义展示错误态（不残留旧数据）；
- 取消收藏失败 → SnackBar 提示 + 条目保留；
- 请求进行中遮罩。

## 测试

- `test/features/profile/collections_service_test.dart`：
  - 6 个列表 GET 的 path/query 断言（演员 type、清单 sort_by）；
  - 单个 uncollect POST body `{'name':'uncollect'}`；
  - batchUncollect 的 DELETE 方法 + body `{'ids':'1,2,3'}`；
  - 详情 has_collected 解析（true/false/缺失）；
- `test/features/profile/collected_entities_page_test.dart`：
  左滑出现取消收藏、确认/取消、成功刷新、失败保留；
- `test/features/profile/collected_lists_page_test.dart`：
  排序切换请求参数（recently → release）；
- `test/features/profile/collected_actors_page_test.dart`：
  Tab type 参数、编辑模式选中/取消、确认条计数、批量取关成功/失败；
- `test/core/widgets/favorite_button_test.dart`：图标切换 + busy 禁用。

全部用 `_FakeFavoritesDataSource` 注入（参照 `my_lists_page_test.dart`
模式）。
