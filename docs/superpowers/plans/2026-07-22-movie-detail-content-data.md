# 影片详情内容数据与紧凑间距实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收紧影片详情信息卡和类别标签间距，并让剧照、演员关联影片、相关推荐、磁链和相关清单按真实 API 契约正确加载、展示及重试。

**Architecture:** V4 影片详情作为剧照、`actor_movies`、`relative_movies` 的唯一数据源；磁链和相关清单通过各自专用接口异步加载。API 规范化层吸收不可信字段类型差异，页面只消费强类型模型，并为磁链与相关清单分别维护加载、成功、空数据和失败状态。

**Tech Stack:** Flutter、Dart、Material 3、Dio、json_serializable、flutter_test、现有 FakeAdapter。

## Global Constraints

- 保持现有四个 Tab 的结构和顺序，不引入新依赖。
- 剧照、TA出演、相关推荐只读取 `/api/v4/movies/{movie_id}` 中的 `preview_images`、`actor_movies`、`relative_movies`，禁止调用独立接口或 `/api/v1/movies/may_also_like` 回退。
- 磁链固定调用 `GET /api/v1/movies/{movie_id}/magnets`。
- 相关清单固定调用 `GET /api/v1/lists/related?movie_id={movie_id}`。
- 磁链和相关清单失败时分别显示错误与重试入口，不能伪装为空数据。
- 基本信息评分 `"4.33"` 显示为 `4.33`，不强制保留一位小数。
- 不实现片单详情路由、操作按钮业务逻辑或额外分页。
- 所有新增中文文案直接硬编码，遵循项目 `RULES.md`。

---

## 文件职责映射

- `lib/core/network/api_data.dart`：规范化 V4 详情、磁链和片单响应中的动态类型。
- `lib/core/models/movie.dart`、`lib/core/models/movie.g.dart`：保存 `actorMovies` 和 `relativeMovies`。
- `lib/features/movie_detail/services/movie_detail_service.dart`：请求磁链与相关清单，不保存 UI 状态。
- `lib/features/movie_detail/screens/movie_detail_screen.dart`：渲染详情内容并管理磁链、短评、相关清单状态。
- `lib/core/widgets/tag_chip.dart`：提供不影响默认场景的紧凑标签内边距。
- `test/core/network/api_data_test.dart`：覆盖动态 API 数据规范化。
- `test/api_integration_test.dart`：覆盖服务端点、查询参数和模型转换。
- `test/core/widgets/tag_chip_test.dart`：覆盖紧凑与默认标签样式隔离。
- `test/features/movie_detail/movie_detail_screen_test.dart`：覆盖布局、内容来源、状态、重试和展示。

---

### Task 1: 解析 V4 详情中的剧照与两类关联影片

**Files:**
- Modify: `test/core/network/api_data_test.dart`
- Modify: `lib/core/network/api_data.dart`
- Modify: `lib/core/models/movie.dart`
- Regenerate: `lib/core/models/movie.g.dart`

**Interfaces:**
- Produces: `MovieDetail.actorMovies: List<MovieSummary>`。
- Produces: `MovieDetail.relativeMovies: List<MovieSummary>`。
- Produces: `normalizeMovieDetailJson(dynamic data)` 始终输出字符串列表 `screenshots` 以及规范化的 `actor_movies`、`relative_movies`。

- [ ] **Step 1: 写入失败的数据规范化测试**

在 `test/core/network/api_data_test.dart` 新增测试，输入真实 V4 包装结构并区分三类数据：

```dart
test('normalizeMovieDetailJson 解析内嵌剧照和两类关联影片', () {
  final movie = MovieDetail.fromJson(
    normalizeMovieDetailJson({
      'movie': {
        'id': 'm1',
        'number': 'ABC-001',
        'title': 'Title',
        'cover_url': 'cover.jpg',
        'preview_images': {
          'sample': [
            {'url': 'screenshots/one.jpg'},
            'screenshots/two.jpg',
          ],
        },
        'actor_movies': [
          {
            'id': 'actor-movie',
            'number': 'ACT-001',
            'title': 'Actor Movie',
            'thumb_url': 'thumbs/actor.jpg',
          },
        ],
        'relative_movies': [
          {
            'id': 'relative-movie',
            'number': 'REL-001',
            'title': 'Relative Movie',
            'cover_url': 'covers/relative.jpg',
          },
        ],
      },
    }),
  );

  expect(movie.screenshots, [
    'screenshots/one.jpg',
    'screenshots/two.jpg',
  ]);
  expect(movie.actorMovies.single.id, 'actor-movie');
  expect(movie.actorMovies.single.thumbUrl, 'thumbs/actor.jpg');
  expect(movie.relativeMovies.single.id, 'relative-movie');
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/network/api_data_test.dart`

