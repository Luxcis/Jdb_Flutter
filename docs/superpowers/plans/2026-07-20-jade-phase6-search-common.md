# Jade Phase 6 — 搜索 + 通用列表页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 §14 搜索页（7 Tab 搜索结果 + 磁链搜索 + 图片搜索）和 §15 通用列表页（CommonListConfig 参数化重构），复用 MovieGridView/ActorGridView/PaginationController/SortSegmented/SortSelect。

**Architecture:** `lib/features/search/` 下新增 `services/search_service.dart` 封装 3 个搜索 API，扩展 `screens/search_screen.dart` 从 3 Tab 到 7 Tab，新增 `screens/magnet_search_screen.dart` 和 `screens/image_search_screen.dart`。`lib/features/common/` 下新增 `models/common_list_config.dart` 参数化配置类，重构 `screens/common_list_page.dart` 支持 filter + sort 可变参数 dataSource。所有 Cell 列表（系列/片商/导演/清单/番号）使用 `ListView.builder` + `ListTile` 渲染。

**Tech Stack:** Dart 3.8+, Flutter, provider ^6.1.5, dio ^5.7.0, go_router ^14.6.2, json_serializable, cached_network_image, shared_preferences, image_picker（新增依赖）。

## Global Constraints

- Material Design 3；ThemeMode.system；ColorScheme.fromSeed()；系统字体；无 google_fonts。
- 不做本地化，所有文案中文硬编码；不使用 .arb/flutter_localizations。
- Feature-First：core/ 放公共层；feature 只依赖 core。
- JSON 序列化用 json_serializable，fieldRename: FieldRename.snake。
- CDN 图片域名 https://tp.spfcas.com/rhe951l4q/（AppConstants.imageCdnBase）。
- 状态管理优先内置 + provider。
- 测试：widget test 验证组件渲染，unit test 验证 service 逻辑。
- Git 提交前设置代理：export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
- 不使用触觉反馈。

## Key Architecture Decisions

1. **SearchService 设计：** 当前 `search_screen.dart` 直接在 Widget 中调用 `ApiClient`。需要抽取 `SearchService` 封装 `/v2/search`、`/search_magnet`、`/search_image` 三个接口。每个搜索类型返回明确的类型化结果，避免在 Widget 中手动解析 JSON。

2. **搜索结果页 Tab 扩展：** 当前 `_ResultView` 只有 3 个 Tab（影片、演员、番号），需扩展到 7 个（增加系列、片商、导演、清单）。每个 Tab 有独立的 Widget 类，接受 `query` 参数。影片 Tab 顶部需要加入筛选条（SortSegmented + SortSelect），复用 CommonListPage 的筛选模式。

3. **Cell 列表模式：** 系列/片商/导演/清单/番号 五个 Tab 都是 Cell 列表（`ListView.builder` + `ListTile`）。这些类型的搜索结果不分页、不分数量少，直接用 `FutureBuilder` 或 `initState` 拉取全量，不依赖 `PaginationController`。代码 Tab 已有类似实现，需要重构为使用 `SearchService` + 数据模型。

4. **磁链搜索：** 新页面 `MagnetSearchPage`，顶部搜索框 + `MovieGridView` 结果列表。接口 `GET /v1/search_magnet?q=&page=` 返回分页影片数据。

5. **图片搜索：** 新页面 `ImageSearchPage`，使用 `image_picker` 选择图片后上传到 `POST /v2/search_image`（multipart/form-data），返回影片列表。需要新增 `image_picker` 依赖。

6. **CommonListConfig 参数化：** 当前 `CommonListPage` 只接受 `(int page) => Future<PagedResult<MovieSummary>>`，不含筛选/排序参数。重构后 `dataSource` 签名为 `(int page, String filter, String sortBy, String orderBy) => Future<PagedResult<MovieSummary>>`，`CommonListConfig` 包含 title、dataSource、filterOptions、sortOptions 等配置项。

7. **PaginationController 闭包机制：** `PaginationController.fetch` 是闭包，捕获 State 的 `this`。当 `_filter`/`_sortBy`/`_sortOrder` 变化时，调用 `_ctrl.refresh()` 会重新执行 `fetch(1)`，闭包读取最新的 `_filter` 等值。无需重建 PaginationController。

---

### Task 1: 创建 SearchService — 封装搜索 API

**Files:**

| Action | Path |
|--------|------|
| Create | `lib/features/search/services/search_service.dart` |
| Create | `test/features/search/services/search_service_test.dart` |

**Interfaces:**

- Consumes: `ApiClient.get(path, queryParameters?)`、`ApiClient.post(path, data)` — 已有
- Produces:

