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
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/screens/search_results_screen.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/router/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _query = '旧关键词';

typedef _MovieCall = ({String query, SearchMovieFilter filter, int page});
typedef _ActorCall = ({String query, int page});

class _RecordingMovieDataSource implements SearchMovieDataSource {
  _RecordingMovieDataSource(this.moviesPerPage);

  final int moviesPerPage;
  final calls = <_MovieCall>[];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async {
    calls.add((query: query, filter: filter, page: page));
    final items = List<MovieSummary>.generate(
      moviesPerPage,
      (index) => MovieSummary(
        id: '$query-$page-$index',
        number: 'JDB-$query-$index',
        title: '$query 影片 $index',
        coverUrl: '',
      ),
    );
    // totalPages = page：单页数据，滚动不会触发追加请求。
    return PagedResult(
      items: items,
      currentPage: page,
      totalPages: page,
      total: items.length,
    );
  }
}

class _RecordingEntityDataSource implements SearchEntityDataSource {
  final actorCalls = <_ActorCall>[];

  @override
  Future<PagedResult<ActorSummary>> getActors({
    required String query,
    int page = 1,
  }) async {
    actorCalls.add((query: query, page: page));
    return PagedResult(
      items: [
        ActorSummary(id: 'actor-$page', name: '演员$page-$query', avatarUrl: ''),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }

  @override
  Future<PagedResult<Series>> getSeries({
    required String query,
    int page = 1,
  }) async => _empty();

  @override
  Future<PagedResult<Maker>> getMakers({
    required String query,
    int page = 1,
  }) async => _empty();

  @override
  Future<PagedResult<Director>> getDirectors({
    required String query,
    int page = 1,
  }) async => _empty();

  @override
  Future<PagedResult<ListModel>> getLists({
    required String query,
    int page = 1,
  }) async => _empty();

  @override
  Future<PagedResult<Code>> getCodes({
    required String query,
    int page = 1,
  }) async => _empty();

  PagedResult<T> _empty<T>() =>
      PagedResult<T>(items: const [], currentPage: 1, totalPages: 1, total: 0);
}

/// 镜像 app_router.dart 的结果页路由（完整 URI 作为页面键），注入 fake 数据源。
GoRouter _router({
  required SearchMovieDataSource movieSource,
  required SearchEntityDataSource entitySource,
}) {
  return GoRouter(
    initialLocation: '${AppRoutes.searchResults}?q=$_query',
    routes: [
      GoRoute(
        path: AppRoutes.search,
        builder: (_, _) => const Scaffold(body: Text('搜索首页')),
        routes: [
          GoRoute(
            path: 'results',
            redirect: (context, state) {
              final query = state.uri.queryParameters['q']?.trim() ?? '';
              return query.isEmpty ? AppRoutes.search : null;
            },
            builder: (context, state) => SearchResultsScreen(
              key: ValueKey(state.uri),
              query: state.uri.queryParameters['q']!.trim(),
              movieDataSource: movieSource,
              entityDataSource: entitySource,
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  SharedPreferences.setMockInitialValues({});
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _flush(tester);
}

/// 结果页含封面图占位动画，无法 pumpAndSettle，用固定节奏推进帧。
Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await _flush(tester);
}

/// 影片网格（`MovieGridView` 内的 CustomScrollView）当前滚动偏移。
double _movieGridOffset(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsOneWidget);
  return tester.state<ScrollableState>(scrollable).position.pixels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('切换 Tab 再切回影片 Tab 不重复请求', (tester) async {
    final movieSource = _RecordingMovieDataSource(6);
    final entitySource = _RecordingEntityDataSource();
    await _pump(
      tester,
      _router(movieSource: movieSource, entitySource: entitySource),
    );

    expect(movieSource.calls, hasLength(1));
    expect(movieSource.calls.single.query, _query);
    expect(movieSource.calls.single.page, 1);
    expect(find.text('$_query 影片 0'), findsOneWidget);

    await _tapTab(tester, '演员');
    expect(entitySource.actorCalls, hasLength(1));
    expect(entitySource.actorCalls.single.query, _query);

    await _tapTab(tester, '影片');

    expect(movieSource.calls, hasLength(1));
    expect(find.text('$_query 影片 0'), findsOneWidget);
  });

  testWidgets('切回影片 Tab 保留滚动位置', (tester) async {
    final movieSource = _RecordingMovieDataSource(30);
    final entitySource = _RecordingEntityDataSource();
    await _pump(
      tester,
      _router(movieSource: movieSource, entitySource: entitySource),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    final before = _movieGridOffset(tester);
    expect(before, greaterThan(0));

    await _tapTab(tester, '演员');
    await _tapTab(tester, '影片');

    expect(movieSource.calls, hasLength(1));
    expect(_movieGridOffset(tester), before);
  });

  testWidgets('切回影片 Tab 保留筛选条件且不重新加载', (tester) async {
    final movieSource = _RecordingMovieDataSource(6);
    final entitySource = _RecordingEntityDataSource();
    await _pump(
      tester,
      _router(movieSource: movieSource, entitySource: entitySource),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '有码'));
    await _flush(tester);
    expect(movieSource.calls, hasLength(2));
    expect(movieSource.calls.last.filter.type, SearchMovieType.censored);

    await _tapTab(tester, '演员');
    await _tapTab(tester, '影片');

    expect(movieSource.calls, hasLength(2));
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '有码')).selected,
      isTrue,
    );
  });

  testWidgets('影片与演员之间往返不重复请求演员数据', (tester) async {
    final movieSource = _RecordingMovieDataSource(6);
    final entitySource = _RecordingEntityDataSource();
    await _pump(
      tester,
      _router(movieSource: movieSource, entitySource: entitySource),
    );

    await _tapTab(tester, '演员');
    expect(entitySource.actorCalls, hasLength(1));
    expect(find.text('演员1-$_query'), findsOneWidget);

    await _tapTab(tester, '影片');
    await _tapTab(tester, '演员');

    expect(entitySource.actorCalls, hasLength(1));
    expect(find.text('演员1-$_query'), findsOneWidget);
  });
}
