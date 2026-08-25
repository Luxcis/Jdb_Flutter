import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';
import 'package:jade/features/categories/screens/categories_screen.dart';
import 'package:jade/features/categories/services/category_service.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';
import 'package:jade/features/categories/widgets/category_filter_sheet.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';

final class _MemoryFollowingStore implements FollowingTagsStore {
  List<FollowTagItem> stored = [];
  @override
  Future<void> clear() async => stored = [];
  @override
  Future<List<FollowTagItem>> load() async => stored;
  @override
  Future<void> save(List<FollowTagItem> tags) async => stored = List.of(tags);
}

FollowingTagsProvider _followingProvider() => FollowingTagsProvider(
  store: _MemoryFollowingStore(),
  dataSource: const UnavailableFollowingTagsDataSource(),
);

/// 记录 follow 调用的假数据源，用于断言关注时拼接的 name/value。
final class _RecordingFollowingSource implements FollowingTagsDataSource {
  String? lastName;
  String? lastValue;

  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async {
    lastName = name;
    lastValue = value;
    return FollowTagItem(id: 'new', name: name, value: value);
  }

  @override
  Future<void> unfollow(String id) async {}

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
}

class _MovieFilterRequest {
  const _MovieFilterRequest({
    required this.type,
    required this.filterBy,
    required this.sort,
    required this.orderBy,
    required this.page,
  });

  final int type;
  final String filterBy;
  final CategorySort sort;
  final String orderBy;
  final int page;
}

class _FakeSource implements CategoryDataSource {
  _FakeSource({this.hasMultiplePages = false});

  final bool hasMultiplePages;
  final tagTypes = <int>[];
  final movieRequests = <_MovieFilterRequest>[];
  Completer<List<CategoryTagGroup>>? pendingTags;
  List<CategoryTagGroup> tagsResult = _groups;
  var tagFailuresRemaining = 0;

  List<String> get movieFilters =>
      movieRequests.map((request) => request.filterBy).toList(growable: false);

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async {
    tagTypes.add(type);
    if (tagFailuresRemaining > 0) {
      tagFailuresRemaining--;
      throw StateError('标签加载失败');
    }
    final pending = pendingTags;
    if (pending != null) return pending.future;
    return tagsResult;
  }

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<CategoryFilterGroupOrder> groupOrder,
    int page = 1,
  }) async {
    movieRequests.add(
      _MovieFilterRequest(
        type: type,
        filterBy: filter.toFilterBy(type, groupOrder),
        sort: filter.sort,
        orderBy: filter.orderBy,
        page: page,
      ),
    );
    if (hasMultiplePages) {
      final totalPages = type == 0 ? 2 : 1;
      final itemCount = type == 0 && page == 2 ? 12 : 24;
      return PagedResult(
        items: [
          for (var index = 0; index < itemCount; index++)
            MovieSummary(
              id: '$type-$page-$index',
              number: 'JDB-$type-$page-$index',
              title: '影片 $type-$page-$index',
              coverUrl: '',
            ),
        ],
        currentPage: page,
        totalPages: totalPages,
        total: type == 0 ? 36 : 24,
      );
    }
    return PagedResult(
      items: [
        MovieSummary(
          id: '$type-$page',
          number: 'JDB-$type',
          title: '影片 $type',
          coverUrl: 'http://example.test/$type.jpg',
        ),
      ],
      currentPage: 1,
      totalPages: 1,
      total: 1,
    );
  }
}

