# 最新影片列表页实现计划（最新上架 / 近期磁链更新 → 全部）

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为首页「最新上架」和「近期磁链更新」两个区块的「全部」入口实现统一影片列表页：顶部 6 个类型 Tab（全部/有码/无码/欧美/FC2/动漫），Tab 下方同一行内为筛选 `SortSegmented` 与排序 `SortSelect`，复用 `MovieCard` + `MovieGridView` 固定网格自动分页。

**架构：** 单个页面 `/latest-movies` 由 query 参数 `section`（latest/magnets）区分入口与默认筛选；外层 `LatestMoviesPage` 持 6 Tab 的 `TabController`，每个 Tab 是独立 `LatestTypeTab`（`AutomaticKeepAliveClientMixin`），各自持有 `PaginationController` 与筛选/排序状态。服务 `LatestMoviesService` 封装 `GET /api/v1/movies/latest` 分页解析。

**技术栈：** Flutter、Dart、Dio/`ApiClient`、`go_router`、现有 `MovieSummary` 模型与 `apiPageResult`、`SortSegmented`/`SortSelect`/`MovieGridView`/`MovieCard` 现有组件、`flutter_test` + 项目 `FakeAdapter`。

## Global Constraints

- 只新增 `latest-movies` 页面；不改动 `CommonListPage` 现有行为。
- 接口固定为 `GET /api/v1/movies/latest`，`limit` 固定 48。
- 类型映射固定为 `all/0/1/2/3/4`，对应「全部/有码/无码/欧美/FC2/动漫」。
- 筛选映射固定为 `all/can_play/magnets/subtitle`，对应「全部/可播放/含磁链/含字幕」。
- 排序字段固定为 `release/update`，方向固定 `desc`，不做 asc/desc 切换。
- 每个 Tab 独立保存筛选/排序状态；切 Tab 保留已加载数据。
- `filter_by == 'all'` 时排序强制 `release` 且排序控件禁用（遵循 APK 原版行为）。
- 默认筛选：`section=latest` → `can_play`；`section=magnets` → `magnets`；排序默认 `update`。
- 复用 `MovieGridView`、`MovieCard`，不得复制卡片或分页 UI。
- `MovieGridView` 补全局空态（items 为空且非 loading/error 时显示 `EmptyState`）。
- 所有用户文案直接中文硬编码（项目规则）。
- 不新增依赖，不主动发布或推送。

---

### Task 1: 最新影片接口服务

**文件：**
- 创建：`lib/features/home/services/latest_movies_service.dart`
- 创建：`test/features/home/latest_movies_service_test.dart`
- 复用：`lib/core/network/endpoints.dart`
- 复用：`lib/core/network/api_data.dart`

**接口：**

- 消费：`ApiClient.get`、`Endpoints.moviesLatest`、`apiPageResult`、`normalizeMovieSummaryJson`、`MovieSummary.fromJson`
- 产出：

```dart
class LatestMoviesService {
  LatestMoviesService(ApiClient api);

  Future<PagedResult<MovieSummary>> getMovies({
    required String type,     // all/0/1/2/3/4
    required String filterBy, // all/can_play/magnets/subtitle
    required String sortBy,   // release/update
    int page = 1,
  });
}
```

- [ ] **步骤 1：编写失败的服务契约测试**