Expected: FAIL，`MovieDetail` 尚无 `actorMovies`、`relativeMovies`，或剧照 Map 无法解析。

- [ ] **Step 3: 扩展 MovieDetail 强类型字段**

在 `lib/core/models/movie.dart` 的构造函数和字段中加入：

```dart
this.actorMovies = const [],
this.relativeMovies = const [],

final List<MovieSummary> actorMovies;
final List<MovieSummary> relativeMovies;
```

在 `normalizeMovieDetailJson` 中统一规范化：

```dart
final previewImages = movie['screenshots'] ?? movie['preview_images'];
final actorMovies = apiList(movie, const ['actor_movies'])
    .map(normalizeMovieSummaryJson)
    .toList();
final relativeMovies = apiList(movie, const ['relative_movies'])
    .map(normalizeMovieSummaryJson)
    .toList();

// 在当前返回 Map 中替换 screenshots 键并新增以下两个键：
'screenshots': _imageUrls(previewImages),
'actor_movies': actorMovies,
'relative_movies': relativeMovies,
```

保留 `_imageUrls` 对字符串、`url`、`image_url` 和分组 Map 列表的兼容。

- [ ] **Step 4: 重新生成 JSON 代码**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: `lib/core/models/movie.g.dart` 为两个新字段生成 `fromJson/toJson` 映射。

- [ ] **Step 5: 运行测试并确认 GREEN**

Run: `flutter test test/core/network/api_data_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交本任务**

```bash
git add lib/core/network/api_data.dart lib/core/models/movie.dart lib/core/models/movie.g.dart test/core/network/api_data_test.dart
git commit -m "feat: parse embedded movie detail content"
```

---

### Task 2: 修复磁链类型并实现相关清单服务

**Files:**
- Modify: `test/core/network/api_data_test.dart`
- Modify: `test/api_integration_test.dart`
- Modify: `lib/core/network/api_data.dart`
- Modify: `lib/features/movie_detail/services/movie_detail_service.dart`

**Interfaces:**
- Produces: `normalizeMagnetJson(Map<String, dynamic>)` 将数字大小转换为 `MB/GB` 字符串，并严格解析 `hd`。
- Produces: `normalizeListModelJson(Map<String, dynamic>) -> Map<String, dynamic>`。
- Produces: `MovieDetailService.getRelatedLists(String id) -> Future<List<ListModel>>`。

- [ ] **Step 1: 写入失败的磁链规范化测试**

在 `test/core/network/api_data_test.dart` 导入 `Magnet`，加入：

```dart
test('normalizeMagnetJson 兼容真实数字大小和布尔高清字段', () {
  final magnet = Magnet.fromJson(
    normalizeMagnetJson({
      'name': 'movie.torrent',
      'hash': 'hash-1',
      'size': 9910,
      'hd': false,
      'created_at': '2026-07-22',
    }),
  );

  expect(magnet.title, 'movie.torrent');
  expect(magnet.size, '9.68 GB');
  expect(magnet.publishDate, '2026-07-22');
  expect(magnet.isHighDefinition, isFalse);
});
```

- [ ] **Step 2: 写入失败的服务契约测试**

更新 `test/api_integration_test.dart` 的 `MovieDetailService` 组：

```dart
test('GET /api/v1/movies/{id}/magnets 解析真实字段类型', () async {
  ok(adapter, '/api/v1/movies/m1/magnets', {
    'magnets': [
      {
        'name': 'movie.torrent',
        'hash': 'hash-1',
        'size': 9910,
        'hd': true,
        'created_at': '2026-07-22',
      },
    ],
  });

  final magnets = await svc.getMagnets('m1');

  expect(adapter.requests.last.path, '/api/v1/movies/m1/magnets');
  expect(magnets.single.size, '9.68 GB');
  expect(magnets.single.isHighDefinition, isTrue);
});

