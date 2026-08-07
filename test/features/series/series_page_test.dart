import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/series/models/series_letter.dart';
import 'package:jade/features/series/screens/series_page.dart';
import 'package:jade/features/series/services/series_service.dart';

void main() {
  testWidgets('渲染 5 个 Tab，番号 Tab 展示字母、数量与 description 副标题', (tester) async {
    final source = _RecordingSeriesDataSource();
    await tester.pumpWidget(
      MaterialApp(home: SeriesPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    for (final tab in ['番号', '有码', '无码', '欧美', '动漫']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('IPX'), findsOneWidget);
    expect(find.text('(998)'), findsOneWidget);
    expect(find.text('IdeaPocket美少女夢工廠'), findsOneWidget);
    expect(source.lettersCalls, [1]);
    expect(source.seriesCalls, isEmpty);
  });

  testWidgets('切换到有码 Tab 触发 getSeries(type=0)', (tester) async {
    final source = _RecordingSeriesDataSource();
    await tester.pumpWidget(
      MaterialApp(home: SeriesPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();

    expect(source.seriesCalls, [(type: '0', page: 1)]);
    expect(find.text('测试系列'), findsOneWidget);
    expect(find.text('(1100)'), findsOneWidget);
  });

  testWidgets('番号与系列条目均经 /common-list 路由进入 CommonListPage', (tester) async {
    final source = _RecordingSeriesDataSource();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => SeriesPage(dataSource: source)),
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
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('IPX'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters['title'], '番号 - IPX');
    expect(router.state.uri.queryParameters['category'], 'c');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试系列'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters['title'], '系列 - 测试系列');
    expect(router.state.uri.queryParameters['category'], 's');
    expect(find.text('系列 - 测试系列'), findsOneWidget);
  });
}

class _RecordingSeriesDataSource implements SeriesDataSource {
  final lettersCalls = <int>[];
  final seriesCalls = <({String type, int page})>[];

  @override
  Future<PagedResult<SeriesLetter>> getLetters({
    int page = 1,
    int limit = 48,
  }) async {
    lettersCalls.add(page);
    return PagedResult(
      items: [
        SeriesLetter(
          id: 'IPX',
          letter: 'IPX',
          description: 'IdeaPocket美少女夢工廠',
          videosCount: 998,
          viewsCount: 3593620,
          type: 0,
        ),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }

  @override
  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  }) async {
    seriesCalls.add((type: type, page: page));
    return PagedResult(
      items: [
        Series(
          id: 'rY2v',
          name: '测试系列',
          movieCount: 1100,
          type: int.parse(type),
        ),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }
}
