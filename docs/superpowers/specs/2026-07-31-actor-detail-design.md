# 演员详情页重构设计

**日期:** 2026-07-31  
**状态:** 已确认  

## 概述

重构演员详情页（`ActorDetailPage`），实现以下功能：

1. 进入页面后调用 `/api/v1/actors/{actor_id}` 获取演员完整详情
2. "更多信息"面板改为底部弹出（1/3 高度）
3. 影片列表改用 `/api/v1/movies/tags` 接口并支持筛选
4. AppBar 右侧添加筛选图标，打开筛选面板（底部弹出，2/3 固定高度）
5. 筛选面板由 `filter_tags`（基本）和 `tags`（标签）动态构建
6. tags 展示影片数量，格式如 `巨乳(64)`

---

## 数据模型变更

### ActorDetail 扩展

文件: `lib/core/models/actor.dart`

新增 `ActorTagItem` 类和 `ActorDetail` 扩展字段：

```dart
class ActorTagItem {
  const ActorTagItem({
    required this.id,
    required this.name,
    required this.videosCount,
  });

  final String id;
  final String name;
  final int videosCount;

  factory ActorTagItem.fromJson(Map<String, dynamic> json) => ActorTagItem(
    id: apiString(json['id']) ?? '',
    name: apiString(json['name']) ?? '',
    videosCount: apiInt(json['videos_count'], 0),
  );
}
```

`ActorDetail` 新增字段：
- `type`: `int?` — 演员类别（0=有码, 1=无码, 2=欧美）
- `filterTags`: `List<ActorTagItem>` — 基本筛选标签
- `tags`: `List<ActorTagItem>` — 标签筛选

### normalizeActorDetailJson 扩展

文件: `lib/core/network/api_data.dart`

在现有提取逻辑基础上新增：
```dart
'type': apiIntOrNull(actor['type']),
'filter_tags': apiList(root, const ['filter_tags'])
    .map((t) => ActorTagItem.fromJson(t))
    .toList(),
'tags': apiList(root, const ['tags'])
    .map((t) => ActorTagItem.fromJson(t))
    .toList(),
```

---

## API 服务层

### getActorMovies 重构

文件: `lib/features/actors/services/actor_service.dart`

从当前调用 `${Endpoints.actors}/$id` 改为调用 `Endpoints.moviesTags`：

**参数：**
- `filter_by`: `{type}:a:{actor_id}`（如 `0:a:EvkJ`）
- `filter_by_tags`: 逗号分隔的已选标签 ID（空字符串表示不过滤）
- `sort_by`: 排序字段（默认 `release`）
- `order_by`: 排序方向（默认 `desc`，仅 `sort_by=release` 时有效）
- `page`: 页码
- `limit`: 每页数量（48）

**响应解析：** 从 `data.movies.items` 提取 MovieSummary 列表，同时读取 `current_page`、`total_pages`、`total_count`。

### ActorMovieController（新建）

文件: `lib/features/actors/services/actor_movie_controller.dart`

轻量 ChangeNotifier，管理演员详情页的影片筛选状态：

- `movies`: `PaginationController<MovieSummary>` — 分页控制器
- `selectedTagIds`: `Set<String>` — 已选标签 ID 集合
- `sortBy`: `String` — 排序字段
- `orderBy`: `String` — 排序方向
- `toggleTag(String id)`: 切换标签选中状态，触发重载
- `changeSort(String sortBy)`: 修改排序，触发重载
- `toggleOrder()`: 切换升降序，触发重载
- `_fetchPage(int page)`: 调用 ActorService.getActorMovies，传入 actorId、type、filterByTags

标签变化和排序变化时，调用 `movies.reloadWith(_fetchPage, preserveItems: true)` 即时刷新。

---

## UI 层

### "更多信息"面板

- 从 `endDrawer`（Drawer）改为 `showModalBottomSheet`
- 触发方式不变：点击页面中 `TextButton("更多信息")`
- 约束高度为屏幕 **1/3**：`BoxConstraints.tightFor(height: screenHeight / 3)`
- 设置 `showDragHandle: true` 显示拖拽手柄
- 内容保持现有字段列表（姓名、生日、年龄、身高、罩杯、胸围、腰围、臀围、出生地）

### AppBar 筛选图标

在 AppBar 的 `actions` 中添加筛选图标按钮：