test('GET /api/v1/lists/related 携带 movie_id 并解析统计字段', () async {
  ok(adapter, Endpoints.listsRelated, {
    'lists': [
      {
        'id': 'list-1',
        'name': '测试片单',
        'movies_count': 12,
        'views_count': 34,
      },
    ],
  });

  final lists = await svc.getRelatedLists('m1');

  expect(adapter.requests.last.path, Endpoints.listsRelated);
  expect(adapter.requests.last.uri.queryParameters['movie_id'], 'm1');
  expect(lists.single.movieCount, 12);
  expect(lists.single.viewedCount, 34);
});
```

- [ ] **Step 3: 运行测试并确认 RED**

Run: `flutter test test/core/network/api_data_test.dart test/api_integration_test.dart`

Expected: FAIL，数字 `size` 转换异常、`hd: false` 被错误识别为高清、`getRelatedLists` 尚不存在。

- [ ] **Step 4: 实现最小规范化逻辑**

在 `lib/core/network/api_data.dart` 增加安全布尔和大小格式化：

```dart
bool apiBool(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => fallback,
    };
  }
  return fallback;
}

String? _magnetSize(dynamic value) {
  if (value is! num) return apiString(value);
  final amount = value >= 1024 ? value / 1024 : value;
  final unit = value >= 1024 ? 'GB' : 'MB';
  final digits = amount == amount.roundToDouble() ? 0 : 2;
  return '${amount.toStringAsFixed(digits)} $unit';
}
```

并将磁链规范化改为：

```dart
'title': apiString(json['title'] ?? json['name']),
'size': _magnetSize(json['size']),
'publish_date': apiString(json['publish_date'] ?? json['created_at']),
'is_high_definition': apiBool(
  json['is_high_definition'] ?? json['hd'],
  false,
),
```

新增片单规范化：

```dart
Map<String, dynamic> normalizeListModelJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name'] ?? json['title']) ?? '',
  'movie_count': apiInt(json['movie_count'] ?? json['movies_count'], 0),
  'viewed_count': apiInt(json['viewed_count'] ?? json['views_count'], 0),
};
```

- [ ] **Step 5: 实现相关清单服务**

在 `movie_detail_service.dart` 导入 `ListModel` 并加入：

```dart
Future<List<ListModel>> getRelatedLists(String id) async {
  final resp = await _api.get(
    Endpoints.listsRelated,
    queryParameters: {'movie_id': id},
  );
  return apiList(resp.data, const ['lists', 'items'])
      .map((json) => ListModel.fromJson(normalizeListModelJson(json)))
      .toList();
}
```

- [ ] **Step 6: 运行测试并确认 GREEN**

Run: `flutter test test/core/network/api_data_test.dart test/api_integration_test.dart`

Expected: PASS。

- [ ] **Step 7: 提交本任务**

```bash
git add lib/core/network/api_data.dart lib/features/movie_detail/services/movie_detail_service.dart test/core/network/api_data_test.dart test/api_integration_test.dart
git commit -m "fix: parse movie magnets and related lists"
```

---

### Task 3: 收紧操作区、类别标签并保留评分精度

**Files:**
- Modify: `test/core/widgets/tag_chip_test.dart`
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`
- Modify: `lib/core/widgets/tag_chip.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`

**Interfaces:**
- Produces: `TagChip(compact: true)` 使用零 padding 和 `EdgeInsets.symmetric(horizontal: 6)` labelPadding。
- Produces: 详情信息卡评分按 `detail.score.toString()` 显示。

- [ ] **Step 1: 写入失败的 TagChip 内边距测试**

扩展 `test/core/widgets/tag_chip_test.dart`：

```dart
expect(compactChip.padding, EdgeInsets.zero);
expect(
  compactChip.labelPadding,
  const EdgeInsets.symmetric(horizontal: 6),
);

expect(defaultChip.padding, isNull);
expect(defaultChip.labelPadding, isNull);
```

- [ ] **Step 2: 写入失败的信息卡规格测试**

在完整详情 fixture 中把评分设置为字符串 `'4.33'`，并在 Widget 测试中断言：

