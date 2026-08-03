# Search Movie Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 调整综合搜索结果页影片 Tab，使其支持三行筛选条件，并通过 `/api/v2/search` 按 48 条一页自动加载影片结果。

**Architecture:** 在搜索 feature 内新增不可变筛选模型与影片搜索数据源，集中负责参数映射和分页响应解析。结果页向影片 Tab 注入数据源，影片 Tab 使用现有 `PaginationController<MovieSummary>` 与 `MovieGridView`，筛选变化时通过 `reloadWith` 重新请求第一页并隔离旧响应。

**Tech Stack:** Flutter、Dart、Material 3、Dio `ApiClient`、Provider、`flutter_test`、项目内 `FakeAdapter`。

## Global Constraints

- 以 `docs/superpowers/specs/2026-08-03-search-movie-filters-design.md` 和用户补充的 `single` 映射为准。
- 固定调用 `GET /api/v2/search`，每次发送 `q/type/movie_type/movie_filter_by/movie_sort_by/page/limit`。
- `type` 固定为 `movie`，`limit` 固定为 `48`。
- 默认组合为 `all / all / relevance`。
- “单体”固定映射为 `movie_filter_by=single`。
- 仅调整影片 Tab，不改变其他六个搜索结果 Tab。
- 不新增第三方依赖，继续使用 `MovieGridView` 和 `PaginationController`。
- 新增界面文案直接硬编码中文，不使用 ARB。
- 所有生产代码修改必须先有能正确失败的测试。

---

### Task 1: 影片搜索筛选模型

**Files:**
- Create: `lib/features/search/models/search_movie_filter.dart`
- Create: `test/features/search/search_movie_filter_test.dart`

**Interfaces:**
- Produces: `SearchMovieType`、`SearchMovieAvailability`、`SearchMovieSort` enhanced enums，均提供 `label` 和 `value`。
- Produces: `SearchMovieFilter`，包含 `type`、`availability`、`sort`，默认值为 `all / all / relevance`，并提供 `copyWith`。

- [ ] **Step 1: 写筛选值映射失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';

void main() {
  test('影片搜索筛选提供完整标签与接口值映射', () {
    expect(
      SearchMovieType.values.map((value) => (value.label, value.value)),
      [
        ('全部', 'all'),
        ('有码', '0'),
        ('无码', '1'),
        ('欧美', '2'),
        ('FC2', '3'),
        ('动漫', '4'),
      ],
    );
    expect(
      SearchMovieAvailability.values.map(
        (value) => (value.label, value.value),
      ),
      [
        ('全部', 'all'),
        ('可播放', 'can_play'),
        ('含磁链', 'magnets'),
        ('字幕', 'subtitle'),
        ('单体', 'single'),
      ],
    );
    expect(
      SearchMovieSort.values.map((value) => (value.label, value.value)),
      [
        ('相关度', 'relevance'),
        ('发布时间', 'release'),
        ('更新时间', 'update'),
        ('评分', 'score'),
      ],
    );
  });

  test('默认筛选组合及 copyWith 保持不可变语义', () {
    const original = SearchMovieFilter();
    final changed = original.copyWith(
      availability: SearchMovieAvailability.single,
    );

    expect(original.type, SearchMovieType.all);
    expect(original.availability, SearchMovieAvailability.all);
    expect(original.sort, SearchMovieSort.relevance);
    expect(changed.availability, SearchMovieAvailability.single);
    expect(changed.type, original.type);
    expect(changed.sort, original.sort);
  });
}
```

- [ ] **Step 2: 运行测试并确认因模型不存在而失败**

Run: `flutter test test/features/search/search_movie_filter_test.dart`

Expected: FAIL，提示 `search_movie_filter.dart` 或筛选类型未定义。

- [ ] **Step 3: 实现筛选模型**

```dart
enum SearchMovieType {
  all('全部', 'all'),
  censored('有码', '0'),
  uncensored('无码', '1'),
  western('欧美', '2'),
  fc2('FC2', '3'),
  carton('动漫', '4');

  const SearchMovieType(this.label, this.value);
  final String label;
  final String value;
}

enum SearchMovieAvailability {
  all('全部', 'all'),
  canPlay('可播放', 'can_play'),
  magnets('含磁链', 'magnets'),
  subtitle('字幕', 'subtitle'),
  single('单体', 'single');

  const SearchMovieAvailability(this.label, this.value);
  final String label;
  final String value;
}

enum SearchMovieSort {
  relevance('相关度', 'relevance'),
  release('发布时间', 'release'),
  update('更新时间', 'update'),
  score('评分', 'score');

  const SearchMovieSort(this.label, this.value);
  final String label;
  final String value;
}