创建 `test/features/home/latest_movies_service_test.dart`，使用真实 `ApiClient` + `ResponseInterceptor` + `FakeAdapter`，覆盖查询参数与分页解析规则：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/home/services/latest_movies_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('完整发送类型 筛选 排序 页码和 48 条分页参数', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.moviesLatest, {
      'success': 1,
      'data': {'movies': [], 'current_page': 1},
    });

    await fixture.service.getMovies(
      type: '1',
      filterBy: 'magnets',
      sortBy: 'update',
      page: 2,
    );

    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '1',
      'filter_by': 'magnets',
      'sort_by': 'update',
      'page': 2,
      'limit': 48,
    });
  });

  test('解析 movies 与 current_page 并保留影片摘要字段', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.moviesLatest, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'm1',
            'number': 'SSIS-001',
            'title': '测试影片',
            'thumb_url': 'thumb.jpg',
            'cover_url': 'cover.jpg',
            'release_date': '2026-08-01',
            'score': '4.5',
          },
        ],
        'current_page': 2,
        'total_pages': 3,
        'total_count': 49,
      },
    });

    final result = await fixture.service.getMovies(
      type: 'all',
      filterBy: 'can_play',
      sortBy: 'update',
      page: 2,
    );

    expect(result.items.single.id, 'm1');
    expect(result.items.single.thumbUrl, 'thumb.jpg');
    expect(result.items.single.score, 4.5);
    expect(result.currentPage, 2);
    expect(result.totalPages, 3);
    expect(result.total, 49);
  });

  test('缺少 total_pages 时以 48 条为满页阈值', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesLatest, [
      {
        'success': 1,
        'data': {
          'movies': [
            for (var index = 0; index < 48; index++)
              {
                'id': 'm$index',
                'number': 'N$index',
                'title': '影片 $index',
                'cover_url': '',
              },
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'movies': [
            {'id': 'm48', 'number': 'N48', 'title': '影片 48', 'cover_url': ''},
          ],
          'current_page': 2,
        },
      },
    ]);

    final fullPage = await fixture.service.getMovies(
      type: 'all',
      filterBy: 'magnets',
      sortBy: 'update',
    );
    final partialPage = await fixture.service.getMovies(
      type: 'all',
      filterBy: 'magnets',
      sortBy: 'update',
      page: 2,
    );

    expect(fullPage.totalPages, 2);
    expect(partialPage.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, LatestMoviesService service})>
_buildFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: LatestMoviesService(api));
}
```

- [ ] **步骤 2：运行服务测试确认红色状态**

运行：

```bash
flutter test test/features/home/latest_movies_service_test.dart
```

预期：编译失败，因为 `latest_movies_service.dart` 与 `LatestMoviesService` 不存在。

- [ ] **步骤 3：实现最小服务**

创建 `lib/features/home/services/latest_movies_service.dart`：

```dart
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

class LatestMoviesService {
  LatestMoviesService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.moviesLatest,
      queryParameters: {
        'type': type,
        'filter_by': filterBy,
        'sort_by': sortBy,
        'page': page,
        'limit': _pageSize,
      },
    );
    return apiPageResult(
      response.data,
      keys: const ['movies', 'items'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) =>
          MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}
```

- [ ] **步骤 4：格式化并重跑聚焦服务测试**

运行：

```bash
dart format lib/features/home/services/latest_movies_service.dart test/features/home/latest_movies_service_test.dart
flutter test test/features/home/latest_movies_service_test.dart
```

预期：全部服务测试通过。

- [ ] **步骤 5：提交服务契约**

```bash
git add lib/features/home/services/latest_movies_service.dart test/features/home/latest_movies_service_test.dart
git commit -m "feat(home): add latest movies service"
```

---

### Task 2: MovieGridView 全局空态

**文件：**
- 修改：`lib/core/widgets/movie_grid_view.dart:22-34`
- 测试：`test/core/widgets/movie_grid_view_test.dart`（追加）

**接口：**
- 消费：`EmptyState`（`lib/core/widgets/empty_state.dart`）
- 行为：`controller.items.isEmpty && !controller.isLoading && controller.error == null` 时显示 `EmptyState`

- [ ] **步骤 1：编写失败的空态测试**

在 `test/core/widgets/movie_grid_view_test.dart` 末尾追加：

```dart
testWidgets('空数据且非加载非错误时显示空态', (tester) async {
  final controller = PaginationController<MovieSummary>(
    fetch: (_) async =>
        PagedResult(items: const [], currentPage: 1, totalPages: 1, total: 0),
  );
  addTearDown(controller.dispose);
  await controller.fetchMore();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MovieGridView(controller: controller)),
    ),
  );

  expect(find.text('暂无数据'), findsOneWidget);
  expect(find.byType(GridView), findsNothing);
});
```

- [ ] **步骤 2：运行空态测试确认红色状态**

运行：

```bash
flutter test test/core/widgets/movie_grid_view_test.dart
```

预期：新用例失败（MovieGridView 目前不显示空态）。

- [ ] **步骤 3：实现空态分支**

修改 `lib/core/widgets/movie_grid_view.dart`，在 `isLoading` 分支之后、`NotificationListener` 之前插入：

```dart
        if (controller.items.isEmpty) {
          return const EmptyState();
        }
