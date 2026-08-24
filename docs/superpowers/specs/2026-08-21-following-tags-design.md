# 我的-我的关注 设计文档

日期：2026-08-21
状态：已获用户分节确认，待用户审查书面规格

## 1. 需求概述

实现「我的-我的关注」功能，包含标签关注/取消关注、本地缓存、启动同步，以及在类别页导航栏的快捷关注入口。

### 功能拆解

1. **登录缓存**：登录接口返回 `following_tags` 字段，缓存到本地。
2. **启动同步**：每次打开应用（已登录）时调用 `POST /api/v1/following_tags/batch_push`，用返回的远程关注列表覆盖本地缓存。
3. **关注**：类别页点击关注 → `POST /api/v1/following_tags`，并用返回数据更新本地缓存。
4. **取消关注**：`DELETE /api/v1/following_tags/{tag_id}`，并更新本地缓存。
5. **影片列表页**：`GET /api/v1/movies/tags`，`filter_by` 根据关注标签的 `value` 自动填充；排序仅「更新日期」「发布日期」两项。
6. **类别页入口**：导航栏右侧新增关注按钮，图标用 `visibility`（未关注）/ `visibility_off`（已关注）。
7. **我的-我的关注页**：展示已关注标签列表，点击跳转影片列表，左滑取消关注。

## 2. 接口约定

### `POST /api/v1/following_tags`（关注单个标签）

请求体（`FollowTagRequest`）：
```json
{ "name": "有碼,森螢", "value": "0:a:g1Q" }
```

实际返回（实测，非 openapi 抽象 `BaseEntity`）：
```json
{
  "success": 1,
  "action": null,
  "message": null,
  "data": {
    "id": 13384922,
    "name": "有碼,森螢",
    "value": "0:a:g1Q",
    "priority": 6.0
  }
}
```
> 关键：响应 `data` 含真实 `id`，是后续 `DELETE /following_tags/{tag_id}` 所需的 id 来源。

### `DELETE /api/v1/following_tags/{tag_id}`（取消关注）

路径参数 `tag_id` 为标签 id。返回 `BaseEntity`。

### `POST /api/v1/following_tags/batch_push`（启动同步）

请求体（`BatchFollowTagRequest`）：
```json
{ "tags": [ { "name": "...", "value": "...", "priority": 1 }, ... ] }
```

返回 `FollowTagAllEntity`，其 `data.following_tags` 为远程关注列表，用于覆盖本地缓存。

### `GET /api/v1/movies/tags`（影片列表，按关注标签 value 筛选）

查询参数：
- `filter_by`：直接用该关注标签的 `value`（如 `0:a:g1Q`）。
- `sort_by`：`update`（更新日期）或 `release`（发布日期），仅这两项可选。
- `order_by`：仅 `sort_by=release` 时生效（desc/asc）。
- `page` / `limit`（默认 48）。

## 3. 数据模型

`FollowTagItem`（对应 API 的 `FollowTagItem` / 关注返回 `data` 对象）：

```dart
class FollowTagItem {
  const FollowTagItem({required this.id, required this.name, required this.value, this.priority});
  final String id;      // openapi 标为 int，统一存 String 便于缓存与 DELETE 路径拼接
  final String name;    // 已选中标签名称，用 ',' 拼接
  final String value;   // filter_by 片段，如 `0:a:g1Q`
  final num? priority;  // 优先级权重
  factory FollowTagItem.fromJson(Map<String, dynamic> json);
}
```

> `value == filter_by`：本设计将 `value` 直接视为 `/api/v1/movies/tags` 的 `filter_by` 参数值。

## 4. 目录结构（Feature-First）

```
lib/features/following/
├── index.dart                    # 对外入口
├── models/follow_tag.dart        # FollowTagItem 模型
├── services/following_tags_store.dart   # 本地缓存（SharedPreferences）
├── services/following_tags_service.dart # 网络 API + 数据源抽象
├── screens/following_page.dart          # 我的-我的关注 页（改造 ProfileFollowingPage）
├── screens/follow_tag_movies_page.dart  # 点击标签后的影片列表页
└── widgets/follow_tags_button.dart      # 类别页可见性按钮
```

- 遵循项目结构规则：feature 只依赖 `core`，feature 间不互相依赖，core 不依赖 feature。
- 模型/服务/页面/组件都放 feature 内；`index.dart` 只 export 路由需要的部分。

## 5. 数据流

### 5.1 登录时缓存

- `AuthProvider.login()` 目前只接收 `token` + `user`。关注标签是独立业务状态，不混入鉴权会话。
- 登录页 `_login()` 成功后，从响应 `data['following_tags']` 解析为 `List<FollowTagItem>`，调用 `FollowingTagsProvider.syncFromLogin(list)` 写入缓存并通知 UI。
- 响应无 `following_tags` 字段时视为空列表，不报错。

### 5.2 启动同步（batch_push）

