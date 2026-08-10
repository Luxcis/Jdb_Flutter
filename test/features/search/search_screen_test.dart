import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/screens/search_results_screen.dart';
import 'package:jade/features/search/screens/search_screen.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _SearchMovieCall = ({String query, SearchMovieFilter filter, int page});

class _RecordingSearchMovieDataSource implements SearchMovieDataSource {
  _RecordingSearchMovieDataSource({this.hasSecondPage = false});

  final bool hasSecondPage;
  final calls = <_SearchMovieCall>[];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async {
    calls.add((query: query, filter: filter, page: page));
    if (!hasSecondPage) {
      return PagedResult(
        items: const [],
        currentPage: page,
        totalPages: page,
        total: 0,
      );
    }
    if (page == 1) {
      return PagedResult(
        items: [
          for (var index = 0; index < 48; index++)
            MovieSummary(
              id: 'page-1-$index',
              number: 'PAGE1-${index.toString().padLeft(3, '0')}',
              title: '第一页影片 $index',
              coverUrl: '',
            ),
        ],
        currentPage: 1,
        totalPages: 2,
        total: 49,
      );
    }
    return const PagedResult(
      items: [
        MovieSummary(
          id: 'page-2-1',
          number: 'PAGE2-001',
          title: '第二页影片',
          coverUrl: '',
        ),
      ],
      currentPage: 2,
      totalPages: 2,
      total: 49,
    );
  }
}

Future<SearchHistoryStore> _storeWithHistory(List<String> history) async {
  SharedPreferences.setMockInitialValues({
    if (history.isNotEmpty) StorageKeys.searchHistory: jsonEncode(history),
  });
  return SearchHistoryStore(await SharedPreferences.getInstance());
}