```dart
expect(find.text('4.33'), findsOneWidget);
expect(find.text('4.3'), findsNothing);

final infoCardColumn = tester.widget<Column>(
  find.descendant(
    of: find.byType(Card).first,
    matching: find.byType(Column),
  ).first,
);
expect(infoCardColumn.spacing, 6);

final divider = tester.widget<Divider>(
  find.descendant(
    of: find.byType(Card).first,
    matching: find.byType(Divider),
  ),
);
expect(divider.height, 12);
```

同时断言操作按钮前不再存在专用 4 像素 `SizedBox`，可给旧占位添加/移除 `Key('movie-detail-actions-top-gap')` 以形成明确 RED。

- [ ] **Step 3: 运行测试并确认 RED**

Run: `flutter test test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart`

Expected: FAIL，紧凑内边距未设置、Column spacing 仍为 8、评分仍显示 `4.3`。

- [ ] **Step 4: 实现紧凑标签样式**

在 `TagChip.build` 的 `ActionChip` 中加入：

```dart
padding: compact ? EdgeInsets.zero : null,
labelPadding: compact
    ? const EdgeInsets.symmetric(horizontal: 6)
    : null,
```

- [ ] **Step 5: 实现信息卡间距与评分显示**

在 `_MovieInfoCard` 中：

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: 6,
  children: [
    // 删除操作按钮前 const SizedBox(height: 4)
    // 保持现有 Wrap 按钮样式
    Divider(
      height: 12,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  ],
)
```

评分改为：

```dart
Text(detail.score.toString()),
```

- [ ] **Step 6: 运行测试并确认 GREEN**

Run: `flutter test test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart`

Expected: PASS。

- [ ] **Step 7: 提交本任务**

```bash
git add lib/core/widgets/tag_chip.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "style: tighten movie detail metadata spacing"
```

---

### Task 4: 使用详情内嵌数据展示剧照与两类推荐

**Files:**
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`
- Modify: `test/api_integration_test.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Modify: `lib/features/movie_detail/services/movie_detail_service.dart`

**Interfaces:**
- Consumes: `MovieDetail.actorMovies`、`MovieDetail.relativeMovies`、`MovieDetail.screenshots`。
- Produces: `_BasicInfoTab` 仅接收 `MovieDetail`，不接收通用 `mayAlsoLike` 列表。
- Removes: `MovieDetailService.getMayAlsoLike` 及详情页 `/api/v1/movies/may_also_like` 请求。

- [ ] **Step 1: 将完整详情 fixture 改为三类不同数据**

在 `_enqueueCompleteMovieDetail` 的 V4 `movie` 中加入：

```dart
'preview_images': [
  {'url': 'screenshots/detail.jpg'},
],
'actor_movies': [
  {
    'id': 'actor-movie',
    'number': 'ACT-001',
    'title': '演员关联影片',
    'thumb_url': 'thumbs/actor.jpg',
  },
],
'relative_movies': [
  {
    'id': 'relative-movie',
    'number': 'REL-001',
    'title': '相关推荐影片',
    'thumb_url': 'thumbs/relative.jpg',
  },
],
```

删除 `/api/v1/movies/may_also_like` stub。

- [ ] **Step 2: 写入失败的内容来源与请求测试**

在 Widget 测试滚动到对应区块后断言：

```dart
expect(find.byType(MovieScreenshotImage), findsOneWidget);
expect(find.text('演员关联影片'), findsOneWidget);
expect(find.text('相关推荐影片'), findsOneWidget);
expect(
  adapter.requests.where(
    (request) => request.path == Endpoints.moviesMayAlsoLike,
  ),
  isEmpty,
);
```

在 `test/api_integration_test.dart` 删除 `getMayAlsoLike` 成功测试，避免保留错误契约。

- [ ] **Step 3: 运行测试并确认 RED**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart test/api_integration_test.dart`

Expected: FAIL，当前页面仍请求通用猜你喜欢并把同一列表用于两个区块。

- [ ] **Step 4: 移除通用推荐状态和请求**

从 `_MovieDetailPageState` 删除：

```dart
List<MovieSummary> _mayAlsoLike = [];
Future<List<MovieSummary>> _loadMayAlsoLike(...)
```

