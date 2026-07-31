# 演员详情页重构实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构演员详情页 — 调用 /api/v1/actors/{id} 获取完整详情，更多信息面板改为底部弹出(1/3)，影片列表改用 /api/v1/movies/tags 并支持筛选(2/3 固定面板)，tag 展示影片数量。

**Architecture:** 扩展 ActorDetail 模型新增 type/filterTags/tags 字段；ActorService.getActorMovies 改为调用 movies/tags 端点；新建 ActorMovieController 管理筛选状态（ChangeNotifier + PaginationController）；新建 ActorMovieFilterSheet（参考 CategoryFilterSheet 布局）；重构 ActorDetailPage UI。

**Tech Stack:** Flutter/Dart, json_annotation, go_router, ChangeNotifier

## Global Constraints

- 行宽 ≤ 80 字符
- 所有公开 API 需 dartdoc 注释
- 使用 const 构造函数和 const widget
- 命名规范：PascalCase 类名, camelCase 方法/变量, snake_case 文件名
- PaginationController 自带 generation 竞态防护，无需额外处理
- MovieSummary 使用 normalizeMovieSummaryJson 后再 fromJson
- ActorSummary 使用 normalizeActorSummaryJson 后再 fromJson

---

### Task 1: 数据模型变更 (actor.dart + api_data.dart)

**Files:**
- Modify: `lib/core/models/actor.dart`
- Modify: `lib/core/network/api_data.dart`

**Interfaces:**
- Produces: `ActorTagItem` class (id, name, videosCount), `ActorDetail` 新增 `type` (int?), `filterTags` (List<ActorTagItem>), `tags` (List<ActorTagItem>)
- Produces: `normalizeActorDetailJson` 输出新增 `type`, `filter_tags`, `tags` 字段

- [ ] **Step 1: 在 actor.dart 中添加 ActorTagItem 类**

在 `ActorDetail` 类定义之前（第 22 行前）插入：

```dart
// lib/core/models/actor.dart — 在 ActorDetail 类之前插入

/// 演员标签项，用于演员详情页的影片筛选。
class ActorTagItem {
  const ActorTagItem({
    required this.id,
    required this.name,
    required this.videosCount,
  });

  /// 标签 ID，用于拼装 filter_by_tags 参数。
  final String id;

  /// 标签显示名称。
  final String name;

  /// 该标签关联的影片数量。
  final int videosCount;
}
```

- [ ] **Step 2: 在 ActorDetail 中添加新字段**

在 `ActorDetail` 类的字段列表末尾（`movieCount` 字段之后，第 37 行）插入：

```dart
// lib/core/models/actor.dart — 在 ActorDetail 类字段末尾插入
  final int? type;
  final List<ActorTagItem> filterTags;
  final List<ActorTagItem> tags;
```

修改构造函数，添加新参数：

```dart
// 将 ActorDetail 构造函数修改为：
  const ActorDetail({
    required super.id,
    required super.name,
    required super.avatarUrl,
    super.gender,
    this.birthday,
    this.age,
    this.height,
    this.cup,
    this.bust,
    this.waist,
    this.hip,
    this.birthplace,
    this.movieCount = 0,
    this.type,
    this.filterTags = const [],
    this.tags = const [],
  });
```

- [ ] **Step 3: 在 api_data.dart 中添加 import**

在 `lib/core/network/api_data.dart` 文件顶部添加 import：

```dart
import 'package:jade/core/models/actor.dart';
```

- [ ] **Step 4: 扩展 normalizeActorDetailJson**

在 `normalizeActorDetailJson` 函数的返回 Map 中（`'movie_count'` 行之后），新增：

```dart
// lib/core/network/api_data.dart — 在 normalizeActorDetailJson 返回 Map 末尾新增

      'type': apiIntOrNull(actor['type']),
      'filter_tags': apiList(root, const ['filter_tags'])
          .map(
            (t) => ActorTagItem(
              id: apiString(t['id']) ?? '',
              name: apiString(t['name']) ?? '',
              videosCount: apiInt(t['videos_count'], 0),
            ),
          )
          .toList(),
      'tags': apiList(root, const ['tags'])
          .map(
            (t) => ActorTagItem(
              id: apiString(t['id']) ?? '',
              name: apiString(t['name']) ?? '',
              videosCount: apiInt(t['videos_count'], 0),
            ),
          )
          .toList(),
```