Future<void> _pumpSearchPage(
  WidgetTester tester, {
  required List<String> history,
  required List<String> recentKeywords,
}) async {
  final store = await _storeWithHistory(history);
  await tester.pumpWidget(
    MaterialApp(
      home: SearchPage(historyStore: store, recentKeywords: recentKeywords),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('按历史搜索和近期热搜顺序显示非空模块', (tester) async {
    await _pumpSearchPage(
      tester,
      history: const ['历史番号'],
      recentKeywords: const ['热门演员'],
    );

    expect(find.text('历史搜索'), findsOneWidget);
    expect(find.text('近期热搜'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('历史搜索')).dy,
      lessThan(tester.getTopLeft(find.text('近期热搜')).dy),
    );
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('模块标题大号加粗且清空按钮位于历史标题右侧', (tester) async {
    await _pumpSearchPage(
      tester,
      history: const ['历史番号'],
      recentKeywords: const ['热门演员'],
    );

    final title = tester.widget<Text>(find.text('历史搜索'));
    final theme = Theme.of(tester.element(find.byType(SearchPage)));
    expect(title.style?.fontWeight, FontWeight.bold);
    expect(title.style?.fontSize, theme.textTheme.titleLarge?.fontSize);
    expect(
      tester.getCenter(find.text('清空')).dx,
      greaterThan(tester.getCenter(find.text('历史搜索')).dx),
    );
  });

  testWidgets('历史和热词为空时隐藏两个模块', (tester) async {
    await _pumpSearchPage(tester, history: const [], recentKeywords: const []);

    expect(find.text('历史搜索'), findsNothing);
    expect(find.text('近期热搜'), findsNothing);
  });

  testWidgets('历史和热词使用紧凑可点击标签', (tester) async {
    await _pumpSearchPage(
      tester,
      history: const ['历史番号'],
      recentKeywords: const ['热门演员'],
    );

    final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
    expect(chips, hasLength(2));
    expect(
      chips.every((chip) => chip.visualDensity == VisualDensity.compact),
      isTrue,
    );
    expect(chips.every((chip) => chip.onPressed != null), isTrue);
  });

  testWidgets('清空历史后隐藏历史模块并删除缓存', (tester) async {
    final store = await _storeWithHistory(const ['历史番号']);
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(historyStore: store, recentKeywords: const ['热门演员']),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('清空'));
    await tester.pump();

    expect(find.text('历史搜索'), findsNothing);
    expect(find.text('近期热搜'), findsOneWidget);
    expect(store.load(), isEmpty);
  });

  testWidgets('提交搜索后保存历史并打开独立结果路由', (tester) async {
    final store = await _storeWithHistory(const []);
    final router = GoRouter(
      initialLocation: AppRoutes.search,
      routes: [
        GoRoute(
          path: AppRoutes.search,
          builder: (_, _) =>
              SearchPage(historyStore: store, recentKeywords: const ['热门演员']),
          routes: [
            GoRoute(
              path: 'results',
              builder: (_, state) =>
                  Scaffold(body: Text('结果 ${state.uri.queryParameters['q']}')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.enterText(find.byType(TextField), ' ABP-001 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/search/results?q=ABP-001');
    expect(find.text('结果 ABP-001'), findsOneWidget);
    expect(store.load().first, 'ABP-001');
  });

  testWidgets('点击近期热词后保存历史并打开结果路由', (tester) async {
    final store = await _storeWithHistory(const []);
    final router = GoRouter(
      initialLocation: AppRoutes.search,
      routes: [
        GoRoute(
          path: AppRoutes.search,
          builder: (_, _) =>
              SearchPage(historyStore: store, recentKeywords: const ['热门演员']),
          routes: [
            GoRoute(
              path: 'results',
              builder: (_, state) =>
                  Scaffold(body: Text('结果 ${state.uri.queryParameters['q']}')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.tap(find.text('热门演员'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.searchResults);
    expect(router.state.uri.queryParameters['q'], '热门演员');
    expect(store.load().first, '热门演员');
  });

  testWidgets('结果页显示七个搜索分类并预填当前关键词', (tester) async {
    final store = await _storeWithHistory(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultsPage(query: 'ABP-001', historyStore: store),
      ),
    );
    await tester.pump();

    expect(find.text('影片'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('系列'), findsOneWidget);
    expect(find.text('片商'), findsOneWidget);
    expect(find.text('导演'), findsOneWidget);
    expect(find.text('清单'), findsOneWidget);
    expect(find.text('番号'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'ABP-001',
    );
  });

  testWidgets('影片筛选变化从第一页刷新且重复点击当前选项不请求', (tester) async {
    final store = await _storeWithHistory(const []);
    final dataSource = _RecordingSearchMovieDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultsPage(
          query: 'ABP-001',
          historyStore: store,
          movieDataSource: dataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.calls, hasLength(1));
    expect(dataSource.calls.single.query, 'ABP-001');
    expect(dataSource.calls.single.page, 1);
    expect(dataSource.calls.single.filter.type, SearchMovieType.all);
    expect(
      dataSource.calls.single.filter.availability,
      SearchMovieAvailability.all,
    );
    expect(dataSource.calls.single.filter.sort, SearchMovieSort.relevance);

    await tester.tap(find.text('无码'));
    await tester.pumpAndSettle();
    expect(dataSource.calls.last.page, 1);
    expect(dataSource.calls.last.filter.type, SearchMovieType.uncensored);
    expect(
      dataSource.calls.last.filter.availability,
      SearchMovieAvailability.all,
    );
    expect(dataSource.calls.last.filter.sort, SearchMovieSort.relevance);

    await tester.tap(find.text('单体'));
    await tester.pumpAndSettle();
    expect(dataSource.calls.last.page, 1);
    expect(dataSource.calls.last.filter.type, SearchMovieType.uncensored);
    expect(
      dataSource.calls.last.filter.availability,
      SearchMovieAvailability.single,
    );
    expect(dataSource.calls.last.filter.sort, SearchMovieSort.relevance);

    await tester.tap(find.text('评分'));
    await tester.pumpAndSettle();
    expect(dataSource.calls.last.page, 1);
    expect(dataSource.calls.last.filter.type, SearchMovieType.uncensored);
    expect(
      dataSource.calls.last.filter.availability,
      SearchMovieAvailability.single,
    );
    expect(dataSource.calls.last.filter.sort, SearchMovieSort.score);

    final requestCount = dataSource.calls.length;
    await tester.tap(find.text('评分'));
    await tester.pumpAndSettle();
    expect(dataSource.calls, hasLength(requestCount));
  });

  testWidgets('影片 Tab 滚动到底部自动加载下一页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await _storeWithHistory(const []);
    final dataSource = _RecordingSearchMovieDataSource(hasSecondPage: true);
    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: SearchResultsPage(
            query: 'ABP-001',
            historyStore: store,
            movieDataSource: dataSource,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -3000),
      2000,
    );
    await tester.pumpAndSettle();

    expect(
      dataSource.calls.map((call) => call.page),
      containsAllInOrder([1, 2]),
    );
    expect(find.text('PAGE2-001'), findsOneWidget);
  });

  testWidgets('结果页重新搜索时替换当前路由', (tester) async {
    final store = await _storeWithHistory(const []);
    final router = GoRouter(
      initialLocation: AppRoutes.search,
      routes: [
        GoRoute(
          path: AppRoutes.search,
          builder: (_, _) =>
              SearchPage(historyStore: store, recentKeywords: const []),
          routes: [
            GoRoute(
              path: 'results',
              builder: (_, state) => SearchResultsPage(
                key: state.pageKey,
                query: state.uri.queryParameters['q']!,
                historyStore: store,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'first');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' second ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/search/results?q=second');
    expect(store.load().first, 'second');
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.search);
    final historyLabels = tester
        .widgetList<ActionChip>(find.byType(ActionChip))
        .map((chip) => (chip.label as Text).data)
        .toList();
    expect(historyLabels, contains('second'));
  });

  testWidgets('系列 Tab 自动分页并保留已加载状态', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeSearchEntityDataSource(
      seriesPages: {
        1: PagedResult(
          items: List.generate(
            48,
            (index) =>
                Series(id: 's$index', name: '系列$index', movieCount: index),
          ),
          currentPage: 1,
          totalPages: 2,
          total: 49,
        ),
        2: const PagedResult(
          items: [Series(id: 's48', name: '系列48', movieCount: 48)],
          currentPage: 2,
          totalPages: 2,
          total: 49,
        ),
      },
    );

    await _pumpSearchResults(tester, entityDataSource: source);
    await tester.tap(find.text('系列'));
    await tester.pumpAndSettle();

    expect(find.byType(EntityListTile), findsWidgets);
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 5000);
    await tester.pumpAndSettle();
    expect(source.seriesRequestedPages, [1, 2]);
    expect(find.text('系列48'), findsOneWidget);

    await tester.tap(find.text('片商'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('系列'));
    await tester.pumpAndSettle();
    expect(source.seriesRequestedPages, [1, 2]);
  });

  testWidgets('演员 Tab 使用演员卡片并进入演员详情', (tester) async {
    final source = _FakeSearchEntityDataSource(
      actors: const PagedResult(
        items: [ActorSummary(id: 'a1', name: '演员A', avatarUrl: '')],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    final router = _buildSearchResultsRouter(source);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('演员'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ActorCard), findsOneWidget);
    await tester.tap(find.byType(ActorCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(router.state.uri.path, '/actor/a1');
  });

  testWidgets('非演员实体经路由进入类型减名称公共页且不请求搜索或影片接口', (tester) async {
    final cases = <({String tab, String expectedTitle, Type rowType})>[
      (tab: '系列', expectedTitle: '系列 - 测试系列', rowType: EntityListTile),
      (tab: '片商', expectedTitle: '片商 - 测试片商', rowType: EntityListTile),
      (tab: '导演', expectedTitle: '导演 - 测试导演', rowType: EntityListTile),
      (tab: '清单', expectedTitle: '清单 - 测试清单', rowType: ListSummaryTile),
      (tab: '番号', expectedTitle: '番号 - TEST', rowType: EntityListTile),
    ];

    for (final item in cases) {
      final source = _FakeSearchEntityDataSource.singleNamedResults();
      final movieSource = _RecordingSearchMovieDataSource();
      final router = _buildNamedResultsRouter(
        source,
        movieDataSource: movieSource,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.tab));
      await tester.pumpAndSettle();
      final entityRequestCount = source.totalCalls;
      final movieRequestCount = movieSource.calls.length;

      await tester.tap(find.byType(item.rowType).first);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.commonList);
      expect(find.text(item.expectedTitle), findsOneWidget);
      expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
      expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
      expect(find.byType(MovieGridView), findsOneWidget);
      expect(source.totalCalls, entityRequestCount);
      expect(movieSource.calls, hasLength(movieRequestCount));

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _pumpSearchResults(
  WidgetTester tester, {
  required SearchEntityDataSource entityDataSource,
}) => tester.pumpWidget(
  MaterialApp(
    home: SearchResultsPage(
      query: 'test',
      entityDataSource: entityDataSource,
      movieDataSource: _RecordingSearchMovieDataSource(),
    ),
  ),
);

GoRouter _buildSearchResultsRouter(SearchEntityDataSource entityDataSource) =>
    GoRouter(
      initialLocation: '/search/results',
      routes: [
        GoRoute(
          path: '/search/results',
          builder: (_, _) => SearchResultsPage(
            query: 'test',
            entityDataSource: entityDataSource,
            movieDataSource: _RecordingSearchMovieDataSource(),
          ),
        ),
        GoRoute(
          path: '/actor/:id',
          builder: (_, state) =>
              Scaffold(body: Text('actor ${state.pathParameters['id']}')),
        ),
      ],
    );

GoRouter _buildNamedResultsRouter(
  SearchEntityDataSource entityDataSource, {
  SearchMovieDataSource? movieDataSource,
}) =>
    GoRouter(
      initialLocation: '/search/results',
      routes: [
        GoRoute(
          path: '/search/results',
          builder: (_, _) => SearchResultsPage(
            query: 'test',
            entityDataSource: entityDataSource,
            movieDataSource: movieDataSource ?? _RecordingSearchMovieDataSource(),
          ),
        ),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (c, s) {
            final q = s.uri.queryParameters;
            return CommonListPage(
              title: q['title'] ?? '',
              type: int.tryParse(q['type'] ?? '') ?? 0,
              category: q['category'] ?? '',
              id: q['id'] ?? '',
            );
          },
        ),
      ],
    );

class _FakeSearchEntityDataSource implements SearchEntityDataSource {
  _FakeSearchEntityDataSource({
    this.actors = const PagedResult(
      items: [],
      currentPage: 1,
      totalPages: 1,
      total: 0,
    ),
    this.seriesPages = const {},
    this.makers = const PagedResult(
      items: [],
      currentPage: 1,
      totalPages: 1,
      total: 0,
    ),
    this.directors = const PagedResult(
      items: [],
      currentPage: 1,
      totalPages: 1,
      total: 0,
    ),
    this.lists = const PagedResult(
      items: [],
      currentPage: 1,
      totalPages: 1,
      total: 0,
    ),
    this.codes = const PagedResult(
      items: [],
      currentPage: 1,
      totalPages: 1,
      total: 0,
    ),
  });

  factory _FakeSearchEntityDataSource.singleNamedResults() =>
      _FakeSearchEntityDataSource(
        seriesPages: const {
          1: PagedResult(
            items: [Series(id: 's1', name: '测试系列', movieCount: 1, type: 2)],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          ),
        },
        makers: const PagedResult(
          items: [Maker(id: 'm1', name: '测试片商', movieCount: 2)],
          currentPage: 1,
          totalPages: 1,
          total: 1,
        ),
        directors: const PagedResult(
          items: [Director(id: 'd1', name: '测试导演', movieCount: 3)],
          currentPage: 1,
          totalPages: 1,
          total: 1,
        ),
        lists: const PagedResult(
          items: [
            ListModel(id: 'l1', name: '测试清单', movieCount: 4, viewedCount: 5),
          ],
          currentPage: 1,
          totalPages: 1,
          total: 1,
        ),
        codes: const PagedResult(
          items: [Code(id: 'TEST', number: 'TEST', movieCount: 6)],
          currentPage: 1,
          totalPages: 1,
          total: 1,
        ),
      );

  final PagedResult<ActorSummary> actors;
  final Map<int, PagedResult<Series>> seriesPages;
  final PagedResult<Maker> makers;
  final PagedResult<Director> directors;
  final PagedResult<ListModel> lists;
  final PagedResult<Code> codes;
  final actorRequestedPages = <int>[];
  final seriesRequestedPages = <int>[];
  final makerRequestedPages = <int>[];
  final directorRequestedPages = <int>[];
  final listRequestedPages = <int>[];
  final codeRequestedPages = <int>[];

  int get totalCalls =>
      actorRequestedPages.length +
      seriesRequestedPages.length +
      makerRequestedPages.length +
      directorRequestedPages.length +
      listRequestedPages.length +
      codeRequestedPages.length;

  @override
  Future<PagedResult<ActorSummary>> getActors({
    required String query,
    int page = 1,
  }) async {
    actorRequestedPages.add(page);
    return actors;
  }

  @override
  Future<PagedResult<Series>> getSeries({
    required String query,
    int page = 1,
  }) async {
    seriesRequestedPages.add(page);
    return seriesPages[page] ??
        PagedResult(
          items: const [],
          currentPage: page,
          totalPages: page,
          total: 0,
        );
  }

  @override
  Future<PagedResult<Maker>> getMakers({
    required String query,
    int page = 1,
  }) async {
    makerRequestedPages.add(page);
    return makers;
  }

  @override
  Future<PagedResult<Director>> getDirectors({
    required String query,
    int page = 1,
  }) async {
    directorRequestedPages.add(page);
    return directors;
  }

  @override
  Future<PagedResult<ListModel>> getLists({
    required String query,
    int page = 1,
  }) async {
    listRequestedPages.add(page);
    return lists;
  }

  @override
  Future<PagedResult<Code>> getCodes({
    required String query,
    int page = 1,
  }) async {
    codeRequestedPages.add(page);
    return codes;
  }
}