```dart
class SearchService {
  SearchService(this._api);
  final ApiClient _api;

  Future<PagedResult<MovieSummary>> searchMovies(String query, {int? page, String? sortBy, String? orderBy, String? filter});
  Future<PagedResult<ActorSummary>> searchActors(String query, {int? page});
  Future<List<Series>> searchSeries(String query);
  Future<List<Maker>> searchMakers(String query);
  Future<List<Director>> searchDirectors(String query);
  Future<List<ListModel>> searchLists(String query);
  Future<List<Code>> searchCodes(String query);
  Future<PagedResult<MovieSummary>> searchMagnet(String query, {int? page});
  Future<List<MovieSummary>> searchImage(String filePath);
}
```

#### 5-Step Checklist

- [ ] **Step 1: 写测试先跑失败**

```dart
// test/features/search/services/search_service_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/features/search/services/search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ApiClient client;
  late FakeAdapter adapter;
  late SearchService service;
  late TokenProviderFake tokenProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = FakeAdapter();
    tokenProvider = TokenProviderFake();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.com'));
    dio.httpClientAdapter = adapter;
    client = ApiClient._(dio: dio, domainManager: null!);
    service = SearchService(client);
  });

  test('searchMovies 返回分页影片', () async {
    adapter.enqueue('/api/v2/search', {
      'movies': [
        {'id': '1', 'number': 'ABC-001', 'title': 'Test', 'cover_url': 'c.jpg'},
      ],
      'current_page': 1,
      'total_pages': 3,
      'total': 30,
    });
    final result = await service.searchMovies('test', page: 1);
    expect(result.items.length, 1);
    expect(result.items.first.title, 'Test');
    expect(result.currentPage, 1);
  });

  test('searchSeries 返回系列列表', () async {
    adapter.enqueue('/api/v2/search', {
      'series': [
        {'id': 's1', 'name': 'Series A', 'movie_count': 5},
      ],
    });
    final result = await service.searchSeries('test');
    expect(result.length, 1);
    expect(result.first.name, 'Series A');
  });

  test('searchCodes 返回番号列表', () async {
    adapter.enqueue('/api/v2/search', {
      'codes': [
        {'id': 'c1', 'number': 'SSIS', 'movie_count': 10},
      ],
    });
    final result = await service.searchCodes('test');
    expect(result.length, 1);
    expect(result.first.number, 'SSIS');
  });
}

class TokenProviderFake implements TokenProvider {
  @override
  String? get token => null;
}
```

- [ ] **Step 2: 验证测试失败**

```bash
flutter test test/features/search/services/search_service_test.dart
```

预期：所有测试 FAIL（`SearchService` 类不存在 / 方法不存在）。

- [ ] **Step 3: 写实现**

```dart
// lib/features/search/services/search_service.dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/paged_result.dart';
import 'dart:io';

class SearchService {
  SearchService(this._api);
  final ApiClient _api;

  Future<PagedResult<MovieSummary>> searchMovies(
    String query, {
    int? page,
    String? sortBy,
    String? orderBy,
    String? filter,
  }) async {
    final params = <String, dynamic>{'q': query, 'type': 'movie'};
    if (page != null) params['page'] = page;
    if (sortBy != null) params['sort_by'] = sortBy;
    if (orderBy != null) params['order_by'] = orderBy;
    if (filter != null) params['filter'] = filter;
    final resp = await _api.get(Endpoints.searchV2, queryParameters: params);
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: (m['movies'] as List?)
              ?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [],
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<PagedResult<ActorSummary>> searchActors(
    String query, {
    int? page,
  }) async {
    final params = <String, dynamic>{'q': query, 'type': 'actor'};
    if (page != null) params['page'] = page;
    final resp = await _api.get(Endpoints.searchV2, queryParameters: params);
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: (m['actors'] as List?)
              ?.map((j) => ActorSummary.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [],
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<List<Series>> searchSeries(String query) async {
    final resp = await _api.get(Endpoints.searchV2,
        queryParameters: {'q': query, 'type': 'series'});
    final m = resp.data as Map<String, dynamic>;
    return (m['series'] as List?)
            ?.map((j) => Series.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<List<Maker>> searchMakers(String query) async {
    final resp = await _api.get(Endpoints.searchV2,
        queryParameters: {'q': query, 'type': 'maker'});
    final m = resp.data as Map<String, dynamic>;
    return (m['makers'] as List?)
            ?.map((j) => Maker.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<List<Director>> searchDirectors(String query) async {
    final resp = await _api.get(Endpoints.searchV2,
        queryParameters: {'q': query, 'type': 'director'});
    final m = resp.data as Map<String, dynamic>;
    return (m['directors'] as List?)
            ?.map((j) => Director.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<List<ListModel>> searchLists(String query) async {
    final resp = await _api.get(Endpoints.searchV2,
        queryParameters: {'q': query, 'type': 'list'});
    final m = resp.data as Map<String, dynamic>;
    return (m['lists'] as List?)
            ?.map((j) => ListModel.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<List<Code>> searchCodes(String query) async {
    final resp = await _api.get(Endpoints.searchV2,
        queryParameters: {'q': query, 'type': 'code'});
    final m = resp.data as Map<String, dynamic>;
    return (m['codes'] as List?)
            ?.map((j) => Code.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
  }

  Future<PagedResult<MovieSummary>> searchMagnet(
    String query, {
    int? page,
  }) async {
    final params = <String, dynamic>{'q': query};
    if (page != null) params['page'] = page;
    final resp =
        await _api.get(Endpoints.searchMagnet, queryParameters: params);
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: (m['movies'] as List?)
              ?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [],
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<List<MovieSummary>> searchImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final resp = await _api.post(Endpoints.searchImage, data: formData);
    final m = resp.data as Map<String, dynamic>;
    return (m['movies'] as List?)
            ?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
  }
}
```