- [ ] **Step 5: 更新 ActorDetailPage 中创建占位 ActorDetail 的逻辑**

在 `actor_detail_screen.dart` 的 `_load` 方法中，ApiClient 为空时的占位 ActorDetail（约第 50-52 行）需要新增默认值。这一步因为 actor.dart 已改为命名参数，如果现有代码使用了位置参数会编译失败。确认当前占位代码：

```dart
_detail = ActorDetail(id: widget.id, name: '演员详情', avatarUrl: '');
```

这已经是命名参数，新增的字段都有默认值，无需修改。但需要确认 `type` 参数在后续 Task 中使用。

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/actor.dart lib/core/network/api_data.dart
git commit -m "feat: add ActorTagItem and extend ActorDetail with type/filterTags/tags"
```

---

### Task 2: 重新生成 actor.g.dart

**Files:**
- Modify: `lib/core/models/actor.g.dart` (auto-generated)

**Interfaces:**
- Consumes: Task 1 的产品 — ActorDetail 新增的 type/filterTags/tags 字段
- Produces: 更新的 `_$ActorDetailFromJson` / `_$ActorDetailToJson`

- [ ] **Step 1: 运行 build_runner 重新生成序列化代码**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: 验证生成的 actor.g.dart 包含新字段**

```bash
grep -E 'type|filter_tags|filterTags|tags' lib/core/models/actor.g.dart
```

预期输出应包含 `type`、`filter_tags`、`filterTags`、`tags` 相关的序列化代码。

- [ ] **Step 3: Commit**

```bash
git add lib/core/models/actor.g.dart
git commit -m "chore: regenerate actor.g.dart with new ActorDetail fields"
```

---

### Task 3: 重构 ActorService

**Files:**
- Modify: `lib/features/actors/services/actor_service.dart`

**Interfaces:**
- Consumes: Task 1 的产品 — ActorTagItem、ActorDetail 新字段；Endpoints.moviesTags 端点
- Produces: `getActorMovies` 新签名 — 使用 movies/tags 端点，接受 type/filterByTags/sortBy/orderBy 参数
- Produces: `getDetail` 保持不变（normalizeActorDetailJson 已自动提取新字段）

- [ ] **Step 1: 重写 getActorMovies 方法**

将现有的 `getActorMovies` 方法（第 79-98 行）替换为：

```dart
// lib/features/actors/services/actor_service.dart

  /// 获取演员出演的影片列表（分页）。
  ///
  /// 使用 [Endpoints.moviesTags] 端点，以演员模式
  /// `filter_by={type}:a:{id}` 查询该演员的影片。
  /// 配合 [filterByTags] 可进一步按标签过滤。
  Future<PagedResult<MovieSummary>> getActorMovies(
    String id, {
    required int type,
    String? filterByTags,
    int page = 1,
    int limit = 48,
    String sortBy = 'release',
    String orderBy = 'desc',
  }) async {
    final query = <String, dynamic>{
      'filter_by': '$type:a:$id',
      'sort_by': sortBy,
      'order_by': orderBy,
      'page': page,
      'limit': limit,
      if (filterByTags != null && filterByTags.isNotEmpty)
        'filter_by_tags': filterByTags,
    };
    final response = await _api.get(
      Endpoints.moviesTags,
      queryParameters: query,
    );
    final data = apiMap(response.data);
    final items = apiList(data, const ['movies', 'items'])
        .map(normalizeMovieSummaryJson)
        .map(MovieSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    final totalPages = data['total_pages'] == null
        ? currentPage + (items.length >= limit ? 1 : 0)
        : apiInt(data['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
```

- [ ] **Step 2: 验证 getDetail 无需修改**

`getDetail` 方法（第 67-78 行）已调用正确的端点 `${Endpoints.actors}/$id`，且 `normalizeActorDetailJson` 在 Task 1 中已扩展，无需额外修改。

- [ ] **Step 3: Commit**

```bash
git add lib/features/actors/services/actor_service.dart
git commit -m "feat: refactor getActorMovies to use movies/tags endpoint"
```

---

### Task 4: 创建 ActorMovieController

**Files:**
- Create: `lib/features/actors/services/actor_movie_controller.dart`

**Interfaces:**
- Consumes: Task 3 的产品 — ActorService.getActorMovies 新签名
- Consumes: Task 1 的产品 — ActorTagItem
- Produces: `ActorMovieController` (ChangeNotifier) — movies, filterTags, tags, selectedTagIds, sortBy, orderBy, initialize(), toggleTag(id), changeSort(sortBy), toggleOrder()

- [ ] **Step 1: 创建 actor_movie_controller.dart**

```dart
// lib/features/actors/services/actor_movie_controller.dart

import 'package:flutter/foundation.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/actors/services/actor_service.dart';

/// 演员详情页的影片筛选状态管理。
///
/// 管理 [PaginationController]、标签选中状态、排序参数。
/// 标签或排序变化时通过 [movies.reloadWith] 即时刷新影片列表。
class ActorMovieController extends ChangeNotifier {
  ActorMovieController({
    required this.actorId,
    required this.type,
    required List<ActorTagItem> filterTags,
    required List<ActorTagItem> tags,
    required ActorService service,
  }) : _filterTags = filterTags,
       _tags = tags,
       _service = service,
       movies = PaginationController<MovieSummary>(
         fetch: (_) => throw StateError('controller not initialized'),
       ) {
    movies.addListener(_notifyFromMovies);
  }

  /// 演员 ID。
  final String actorId;

  /// 演员类别（0=有码, 1=无码, 2=欧美）。
  final int type;

  final ActorService _service;

  /// 影片分页控制器。
  final PaginationController<MovieSummary> movies;

  final List<ActorTagItem> _filterTags;

  /// 基本筛选标签列表（来源于演员详情的 filter_tags）。
  List<ActorTagItem> get filterTags => _filterTags;

  final List<ActorTagItem> _tags;

  /// 标签筛选列表（来源于演员详情的 tags）。
  List<ActorTagItem> get tags => _tags;

  final Set<String> _selectedTagIds = {};

  /// 当前选中的标签 ID 集合。
  Set<String> get selectedTagIds => Set.unmodifiable(_selectedTagIds);

  String _sortBy = 'release';

  /// 排序字段（release / update / score / hit）。
  String get sortBy => _sortBy;

  String _orderBy = 'desc';

  /// 排序方向（asc / desc），仅 sortBy == release 时生效。
  String get orderBy => _orderBy;

  bool _initialized = false;
  bool _disposed = false;

  /// 初始化控制器，触发首次影片加载。
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await movies.reloadWith(_fetchPage);
  }

  /// 切换标签选中状态，立即刷新影片列表。
  Future<void> toggleTag(String id) async {
    if (_disposed) return;
    if (_selectedTagIds.contains(id)) {
      _selectedTagIds.remove(id);
    } else {
      _selectedTagIds.add(id);
    }
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  /// 修改排序字段，立即刷新影片列表。
  Future<void> changeSort(String sortBy) async {
    if (_disposed) return;
    _sortBy = sortBy;
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  /// 切换升降序，立即刷新影片列表。
  Future<void> toggleOrder() async {
    if (_disposed) return;
    _orderBy = _orderBy == 'desc' ? 'asc' : 'desc';
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) =>
      _service.getActorMovies(
        actorId,
        type: type,
        filterByTags:
            _selectedTagIds.isEmpty ? null : _selectedTagIds.join(','),
        page: page,
        sortBy: _sortBy,
        orderBy: _orderBy,
      );

  void _notifyFromMovies() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    movies.removeListener(_notifyFromMovies);
    movies.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/actors/services/actor_movie_controller.dart
git commit -m "feat: add ActorMovieController for actor movie filtering"
```

---

### Task 5: 创建 ActorMovieFilterSheet

**Files:**
- Create: `lib/features/actors/widgets/actor_movie_filter_sheet.dart`

**Interfaces:**
- Consumes: Task 4 的产品 — ActorMovieController (filterTags, tags, selectedTagIds, sortBy, orderBy, toggleTag, changeSort, toggleOrder)
- Consumes: Task 1 的产品 — ActorTagItem (id, name, videosCount)

- [ ] **Step 1: 创建 actor_movie_filter_sheet.dart**

```dart
// lib/features/actors/widgets/actor_movie_filter_sheet.dart

import 'package:flutter/material.dart';
import 'package:jade/features/actors/services/actor_movie_controller.dart';

/// 演员详情页的影片筛选底部面板。
///
/// 展示基本筛选（filter_tags）和标签筛选（tags），
/// 标签显示影片数量（如 `巨乳(64)`）。
/// 多选、即时生效。
class ActorMovieFilterSheet extends StatelessWidget {
  const ActorMovieFilterSheet({super.key, required this.controller});

  final ActorMovieController controller;

  static const _sortOptions = [
    ('发布日期', 'release'),
    ('更新时间', 'update'),
    ('评分', 'score'),
    ('热度', 'hit'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Text(
                  '筛选',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: controller.sortBy,
                  onSelected: controller.changeSort,
                  itemBuilder: (_) => [
                    for (final (label, value) in _sortOptions)
                      PopupMenuItem(value: value, child: Text(label)),
                  ],
                  child: Text(
                    _sortOptions
                        .firstWhere(
                          (o) => o.$2 == controller.sortBy,
                          orElse: () => _sortOptions.first,
                        )
                        .$1,
                  ),
                ),
                if (controller.sortBy == 'release')
                  IconButton(
                    tooltip:
                        controller.orderBy == 'desc' ? '降序' : '升序',
                    onPressed: controller.toggleOrder,
                    icon: Icon(
                      controller.orderBy == 'desc'
                          ? Icons.south
                          : Icons.north,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (controller.filterTags.isNotEmpty) ...[
                  _TagGroup(
                    label: '基本',
                    tags: controller.filterTags,
                    selectedIds: controller.selectedTagIds,
                    showCount: false,
                    onToggle: controller.toggleTag,
                  ),
                  const SizedBox(height: 12),
                ],
                if (controller.tags.isNotEmpty)
                  _TagGroup(
                    label: '标签',
                    tags: controller.tags,
                    selectedIds: controller.selectedTagIds,
                    showCount: true,
                    onToggle: controller.toggleTag,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.label,
    required this.tags,
    required this.selectedIds,
    required this.showCount,
    required this.onToggle,
  });

  final String label;
  final List<ActorTagItem> tags;
  final Set<String> selectedIds;
  final bool showCount;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(label),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(
                    showCount ? '${tag.name}(${tag.videosCount})' : tag.name,
                  ),
                  selected: selectedIds.contains(tag.id),
                  onSelected: (_) => onToggle(tag.id),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 6),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

注意：上述代码中引用了 `ActorTagItem`，需要添加 import：

```dart
import 'package:jade/core/models/actor.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/actors/widgets/actor_movie_filter_sheet.dart
git commit -m "feat: add ActorMovieFilterSheet for actor page movie filtering"
```

---

### Task 6: 重构 ActorDetailPage UI

**Files:**
- Modify: `lib/features/actors/screens/actor_detail_screen.dart`

**Interfaces:**
- Consumes: Task 1-5 所有产品
- 移除 endDrawer → 使用 showModalBottomSheet 打开更多信息面板 (1/3 高度)
- 移除直接使用的 PaginationController → 使用 ActorMovieController
- AppBar 添加筛选图标 → showModalBottomSheet 打开 ActorMovieFilterSheet (2/3 高度)

- [ ] **Step 1: 重写 actor_detail_screen.dart**

完整重写文件：

```dart
// lib/features/actors/screens/actor_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/actor_avatar_image.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/actors/services/actor_movie_controller.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:jade/features/actors/widgets/actor_movie_filter_sheet.dart';

class ActorDetailPage extends StatefulWidget {
  const ActorDetailPage({super.key, required this.id});

  final String id;

  @override
  State<ActorDetailPage> createState() => _ActorDetailPageState();
}

class _ActorDetailPageState extends State<ActorDetailPage> {
  ActorMovieController? _controller;
  ActorDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      if (!mounted) return;
      setState(() {
        _detail = ActorDetail(
          id: widget.id,
          name: '演员详情',
          avatarUrl: '',
        );
        _isLoading = false;
      });
      return;
    }

    try {
      final detail = await ActorService(api).getDetail(widget.id);
      if (!mounted) return;
      final type = detail.type;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
      if (type != null) {
        final controller = ActorMovieController(
          actorId: widget.id,
          type: type,
          filterTags: detail.filterTags,
          tags: detail.tags,
          service: ActorService(api),
        );
        _controller = controller;
        await controller.initialize();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showInfo() {
    final detail = _detail;
    if (detail == null) return;
    final height = MediaQuery.sizeOf(context).height / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: height),
      builder: (_) => _ActorInfoContent(detail: detail),
    );
  }

  void _showFilter() {
    final controller = _controller;
    if (controller == null) return;
    final height = MediaQuery.sizeOf(context).height * 2 / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: height),
      builder: (_) => ActorMovieFilterSheet(controller: controller),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('演员详情')),
        body: Center(child: Text(_error!)),
      );
    }

    final detail = _detail!;
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('演员详情'),
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: _showFilter,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: ActorAvatarImage(detail),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text('出演过 ${detail.movieCount} 部影片'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showInfo,
                  child: const Text('更多信息'),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller != null
                ? MovieGridView(controller: controller.movies)
                : const Center(child: Text('暂无影片数据')),
          ),
        ],
      ),
    );
  }
}

/// 演员更多信息的底部面板内容。
class _ActorInfoContent extends StatelessWidget {
  const _ActorInfoContent({required this.detail});

  final ActorDetail detail;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('姓名', detail.name),
      ('出演过', '${detail.movieCount} 部影片'),
      ('生日', detail.birthday ?? '-'),
      ('年龄', detail.age?.toString() ?? '-'),
      ('身高', detail.height ?? '-'),
      ('罩杯', detail.cup ?? '-'),
      ('胸围', detail.bust ?? '-'),
      ('腰围', detail.waist ?? '-'),
      ('臀围', detail.hip ?? '-'),
      ('出生地', detail.birthplace ?? '-'),
    ];
    return ListView(
      children: [
        const ListTile(title: Text('更多信息')),
        ...rows.map(
          (row) => ListTile(title: Text(row.$1), subtitle: Text(row.$2)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 检查 import 是否完整**

确认新文件需要的 import：
- `actor_movie_filter_sheet.dart` 需要 `import 'package:jade/core/models/actor.dart';`（ActorTagItem）
- `actor_detail_screen.dart` 需要 `import 'package:jade/features/actors/widgets/actor_movie_filter_sheet.dart';`

- [ ] **Step 3: Commit**

```bash
git add lib/features/actors/screens/actor_detail_screen.dart
git commit -m "feat: refactor ActorDetailPage with bottom sheets and movie filtering"
```

---

### Task 7: 验证

**Files:** 无新建文件

- [ ] **Step 1: 运行静态分析**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && flutter analyze lib/core/models/actor.dart lib/core/network/api_data.dart lib/features/actors/
```

预期：无 error，无 warning。

- [ ] **Step 2: 运行项目测试**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && flutter test
```

预期：所有现有测试通过，无回归。

- [ ] **Step 3: 修复 compile 错误（如有）**

如果 `flutter analyze` 报告错误，逐一修复。常见问题：
- `ActorTagItem` 未被正确 import → 确认 api_data.dart 和 actor_movie_filter_sheet.dart 中有正确的 import
- `actor.g.dart` 未重新生成 → 重新运行 build_runner
- `mount` 检查丢失 → 确保所有 setState 前有 `if (!mounted) return;`

- [ ] **Step 4: 最终 Commit**

```bash
git add -A
git commit -m "chore: fix analysis warnings and verify build"
```