```

注意：此分支在 error/loading 分支之后，因此 items 为空且非 error 非 loading 时才到达。

- [ ] **步骤 4：运行 MovieGridView 回归**

运行：

```bash
dart format lib/core/widgets/movie_grid_view.dart test/core/widgets/movie_grid_view_test.dart
flutter test test/core/widgets/movie_grid_view_test.dart
```

预期：全部通过（原有用例不受影响，空态只在无数据时显示）。

- [ ] **步骤 5：提交空态**

```bash
git add lib/core/widgets/movie_grid_view.dart test/core/widgets/movie_grid_view_test.dart
git commit -m "feat(core): show empty state in movie grid view"
```

---

### Task 3: 页面、6 Tab 独立状态与筛选排序联动

**文件：**
- 创建：`lib/features/home/screens/latest_movies_page.dart`
- 创建：`lib/features/home/widgets/latest_type_tab.dart`
- 创建：`test/features/home/latest_movies_page_test.dart`

**接口：**

- 消费：`LatestMoviesService`、`PaginationController`、`SortSegmented<String>`、`SortSelect<String>`、`MovieGridView`、`ApiClient.instanceOrNull`
- 产出：

```dart
class LatestMoviesPage extends StatefulWidget {
  const LatestMoviesPage({
    super.key,
    this.section = 'latest',  // 'latest' | 'magnets'
    this.title = '最新影片',
    this.dataSource,
  });
}

class LatestTypeTab extends StatefulWidget {
  const LatestTypeTab({
    super.key,
    required this.type,          // all/0/1/2/3/4
    required this.defaultFilter, // can_play | magnets
    this.dataSource,
  });
}
```

（`dataSource` 可注入用于测试，默认从 `ApiClient.instanceOrNull` 构造 `LatestMoviesService`；`ApiClient` 不可用返回空结果。）

- [ ] **步骤 1：编写失败的页面结构测试**

创建 `test/features/home/latest_movies_page_test.dart`，注入 recording source 验证 UI 契约：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/home/screens/latest_movies_page.dart';
import 'package:jade/features/home/services/latest_movies_service.dart';

typedef _Request = ({
  String type,
  String filterBy,
  String sortBy,
  int page,
});

class _RecordingSource {
  _RecordingSource({this.multiplePages = false});

  final bool multiplePages;
  final requests = <_Request>[];

  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  }) async {
    requests.add((
      type: type,
      filterBy: filterBy,
      sortBy: sortBy,
      page: page,
    ));
    final itemCount = multiplePages ? (page == 1 ? 48 : 12) : 1;
    return PagedResult(
      items: [
        for (var index = 0; index < itemCount; index++)
          MovieSummary(
            id: '$type-$page-$index',
            number: 'N-$type-$page-$index',
            title: '影片 $type-$page-$index',
            coverUrl: '',
          ),
      ],
      currentPage: page,
      totalPages: multiplePages ? 2 : 1,
      total: multiplePages ? 60 : 1,
    );
  }
}

Future<_RecordingSource> _pumpPage(
  WidgetTester tester, {
  String section = 'latest',
  String title = '最新影片',
  bool multiplePages = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _RecordingSource(multiplePages: multiplePages);
  await tester.pumpWidget(
    MaterialApp(
      home: LatestMoviesPage(
        section: section,
        title: title,
        dataSource: source,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return source;
}

void main() {
  testWidgets('显示标题六个 Tab 筛选排序控件与 MovieCard 网格', (tester) async {
    final source = await _pumpPage(tester);

    expect(find.text('最新影片'), findsOneWidget);
    for (final label in ['全部', '有码', '无码', '欧美', 'FC2', '动漫']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(SortSegmented<String>), findsOneWidget);
    expect(find.byType(SortSelect<String>), findsOneWidget);
    expect(find.byType(MovieGridView), findsOneWidget);
    expect(find.byType(MovieCard), findsOneWidget);
    // latest 入口默认 filter=can_play、sort=update
    expect(source.requests.single, (
      type: 'all',
      filterBy: 'can_play',
      sortBy: 'update',
      page: 1,
    ));
  });

  testWidgets('magnets 入口默认筛选为含磁链', (tester) async {
    final source = await _pumpPage(tester, section: 'magnets', title: '磁链更新');

    expect(find.text('磁链更新'), findsOneWidget);
    expect(source.requests.single.filterBy, 'magnets');
    expect(source.requests.single.sortBy, 'update');
  });
}
```

