import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/home/models/recommend_period.dart';
import 'package:jade/features/home/screens/history_recommend_detail_page.dart';
import 'package:jade/features/home/services/history_recommend_service.dart';
import 'package:jade/features/home/widgets/recommend_movie_card.dart';

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(page);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  testWidgets('详情页展示该期影片卡片列表', (tester) async {
    final source = _RecordingRecommendPeriodDataSource();
    await _pumpPage(
      tester,
      MaterialApp(
        home: HistoryRecommendDetailPage(period: '586', dataSource: source),
      ),
    );

    expect(source.moviesCalls, ['586']);
    expect(find.text('第586期'), findsOneWidget);
    expect(find.byType(RecommendMovieCard), findsNWidgets(2));
    expect(find.text('影片A'), findsOneWidget);
    expect(find.text('影片B'), findsOneWidget);
  });

  testWidgets('加载失败显示重试，点击重试重新请求', (tester) async {
    final source = _RecordingRecommendPeriodDataSource(failFirst: true);
    await _pumpPage(
      tester,
      MaterialApp(
        home: HistoryRecommendDetailPage(period: '586', dataSource: source),
      ),
    );

    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(source.moviesCalls, ['586', '586']);
    expect(find.byType(RecommendMovieCard), findsNWidgets(2));
  });

  testWidgets('本期无影片时显示空状态', (tester) async {
    final source = _RecordingRecommendPeriodDataSource(empty: true);
    await _pumpPage(
      tester,
      MaterialApp(
        home: HistoryRecommendDetailPage(period: '586', dataSource: source),
      ),
    );

    expect(find.text('本期暂无影片'), findsOneWidget);
  });

  testWidgets('点击卡片跳转到影片详情页', (tester) async {
    final source = _RecordingRecommendPeriodDataSource();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              HistoryRecommendDetailPage(period: '586', dataSource: source),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (c, s) =>
              Scaffold(body: Text('详情 ${s.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpPage(tester, MaterialApp.router(routerConfig: router));

    await tester.tap(find.byType(RecommendMovieCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, '/movie/movie-a');
    expect(find.text('详情 movie-a'), findsOneWidget);
  });
}

class _RecordingRecommendPeriodDataSource implements RecommendPeriodDataSource {
  _RecordingRecommendPeriodDataSource({
    this.failFirst = false,
    this.empty = false,
  });

  final bool failFirst;
  final bool empty;
  final moviesCalls = <String>[];

  @override
  Future<PagedResult<RecommendPeriod>> getPeriods({
    int page = 1,
    int limit = 48,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<List<MovieSummary>> getMovies(String period) async {
    moviesCalls.add(period);
    if (failFirst && moviesCalls.length == 1) {
      throw Exception('network');
    }
    if (empty) return const [];
    return [
      MovieSummary(
        id: 'movie-a',
        number: 'A-001',
        title: '影片A',
        coverUrl: 'cover-a.jpg',
        score: 8.0,
      ),
      MovieSummary(
        id: 'movie-b',
        number: 'B-002',
        title: '影片B',
        coverUrl: 'cover-b.jpg',
        score: 6.5,
      ),
    ];
  }
}