从 `_load` 删除 `service.getMayAlsoLike` 调用；从 `MovieDetailService` 删除 `getMayAlsoLike`。

- [ ] **Step 5: 直接使用 MovieDetail 内嵌列表**

让 `_BasicInfoTab` 使用：

```dart
if (detail.actorMovies.isNotEmpty)
  _MovieRowSection(
    title: 'TA还出演过',
    movies: detail.actorMovies,
    onMovieTap: onMovieTap,
  ),
if (detail.relativeMovies.isNotEmpty)
  _MovieRowSection(
    title: '你可能也喜欢',
    movies: detail.relativeMovies,
    onMovieTap: onMovieTap,
  ),
```

保留 `detail.screenshots` 的现有 `_ScreenshotSection`。

- [ ] **Step 6: 运行测试并确认 GREEN**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart test/api_integration_test.dart`

Expected: PASS，且 FakeAdapter 请求历史中没有 `/api/v1/movies/may_also_like`。

- [ ] **Step 7: 提交本任务**

```bash
git add lib/features/movie_detail/screens/movie_detail_screen.dart lib/features/movie_detail/services/movie_detail_service.dart test/features/movie_detail/movie_detail_screen_test.dart test/api_integration_test.dart
git commit -m "fix: use embedded movie detail recommendations"
```

---

### Task 5: 独立加载、展示和重试磁链与相关清单

**Files:**
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`

**Interfaces:**
- Consumes: `MovieDetailService.getMagnets(String)`。
- Consumes: `MovieDetailService.getRelatedLists(String)`。
- Produces: `_loadMagnets(MovieDetailService)` 与 `_loadRelatedLists(MovieDetailService)` 各自维护 loading/error/data。
- Produces: `_MagnetTabContent` 与 `_RelatedListsTabContent`，分别接收显式 loading/error/data 和重试回调。

- [ ] **Step 1: 更新成功 fixture 并写入展示测试**

给 FakeAdapter 加入真实磁链与相关清单响应：

```dart
adapter.enqueue('/api/v1/movies/m1/magnets', {
  'success': 1,
  'data': {
    'magnets': [
      {
        'name': '测试磁链.torrent',
        'hash': 'hash-1',
        'size': 9910,
        'hd': true,
        'created_at': '2026-07-22',
      },
    ],
  },
});
adapter.enqueue(Endpoints.listsRelated, {
  'success': 1,
  'data': {
    'lists': [
      {
        'id': 'list-1',
        'name': '测试相关清单',
        'movies_count': 12,
        'views_count': 34,
      },
    ],
  },
});
```

断言磁链 Tab 展示 `测试磁链.torrent`、`高清 · 9.68 GB · 2026-07-22`，相关清单 Tab 展示 `测试相关清单`、`12 部影片 · 34 次浏览`。

- [ ] **Step 2: 写入失败与独立重试测试**

使用 `enqueueSequence` 让磁链先 HTTP 500 后成功，并让相关清单直接成功：

```dart
adapter.enqueueSequence(
  '/api/v1/movies/m1/magnets',
  [
    {'success': 0, 'message': '磁链失败'},
    {
      'success': 1,
      'data': {
        'magnets': [
          {'hash': 'retry-hash', 'name': '重试成功', 'size': 100},
        ],
      },
    },
  ],
  codes: [500, 200],
);
```

切换磁链 Tab 后断言“磁链加载失败”和“重试”；点击重试后断言“重试成功”。同时统计请求历史：磁链接口共 2 次，相关清单接口仍为 1 次，V4 详情仍为 1 次。

再添加对称测试：相关清单失败重试不能重新请求磁链或主详情。

- [ ] **Step 3: 运行测试并确认 RED**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: FAIL，当前异常被转换为空列表，相关清单仍为静态占位。

- [ ] **Step 4: 添加独立状态字段和加载方法**

在 State 中加入：

```dart
MovieDetailService? _service;
List<Magnet> _magnets = [];
Object? _magnetsError;
bool _magnetsLoading = false;
List<ListModel> _relatedLists = [];
Object? _relatedListsError;
bool _relatedListsLoading = false;
```