class SearchMovieFilter {
  const SearchMovieFilter({
    this.type = SearchMovieType.all,
    this.availability = SearchMovieAvailability.all,
    this.sort = SearchMovieSort.relevance,
  });

  final SearchMovieType type;
  final SearchMovieAvailability availability;
  final SearchMovieSort sort;

  SearchMovieFilter copyWith({
    SearchMovieType? type,
    SearchMovieAvailability? availability,
    SearchMovieSort? sort,
  }) => SearchMovieFilter(
    type: type ?? this.type,
    availability: availability ?? this.availability,
    sort: sort ?? this.sort,
  );
}
```

- [ ] **Step 4: 格式化并运行模型测试**

Run: `dart format lib/features/search/models/search_movie_filter.dart test/features/search/search_movie_filter_test.dart`

Run: `flutter test test/features/search/search_movie_filter_test.dart`

Expected: PASS，2 项测试通过。

- [ ] **Step 5: 提交筛选模型**

```bash
git add lib/features/search/models/search_movie_filter.dart test/features/search/search_movie_filter_test.dart
git commit -m "feat: model search movie filters"
```

### Task 2: 综合搜索影片数据源

**Files:**
- Create: `lib/features/search/services/search_movie_service.dart`
- Create: `test/features/search/search_movie_service_test.dart`

**Interfaces:**
- Consumes: `SearchMovieFilter` 及三个 enum 的 `.value`。
- Produces: `abstract interface class SearchMovieDataSource`，方法 `Future<PagedResult<MovieSummary>> getMovies({required String query, required SearchMovieFilter filter, int page = 1})`。
- Produces: `SearchMovieService(ApiClient api)`，实现完整请求参数与分页回退。
- Produces: `UnavailableSearchMovieDataSource`，在未初始化 API 时返回当前页空结果。

- [ ] **Step 1: 写完整请求参数和响应解析失败测试**

测试创建 `Dio`、`FakeAdapter` 和 `ApiClient`，为 `Endpoints.searchV2` 入队成功响应，然后调用：

```dart
final result = await service.getMovies(
  query: 'ABP-001',
  filter: const SearchMovieFilter(
    type: SearchMovieType.uncensored,
    availability: SearchMovieAvailability.single,
    sort: SearchMovieSort.score,
  ),
  page: 2,
);

expect(adapter.requests.single.queryParameters, {
  'q': 'ABP-001',
  'type': 'movie',
  'movie_type': '1',
  'movie_filter_by': 'single',
  'movie_sort_by': 'score',
  'page': 2,
  'limit': 48,
});
expect(result.currentPage, 2);
expect(result.totalPages, 4);
expect(result.total, 150);
expect(result.items.single.number, 'ABP-001');
```

响应 fixture 使用：

```dart
{
  'success': 1,
  'data': {
    'movies': [
      {'id': 'movie-1', 'number': 'ABP-001', 'cover_url': 'cover.jpg'},
    ],
    'current_page': 2,
    'total_pages': 4,
    'total_count': 150,
  },
}
```

- [ ] **Step 2: 写缺失 `total_pages` 的分页推断失败测试**

同一测试文件增加两个用例：返回 48 条时期待 `totalPages == 2`；返回 47 条时期待 `totalPages == 1`。两个用例均传 `page: 1`，并断言 `currentPage == 1`。

- [ ] **Step 3: 运行服务测试并确认因服务不存在而失败**

Run: `flutter test test/features/search/search_movie_service_test.dart`

Expected: FAIL，提示 `SearchMovieService` 或 `SearchMovieDataSource` 未定义。

- [ ] **Step 4: 实现数据源和请求解析**

```dart
abstract interface class SearchMovieDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  });
}

class SearchMovieService implements SearchMovieDataSource {
  SearchMovieService(this._api);

