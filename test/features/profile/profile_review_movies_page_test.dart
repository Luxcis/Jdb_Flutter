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

Future<void> _pumpTabAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump();
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

  testWidgets('切换无码 Tab 首次请求 type 1 且切回不重复首屏请求', (tester) async {
    final source = await _pumpPage(tester);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));

    tabBar.controller!.animateTo(2);
    await _pumpTabAnimation(tester);
    expect(
      source.requests
          .where((request) => request.type == '1')
          .map((request) => request.page),
      [1],
    );

    tabBar.controller!.animateTo(0);
    await _pumpTabAnimation(tester);
    expect(
      source.requests
          .where((request) => request.type == 'all')
          .map((request) => request.page),
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
      source.requests
          .where((request) => request.type == 'all')
          .map((request) => request.page),
      [1, 2],
    );
    expect(tester.widget<MovieGridView>(grid).controller.items, hasLength(36));
  });
}