- `StartupPage._refreshSessionThenNavigate()` 在 `SessionRefreshStatus.success` 且已登录后，追加调用 `FollowingTagsProvider.syncFromRemote()`。
- `syncFromRemote()`：取当前本地缓存 tags 作为请求体调 `batchPush`，用返回的远程 `following_tags` **覆盖**本地缓存。
- 失败兜底：`log` 记录，保留本地缓存，不阻塞导航（不打断启动流程）。

### 5.3 类别页关注 / 取消

- 关注按钮状态跟随**当前选中 Tab**（类别页 5 个 Tab 各自有独立 `CategoryTabController`）。
- `isFollowing(value)`：本地缓存中是否存在 `value` 相等的项。
- **未关注** → `follow({name, value})`：
  - `name` = 当前筛选面板已选中的标签名称，用 `,` 拼接；
  - `value` = `controller.filter.toFilterBy(type, groupOrder)`；
  - 成功后用返回的 `FollowTagItem` **插入本地列表头部**并写缓存。
- **已关注** → 用本地列表中匹配项（按 `value`）的 `id` 调 `unfollow(id)`，成功后从本地列表移除并写缓存。
- 未选中任何标签时按钮禁用（tooltip「请先选择标签」）。

### 5.4 我的-我的关注 列表页

- 单一 `ListView.builder` 展示 `FollowingTagsProvider.tags`。
- 每项 `Dismissible`（左滑）→ `unfollow(id)` + 缓存更新 + 列表移除。
- 点击某项 → push `FollowTagMoviesPage(tag)`。

## 6. UI 设计

### 6.1 类别页导航栏按钮

- 位置：**在「筛选」按钮之前**插入，紧随标题之后。
- 图标：未关注 → `Icons.visibility`（点击关注）；已关注 → `Icons.visibility_off`（点击取消）。
- 未选中任何标签时禁用（tooltip「请先选择标签」）。

### 6.2 我的-我的关注页（改造）

- 去掉现有 3 个占位 Tab（全部关注/演员/标签）与筛选按钮。
- 改为单一列表：标题「我的关注」，无 AppBar actions 按钮。列表数据由 `FollowingTagsProvider` 提供，页面自身可通过下拉/进入时刷新显示（进入页面时重读 provider 缓存的当前值）。
- 每项：`Dismissible` 包裹 `ListTile`，标题 `tag.name`，副标题 `tag.value`；滑动背景删除图标（`Icons.delete`）。
- 空态：居中提示「暂无关注标签」。

### 6.3 关注标签影片列表页（`FollowTagMoviesPage`）

- 复用 `PaginationController` + `MovieGridView` + `SortSegmented`。
- 排序仅两项：`更新日期(update)` / `发布日期(release)`。
- 数据源：`GET /api/v1/movies/tags`，`filter_by = tag.value`，`sort_by` 用户所选，`order_by`（仅 release）。
- 为解耦，不直接复用 `CommonListPage`（其耦合了 category 排序选项、收藏按钮、可播放筛选段）。新建简洁页面，用统一的数据源抽象，方法直接接收完整 `filter_by`。

## 7. 错误处理

| 场景 | 处理 |
|------|------|
| 关注/取消关注失败 | `SnackBar`「操作失败，请重试」，不回滚本地缓存，按钮恢复可点 |
| `batch_push` 失败 | `log` 记录，保留本地缓存，不阻塞启动 |
| 登录无 `following_tags` | 视为空列表 |
| 登出 / token 过期登出 | `FollowingTagsProvider.clear()` 清空缓存（避免残留他人数据） |

## 8. 登录 / 登出联动

- **登出**（`AuthProvider.logout()` / `onAuthError` / SessionRefresh expired）：触发 `clear()`。
- **登录**：`syncFromLogin()` 写入。
- 无鉴权状态下（未登录）关注相关按钮隐藏或禁用。

## 9. 测试计划

| 测试文件 | 覆盖 |
|----------|------|
| `test/features/following/following_tags_store_test.dart` | save/load/clear 往返、空/畸形 JSON 兜底 |
| `test/features/following/following_tags_service_test.dart` | follow/unfollow/batchPush 请求路径、参数、响应解析（用 `fake_adapter`） |
| `test/features/following/following_tags_provider_test.dart` | isFollowing/insert/remove/syncFromLogin/syncFromRemote/clear 状态与缓存一致 |
| `test/features/following/follow_tags_button_test.dart` | 图标与禁用态 |
| `test/features/following/following_page_test.dart` | 空态/列表/左滑删除 |
| `test/features/following/follow_tag_movies_page_test.dart` | 排序仅两项、数据加载 |
| 登录页补测 | 登录成功解析 `following_tags` 写入 provider |

## 10. 边界与风险

- **value 唯一性**：`isFollowing`/取消关注按 `value` 匹配。若同一 `value` 存在多条（如用户对多个标签拼接出相同 filter_by），以最先匹配为准；正常场景下 `value` 由选中标签唯一决定。
- **id 类型**：`id` 存 String，兼容 openapi int 与 DELETE 路径拼接。
- **batch_push 覆盖**：以服务端返回为准，避免本地与远程不一致。