  static const pageSize = 48;
  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.searchV2,
      queryParameters: {
        'q': query,
        'type': 'movie',
        'movie_type': filter.type.value,
        'movie_filter_by': filter.availability.value,
        'movie_sort_by': filter.sort.value,
        'page': page,
        'limit': pageSize,
      },
    );
    final data = apiMap(response.data);
    final items = apiList(data, const ['movies'])
        .map(normalizeMovieSummaryJson)
        .map(MovieSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    final totalPages = data['total_pages'] == null
        ? currentPage + (items.length >= pageSize ? 1 : 0)
        : apiInt(data['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}

class UnavailableSearchMovieDataSource implements SearchMovieDataSource {
  const UnavailableSearchMovieDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
```

- [ ] **Step 5: 格式化并运行模型和服务测试**

Run: `dart format lib/features/search/services/search_movie_service.dart test/features/search/search_movie_service_test.dart`

Run: `flutter test test/features/search/search_movie_filter_test.dart test/features/search/search_movie_service_test.dart`

Expected: PASS，筛选映射、`single` 请求、影片解析和分页回退全部通过。

- [ ] **Step 6: 提交影片搜索服务**

```bash
git add lib/features/search/services/search_movie_service.dart test/features/search/search_movie_service_test.dart
git commit -m "feat: add search movie service"
```

### Task 3: 三行筛选控件与筛选刷新

**Files:**
- Create: `lib/features/search/widgets/search_movie_filter_bar.dart`
- Create: `test/features/search/search_movie_filter_bar_test.dart`
- Modify: `lib/features/search/screens/search_results_screen.dart:17-270`
- Modify: `test/features/search/search_screen_test.dart:173-240`

**Interfaces:**
- Consumes: `SearchMovieFilter` 和三个 enum。
- Produces: `SearchMovieFilterBar({required SearchMovieFilter value, required ValueChanged<SearchMovieFilter> onChanged})`。
- Extends: `SearchResultsPage` 增加可选参数 `SearchMovieDataSource? movieDataSource`。
- Changes: `_MovieSearchTab` 接收 `SearchMovieDataSource dataSource`，筛选变化时调用 `_controller.reloadWith(_fetchPage)`。

- [ ] **Step 1: 写筛选栏布局、默认选中和窄屏失败测试**

在 `search_movie_filter_bar_test.dart` 中以 320px 宽、`textScaler: TextScaler.linear(1.5)` 构建控件，并断言：

```dart
expect(find.text('类型'), findsOneWidget);
expect(find.text('筛选'), findsOneWidget);
expect(find.text('排序'), findsOneWidget);
for (final label in [
  '有码', '无码', '欧美', 'FC2', '动漫',
  '可播放', '含磁链', '字幕', '单体',
  '相关度', '发布时间', '更新时间', '评分',
]) {
  expect(find.text(label), findsOneWidget);
}
final selected = tester
    .widgetList<ChoiceChip>(find.byType(ChoiceChip))
    .where((chip) => chip.selected)
    .map((chip) => (chip.label as Text).data);
expect(selected, ['全部', '全部', '相关度']);
expect(tester.takeException(), isNull);
```

测试还断言所有 `ChoiceChip` 使用 `VisualDensity.compact`、`showCheckmark == false`，且每行右侧包含横向 `SingleChildScrollView`。

- [ ] **Step 2: 运行筛选栏测试并确认因控件不存在而失败**

Run: `flutter test test/features/search/search_movie_filter_bar_test.dart`

Expected: FAIL，提示 `SearchMovieFilterBar` 未定义。

- [ ] **Step 3: 实现三行紧凑筛选控件**

`SearchMovieFilterBar` 使用 `Column` 组合三个 `_FilterRow<T>`。每个 `_FilterRow` 左侧固定宽度标题，右侧为：

```dart
Expanded(
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      spacing: 6,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(labelOf(option)),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          ),
      ],
    ),
  ),
)
```

三个回调分别通过 `value.copyWith(type: ...)`、`copyWith(availability: ...)`、`copyWith(sort: ...)` 生成新值。控件内部在新值等于当前值时不调用 `onChanged`。

- [ ] **Step 4: 运行筛选栏测试确认通过**

Run: `dart format lib/features/search/widgets/search_movie_filter_bar.dart test/features/search/search_movie_filter_bar_test.dart`

Run: `flutter test test/features/search/search_movie_filter_bar_test.dart`

Expected: PASS，三行布局、全部标签、默认选中、紧凑样式和窄屏无溢出均通过。

- [ ] **Step 5: 写结果页数据源注入和筛选刷新失败测试**

在 `search_screen_test.dart` 增加 `_RecordingSearchMovieDataSource`，记录 `(query, filter, page)` 并返回空的 `PagedResult`。使用它构建：

```dart
SearchResultsPage(
  query: 'ABP-001',
  historyStore: store,
  movieDataSource: dataSource,
)
```

断言首次调用为默认值和 `page == 1`。依次点击“无码”“单体”“评分”，每次 `pumpAndSettle()` 后逐字段断言最后一次调用仍为第 1 页，且 `filter.type`、`filter.availability`、`filter.sort` 依次更新为：

```dart
const SearchMovieFilter(type: SearchMovieType.uncensored)
const SearchMovieFilter(
  type: SearchMovieType.uncensored,
  availability: SearchMovieAvailability.single,
)
const SearchMovieFilter(
  type: SearchMovieType.uncensored,
  availability: SearchMovieAvailability.single,
  sort: SearchMovieSort.score,
)
```

再次点击当前已选“评分”后，断言调用次数不增加。

同一步先增加“影片 Tab 滚动到底部自动加载下一页”测试：让数据源第 1 页返回足够填满滚动区域的 48 个 `MovieSummary`、`currentPage: 1`、`totalPages: 2`，第 2 页返回 1 个编号为 `PAGE2-001` 的影片。构建结果页后滚动 `CustomScrollView` 到接近底部：

```dart
await tester.fling(
  find.byType(CustomScrollView),
  const Offset(0, -3000),
  2000,
);
await tester.pumpAndSettle();