- [ ] **步骤 2：运行页面测试确认红色状态**

运行：

```bash
flutter test test/features/home/latest_movies_page_test.dart
```

预期：编译失败，因为 `LatestMoviesPage` 不存在。

- [ ] **步骤 3：实现页面壳与类型 Tab**

创建 `lib/features/home/screens/latest_movies_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/features/home/services/latest_movies_service.dart';
import 'package:jade/features/home/widgets/latest_type_tab.dart';

typedef _MovieTypeTab = ({String label, String value});

class LatestMoviesPage extends StatefulWidget {
  const LatestMoviesPage({
    super.key,
    this.section = 'latest',
    this.title = '最新影片',
    this.dataSource,
  });

  final String section;
  final String title;
  final LatestMoviesDataSource? dataSource;

  @override
  State<LatestMoviesPage> createState() => _LatestMoviesPageState();
}

class _LatestMoviesPageState extends State<LatestMoviesPage>
    with TickerProviderStateMixin {
  static const _tabs = <_MovieTypeTab>[
    (label: '全部', value: 'all'),
    (label: '有码', value: '0'),
    (label: '无码', value: '1'),
    (label: '欧美', value: '2'),
    (label: 'FC2', value: '3'),
    (label: '动漫', value: '4'),
  ];

  late final TabController _tabController;

  String get _defaultFilter =>
      widget.section == 'magnets' ? 'magnets' : 'can_play';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in _tabs) Tab(text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in _tabs)
            LatestTypeTab(
              key: PageStorageKey<String>(tab.value),
              type: tab.value,
              defaultFilter: _defaultFilter,
              dataSource: widget.dataSource,
            ),
        ],
      ),
    );
  }
}
```

创建 `lib/features/home/widgets/latest_type_tab.dart`：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/home/services/latest_movies_service.dart';

class LatestTypeTab extends StatefulWidget {
  const LatestTypeTab({
    super.key,
    required this.type,
    required this.defaultFilter,
    this.dataSource,
  });

  final String type;
  final String defaultFilter;
  final LatestMoviesDataSource? dataSource;

  @override
  State<LatestTypeTab> createState() => _LatestTypeTabState();
}