const _groups = <CategoryTagGroup>[
  CategoryTagGroup(
    category: '基本',
    categoryId: 'main',
    tags: [
      CategoryTagItem(id: 'p', name: '可播放', videosCount: 1),
      CategoryTagItem(id: 'm', name: '有磁链', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '题材',
    categoryId: 'subject',
    tags: [
      CategoryTagItem(id: '23', name: '剧情', videosCount: 1),
      CategoryTagItem(id: '51', name: '喜剧', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '年份',
    categoryId: 'year',
    tags: [
      CategoryTagItem(id: '2025', name: '2025', videosCount: 1),
      CategoryTagItem(id: '2024', name: '2024', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '时长',
    categoryId: 'duration',
    tags: [
      CategoryTagItem(id: '60', name: '60 分钟内', videosCount: 1),
      CategoryTagItem(id: '120', name: '120 分钟内', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '月份',
    categoryId: 'month',
    tags: [
      CategoryTagItem(id: '01', name: '一月', videosCount: 1),
      CategoryTagItem(id: '02', name: '二月', videosCount: 1),
    ],
  ),
];

Widget _sheet(CategoryTabController controller) => MaterialApp(
  home: Scaffold(body: CategoryFilterSheet(controller: controller)),
);

String _filterBy(CategoryTabController controller) =>
    controller.filter.toFilterBy(
      controller.type,
      controller.groups
          .map(
            (group) => (
              categoryId: group.categoryId,
              tagIds: group.tags.map((tag) => tag.id).toList(growable: false),
            ),
          )
          .toList(growable: false),
    );

Future<_FakeSource> _pumpCategories(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _FakeSource();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _followingProvider()),
      ],
      child: MaterialApp(home: CategoriesPage(dataSource: source)),
    ),
  );
  await tester.pump();
  await tester.pump();
  return source;
}

Future<void> _pumpPageTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

/// 用可记录 follow 调用的数据源 pump 类别页，返回分类源与记录源。
Future<({_FakeSource category, _RecordingFollowingSource following})>
_pumpCategoriesWithSource(
  WidgetTester tester, {
  required _RecordingFollowingSource dataSource,
}) async {
  final category = _FakeSource();
  final following = FollowingTagsProvider(
    store: _MemoryFollowingStore(),
    dataSource: dataSource,
  );
  await following.initialize();
  addTearDown(following.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: following)],
      child: MaterialApp(home: CategoriesPage(dataSource: category)),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (category: category, following: dataSource);
}

void main() {
  testWidgets('类别页顶部搜索按钮进入搜索页且位于筛选按钮右侧', (tester) async {
    final source = _FakeSource();
    final router = GoRouter(
      initialLocation: AppRoutes.categories,
      routes: [
        GoRoute(
          path: AppRoutes.categories,
          builder: (_, _) => CategoriesPage(dataSource: source),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (_, _) => const Scaffold(body: Text('搜索页')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _followingProvider()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('搜索')).dx,
      greaterThan(
        tester.getCenter(find.byKey(const Key('categories-filter-button'))).dx,
      ),
    );

    await tester.tap(find.byTooltip('搜索'));
    await _pumpPageTransition(tester);

    expect(router.state.uri.path, AppRoutes.search);
  });

  testWidgets('点击分类影片进入详情且返回后保留当前网格', (tester) async {
    final source = _FakeSource();
    final router = GoRouter(
      initialLocation: '/categories',
      routes: [
        GoRoute(
          path: '/categories',
          builder: (context, state) => CategoriesPage(dataSource: source),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (context, state) =>
              Scaffold(body: Text('详情 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _followingProvider()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(MovieCard).first);
    await _pumpPageTransition(tester);

    expect(router.state.uri.path, '/movie/0-1');
    expect(find.text('详情 0-1'), findsOneWidget);

    router.pop();
    await _pumpPageTransition(tester);

    expect(router.state.uri.path, '/categories');
    expect(find.byKey(const Key('category-tab-grid-0')), findsOneWidget);
  });

  testWidgets('首页为有码且首次 filter_by 为 0:t:m::::', (tester) async {
    final source = await _pumpCategories(tester);

    expect(source.movieFilters.first, '0:t:m::::');
    expect(source.tagTypes, [0]);
    expect(find.byType(MovieCard), findsWidgets);
    final grid = find.byKey(const Key('category-tab-grid-0'));
    expect(grid, findsOneWidget);
    expect(tester.widget<MovieGridView>(grid).crossAxisCount, 3);
  });

  testWidgets('筛选面板内容来自当前 Tab 标签接口且点击后保持打开', (tester) async {
    final source = await _pumpCategories(tester);

    await tester.tap(find.byKey(const Key('categories-filter-button')));
    await _pumpPageTransition(tester);

    expect(find.text('题材'), findsOneWidget);
    expect(source.tagTypes, [0]);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      closeTo(844 * 2 / 3, 1),
    );

    await tester.tap(find.byKey(const Key('category-filter-subject-23')));
    await tester.pump();

    expect(source.movieFilters.last, '0:t:m:23:::');
    expect(find.text('筛选'), findsOneWidget);
  });

  testWidgets('切换 Tab 使用 1:t::::: 且切回恢复有码选择', (tester) async {
    final source = await _pumpCategories(tester);

    await tester.tap(find.byKey(const Key('categories-filter-button')));
    await _pumpPageTransition(tester);
    await tester.tap(find.byKey(const Key('category-filter-main-p')));
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await _pumpPageTransition(tester);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    tabBar.controller!.animateTo(1);
    await _pumpPageTransition(tester);

    expect(source.movieFilters, contains('1:t:m::::'));
    expect(source.tagTypes, [0, 1]);
    expect(find.byKey(const Key('category-tab-grid-1')), findsOneWidget);

    tabBar.controller!.animateTo(0);
    await _pumpPageTransition(tester);
    expect(source.tagTypes, [0, 1]);
    await tester.tap(find.byKey(const Key('categories-filter-button')));
    await _pumpPageTransition(tester);

    final chip = tester.widget<FilterChip>(
      find.byKey(const Key('category-filter-main-p')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('Tab 0 的第二页和滚动位置在切换 Tab 后独立保留', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeSource(hasMultiplePages: true);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _followingProvider()),
        ],
        child: MaterialApp(home: CategoriesPage(dataSource: source)),
      ),
    );
    await tester.pump();
    await tester.pump();

    final tab0Grid = find.byKey(const Key('category-tab-grid-0'));
    final tab0ScrollView = find.descendant(
      of: tab0Grid,
      matching: find.byType(CustomScrollView),
    );
    final tab0Scrollable = tester.state<ScrollableState>(
      find.descendant(of: tab0Grid, matching: find.byType(Scrollable)),
    );
    final distanceToPrefetch = tab0Scrollable.position.maxScrollExtent - 200;
    await tester.drag(tab0ScrollView, Offset(0, -distanceToPrefetch));
    await tester.pump();
    await tester.pump();

    expect(
      source.movieRequests
          .where((request) => request.type == 0)
          .map((request) => request.page),
      [1, 2],
    );
    expect(
      tester.widget<MovieGridView>(tab0Grid).controller.items,
      hasLength(36),
    );
    final tab0Offset = tab0Scrollable.position.pixels;
    expect(tab0Offset, greaterThan(0));

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    tabBar.controller!.animateTo(1);
    await _pumpPageTransition(tester);

    final tab1Grid = find.byKey(const Key('category-tab-grid-1'));
    final tab1Scrollable = tester.state<ScrollableState>(
      find.descendant(of: tab1Grid, matching: find.byType(Scrollable)),
    );
    expect(
      source.movieRequests
          .where((request) => request.type == 1)
          .map((request) => request.page),
      [1],
    );
    expect(
      tester.widget<MovieGridView>(tab1Grid).controller.items,
      hasLength(24),
    );
    expect(tab1Scrollable.position.pixels, 0);

    tabBar.controller!.animateTo(0);
    await _pumpPageTransition(tester);

    final restoredScrollable = tester.state<ScrollableState>(
      find.descendant(of: tab0Grid, matching: find.byType(Scrollable)),
    );
    expect(
      tester.widget<MovieGridView>(tab0Grid).controller.items,
      hasLength(36),
    );
    expect(
      source.movieRequests
          .where((request) => request.type == 0)
          .map((request) => request.page),
      [1, 2],
    );
    expect(restoredScrollable.position.pixels, closeTo(tab0Offset, 0.1));
  });

  testWidgets('欧美 FC2 动漫首次请求分别映射 type 2 3 4', (tester) async {
    final source = await _pumpCategories(tester);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));

    for (final type in [2, 3, 4]) {
      tabBar.controller!.animateTo(type);
      await _pumpPageTransition(tester);

      final firstRequest = source.movieRequests.firstWhere(
        (request) => request.type == type,
      );
      expect(firstRequest.filterBy, '$type:t:m::::');
      expect(firstRequest.page, 1);
    }
  });

  testWidgets('动态标签以紧凑 Chip 渲染且点击立即更新筛选', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    expect(find.text('基本'), findsOneWidget);
    expect(find.text('题材'), findsOneWidget);
    expect(find.text('可播放'), findsOneWidget);
    expect(find.text('剧情'), findsOneWidget);
    expect(find.text('客户端固定分组'), findsNothing);

    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.visualDensity, VisualDensity.compact);
      expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(chip.showCheckmark, isFalse);
    }

    await tester.tap(find.byKey(const Key('category-filter-main-p')));
    await tester.pump();

    expect(source.movieFilters.last, '0:t:p::::');
    expect(find.text('筛选'), findsOneWidget);
  });

  testWidgets('固定段单选而动态题材保持多选', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    await tester.tap(find.byKey(const Key('category-filter-main-p')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-filter-main-m')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-filter-subject-51')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-filter-subject-23')));
    await tester.pump();

    expect(source.movieFilters.last, '0:t:m:23,51:::');
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('category-filter-main-p')))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('category-filter-main-m')))
          .selected,
      isTrue,
    );
  });

  testWidgets('标签请求在途显示加载状态，完成后显示动态分组', (tester) async {
    final source = _FakeSource()
      ..pendingTags = Completer<List<CategoryTagGroup>>();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('category-filter-list')), findsNothing);

    source.pendingTags!.complete(_groups);
    await initialization;
    await tester.pump();

    expect(find.byKey(const Key('category-filter-group-main')), findsOneWidget);
  });

  testWidgets('标签失败显示重试，重试成功后恢复动态分组', (tester) async {
    final source = _FakeSource()..tagFailuresRemaining = 1;
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    await tester.pumpWidget(_sheet(controller));
    await tester.pump();
    await initialization;
    await tester.pump();

    final retry = find.text('筛选内容加载失败，点击重试');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-filter-group-main')), findsOneWidget);
    expect(find.text('可播放'), findsOneWidget);
  });

  testWidgets('成功空标签列表显示明确空状态', (tester) async {
    final source = _FakeSource()..tagsResult = const [];
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    expect(find.byKey(const Key('category-filter-empty')), findsOneWidget);
    expect(find.text('暂无筛选项'), findsOneWidget);
    expect(find.byKey(const Key('category-filter-list')), findsNothing);
  });

  testWidgets('year duration month 由模型保持单选和取消语义', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    final year2025 = find.byKey(const Key('category-filter-year-2025'));
    final year2024 = find.byKey(const Key('category-filter-year-2024'));
    await tester.tap(year2025);
    await tester.pump();
    expect(tester.widget<FilterChip>(year2025).selected, isTrue);
    expect(_filterBy(controller), '0:t:m::2025::');
    await tester.tap(year2024);
    await tester.pump();
    expect(tester.widget<FilterChip>(year2025).selected, isFalse);
    expect(tester.widget<FilterChip>(year2024).selected, isTrue);
    expect(_filterBy(controller), '0:t:m::2024::');
    await tester.tap(year2024);
    await tester.pump();
    expect(tester.widget<FilterChip>(year2024).selected, isFalse);
    expect(_filterBy(controller), '0:t:m::::');

    final list = find.byKey(const Key('category-filter-list'));
    final duration60 = find.byKey(const Key('category-filter-duration-60'));
    final duration120 = find.byKey(const Key('category-filter-duration-120'));
    await tester.scrollUntilVisible(
      duration60,
      250,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.tap(duration60);
    await tester.pump();
    expect(tester.widget<FilterChip>(duration60).selected, isTrue);
    expect(_filterBy(controller), '0:t:m:::60:');
    await tester.tap(duration120);
    await tester.pump();
    expect(tester.widget<FilterChip>(duration60).selected, isFalse);
    expect(tester.widget<FilterChip>(duration120).selected, isTrue);
    expect(_filterBy(controller), '0:t:m:::120:');
    await tester.tap(duration120);
    await tester.pump();
    expect(tester.widget<FilterChip>(duration120).selected, isFalse);
    expect(_filterBy(controller), '0:t:m::::');

    final month01 = find.byKey(const Key('category-filter-month-01'));
    final month02 = find.byKey(const Key('category-filter-month-02'));
    await tester.scrollUntilVisible(
      month01,
      250,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.tap(month01);
    await tester.pump();
    expect(tester.widget<FilterChip>(month01).selected, isTrue);
    expect(_filterBy(controller), '0:t:m::::01');
    await tester.tap(month02);
    await tester.pump();
    expect(tester.widget<FilterChip>(month01).selected, isFalse);
    expect(tester.widget<FilterChip>(month02).selected, isTrue);
    expect(_filterBy(controller), '0:t:m::::02');
    await tester.tap(month02);
    await tester.pump();
    expect(tester.widget<FilterChip>(month02).selected, isFalse);
    expect(_filterBy(controller), '0:t:m::::');
  });

  testWidgets('排序菜单和发布日期升降序可即时触达', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    await tester.tap(find.byKey(const Key('category-order-toggle')));
    await tester.pump();

    expect(controller.filter.orderBy, 'asc');
    expect(source.movieRequests.last.orderBy, 'asc');

    await tester.tap(find.byKey(const Key('category-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评分').last);
    await tester.pump();

    expect(controller.filter.sort, CategorySort.score);
    expect(source.movieRequests.last.sort, CategorySort.score);
    expect(find.byKey(const Key('category-order-toggle')), findsNothing);

    await tester.tap(find.byKey(const Key('category-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布日期').last);
    await tester.pump();

    expect(find.byKey(const Key('category-order-toggle')), findsOneWidget);
  });

  testWidgets('关注时 name 以当前 Tab 名称开头并拼接已选标签名', (tester) async {
    final subject = await _pumpCategoriesWithSource(
      tester,
      dataSource: _RecordingFollowingSource(),
    );
    final recording = subject.following;

    // 打开筛选，选中「题材:剧情」，关注按钮启用。
    await tester.tap(find.byKey(const Key('categories-filter-button')));
    await _pumpPageTransition(tester);
    await tester.tap(find.byKey(const Key('category-filter-subject-23')));
    await tester.pump();
    // 关闭底部筛选面板，回到 AppBar 才能点到关注按钮。
    await tester.tapAt(const Offset(8, 8));
    await _pumpPageTransition(tester);

    // 点击关注按钮（未关注时显示 visibility 图标）。
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(recording.lastName, '有码,有磁链,剧情');
    // value 为 filter_by：type=0(tab有码), t, main='m', 标签 23，其余空。
    expect(recording.lastValue, '0:t:m:23:::');
  });

  testWidgets('窄屏大字体下动态长列表可滚动且不溢出', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: _sheet(controller),
      ),
    );
    await tester.pump();

    final list = find.byKey(const Key('category-filter-list'));
    final monthChip = find.byKey(const Key('category-filter-month-01'));
    expect(list, findsOneWidget);
    await tester.scrollUntilVisible(
      monthChip,
      250,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(monthChip, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
