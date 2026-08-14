# Profile Want-Watch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现“我的－我想看的”真实影片列表，以六个类型 Tab、两组排序控件和 `MovieCard` 网格完成自动分页展示。

**Architecture:** 在 profile feature 内新增独立的接口服务、每 Tab 分页控制器和页面文件。页面共享排序状态，但每个 Tab 独立持有 `PaginationController<MovieSummary>`；`MovieGridView` 继续承担渲染、下拉刷新、接近底部预取和错误重试。

**Tech Stack:** Flutter、Dart、Provider 项目基础设施、Dio/`ApiClient`、`json_serializable` 现有模型、`flutter_test`、项目 `FakeAdapter`

## Global Constraints

- 本次只接管 `/profile/want-watch`；不实现或改变“我看过的”“近期浏览”。
- 接口固定为 `GET /api/v2/users/review_movies`，页面固定发送 `status=want_watch`。
- 类型映射固定为 `all/0/1/2/3/4`，对应“全部/有码/无码/欧美/FC2/动漫”。
- 排序字段固定为 `create/release`，方向固定为 `desc/asc`，默认 `create + desc`。
- 分页从 1 开始，`limit=24`；缺少 `total_pages` 时按 24 条满页推断下一页。
- 页面必须复用 `MovieGridView` 和 `MovieCard`，不得复制卡片或分页 UI。
- AppBar 不显示筛选按钮，页面不挂载 `FilterDrawer`。
- 所有用户文案按项目规则直接使用中文硬编码。
- 不新增依赖，不修改 `MovieCard` 公共行为，不主动发布或推送。

---

### Task 1: 已评价电影接口服务

**Files:**

- Create: `lib/features/profile/services/review_movies_service.dart`
- Create: `test/features/profile/review_movies_service_test.dart`
- Reuse: `lib/core/network/endpoints.dart`
- Reuse: `lib/core/network/api_data.dart`

**Interfaces:**

- Consumes: `ApiClient.get`、`Endpoints.usersReviewMoviesV2`、`apiPageResult`、`normalizeMovieSummaryJson`、`MovieSummary.fromJson`
- Produces:

```dart
abstract interface class ReviewMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  });
}

class ReviewMoviesService implements ReviewMoviesDataSource {
  ReviewMoviesService(ApiClient api);
}

class UnavailableReviewMoviesDataSource implements ReviewMoviesDataSource {
  const UnavailableReviewMoviesDataSource();
}
```

- [ ] **Step 1: Write the failing service contract tests**

Create `test/features/profile/review_movies_service_test.dart` with a real test `ApiClient`, `ResponseInterceptor`, and `FakeAdapter`. Cover the exact query and response rules:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('我想看的首屏完整发送状态 类型 排序和 24 条分页参数', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersReviewMoviesV2, {
      'success': 1,
      'data': {'movies': [], 'current_page': 1},
    });

    await fixture.service.getMovies(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
    );

    expect(fixture.adapter.requests.single.queryParameters, {
      'status': 'want_watch',
      'type': 'all',
      'sort_by': 'create',
      'order_by': 'desc',
      'page': 1,
      'limit': 24,
    });
  });

  test('解析 movies 与 current_page 并保留影片摘要字段', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersReviewMoviesV2, {
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
      status: 'want_watch',
      type: '1',
      sortBy: 'release',
      orderBy: 'asc',
      page: 2,
    );

    expect(result.items.single.id, 'm1');
    expect(result.items.single.thumbUrl, 'thumb.jpg');
    expect(result.items.single.score, 4.5);
    expect(result.currentPage, 2);
    expect(result.totalPages, 3);
    expect(result.total, 49);
  });

  test('缺少 total_pages 时以 24 条为满页阈值', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueueSequence(Endpoints.usersReviewMoviesV2, [
      {
        'success': 1,
        'data': {
          'movies': [
            for (var index = 0; index < 24; index++)
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
            {'id': 'm24', 'number': 'N24', 'title': '影片 24', 'cover_url': ''},
          ],
          'current_page': 2,
        },
      },
    ]);

    final fullPage = await fixture.service.getMovies(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
    );
    final partialPage = await fixture.service.getMovies(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
      page: 2,
    );

    expect(fullPage.totalPages, 2);
    expect(partialPage.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, ReviewMoviesService service})>
_buildFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: ReviewMoviesService(api));
}
```

- [ ] **Step 2: Run the service tests and confirm the expected red state**

Run:

```bash
flutter test test/features/profile/review_movies_service_test.dart
```

Expected: compilation fails because `review_movies_service.dart` and `ReviewMoviesService` do not exist.

- [ ] **Step 3: Implement the minimal service**

Create `lib/features/profile/services/review_movies_service.dart`:

```dart
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class ReviewMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  });
}

class ReviewMoviesService implements ReviewMoviesDataSource {
  ReviewMoviesService(this._api);

  static const _pageSize = 24;

  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.usersReviewMoviesV2,
      queryParameters: {
        'status': status,
        'type': type,
        'sort_by': sortBy,
        'order_by': orderBy,
        'page': page,
        'limit': _pageSize,
      },
    );
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) =>
          MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}

class UnavailableReviewMoviesDataSource implements ReviewMoviesDataSource {
  const UnavailableReviewMoviesDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
```

- [ ] **Step 4: Format and rerun the focused service tests**

Run:

```bash
dart format lib/features/profile/services/review_movies_service.dart test/features/profile/review_movies_service_test.dart
flutter test test/features/profile/review_movies_service_test.dart
```

Expected: all service tests pass.

- [ ] **Step 5: Commit the service contract**

```bash
git add lib/features/profile/services/review_movies_service.dart test/features/profile/review_movies_service_test.dart
git commit -m "feat(profile): add review movies service"
```

---

### Task 2: 每 Tab 独立分页与排序控制器

**Files:**

- Create: `lib/features/profile/services/review_movies_tab_controller.dart`
- Create: `test/features/profile/review_movies_tab_controller_test.dart`

**Interfaces:**

- Consumes: `ReviewMoviesDataSource.getMovies`、`PaginationController<MovieSummary>`
- Produces:

```dart
class ReviewMoviesTabController {
  ReviewMoviesTabController({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    required ReviewMoviesDataSource source,
  });

  final String type;
  final PaginationController<MovieSummary> movies;

  Future<void> initialize();

  Future<void> changeSorting({
    required String sortBy,
    required String orderBy,
  });

  void dispose();
}
```

- [ ] **Step 1: Write the failing controller tests**

Create `test/features/profile/review_movies_tab_controller_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';
import 'package:jade/features/profile/services/review_movies_tab_controller.dart';

typedef _Request = ({
  String status,
  String type,
  String sortBy,
  String orderBy,
  int page,
});

class _RecordingSource implements ReviewMoviesDataSource {
  final requests = <_Request>[];
  Completer<PagedResult<MovieSummary>>? pending;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) {
    requests.add((
      status: status,
      type: type,
      sortBy: sortBy,
      orderBy: orderBy,
      page: page,
    ));
    final currentPending = pending;
    if (currentPending != null) return currentPending.future;
    return Future.value(
      PagedResult(
        items: [
          MovieSummary(
            id: '$type-$page',
            number: 'N-$type-$page',
            title: '影片 $type-$page',
            coverUrl: '',
          ),
        ],
        currentPage: page,
        totalPages: page,
        total: 1,
      ),
    );
  }
}