class _LatestTypeTabState extends State<LatestTypeTab>
    with AutomaticKeepAliveClientMixin {
  static const _filterOptions = [
    (label: '全部', value: 'all'),
    (label: '可播放', value: 'can_play'),
    (label: '含磁链', value: 'magnets'),
    (label: '含字幕', value: 'subtitle'),
  ];
  static const _sortOptions = [
    (label: '发布日期', value: 'release'),
    (label: '更新时间', value: 'update'),
  ];

  late final LatestMoviesDataSource _source;
  late final PaginationController<MovieSummary> _controller;
  late String _filter;
  var _sort = 'update';

  bool get _filterIsAll => _filter == 'all';

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _source =
        widget.dataSource ??
        (api == null
            ? const UnavailableLatestMoviesDataSource()
            : LatestMoviesService(api));
    _filter = widget.defaultFilter;
    _controller = PaginationController<MovieSummary>(fetch: _fetchPage);
    unawaited(_controller.fetchMore());
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _source.getMovies(
    type: widget.type,
    filterBy: _filter,
    sortBy: _filterIsAll ? 'release' : _sort,
    page: page,
  );

  void _changeFilter(String value) {
    if (value == _filter) return;
    setState(() => _filter = value);
    _controller.reloadWith(_fetchPage);
  }

  void _changeSort(String value) {
    if (value == _sort) return;
    setState(() => _sort = value);
    _controller.reloadWith(_fetchPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: SortSegmented<String>(
            key: const Key('latest-tab-filter'),
            compact: true,
            expanded: true,
            options: _filterOptions,
            value: _filter,
            onChanged: _changeFilter,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SortSelect<String>(
                key: const Key('latest-tab-sort'),
                compact: true,
                options: _sortOptions,
                value: _filterIsAll ? 'release' : _sort,
                onChanged: _filterIsAll ? null : _changeSort,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: MovieGridView(controller: _controller)),
      ],
    );
  }
}
```

注意：`LatestMoviesDataSource` 是服务的抽象接口（Task 1 未定义）。需要在 `latest_movies_service.dart` 中补充抽象接口与不可用实现（见下方 Task 4 步骤 1 的服务契约升级——为避免循环依赖，Task 3 中直接使用 `LatestMoviesDataSource` 与 `UnavailableLatestMoviesDataSource`，实现放在服务文件内，Task 4 统一路由接入后校验）。

- [ ] **步骤 4：补充服务抽象接口（供 Tab 注入）**

在 `lib/features/home/services/latest_movies_service.dart` 中追加（保持现有 `LatestMoviesService` 不变）：

```dart
abstract interface class LatestMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  });
}