- [ ] **Step 4: 验证测试通过**

```bash
flutter test test/features/search/services/search_service_test.dart
```

预期：全部 PASS（3 tests）。

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/search/services/search_service.dart test/features/search/services/search_service_test.dart
git commit -m "feat(search): add SearchService with searchMovies, searchActors, searchSeries, searchMakers, searchDirectors, searchLists, searchCodes, searchMagnet, searchImage"
```

---

### Task 2: 扩展搜索结果页 — 7 Tab + Cell 列表组件

**Files:**

| Action | Path |
|--------|------|
| Modify | `lib/features/search/screens/search_screen.dart` |
| Create | `lib/features/search/widgets/cell_list_tile.dart` |
| Create | `test/features/search/widgets/cell_list_tile_test.dart` |

**Interfaces:**

- Consumes: `SearchService`（Task 1）、`PaginationController<T>`、`MovieGridView`、`ActorGridView`、`SortSegmented`、`SortSelect`
- Produces:

```dart
// cell_list_tile.dart
class CellListTile extends StatelessWidget {
  const CellListTile({required this.title, this.subtitle, this.leading, this.onTap});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;
}
```

<details>
<summary>search_screen.dart 重构关键变更：</summary>

- `_ResultView` TabController length: 3 → 7
- TabBar tabs 从 [影片, 演员, 番号] 扩展为 [影片, 演员, 系列, 片商, 导演, 清单, 番号]
- TabBarView children 新增 `_SeriesSearchTab`、`_MakerSearchTab`、`_DirectorSearchTab`、`_ListSearchTab`
- 影片 Tab `_MovieSearchTab` 顶部新增筛选条（SortSegmented + SortSelect）
- 所有 Tab 内部使用 `SearchService` 替代直接 `ApiClient` 调用

</details>

#### 5-Step Checklist

- [ ] **Step 1: 写 CellListTile widget test 先跑失败**

```dart
// test/features/search/widgets/cell_list_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/search/widgets/cell_list_tile.dart';