expect(dataSource.calls.map((call) => call.page), containsAllInOrder([1, 2]));
expect(find.text('PAGE2-001'), findsOneWidget);
```

- [ ] **Step 6: 运行结果页测试并确认因数据源参数或筛选栏缺失而失败**

Run: `flutter test test/features/search/search_screen_test.dart`

Expected: FAIL，提示 `movieDataSource` 参数不存在、找不到筛选标签，或搜索影片 Tab 尚未通过注入数据源自动加载第 2 页。

- [ ] **Step 7: 接入搜索服务和筛选刷新**

`SearchResultsPage` 增加 `movieDataSource`，默认解析为：

```dart
final movieDataSource = widget.movieDataSource ??
    (ApiClient.instanceOrNull case final api?
        ? SearchMovieService(api)
        : const UnavailableSearchMovieDataSource());
```

将 `_MovieSearchTab` 改为持有 `dataSource`、`query` 和当前 `SearchMovieFilter`。提取：

```dart
Future<PagedResult<MovieSummary>> _fetchPage(int page) =>
    widget.dataSource.getMovies(
      query: widget.query,
      filter: _filter,
      page: page,
    );

Future<void> _changeFilter(SearchMovieFilter value) async {
  if (value.type == _filter.type &&
      value.availability == _filter.availability &&
      value.sort == _filter.sort) {
    return;
  }
  setState(() => _filter = value);
  await _controller.reloadWith(_fetchPage);
}
```

影片 Tab 的 `build` 返回：

```dart
Column(
  children: [
    SearchMovieFilterBar(value: _filter, onChanged: _changeFilter),
    Expanded(child: MovieGridView(controller: _controller)),
  ],
)
```

移除 `_MovieSearchTab` 中原有的内联 `/api/v2/search` 请求解析，其他六个 Tab 保持不变，并在 `dispose` 中释放影片分页控制器。

- [ ] **Step 8: 格式化并运行搜索 UI 定向测试**

Run: `dart format lib/features/search/screens/search_results_screen.dart lib/features/search/widgets/search_movie_filter_bar.dart test/features/search/search_screen_test.dart test/features/search/search_movie_filter_bar_test.dart`

Run: `flutter test test/features/search/search_movie_filter_bar_test.dart test/features/search/search_screen_test.dart`

Expected: PASS，原有搜索结果页行为和新增筛选交互全部通过。

- [ ] **Step 9: 提交筛选 UI 和结果页接入**

```bash
git add lib/features/search/widgets/search_movie_filter_bar.dart lib/features/search/screens/search_results_screen.dart test/features/search/search_movie_filter_bar_test.dart test/features/search/search_screen_test.dart
git commit -m "feat: filter search movie results"
```

### Task 4: OpenAPI 契约同步与最终验证

**Files:**
- Modify: `docs/main/api/jdb_api_openapi.json`

**Interfaces:**
- Changes: OpenAPI `movie_filter_by` enum 增加 `single`，描述补充“单体”。

- [ ] **Step 1: 将 `single` 补入仓库 OpenAPI**

在 `/api/v2/search` 的 `movie_filter_by` 描述末尾增加 `single=单体`，并在 enum 的 `subtitle` 后增加 `single`。只修改该端点，不调整其他接口。

- [ ] **Step 2: 运行搜索模块完整测试**

Run: `dart format lib/features/search test/features/search`

Run: `flutter test test/features/search test/app_router_test.dart`

Expected: PASS，搜索历史、入口页、结果页、筛选服务、筛选 UI 和路由测试全部通过。

- [ ] **Step 3: 运行全量验证**

Run: `flutter test`

Expected: 所有测试通过，无失败。

Run: `flutter analyze`

Expected: `No issues found!`

Run: `git diff --check`

Expected: 无输出。

- [ ] **Step 4: 提交契约更新和最终实现**

```bash
git add docs/main/api/jdb_api_openapi.json docs/superpowers/plans/2026-08-03-search-movie-filters.md
git commit -m "docs: align search movie filters contract"
```

- [ ] **Step 5: 复核最终提交范围**

Run: `git status --short --branch`

Expected: 工作区无未提交文件；当前分支只领先本次已确认的设计、计划和实现提交，不包含意外修改。