```dart
IconButton(
  tooltip: '筛选',
  onPressed: _showFilter,
  icon: const Icon(Icons.filter_alt_outlined),
),
```

### 筛选面板

底部弹出，**固定 2/3 高度**，不可拖拽调整：

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: BoxConstraints.tightFor(height: screenHeight * 2 / 3),
  builder: (_) => ActorMovieFilterSheet(controller: _controller),
);
```

筛选面板内容（`ActorMovieFilterSheet` Widget，新建文件 `lib/features/actors/widgets/actor_movie_filter_sheet.dart`）：

**顶部区域：**
- "筛选"标题
- 排序下拉菜单（参考 CategoryFilterSheet 的 PopupMenuButton）
- 升降序切换按钮（仅在 sort_by=release 时显示）

**筛选主体：**
- 分组 1: "基本" — `filter_tags` 列表，FilterChip 多选
- 分组 2: "标签" — `tags` 列表，FilterChip 多选，标签文本格式 `name(videos_count)` 如 `巨乳(64)`

布局参考 `CategoryFilterSheet._FilterBody`：左侧分组标签（64px 宽），右侧 Wrap 排列 FilterChip。

交互模式：
- 标签多选，即时生效
- 选中/取消标签立即触发 `controller.toggleTag(id)`
- 影片网格自动刷新

### ActorDetailPage 重构

文件: `lib/features/actors/screens/actor_detail_screen.dart`

**主要变更：**

1. 初始化 `ActorMovieController` 替代直接使用 `PaginationController`
2. `_load()` 方法获取完整 ActorDetail（含 type/filter_tags/tags）后初始化 controller
3. 移除 `endDrawer` 属性，新增 `_showInfo()` 方法打开信息面板
4. AppBar 新增筛选 actions
5. AppBar title 改为 `ActorDetailPage` 固定标题（避免与下文演员名重复）
6. 新增 `_showFilter()` 方法打开筛选面板

**加载流程：**
```
initState → ActorService.getDetail(id) → 获取 ActorDetail（含 type/filter_tags/tags）
       → 创建 ActorMovieController(actorId, type)
       → controller.movies.fetchMore() 首次加载影片
```

---

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `lib/core/models/actor.dart` | 修改 | 新增 ActorTagItem，ActorDetail 新增 type/filterTags/tags |
| `lib/core/models/actor.g.dart` | 重新生成 | 运行 build_runner |
| `lib/core/network/api_data.dart` | 修改 | normalizeActorDetailJson 新增字段提取 |
| `lib/features/actors/services/actor_service.dart` | 修改 | getActorMovies 改为 movies/tags，getDetail 返回完整数据 |
| `lib/features/actors/services/actor_movie_controller.dart` | **新建** | 影片筛选状态管理 |
| `lib/features/actors/screens/actor_detail_screen.dart` | 修改 | Drawer→BottomSheet，新增筛选功能 |
| `lib/features/actors/widgets/actor_movie_filter_sheet.dart` | **新建** | 演员影片筛选面板 |

---

## 数据流

```
用户进入 ActorDetailPage(id)
  │
  ├─ 1. ActorService.getDetail(id)
  │     └─ GET /api/v1/actors/{id}
  │        返回: actor info + type + filter_tags + tags
  │
  ├─ 2. 创建 ActorMovieController(actorId, type)
  │     └─ 初始化 PaginationController
  │
  ├─ 3. controller.movies.fetchMore()
  │     └─ GET /api/v1/movies/tags
  │        参数: filter_by={type}:a:{actor_id}, page=1, limit=48
  │        返回: 影片列表（分页）
  │
  └─ 用户点击筛选图标
       └─ 打开 ActorMovieFilterSheet
           展示 filter_tags（基本）+ tags（标签）
           用户选择标签 → controller.toggleTag(id)
             └─ movies.reloadWith(_fetchPage)
                  GET /api/v1/movies/tags
                  参数: filter_by={type}:a:{actor_id}
                        filter_by_tags={已选标签ID逗号分隔}
```

---

## 边界情况

- **加载失败**：actor 详情加载失败时显示错误页面（复用现有错误处理）
- **缺少 filter_tags/tags**：面板中对应分组不显示（空数组处理）
- **ApiClient 为空**：显示默认占位信息（复用现有兜底逻辑）
- **快速切换标签**：PaginationController 自带 generation 竞态防护
- **type 为 null**：不发起影片请求，显示空状态