void main() {
  testWidgets('CellListTile 渲染标题和副标题', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CellListTile(title: '系列A', subtitle: '5部影片'),
      ),
    ));
    expect(find.text('系列A'), findsOneWidget);
    expect(find.text('5部影片'), findsOneWidget);
  });

  testWidgets('CellListTile onTap 回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellListTile(
          title: '系列A',
          onTap: () => tapped = true,
        ),
      ),
    ));
    await tester.tap(find.text('系列A'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: 验证 widget test 失败**

```bash
flutter test test/features/search/widgets/cell_list_tile_test.dart
```

预期：FAIL（文件不存在 / CellListTile 未定义）。

- [ ] **Step 3: 写 CellListTile 实现 + 重构 search_screen.dart**

**CellListTile 实现：**

```dart
// lib/features/search/widgets/cell_list_tile.dart
import 'package:flutter/material.dart';

class CellListTile extends StatelessWidget {
  const CellListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      leading: leading,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
```

**搜索页 Tab 扩展 widget 类（追加到 search_screen.dart 末尾）：**

```dart
// ========== 系列搜索 Tab ==========
class _SeriesSearchTab extends StatefulWidget {
  final String query;
  const _SeriesSearchTab({required this.query});
  @override
  State<_SeriesSearchTab> createState() => _SeriesSearchTabState();
}

class _SeriesSearchTabState extends State<_SeriesSearchTab> {
  final SearchService _service = SearchService(ApiClient.instance);
  List<Series> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final items = await _service.searchSeries(widget.query);
      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const EmptyState(message: '暂无系列');
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final s = _items[i];
        return CellListTile(
          title: s.name,
          subtitle: '${s.movieCount}部影片',
        );
      },
    );
  }
}

// ========== 片商搜索 Tab ==========
class _MakerSearchTab extends StatefulWidget {
  final String query;
  const _MakerSearchTab({required this.query});
  @override
  State<_MakerSearchTab> createState() => _MakerSearchTabState();
}

class _MakerSearchTabState extends State<_MakerSearchTab> {
  final SearchService _service = SearchService(ApiClient.instance);
  List<Maker> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final items = await _service.searchMakers(widget.query);
      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const EmptyState(message: '暂无片商');
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final m = _items[i];
        return CellListTile(
          title: m.name,
          subtitle: '${m.movieCount}部影片',
          leading: m.avatarUrl != null
              ? CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(
                    AppConstants.imageCdnBase + m.avatarUrl!,
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ========== 导演搜索 Tab ==========
class _DirectorSearchTab extends StatefulWidget {
  final String query;
  const _DirectorSearchTab({required this.query});
  @override
  State<_DirectorSearchTab> createState() => _DirectorSearchTabState();
}

class _DirectorSearchTabState extends State<_DirectorSearchTab> {
  final SearchService _service = SearchService(ApiClient.instance);
  List<Director> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final items = await _service.searchDirectors(widget.query);
      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const EmptyState(message: '暂无导演');
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final d = _items[i];
        return CellListTile(
          title: d.name,
          subtitle: '${d.movieCount}部影片',
          leading: d.avatarUrl != null
              ? CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(
                    AppConstants.imageCdnBase + d.avatarUrl!,
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ========== 清单搜索 Tab ==========
class _ListSearchTab extends StatefulWidget {
  final String query;
  const _ListSearchTab({required this.query});
  @override
  State<_ListSearchTab> createState() => _ListSearchTabState();
}

class _ListSearchTabState extends State<_ListSearchTab> {
  final SearchService _service = SearchService(ApiClient.instance);
  List<ListModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final items = await _service.searchLists(widget.query);
      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const EmptyState(message: '暂无清单');
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final l = _items[i];
        return CellListTile(
          title: l.name,
          subtitle: '${l.movieCount}部影片',
        );
      },
    );
  }
}
```

**重构 `_MovieSearchTab`（使用 SearchService + 添加筛选条）：**

```dart
class _MovieSearchTab extends StatefulWidget {
  final String query;
  const _MovieSearchTab({required this.query});
  @override
  State<_MovieSearchTab> createState() => _MovieSearchTabState();
}

class _MovieSearchTabState extends State<_MovieSearchTab> {
  final SearchService _service = SearchService(ApiClient.instance);
  var _filter = 'all';
  var _sortBy = 'date';
  var _sortOrder = 'desc';

  late final _ctrl = PaginationController<MovieSummary>(
    fetch: (page) => _service.searchMovies(
      widget.query,
      page: page,
      filter: _filter == 'all' ? null : _filter,
      sortBy: _sortBy,
      orderBy: _sortOrder,
    ),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SortSegmented<String>(
                    options: const [
                      (label: '全部', value: 'all'),
                      (label: '可播放', value: 'playable'),
                      (label: '含磁链', value: 'magnet'),
                      (label: '字幕', value: 'subtitle'),
                    ],
                    value: _filter,
                    onChanged: (v) {
                      setState(() => _filter = v);
                      _ctrl.refresh();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SortSelect<String>(
                  options: const [
                    (label: '最新', value: 'date'),
                    (label: '热门', value: 'hot'),
                    (label: '评分', value: 'score'),
                  ],
                  value: _sortBy,
                  onChanged: (v) {
                    if (v != null && v != _sortBy) {
                      setState(() => _sortBy = v);
                      _ctrl.refresh();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(child: MovieGridView(controller: _ctrl)),
        ],
      );
}
```

**重构 `_ResultView`：**

```dart
class _ResultView extends StatefulWidget {
  final String query;
  const _ResultView({required this.query});
  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView>
    with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 7, vsync: this);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: '影片'),
              Tab(text: '演员'),
              Tab(text: '系列'),
              Tab(text: '片商'),
              Tab(text: '导演'),
              Tab(text: '清单'),
              Tab(text: '番号'),
            ],
          ),
          Expanded(
            child: TabBarView(controller: _tab, children: [
              _MovieSearchTab(query: widget.query),
              _ActorSearchTab(query: widget.query),
              _SeriesSearchTab(query: widget.query),
              _MakerSearchTab(query: widget.query),
              _DirectorSearchTab(query: widget.query),
              _ListSearchTab(query: widget.query),
              _CodeSearchTab(query: widget.query),
            ]),
          ),
        ],
      );
}
```

**重构 `_CodeSearchTab`（使用 SearchService + Code 模型）：**

```dart
class _CodeSearchTab extends StatefulWidget {
  final String query;
  const _CodeSearchTab({required this.query});
  @override
  State<_CodeSearchTab> createState() => _CodeSearchTabState();
}

class _CodeSearchTabState extends State<_CodeSearchTab> {
  final SearchService _service = SearchService(ApiClient.instance);
  List<Code> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final items = await _service.searchCodes(widget.query);
      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const EmptyState(message: '暂无番号');
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final c = _items[i];
        return CellListTile(
          title: c.number,
          subtitle: '${c.movieCount}部影片',
        );
      },
    );
  }
}
```

**重构 `_ActorSearchTab`（使用 SearchService，保持 PaginationController）：**

```dart
class _ActorSearchTab extends StatefulWidget {
  final String query;
  const _ActorSearchTab({required this.query});
  @override
  State<_ActorSearchTab> createState() => _ActorSearchTabState();
}

class _ActorSearchTabState extends State<_ActorSearchTab> {
  final SearchService _service = SearchService(ApiClient.instance);

  late final _ctrl = PaginationController<ActorSummary>(
    fetch: (page) => _service.searchActors(widget.query, page: page),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) => ActorGridView(controller: _ctrl);
}
```

**search_screen.dart 新增 import：**

在文件顶部添加：
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/search/services/search_service.dart';
import 'package:jade/features/search/widgets/cell_list_tile.dart';
```

需要删除的 import（不再直接使用）：
```dart
// 删除: import 'dart:convert';  — 不再需要手动 jsonDecode
// ApiClient、StorageKeys 在 search_screen.dart 中仍被 SearchPage（非 SearchService 部分）使用，保留
// movie.dart、actor.dart、paged_result.dart、pagination_controller.dart 仍被使用，保留
```

- [ ] **Step 4: 验证测试通过**

```bash
flutter test test/features/search/widgets/cell_list_tile_test.dart
```

预期：全部 PASS（2 tests）。

同时运行整体测试确认未破坏现有功能：
```bash
flutter test
```

预期：所有已有测试仍然 PASS，新增测试 PASS。

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/search/screens/search_screen.dart lib/features/search/widgets/cell_list_tile.dart test/features/search/widgets/cell_list_tile_test.dart
git commit -m "feat(search): expand result tabs to 7 (series/maker/director/list), add CellListTile, add filter/sort bar to movie tab, refactor to use SearchService"
```

---

### Task 3: 添加磁链搜索页和图片搜索页

**Files:**

| Action | Path |
|--------|------|
| Create | `lib/features/search/screens/magnet_search_screen.dart` |
| Create | `lib/features/search/screens/image_search_screen.dart` |
| Modify | `lib/features/search/index.dart` |
| Modify | `lib/core/router/routes.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/search/screens/magnet_search_screen_test.dart` |
| Create | `test/features/search/screens/image_search_screen_test.dart` |
| Modify | `pubspec.yaml`（新增 image_picker 依赖）|

**Interfaces:**

- Consumes: `SearchService`（Task 1）、`PaginationController<MovieSummary>`、`MovieGridView`
- Produces:

```dart
// magnet_search_screen.dart
class MagnetSearchPage extends StatefulWidget { ... }

// image_search_screen.dart
class ImageSearchPage extends StatefulWidget { ... }

// routes.dart 新增
static const String magnetSearch = '/search/magnet';
static const String imageSearch = '/search/image';
```

#### 5-Step Checklist

- [ ] **Step 1: 写 widget test 先跑失败 + 添加 image_picker 依赖**

**添加依赖：**
```bash
flutter pub add image_picker
```

**Magnet test：**

```dart
// test/features/search/screens/magnet_search_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/search/screens/magnet_search_screen.dart';

void main() {
  testWidgets('MagnetSearchPage 渲染搜索框', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MagnetSearchPage()));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('搜索磁链...'), findsOneWidget);
  });
}
```

**Image test：**

```dart
// test/features/search/screens/image_search_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/search/screens/image_search_screen.dart';

void main() {
  testWidgets('ImageSearchPage 渲染选择图片按钮', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ImageSearchPage()));
    expect(find.text('选择图片搜索'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 验证测试失败**

```bash
flutter test test/features/search/screens/magnet_search_screen_test.dart test/features/search/screens/image_search_screen_test.dart
```

预期：FAIL（文件不存在 / 类未定义）。

- [ ] **Step 3: 写实现**

**磁链搜索页：**

```dart
// lib/features/search/screens/magnet_search_screen.dart
import 'package:flutter/material.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/search/services/search_service.dart';

class MagnetSearchPage extends StatefulWidget {
  const MagnetSearchPage({super.key});
  @override
  State<MagnetSearchPage> createState() => _MagnetSearchPageState();
}

class _MagnetSearchPageState extends State<MagnetSearchPage> {
  final _controller = TextEditingController();
  final SearchService _service = SearchService(ApiClient.instance);
  PaginationController<MovieSummary>? _searchCtrl;
  String? _query;

  void _search(String q) {
    setState(() {
      _query = q;
      _searchCtrl = PaginationController<MovieSummary>(
        fetch: (page) => _service.searchMagnet(q, page: page),
      );
    });
    _searchCtrl!.fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索磁链...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: _searchCtrl == null
          ? const Center(child: Text('输入关键词搜索磁链'))
          : MovieGridView(controller: _searchCtrl!),
    );
  }
}
```

**图片搜索页：**

```dart
// lib/features/search/screens/image_search_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/search/services/search_service.dart';

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});
  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  final ImagePicker _picker = ImagePicker();
  final SearchService _service = SearchService(ApiClient.instance);
  List<MovieSummary>? _results;
  bool _isLoading = false;

  void _pickAndSearch() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _isLoading = true);
    try {
      final results = await _service.searchImage(file.path);
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片搜索')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results == null
              ? Center(
                  child: ElevatedButton.icon(
                    onPressed: _pickAndSearch,
                    icon: const Icon(Icons.image_search),
                    label: const Text('选择图片搜索'),
                  ),
                )
              : _results!.isEmpty
                  ? const EmptyState(message: '未找到匹配影片')
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.56,
                      ),
                      itemCount: _results!.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (_, i) {
                        final movie = _results![i];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Image.network(
                                  movie.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(movie.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500)),
                                    Text(movie.number,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
```

**路由更新：**

在 `lib/core/router/routes.dart` 中添加：
```dart
static const String magnetSearch = '/search/magnet';
static const String imageSearch = '/search/image';
```

在 `lib/core/router/app_router.dart` 的 `buildForTest` 方法中，在 `/search` 路由后添加：

> **跨Phase注意：** 本Task以增量方式修改 `app_router.dart`。修编时务必保留前序Phase（Phase 4）已注册的 `/actor/:id` 路由不变。

```dart
GoRoute(
  path: AppRoutes.magnetSearch,
  builder: (c, s) => const MagnetSearchPage(),
),
GoRoute(
  path: AppRoutes.imageSearch,
  builder: (c, s) => const ImageSearchPage(),
),
```

同时添加 import：
```dart
import 'package:jade/features/search/screens/magnet_search_screen.dart';
import 'package:jade/features/search/screens/image_search_screen.dart';
```

**index.dart 更新：**

```dart
// lib/features/search/index.dart
export 'screens/search_screen.dart';
export 'screens/magnet_search_screen.dart';
export 'screens/image_search_screen.dart';
```

- [ ] **Step 4: 验证测试通过**

```bash
flutter test test/features/search/screens/magnet_search_screen_test.dart test/features/search/screens/image_search_screen_test.dart
```

预期：全部 PASS（2 tests）。

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add pubspec.yaml pubspec.lock lib/features/search/screens/magnet_search_screen.dart lib/features/search/screens/image_search_screen.dart lib/features/search/index.dart lib/core/router/routes.dart lib/core/router/app_router.dart test/features/search/screens/magnet_search_screen_test.dart test/features/search/screens/image_search_screen_test.dart
git commit -m "feat(search): add MagnetSearchPage and ImageSearchPage with routing, add image_picker dependency"
```

---

### Task 4: 创建 CommonListConfig 参数化配置类

**Files:**

| Action | Path |
|--------|------|
| Create | `lib/features/common/models/common_list_config.dart` |
| Create | `test/features/common/models/common_list_config_test.dart` |

**Interfaces:**

- Consumes: 无外部依赖
- Produces:

```dart
class CommonListConfig {
  const CommonListConfig({
    required this.title,
    required this.dataSource,
    this.filterOptions = const [
      (label: '全部', value: 'all'),
      (label: '可播放', value: 'playable'),
      (label: '含磁链', value: 'magnet'),
      (label: '字幕', value: 'subtitle'),
    ],
    this.defaultFilter = 'all',
    this.sortOptions = const [
      (label: '最新', value: 'date'),
      (label: '热门', value: 'hot'),
      (label: '评分', value: 'score'),
    ],
    this.defaultSort = 'date',
    this.defaultOrder = 'desc',
  });

  final String title;
  final Future<PagedResult<MovieSummary>> Function(int page, String filter, String sortBy, String orderBy) dataSource;
  final List<({String label, String value})> filterOptions;
  final String defaultFilter;
  final List<({String label, String value})> sortOptions;
  final String defaultSort;
  final String defaultOrder;
}
```

#### 5-Step Checklist

- [ ] **Step 1: 写单元测试先跑失败**

```dart
// test/features/common/models/common_list_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/common/models/common_list_config.dart';

void main() {
  test('CommonListConfig 默认值', () {
    final config = CommonListConfig(
      title: '测试',
      dataSource: (page, filter, sortBy, orderBy) async {
        return const PagedResult(
          items: <MovieSummary>[],
          currentPage: 1,
          totalPages: 1,
          total: 0,
        );
      },
    );
    expect(config.title, '测试');
    expect(config.defaultFilter, 'all');
    expect(config.defaultSort, 'date');
    expect(config.defaultOrder, 'desc');
    expect(config.filterOptions.length, 4);
    expect(config.sortOptions.length, 3);
  });

  test('CommonListConfig 自定义 filter/sort', () {
    final config = CommonListConfig(
      title: '自定义',
      dataSource: (page, filter, sortBy, orderBy) async {
        return const PagedResult(
          items: <MovieSummary>[],
          currentPage: 1,
          totalPages: 1,
          total: 0,
        );
      },
      defaultFilter: 'magnet',
      defaultSort: 'score',
      defaultOrder: 'asc',
    );
    expect(config.defaultFilter, 'magnet');
    expect(config.defaultSort, 'score');
    expect(config.defaultOrder, 'asc');
  });

  test('CommonListConfig dataSource 可用', () async {
    final config = CommonListConfig(
      title: '数据源测试',
      dataSource: (page, filter, sortBy, orderBy) async {
        return PagedResult(
          items: [
            MovieSummary(
              id: '$page',
              number: 'NUM-$page',
              title: 'Movie $page',
              coverUrl: 'c.jpg',
            ),
          ],
          currentPage: page,
          totalPages: 1,
          total: 1,
        );
      },
    );
    final result = await config.dataSource(1, 'all', 'date', 'desc');
    expect(result.items.length, 1);
    expect(result.items.first.title, 'Movie 1');
  });
}
```

- [ ] **Step 2: 验证测试失败**

```bash
flutter test test/features/common/models/common_list_config_test.dart
```

预期：FAIL（文件不存在 / CommonListConfig 未定义）。

- [ ] **Step 3: 写实现**

```dart
// lib/features/common/models/common_list_config.dart
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';

class CommonListConfig {
  const CommonListConfig({
    required this.title,
    required this.dataSource,
    this.filterOptions = const [
      (label: '全部', value: 'all'),
      (label: '可播放', value: 'playable'),
      (label: '含磁链', value: 'magnet'),
      (label: '字幕', value: 'subtitle'),
    ],
    this.defaultFilter = 'all',
    this.sortOptions = const [
      (label: '最新', value: 'date'),
      (label: '热门', value: 'hot'),
      (label: '评分', value: 'score'),
    ],
    this.defaultSort = 'date',
    this.defaultOrder = 'desc',
  });

  final String title;
  final Future<PagedResult<MovieSummary>> Function(
    int page,
    String filter,
    String sortBy,
    String orderBy,
  ) dataSource;

  final List<({String label, String value})> filterOptions;
  final String defaultFilter;

  final List<({String label, String value})> sortOptions;
  final String defaultSort;
  final String defaultOrder;
}
```

- [ ] **Step 4: 验证测试通过**

```bash
flutter test test/features/common/models/common_list_config_test.dart
```

预期：全部 PASS（3 tests）。

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/common/models/common_list_config.dart test/features/common/models/common_list_config_test.dart
git commit -m "feat(common): add CommonListConfig parameterized configuration class"
```

---

### Task 5: 重构 CommonListPage — 使用 CommonListConfig

**Files:**

| Action | Path |
|--------|------|
| Modify | `lib/features/common/screens/common_list_page.dart` |
| Modify | `lib/features/common/index.dart` |
| Create | `test/features/common/screens/common_list_page_test.dart` |

**Interfaces:**

- Consumes: `CommonListConfig`（Task 4）、`PaginationController<MovieSummary>`、`MovieGridView`、`SortSegmented`、`SortSelect`
- Produces:

```dart
class CommonListPage extends StatefulWidget {
  const CommonListPage({super.key, required this.config});
  final CommonListConfig config;
}
```

#### 5-Step Checklist

- [ ] **Step 1: 写 widget test 先跑失败**

```dart
// test/features/common/screens/common_list_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/common/models/common_list_config.dart';
import 'package:jade/features/common/screens/common_list_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('CommonListPage 渲染标题和筛选条', (tester) async {
    final config = CommonListConfig(
      title: '测试列表',
      dataSource: (page, filter, sortBy, orderBy) async {
        return const PagedResult(
          items: <MovieSummary>[],
          currentPage: 1,
          totalPages: 1,
          total: 0,
        );
      },
    );
    await tester.pumpWidget(
      const MaterialApp(home: CommonListPage(config: config)),
    );
    await tester.pump();
    expect(find.text('测试列表'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
  });

  testWidgets('CommonListPage 筛选切换触发刷新', (tester) async {
    var callCount = 0;
    final config = CommonListConfig(
      title: '筛选测试',
      dataSource: (page, filter, sortBy, orderBy) async {
        callCount++;
        return const PagedResult(
          items: <MovieSummary>[],
          currentPage: 1,
          totalPages: 1,
          total: 0,
        );
      },
    );
    await tester.pumpWidget(
      const MaterialApp(home: CommonListPage(config: config)),
    );
    await tester.pump();
    // 初始 fetchMore 调用一次
    expect(callCount, 1);
    // 点击"可播放"触发 refresh
    await tester.tap(find.text('可播放'));
    await tester.pump();
    expect(callCount, 2);
  });
}
```

- [ ] **Step 2: 验证测试失败**

```bash
flutter test test/features/common/screens/common_list_page_test.dart
```

预期：FAIL（CommonListConfig 参数不匹配 / config 属性不存在 等编译错误）。

- [ ] **Step 3: 写实现 — 替换 common_list_page.dart 整个文件**

```dart
// lib/features/common/screens/common_list_page.dart
import 'package:flutter/material.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/common/models/common_list_config.dart';

class CommonListPage extends StatefulWidget {
  const CommonListPage({super.key, required this.config});
  final CommonListConfig config;

  @override
  State<CommonListPage> createState() => _CommonListPageState();
}

class _CommonListPageState extends State<CommonListPage> {
  late String _filter = widget.config.defaultFilter;
  late String _sortBy = widget.config.defaultSort;
  late String _sortOrder = widget.config.defaultOrder;
  late final _ctrl = PaginationController<MovieSummary>(
    fetch: (page) =>
        widget.config.dataSource(page, _filter, _sortBy, _sortOrder),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.config.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SortSegmented<String>(
                    options: widget.config.filterOptions,
                    value: _filter,
                    onChanged: (v) {
                      setState(() => _filter = v);
                      _ctrl.refresh();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SortSelect<String>(
                  options: widget.config.sortOptions,
                  value: _sortBy,
                  onChanged: (v) {
                    if (v != null && v != _sortBy) {
                      setState(() => _sortBy = v);
                      _ctrl.refresh();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(child: MovieGridView(controller: _ctrl)),
        ],
      ),
    );
  }
}
```

**index.dart 更新：**

```dart
// lib/features/common/index.dart
export 'screens/common_list_page.dart';
export 'models/common_list_config.dart';
```

- [ ] **Step 4: 验证测试通过**

```bash
flutter test test/features/common/screens/common_list_page_test.dart
```

预期：全部 PASS（2 tests）。

**验证全局测试无回归：**
```bash
flutter test
```

预期：所有已有测试仍然 PASS。

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/common/screens/common_list_page.dart lib/features/common/index.dart test/features/common/screens/common_list_page_test.dart
git commit -m "refactor(common): parameterize CommonListPage with CommonListConfig, add filter + sort support"
```

---

## Final Integration Check

完成所有 Task 后执行：

```bash
flutter analyze
```

若有 analyzer 警告，使用 `dart fix --apply` 自动修复。

```bash
flutter test
```

全部测试 PASS。

```bash
flutter run
```

手动验证：
1. 搜索页 → 输入关键词 → 结果页 7 个 Tab 均可正常切换和数据展示
2. 影片 Tab 的筛选和排序正常工作
3. 磁链搜索页正常搜索
4. 图片搜索页可选择图片并搜索
5. CommonListPage 从各处传入不同 CommonListConfig 均正常工作