主详情成功后保存 `_service`，并分别启动 `_loadMagnets(service)`、`_loadReviews(service)`、`_loadRelatedLists(service)`。加载方法在请求前清空自己的 error 并设置 loading，请求结束后只更新自己的状态；每次 `setState` 前检查 `mounted`。

重试回调只调用对应方法：

```dart
void _retryMagnets() {
  final service = _service;
  if (service != null) _loadMagnets(service);
}

void _retryRelatedLists() {
  final service = _service;
  if (service != null) _loadRelatedLists(service);
}
```

- [ ] **Step 5: 渲染四态内容**

磁链和相关清单 Tab 分别按以下顺序判断：

```dart
if (loading) return const Center(child: CircularProgressIndicator());
if (error != null) {
  return ErrorRetryWidget(message: failureMessage, onRetry: onRetry);
}
if (items.isEmpty) return Center(child: Text(emptyMessage));
return successBuilder(items);
```

磁链副标题：

```dart
final metadata = [
  if (magnet.isHighDefinition) '高清',
  if (magnet.size case final size?) size,
  if (magnet.publishDate case final date?) date,
];
ListTile(
  title: Text(magnet.title ?? magnet.hash),
  subtitle: metadata.isEmpty ? null : Text(metadata.join(' · ')),
)
```

相关清单项：

```dart
ListTile(
  title: Text(list.name),
  subtitle: Text('${list.movieCount} 部影片 · ${list.viewedCount} 次浏览'),
)
```

- [ ] **Step 6: 运行测试并确认 GREEN**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: PASS，成功、空数据、失败和重试均有独立断言。

- [ ] **Step 7: 运行影片详情相关回归**

Run: `flutter test test/core/network/api_data_test.dart test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/api_integration_test.dart`

Expected: PASS。

- [ ] **Step 8: 提交本任务**

```bash
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "feat: load movie detail tabs independently"
```

---

### Task 6: 格式化、完整验证与 ADB 验收

**Files:**
- Verify all modified Dart files.

**Interfaces:**
- Consumes: Tasks 1–5 的最终行为。
- Produces: 可合并、工作区干净且有自动化与设备证据的功能分支。

- [ ] **Step 1: 格式化所有改动**

Run:

```bash
dart format lib/core/network/api_data.dart lib/core/models/movie.dart lib/features/movie_detail/services/movie_detail_service.dart lib/features/movie_detail/screens/movie_detail_screen.dart lib/core/widgets/tag_chip.dart test/core/network/api_data_test.dart test/api_integration_test.dart test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart
```

Expected: formatter exit 0。

- [ ] **Step 2: 检查差异质量**

Run: `git diff --check && git status --short`

Expected: 无 whitespace error；只有本计划中的文件存在预期修改。

- [ ] **Step 3: 运行完整测试**

Run: `flutter test`

Expected: exit 0，输出 `All tests passed!`。

- [ ] **Step 4: 运行静态分析**

Run: `dart analyze`

Expected: `No issues found!`。

- [ ] **Step 5: 提交格式化差异**

若 formatter 产生未提交差异：

```bash
git add lib test
git commit -m "style: format movie detail content fixes"
```

若工作区已干净，则跳过该提交。

- [ ] **Step 6: 安装到已连接设备**

Run: `flutter run -d emulator-5554 --debug --no-resident`

Expected: APK 构建、安装、启动成功。

- [ ] **Step 7: 使用 adb_tool 验收**

1. 打开包含 `preview_images`、`actor_movies`、`relative_movies` 和磁链的影片详情。
2. 截图确认操作按钮上下留白、类别标签内部留白已收紧，评分显示完整精度。
3. 滚动基本信息确认剧照、TA还出演过、你可能也喜欢使用不同真实内容。
4. 切换磁链下载，确认真实磁链标题、大小、日期、高清状态可见。
5. 切换相关清单，确认真实清单名称和统计可见；若服务端返回空，结合网络日志确认请求携带 `movie_id` 并正确显示空状态。
6. 检查日志不存在 `RenderFlex overflowed`、`Unhandled Exception`、`EXCEPTION CAUGHT` 或崩溃。

- [ ] **Step 8: 最终重新验证 HEAD 与工作区**

Run:

```bash
flutter test
dart analyze
git status --short
```

Expected: 测试全通过、分析无问题、工作区干净。