class UnavailableLatestMoviesDataSource implements LatestMoviesDataSource {
  const UnavailableLatestMoviesDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
```

并让 `LatestMoviesService implements LatestMoviesDataSource`。

- [ ] **步骤 5：格式化并运行页面 + 服务回归**

运行：

```bash
dart format lib/features/home/services/latest_movies_service.dart lib/features/home/screens/latest_movies_page.dart lib/features/home/widgets/latest_type_tab.dart test/features/home/latest_movies_page_test.dart test/features/home/latest_movies_service_test.dart
flutter test test/features/home/latest_movies_page_test.dart test/features/home/latest_movies_service_test.dart
```

预期：页面与服务测试全部通过。

- [ ] **步骤 6：追加联动与独立状态测试**

在 `test/features/home/latest_movies_page_test.dart` 末尾追加：

```dart
testWidgets('筛选切换为全部时排序控件禁用且请求强制 release', (tester) async {
  final source = await _pumpPage(tester);

  await tester.tap(find.text('全部').last);
  await tester.pump();
  await tester.pump();

  final sort = tester.widget<SortSelect<String>>(
    find.byKey(const Key('latest-tab-sort')),
  );
  expect(sort.value, 'release');
  expect(sort.onChanged, isNull);
  expect(source.requests.last.sortBy, 'release');
  expect(source.requests.last.page, 1);
});

testWidgets('筛选为含磁链时排序可选且请求用所选排序', (tester) async {
  final source = await _pumpPage(tester);

  await tester.tap(find.text('含磁链'));
  await tester.pump();
  await tester.pump();
  expect(source.requests.last.filterBy, 'magnets');

  await tester.tap(find.text('发布日期'));
  await tester.pump();
  await tester.pump();
  expect(source.requests.last.sortBy, 'release');
  expect(source.requests.last.filterBy, 'magnets');
});

testWidgets('切换 Tab 请求对应类型且各 Tab 独立状态', (tester) async {
  final source = await _pumpPage(tester);
  final tabBar = tester.widget<TabBar>(find.byType(TabBar));

  tabBar.controller!.animateTo(2);
  await tester.pumpAndSettle();
  expect(
    source.requests
        .where((request) => request.type == '1')
        .map((request) => request.page),
    [1],
  );

  tabBar.controller!.animateTo(0);
  await tester.pumpAndSettle();
  final allRequests = source.requests
      .where((request) => request.type == 'all')
      .toList();
  expect(allRequests.map((request) => request.page), [1]);
  // Tab B 改变筛选不影响 Tab A 的已加载状态
  tabBar.controller!.animateTo(2);
  await tester.pumpAndSettle();
  await tester.tap(find.text('含字幕'));
  await tester.pump();
  await tester.pump();
  expect(
    source.requests
        .where((request) => request.type == '1')
        .last
        .filterBy,
    'subtitle',
  );
  // 切回 Tab A 不重新加载（keepAlive 保留）
  tabBar.controller!.animateTo(0);
  await tester.pumpAndSettle();
  expect(
    source.requests
        .where((request) => request.type == 'all')
        .map((request) => request.page),
    [1],
  );
});
```

- [ ] **步骤 7：运行全部页面测试**

运行：

```bash
dart format test/features/home/latest_movies_page_test.dart
flutter test test/features/home/latest_movies_page_test.dart
```

预期：全部通过（含独立状态与联动）。

- [ ] **步骤 8：提交页面**

```bash
git add lib/features/home/services/latest_movies_service.dart lib/features/home/screens/latest_movies_page.dart lib/features/home/widgets/latest_type_tab.dart test/features/home/latest_movies_page_test.dart test/features/home/latest_movies_service_test.dart
git commit -m "feat(home): build latest movies page with per-tab state"
```

---

### Task 4: 路由接入与首页入口

**文件：**
- 修改：`lib/core/router/routes.dart:6-28`
- 修改：`lib/core/router/app_router.dart:99-107`
- 修改：`lib/features/home/screens/home_screen.dart:106-117`
- 修改：`test/features/home/home_screen_test.dart`（追加跳转测试）
- 校验：`lib/features/home/index.dart`

**接口：**
- 消费：`LatestMoviesPage(section: ..., title: ...)`、`AppRoutes.latestMovies`
- 产出：`/latest-movies?section=latest|magnets&title=...` 渲染 `LatestMoviesPage`；首页两个「全部」入口跳转

- [ ] **步骤 1：编写失败的路由跳转测试**

在 `test/features/home/home_screen_test.dart` 末尾追加：

```dart
testWidgets('点击最新上架全部跳转最新影片页', (tester) async {
  final adapter = await _prepareApi(tester);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(
        path: AppRoutes.latestMovies,
        builder: (_, _) => Scaffold(body: Text('最新影片页')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();

  await tester.tap(find.text('全部').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();

  expect(
    router.state.uri.path,
    AppRoutes.latestMovies,
  );
  expect(router.state.uri.queryParameters['section'], 'latest');
  expect(find.text('最新影片页'), findsOneWidget);
});
```

（点击目标：`SectionHeader` 的 `trailing` 是「全部」。首页推荐区/搜索区无「全部」文案，`find.text('全部')` 应唯一命中「最新上架」区块的 trailing；若存在多个匹配，用 `find.text('全部').last`。第二个「近期磁链更新 > 全部」的跳转测试同理，点击后断言 `section == 'magnets'`。）

- [ ] **步骤 2：运行跳转测试确认红色状态**

运行：

```bash
flutter test test/features/home/home_screen_test.dart
```

预期：新断言失败（当前「全部」无 onTrailing，跳转不发生）。

- [ ] **步骤 3：添加路由常量并注册路由**

在 `lib/core/router/routes.dart` 添加：

```dart
static const String latestMovies = '/latest-movies';
```

在 `lib/core/router/app_router.dart` 的顶层路由列表（`historyRecommendDetail` 之后）添加：

```dart
GoRoute(
  path: AppRoutes.latestMovies,
  builder: (c, s) {
    final q = s.uri.queryParameters;
    return LatestMoviesPage(
      section: q['section'] ?? 'latest',
      title: q['title'] ?? '最新影片',
    );
  },
),
```

并确认 `lib/features/home/index.dart` 已导出页面（默认 `export 'screens/home_screen.dart'` 等；需追加 `export 'screens/latest_movies_page.dart';`）。

- [ ] **步骤 4：首页两个「全部」接入跳转**

修改 `lib/features/home/screens/home_screen.dart` 两处 `SectionHeader`：

```dart
SectionHeader(
  title: '最新上架',
  trailing: '全部',
  onTrailing: () =>
      context.push('/latest-movies?section=latest&title=最新影片'),
),
SectionHeader(
  title: '近期磁链更新',
  trailing: '全部',
  onTrailing: () =>
      context.push('/latest-movies?section=magnets&title=磁链更新'),
),
```

（`home_screen.dart` 已 import `go_router` 的 `context.push`。）

- [ ] **步骤 5：运行路由与首页回归**

运行：

```bash
dart format lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/home/index.dart lib/features/home/screens/home_screen.dart test/features/home/home_screen_test.dart
flutter test test/features/home/home_screen_test.dart test/core/router/app_router_test.dart test/core/router/app_router_requirements_test.dart test/core/router/app_router_auth_test.dart
```

预期：全部通过。

- [ ] **步骤 6：提交路由接入**

```bash
git add lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/home/index.dart lib/features/home/screens/home_screen.dart test/features/home/home_screen_test.dart
git commit -m "feat(home): route latest movies page from home sections"
```

---

### Task 5: 完整质量门禁与范围核查

- [ ] **步骤 1：运行完整测试套件**

运行：

```bash
flutter test
```

预期：全部通过（含新增的 latest 服务/页面/空态/跳转测试）。

- [ ] **步骤 2：运行静态分析**

运行：

```bash
flutter analyze
```

预期：`No issues found!`。

- [ ] **步骤 3：检查 diff 空白**

运行：

```bash
git diff --check
```

预期：退出码 0。

- [ ] **步骤 4：核查范围 diff**

运行：

```bash
git status --short
git diff --stat HEAD
git diff HEAD -- lib/features/home lib/core/router lib/core/widgets/movie_grid_view.dart test/features/home test/core/widgets/movie_grid_view_test.dart
```

预期：变更仅限首页 latest 服务/页面/Tab、路由常量与注册、首页入口、MovieGridView 空态，以及对应测试；无 `CommonListPage`、无新增依赖、无未计划改动。

- [ ] **步骤 5：复核仓库状态**

运行：

```bash
git status --short --branch
git log -5 --oneline --decorate
```

预期：工作区干净；本地 `master` 包含设计、计划、服务、空态、页面、路由提交；不推送。

---

## 自检

**1. 规格覆盖度：**
- 服务 `LatestMoviesService` + 48 分页 → Task 1 ✅
- `MovieGridView` 空态 → Task 2 ✅
- 页面 6 Tab + 每 Tab 独立状态 → Task 3 ✅
- 筛选/排序联动（filter=all 强制 release 禁用排序）→ Task 3 步骤 6 ✅
- 默认筛选（latest→can_play / magnets→magnets）→ Task 3 步骤 1/6 ✅
- 路由 + 首页入口 → Task 4 ✅
- 测试计划（服务/页面/空态/跳转）→ Task 1/2/3/4 ✅

**2. 占位符扫描：** 无「待定/TODO/适当处理」；每个代码步骤含完整代码块 ✅

**3. 类型一致性：**
- `LatestMoviesDataSource.getMovies(type/filterBy/sortBy/page)` 在 Task 1 服务、Task 3 页面/Tab、测试中签名一致 ✅
- `LatestMoviesPage(section/title/dataSource)` 在 Task 3 定义与 Task 4 路由构造一致 ✅
- `LatestTypeTab(type/defaultFilter/dataSource)` 在 Task 3 定义与页面构造一致 ✅
- `SortSelect.value`/`onChanged`、`SortSegmented` 用法与现有组件 API 一致 ✅