void main() {
  test('initialize 只触发一次当前类型首屏请求', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);

    await Future.wait([controller.initialize(), controller.initialize()]);

    expect(source.requests, [
      (
        status: 'want_watch',
        type: 'all',
        sortBy: 'create',
        orderBy: 'desc',
        page: 1,
      ),
    ]);
  });

  test('未初始化 Tab 仅更新排序 首次访问才请求', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: '1',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);

    await controller.changeSorting(sortBy: 'release', orderBy: 'asc');
    expect(source.requests, isEmpty);

    await controller.initialize();
    expect(source.requests.single.sortBy, 'release');
    expect(source.requests.single.orderBy, 'asc');
  });

  test('已初始化 Tab 排序变化时保留旧影片并从第一页替换', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: '0',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final oldMovie = controller.movies.items.single;

    source.pending = Completer<PagedResult<MovieSummary>>();
    final refresh = controller.changeSorting(
      sortBy: 'release',
      orderBy: 'desc',
    );

    expect(controller.movies.items.single, same(oldMovie));
    expect(controller.movies.isRefreshing, isTrue);
    expect(source.requests.last.page, 1);
    source.pending!.complete(
      const PagedResult(
        items: [
          MovieSummary(
            id: 'new',
            number: 'NEW-1',
            title: '新排序影片',
            coverUrl: '',
          ),
        ],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await refresh;

    expect(controller.movies.items.single.id, 'new');
  });

  test('快速连续切换排序时过期响应不能覆盖最终选择', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final stalePage = Completer<PagedResult<MovieSummary>>();
    source.pending = stalePage;
    final staleRefresh = controller.changeSorting(
      sortBy: 'release',
      orderBy: 'desc',
    );

    final currentPage = Completer<PagedResult<MovieSummary>>();
    source.pending = currentPage;
    final currentRefresh = controller.changeSorting(
      sortBy: 'release',
      orderBy: 'asc',
    );
    currentPage.complete(
      const PagedResult(
        items: [
          MovieSummary(
            id: 'current',
            number: 'CURRENT-1',
            title: '最终排序影片',
            coverUrl: '',
          ),
        ],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await currentRefresh;

    stalePage.complete(
      const PagedResult(
        items: [
          MovieSummary(
            id: 'stale',
            number: 'STALE-1',
            title: '过期排序影片',
            coverUrl: '',
          ),
        ],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await staleRefresh;

    expect(controller.movies.items.single.id, 'current');
  });
}
```

- [ ] **Step 2: Run the controller tests and confirm the expected red state**

Run:

```bash
flutter test test/features/profile/review_movies_tab_controller_test.dart
```

Expected: compilation fails because `ReviewMoviesTabController` does not exist.

- [ ] **Step 3: Implement the controller**

Create `lib/features/profile/services/review_movies_tab_controller.dart`:

```dart
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';

class ReviewMoviesTabController {
  ReviewMoviesTabController({
    required this.status,
    required this.type,
    required String sortBy,
    required String orderBy,
    required ReviewMoviesDataSource source,
  }) : _sortBy = sortBy,
       _orderBy = orderBy,
       _source = source {
    movies = PaginationController<MovieSummary>(fetch: _fetchPage);
  }

  final String status;
  final String type;
  final ReviewMoviesDataSource _source;
  late final PaginationController<MovieSummary> movies;

  String _sortBy;
  String _orderBy;
  bool _initialized = false;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    _initialized = true;
    return movies.fetchMore();
  }

  Future<void> changeSorting({
    required String sortBy,
    required String orderBy,
  }) {
    if (_sortBy == sortBy && _orderBy == orderBy) return Future.value();
    _sortBy = sortBy;
    _orderBy = orderBy;
    if (!_initialized) return Future.value();
    return movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _source.getMovies(
    status: status,
    type: type,
    sortBy: _sortBy,
    orderBy: _orderBy,
    page: page,
  );

  void dispose() => movies.dispose();
}
```

- [ ] **Step 4: Format and run service plus controller tests**

Run:

```bash
dart format lib/features/profile/services/review_movies_tab_controller.dart test/features/profile/review_movies_tab_controller_test.dart
flutter test test/features/profile/review_movies_service_test.dart test/features/profile/review_movies_tab_controller_test.dart
```

Expected: both test files pass.

- [ ] **Step 5: Commit the per-Tab state controller**

```bash
git add lib/features/profile/services/review_movies_tab_controller.dart test/features/profile/review_movies_tab_controller_test.dart
git commit -m "feat(profile): add review movies tab state"
```

---

### Task 3: “我想看的”页面、排序和独立 Tab 网格

**Files:**

- Create: `lib/features/profile/screens/profile_review_movies_page.dart`
- Create: `test/features/profile/profile_review_movies_page_test.dart`

**Interfaces:**

- Consumes: `ReviewMoviesDataSource`、`ReviewMoviesTabController`、`SortSegmented<String>`、`MovieGridView`
- Produces:

```dart
class ProfileReviewMoviesPage extends StatefulWidget {
  const ProfileReviewMoviesPage({
    super.key,
    required this.title,
    required this.status,
    this.dataSource,
  });

  final String title;
  final String status;
  final ReviewMoviesDataSource? dataSource;
}
```

- [ ] **Step 1: Write the failing page structure and initial request test**

Create a recording fake in `test/features/profile/profile_review_movies_page_test.dart` and assert the approved UI contract:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/profile/screens/profile_review_movies_page.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';

typedef _Request = ({
  String status,
  String type,
  String sortBy,
  String orderBy,
  int page,
});

class _RecordingSource implements ReviewMoviesDataSource {
  _RecordingSource({this.multiplePages = false});

  final bool multiplePages;
  final requests = <_Request>[];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) async {
    requests.add((
      status: status,
      type: type,
      sortBy: sortBy,
      orderBy: orderBy,
      page: page,
    ));
    final itemCount = multiplePages ? (page == 1 ? 24 : 12) : 1;
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
      total: multiplePages ? 36 : 1,
    );
  }
}

Future<_RecordingSource> _pumpPage(
  WidgetTester tester, {
  bool multiplePages = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _RecordingSource(multiplePages: multiplePages);
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileReviewMoviesPage(
        title: '我想看的',
        status: 'want_watch',
        dataSource: source,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return source;
}

void main() {
  testWidgets('显示六个 Tab 两组默认排序和 MovieCard 且无筛选入口', (tester) async {
    final source = await _pumpPage(tester);

    expect(find.text('我想看的'), findsOneWidget);
    for (final label in ['全部', '有码', '无码', '欧美', 'FC2', '动漫']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.filter_list), findsNothing);
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    expect(find.byType(FilterDrawer), findsNothing);
    expect(find.byType(SortSegmented<String>), findsNWidgets(2));
    expect(
      tester
          .widget<SortSegmented<String>>(
            find.byKey(const Key('profile-review-movies-sort')),
          )
          .value,
      'create',
    );
    expect(
      tester
          .widget<SortSegmented<String>>(
            find.byKey(const Key('profile-review-movies-order')),
          )
          .value,
      'desc',
    );
    expect(find.byType(MovieGridView), findsOneWidget);
    expect(find.byType(MovieCard), findsOneWidget);
    expect(source.requests.single, (
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
      page: 1,
    ));
  });
}
```

- [ ] **Step 2: Run the page test and confirm the expected red state**

Run:

```bash
flutter test test/features/profile/profile_review_movies_page_test.dart
```

Expected: compilation fails because `ProfileReviewMoviesPage` does not exist.

- [ ] **Step 3: Implement the page shell, sorting controls, and lazy Tab children**

Create `lib/features/profile/screens/profile_review_movies_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';
import 'package:jade/features/profile/services/review_movies_tab_controller.dart';

typedef _MovieTypeTab = ({String label, String value});

class ProfileReviewMoviesPage extends StatefulWidget {
  const ProfileReviewMoviesPage({
    super.key,
    required this.title,
    required this.status,
    this.dataSource,
  });

  final String title;
  final String status;
  final ReviewMoviesDataSource? dataSource;

  @override
  State<ProfileReviewMoviesPage> createState() =>
      _ProfileReviewMoviesPageState();
}

class _ProfileReviewMoviesPageState extends State<ProfileReviewMoviesPage>
    with TickerProviderStateMixin {
  static const _tabs = <_MovieTypeTab>[
    (label: '全部', value: 'all'),
    (label: '有码', value: '0'),
    (label: '无码', value: '1'),
    (label: '欧美', value: '2'),
    (label: 'FC2', value: '3'),
    (label: '动漫', value: '4'),
  ];
  static const _sortOptions = [
    (label: '添加时间', value: 'create'),
    (label: '发行时间', value: 'release'),
  ];
  static const _orderOptions = [
    (label: '倒序', value: 'desc'),
    (label: '正序', value: 'asc'),
  ];

  late final TabController _tabController;
  late final ReviewMoviesDataSource _dataSource;
  late final List<ReviewMoviesTabController> _controllers;
  var _sortBy = 'create';
  var _orderBy = 'desc';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableReviewMoviesDataSource()
            : ReviewMoviesService(api));
    _controllers = [
      for (final tab in _tabs)
        ReviewMoviesTabController(
          status: widget.status,
          type: tab.value,
          sortBy: _sortBy,
          orderBy: _orderBy,
          source: _dataSource,
        ),
    ];
  }

  void _changeSortBy(String value) {
    if (value == _sortBy) return;
    setState(() => _sortBy = value);
    _reloadInitializedTabs();
  }

  void _changeOrderBy(String value) {
    if (value == _orderBy) return;
    setState(() => _orderBy = value);
    _reloadInitializedTabs();
  }

  void _reloadInitializedTabs() {
    for (final controller in _controllers) {
      unawaited(
        controller.changeSorting(sortBy: _sortBy, orderBy: _orderBy),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SortSegmented<String>(
              key: const Key('profile-review-movies-sort'),
              compact: true,
              expanded: true,
              options: _sortOptions,
              value: _sortBy,
              onChanged: _changeSortBy,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SortSegmented<String>(
              key: const Key('profile-review-movies-order'),
              compact: true,
              expanded: true,
              options: _orderOptions,
              value: _orderBy,
              onChanged: _changeOrderBy,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (var index = 0; index < _tabs.length; index++)
                  _ReviewMoviesTab(
                    key: PageStorageKey<String>(_tabs[index].value),
                    controller: _controllers[index],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMoviesTab extends StatefulWidget {
  const _ReviewMoviesTab({super.key, required this.controller});

  final ReviewMoviesTabController controller;

  @override
  State<_ReviewMoviesTab> createState() => _ReviewMoviesTabState();
}

class _ReviewMoviesTabState extends State<_ReviewMoviesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MovieGridView(
      key: Key('profile-review-movies-grid-${widget.controller.type}'),
      controller: widget.controller.movies,
    );
  }
}
```

- [ ] **Step 4: Add Tab mapping, sorting, paging, and retained-state tests**

Append these test cases to `test/features/profile/profile_review_movies_page_test.dart`:

```dart
testWidgets('切换无码 Tab 首次请求 type 1 且切回不重复首屏请求', (tester) async {
  final source = await _pumpPage(tester);
  final tabBar = tester.widget<TabBar>(find.byType(TabBar));

  tabBar.controller!.animateTo(2);
  await tester.pumpAndSettle();
  expect(
    source.requests.where((request) => request.type == '1').map((request) => request.page),
    [1],
  );

  tabBar.controller!.animateTo(0);
  await tester.pumpAndSettle();
  expect(
    source.requests.where((request) => request.type == 'all').map((request) => request.page),
    [1],
  );
});

testWidgets('排序字段和方向变化均从第一页刷新已访问 Tab', (tester) async {
  final source = await _pumpPage(tester);

  await tester.tap(find.text('发行时间'));
  await tester.pump();
  await tester.pump();
  expect(source.requests.last.sortBy, 'release');
  expect(source.requests.last.orderBy, 'desc');
  expect(source.requests.last.page, 1);

  await tester.tap(find.text('正序'));
  await tester.pump();
  await tester.pump();
  expect(source.requests.last.sortBy, 'release');
  expect(source.requests.last.orderBy, 'asc');
  expect(source.requests.last.page, 1);
});

testWidgets('滚动接近底部自动请求第二页并追加影片', (tester) async {
  final source = await _pumpPage(tester, multiplePages: true);
  final grid = find.byKey(const Key('profile-review-movies-grid-all'));
  final scrollView = find.descendant(
    of: grid,
    matching: find.byType(CustomScrollView),
  );
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: grid, matching: find.byType(Scrollable)),
  );

  await tester.drag(
    scrollView,
    Offset(0, -(scrollable.position.maxScrollExtent - 200)),
  );
  await tester.pump();
  await tester.pump();

  expect(
    source.requests.where((request) => request.type == 'all').map((request) => request.page),
    [1, 2],
  );
  expect(tester.widget<MovieGridView>(grid).controller.items, hasLength(36));
});
```

After formatting, wrap long predicates according to `dart format`; do not weaken the assertions.

- [ ] **Step 5: Run the page, controller, and shared grid regressions**

Run:

```bash
dart format lib/features/profile/screens/profile_review_movies_page.dart test/features/profile/profile_review_movies_page_test.dart
flutter test test/features/profile/profile_review_movies_page_test.dart test/features/profile/review_movies_tab_controller_test.dart test/core/widgets/movie_grid_view_test.dart test/core/widgets/movie_card_test.dart test/core/widgets/pagination_controller_test.dart test/core/widgets/sort_segmented_test.dart
```

Expected: all tests pass with no layout exceptions at 390×844.

- [ ] **Step 6: Commit the page**

```bash
git add lib/features/profile/screens/profile_review_movies_page.dart test/features/profile/profile_review_movies_page_test.dart
git commit -m "feat(profile): build want-watch movie page"
```

---

### Task 4: 路由接入与完整验证

**Files:**

- Modify: `lib/features/profile/index.dart`
- Modify: `lib/core/router/app_router.dart:215`
- Modify: `test/core/router/app_router_requirements_test.dart`
- Verify: `lib/features/profile/screens/profile_sub_pages.dart`
- Verify: `test/features/profile/profile_sub_pages_test.dart`

**Interfaces:**

- Consumes: `ProfileReviewMoviesPage(title: '我想看的', status: 'want_watch')`
- Produces: `/profile/want-watch` 在原认证守卫内渲染真实页面；`/profile/watched` 和 `/profile/recent` 继续渲染 `ProfileMovieCollectionPage`

- [ ] **Step 1: Write the failing route ownership test**

Add the feature import and route assertion to `test/core/router/app_router_requirements_test.dart`:

```dart
import 'package:jade/features/profile/index.dart';

testWidgets('我想看的路由渲染真实评价影片页且不再使用占位集合页', (tester) async {
  await tester.pumpWidget(
    await _buildApp(initialLocation: '/profile/want-watch'),
  );
  await tester.pump();

  expect(find.byType(ProfileReviewMoviesPage), findsOneWidget);
  expect(find.byType(ProfileMovieCollectionPage), findsNothing);
  expect(find.text('我想看的'), findsOneWidget);
  expect(find.byIcon(Icons.filter_list), findsNothing);
});
```

- [ ] **Step 2: Run the route test and confirm the expected red state**

Run:

```bash
flutter test test/core/router/app_router_requirements_test.dart
```

Expected: the new assertion fails because `/profile/want-watch` still builds `ProfileMovieCollectionPage`.

- [ ] **Step 3: Export the page and switch only the want-watch route**

Add the export to `lib/features/profile/index.dart`:

```dart
export 'screens/profile_review_movies_page.dart';
export 'screens/profile_screen.dart';
export 'screens/profile_sub_pages.dart';
```

Replace only the want-watch child in `lib/core/router/app_router.dart`:

```dart
GoRoute(
  path: AppRoutes.profileWantWatch,
  builder: (c, s) => _AuthGuard(
    route: AppRoutes.profileWantWatch,
    child: const ProfileReviewMoviesPage(
      title: '我想看的',
      status: 'want_watch',
    ),
  ),
),
```

Do not change the `/profile/watched` or `/profile/recent` route blocks.

- [ ] **Step 4: Run route and profile regressions**

Run:

```bash
dart format lib/features/profile/index.dart lib/core/router/app_router.dart test/core/router/app_router_requirements_test.dart
flutter test test/core/router/app_router_requirements_test.dart test/core/router/app_router_auth_test.dart test/features/profile/profile_screen_test.dart test/features/profile/profile_sub_pages_test.dart test/features/profile/profile_review_movies_page_test.dart test/features/profile/review_movies_service_test.dart test/features/profile/review_movies_tab_controller_test.dart
```

Expected: all route, profile, service, controller, and page tests pass.

- [ ] **Step 5: Run the complete quality gate**

Run:

```bash
flutter test
flutter analyze
git diff --check
```

Expected:

- Full test suite passes.
- `flutter analyze` reports `No issues found!`.
- `git diff --check` exits with status 0.

If Flutter attempts to write outside the workspace and fails with an SDK cache permission error, record it as an environment failure and rerun with the approved Flutter command permission; do not describe an unexecuted check as passing.

- [ ] **Step 6: Inspect the final scoped diff**

Run:

```bash
git status --short
git diff --stat HEAD
git diff HEAD -- lib/features/profile lib/core/router/app_router.dart test/features/profile test/core/router/app_router_requirements_test.dart
```

Expected: the working diff contains only the profile export, want-watch route, and route test from Task 4; the plan, service, controller, page, and their tests are already contained in earlier scoped commits.

- [ ] **Step 7: Commit the route integration**

```bash
git add lib/features/profile/index.dart lib/core/router/app_router.dart test/core/router/app_router_requirements_test.dart
git commit -m "feat(profile): route want-watch movie collection"
```

- [ ] **Step 8: Recheck repository state after commits**

Run:

```bash
git status --short --branch
git log -5 --oneline --decorate
```

Expected: worktree is clean; local `master` contains the design, plan, service, controller, page, and route commits and is ahead of `origin/master`; no push is performed.
