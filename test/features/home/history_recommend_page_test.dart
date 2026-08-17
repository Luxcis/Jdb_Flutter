import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/features/home/models/recommend_period.dart';
import 'package:jade/features/home/screens/history_recommend_detail_page.dart';
import 'package:jade/features/home/screens/history_recommend_page.dart';
import 'package:jade/features/home/services/history_recommend_service.dart';

String _day(String iso) {
  final local = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

void main() {
  testWidgets('往期推荐列表展示期号、日期与影片数量', (tester) async {
    final source = _RecordingRecommendPeriodDataSource();
    await tester.pumpWidget(
      MaterialApp(home: HistoryRecommendPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('往期推荐'), findsOneWidget);
    expect(
      find.text('第586期(${_day('2026-08-17T00:30:02.367Z')})'),
      findsOneWidget,
    );
    expect(
      find.text('第585期(${_day('2026-08-13T00:30:14.857Z')})'),
      findsOneWidget,
    );
    expect(find.text('(10)'), findsNWidgets(2));
    expect(source.periodsCalls, [1]);
  });

  testWidgets('滚动到底部自动加载下一页', (tester) async {
    final source = _RecordingRecommendPeriodDataSource(totalPages: 2);
    await tester.pumpWidget(
      MaterialApp(home: HistoryRecommendPage(dataSource: source)),
    );
    await tester.pumpAndSettle();
    expect(source.periodsCalls, [1]);

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(source.periodsCalls, [1, 2]);
  });

  testWidgets('点击某一期跳转到该期影片列表页', (tester) async {
    final source = _RecordingRecommendPeriodDataSource();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HistoryRecommendPage(dataSource: source),
        ),
        GoRoute(
          path: AppRoutes.historyRecommendDetail,
          builder: (c, s) => HistoryRecommendDetailPage(
            period: s.pathParameters['period']!,
            dataSource: source,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('第586期'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, '/home/history-recommend/586');
    expect(router.state.pathParameters['period'], '586');
    expect(source.moviesCalls, ['586']);
    expect(find.text('第586期'), findsWidgets);
  });
}

class _RecordingRecommendPeriodDataSource implements RecommendPeriodDataSource {
  _RecordingRecommendPeriodDataSource({this.totalPages = 1});

  final int totalPages;
  final periodsCalls = <int>[];
  final moviesCalls = <String>[];

  @override
  Future<PagedResult<RecommendPeriod>> getPeriods({
    int page = 1,
    int limit = 48,
  }) async {
    periodsCalls.add(page);
    return PagedResult(
      items: [
        RecommendPeriod(
          period: 586,
          moviesCount: 10,
          viewsCount: 0,
          createdAt: '2026-08-17T00:30:02.367Z',
        ),
        RecommendPeriod(
          period: 585,
          moviesCount: 10,
          viewsCount: 0,
          createdAt: '2026-08-13T00:30:14.857Z',
        ),
      ],
      currentPage: page,
      totalPages: totalPages,
      total: 2,
    );
  }

  @override
  Future<List<MovieSummary>> getMovies(String period) async {
    moviesCalls.add(period);
    return [
      MovieSummary(
        id: 'movie-586',
        number: 'R-586',
        title: '第586期影片',
        coverUrl: 'cover.jpg',
        score: 7.5,
      ),
    ];
  }
}
