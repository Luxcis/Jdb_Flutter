import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/screens/search_results_screen.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _MovieCall = ({String query, SearchMovieFilter filter, int page});

class _RecordingMovieDataSource implements SearchMovieDataSource {
  _RecordingMovieDataSource(this.handler);

  final Future<PagedResult<MovieSummary>> Function(_MovieCall call) handler;
  final calls = <_MovieCall>[];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) {
    final call = (query: query, filter: filter, page: page);
    calls.add(call);
    return handler(call);
  }
}

MovieSummary _movie(String keyword) => MovieSummary(
  id: '$keyword-1',
  number: 'JDB-$keyword',
  title: '$keyword 影片',
  coverUrl: '',
);

PagedResult<MovieSummary> _page(List<MovieSummary> items) => PagedResult(
  items: items,
  currentPage: 1,
  totalPages: 1,
  total: items.length,
);

/// 镜像 app_router.dart 的结果路由结构（含空词重定向与页面键规则），
/// 注入 fake 数据源以观察请求参数。
GoRouter _router({
  required SearchMovieDataSource movieSource,
  String initialLocation = '${AppRoutes.searchResults}?q=旧关键词',
}) {
  return GoRouter(
    initialLocation: initialLocation,
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
            builder: (context, state) => SearchResultsPage(
              key: ValueKey(state.uri),
              query: state.uri.queryParameters['q']!.trim(),
              movieDataSource: movieSource,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.movieDetail,
        builder: (_, state) =>
            Scaffold(body: Text('详情 ${state.pathParameters['id']}')),
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

Future<void> _submitKeyword(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byType(TextField), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await _flush(tester);
}

int _currentTabIndex(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('修改关键词提交后以新关键词重新加载并回到影片 Tab', (tester) async {
    final movieSource = _RecordingMovieDataSource(
      (call) async => _page([_movie(call.query)]),
    );

    await _pump(tester, _router(movieSource: movieSource));
    expect(find.text('旧关键词 影片'), findsOneWidget);
    expect(movieSource.calls.single, (
      query: '旧关键词',
      filter: const SearchMovieFilter(),
      page: 1,
    ));

    await tester.tap(find.text('番号'));
    await _flush(tester);
    expect(find.text('暂无番号'), findsOneWidget);

    await _submitKeyword(tester, '新关键词');

    expect(movieSource.calls, hasLength(2));
    expect(movieSource.calls.last.query, '新关键词');
    expect(movieSource.calls.last.page, 1);
    expect(find.text('新关键词 影片'), findsOneWidget);
    expect(find.text('旧关键词 影片'), findsNothing);
    expect(find.text('暂无番号'), findsNothing);
    expect(_currentTabIndex(tester), 0);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '新关键词',
    );
  });

  testWidgets('提交与当前相同的关键词不重新请求', (tester) async {
    final movieSource = _RecordingMovieDataSource(
      (call) async => _page([_movie(call.query)]),
    );

    await _pump(tester, _router(movieSource: movieSource));
    await _submitKeyword(tester, '旧关键词');

    expect(movieSource.calls, hasLength(1));
    expect(find.text('旧关键词 影片'), findsOneWidget);
  });

  testWidgets('提交空白关键词不导航不重新搜索', (tester) async {
    final movieSource = _RecordingMovieDataSource(
      (call) async => _page([_movie(call.query)]),
    );

    await _pump(tester, _router(movieSource: movieSource));
    await _submitKeyword(tester, '   ');

    expect(movieSource.calls, hasLength(1));
    expect(find.text('旧关键词 影片'), findsOneWidget);
  });

  testWidgets('进入影片详情返回后结果页状态保留', (tester) async {
    final movieSource = _RecordingMovieDataSource(
      (call) async => _page([_movie(call.query)]),
    );
    final router = _router(movieSource: movieSource);

    await _pump(tester, router);
    // 未提交的输入草稿用于区分"页面保留"与"页面重建"。
    await tester.enterText(find.byType(TextField), '输入草稿');
    await tester.pump();

    await tester.tap(find.byType(MovieCard));
    await _flush(tester);
    expect(find.text('详情 旧关键词-1'), findsOneWidget);

    router.pop();
    await _flush(tester);

    expect(find.text('旧关键词 影片'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '输入草稿',
    );
    expect(movieSource.calls, hasLength(1));
    expect(_currentTabIndex(tester), 0);
  });

  testWidgets('结果页重搜后返回到搜索首页', (tester) async {
    final movieSource = _RecordingMovieDataSource(
      (call) async => _page([_movie(call.query)]),
    );
    final router = _router(
      movieSource: movieSource,
      initialLocation: AppRoutes.search,
    );

    await _pump(tester, router);
    expect(find.text('搜索首页'), findsOneWidget);

    unawaited(
      router.push(
        Uri(
          path: AppRoutes.searchResults,
          queryParameters: {'q': '旧关键词'},
        ).toString(),
      ),
    );
    await _flush(tester);
    expect(find.text('旧关键词 影片'), findsOneWidget);

    await _submitKeyword(tester, '新关键词');
    expect(movieSource.calls.last.query, '新关键词');

    router.pop();
    await _flush(tester);

    expect(router.state.uri.path, AppRoutes.search);
    expect(find.text('搜索首页'), findsOneWidget);
  });
}
