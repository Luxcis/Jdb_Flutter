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

class _RecordingSource implements LatestMoviesDataSource {
  _RecordingSource({this.multiplePages = false});

  final bool multiplePages;
  final requests = <_Request>[];

  @override
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

    await tester.tap(find.byKey(const Key('latest-tab-sort')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('发布日期').last);
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
}
