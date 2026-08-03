import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/rating_badge.dart';
import 'package:jade/features/rankings/screens/rankings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RankingFixture {
  const _RankingFixture(this.adapter, this.auth, {this.router});

  final FakeAdapter adapter;
  final AuthProvider auth;
  final GoRouter? router;
}

Map<String, dynamic> _top250Response(int startRank, int count) => {
  'success': 1,
  'data': {
    'movies': [
      for (var index = 0; index < count; index++)
        {
          'id': 'top-${startRank + index}',
          'number': 'TOP-${startRank + index}',
          'title': 'Top Movie ${startRank + index}',
          'cover_url': 'cover.jpg',
        },
    ],
  },
};

Future<_RankingFixture> _pumpRankings(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  bool loggedIn = true,
  double textScaleFactor = 1,
  bool withRouter = false,
  int initialTabIndex = 2,
  List<Map<String, dynamic>>? top250Responses,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'key_baseurl': 'https://jdforrepam.com',
    'key_api_domains': ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  if (loggedIn) {
    await auth.login(token: 'token', user: {'id': 1});
  }
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: auth.logout,
  );
  final adapter = FakeAdapter()..responseDelay = responseDelay;
  api.setAdapterForTest(adapter);
  if (top250Responses != null) {
    adapter.enqueueSequence(Endpoints.moviesTop, top250Responses);
  } else {
    adapter.enqueue(Endpoints.moviesTop, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'top-movie',
            'number': 'ABC-001',
            'title': 'Ranked Movie',
            'cover_url': 'cover.jpg',
          },
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });
  }
  for (final path in [Endpoints.rankingsPlayback, Endpoints.rankings]) {
    final movieId = switch (path) {
      Endpoints.rankingsPlayback => 'hot-movie',
      _ => 'ranked-movie',
    };
    adapter.enqueue(path, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': movieId,
            'number': 'ABC-001',
            'title': path == Endpoints.rankingsPlayback
                ? 'Hot Movie'
                : 'Ranked Movie',
            'cover_url': 'cover.jpg',
          },
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });
  }
  final router = withRouter
      ? GoRouter(
          initialLocation: '/rankings',
          routes: [
            GoRoute(
              path: '/rankings',
              builder: (_, _) => RankingsPage(initialTabIndex: initialTabIndex),
            ),
            GoRoute(
              path: '/movie/:id',
              builder: (_, state) => Scaffold(
                body: Text(
                  '影片 ${state.pathParameters['id']}',
                  key: const Key('movie-detail-placeholder'),
                ),
              ),
            ),
            GoRoute(
              path: AppRoutes.search,
              builder: (_, _) => const Scaffold(body: Text('搜索页')),
            ),
          ],
        )
      : null;
  if (router != null) addTearDown(router.dispose);
  final mediaQueryData = MediaQueryData(
    size: const Size(320, 640),
    textScaler: TextScaler.linear(textScaleFactor),
  );
  final app = router == null
      ? MaterialApp(
          home: MediaQuery(
            data: mediaQueryData,
            child: RankingsPage(initialTabIndex: initialTabIndex),
          ),
        )
      : MaterialApp.router(
          routerConfig: router,
          builder: (_, child) =>
              MediaQuery(data: mediaQueryData, child: child!),
        );
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(value: auth, child: app),
  );
  return _RankingFixture(adapter, auth, router: router);
}

Future<void> _pumpRankingFrame(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _showTab(WidgetTester tester, int targetIndex) async {
  final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
  controller.animateTo(targetIndex);
  await tester.pump();
  await _pumpRankingFrame(tester);
}

Future<void> _scrollFilterSheetToBottom(WidgetTester tester) async {
  final list = find.byKey(const Key('top250-filter-list'));
  await tester.drag(list, const Offset(0, -800));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('排行榜顶部搜索按钮进入搜索页且位于筛选按钮右侧', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      withRouter: true,
      initialTabIndex: 0,
    );

    expect(find.byTooltip('筛选 Top250'), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('搜索')).dx,
      greaterThan(tester.getCenter(find.byTooltip('筛选 Top250')).dx),
    );

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    expect(fixture.router!.state.uri.path, AppRoutes.search);
  });

  testWidgets('指定 initialTabIndex 1 时首帧打开看热播', (tester) async {
    final fixture = await _pumpRankings(tester, initialTabIndex: 1);
    await _pumpRankingFrame(tester);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 1);
    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.rankingsPlayback,
      ),
      isNotEmpty,
    );
    expect(find.byTooltip('筛选 Top250'), findsNothing);
  });

  testWidgets('切换到看热播时先显示 Loading 且不显示空网格', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      responseDelay: const Duration(seconds: 1),
    );

    await _showTab(tester, 1);

    expect(find.byKey(const Key('movie-grid-initial-loading')), findsWidgets);
    expect(find.byType(GridView), findsNothing);
    expect(
      fixture.adapter.requests.map((request) => request.path),
      contains(Endpoints.rankingsPlayback),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });

  testWidgets('看热播使用分组圆角标签并发送 OpenAPI 参数', (tester) async {
    final fixture = await _pumpRankings(tester);
    await _showTab(tester, 1);

    expect(find.text('范围'), findsNothing);
    expect(find.text('周期'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);

    final row = find.byKey(const Key('hot-play-filter-row'));
    final range = find.byKey(const Key('hot-play-range-filter'));
    final period = find.byKey(const Key('hot-play-period-filter'));
    expect(row, findsOneWidget);
    expect(range, findsOneWidget);
    expect(period, findsOneWidget);
    expect(tester.getTopLeft(range).dy, tester.getTopLeft(period).dy);
    expect(
      tester.getSize(range).width / tester.getSize(period).width,
      closeTo(2 / 3, 0.08),
    );

    for (final finder in [range, period]) {
      final segmented = tester.widget<SegmentedButton<String>>(
        find.descendant(
          of: finder,
          matching: find.byType(SegmentedButton<String>),
        ),
      );
      expect(segmented.showSelectedIcon, isFalse);
      expect(segmented.expandedInsets, EdgeInsets.zero);
    }

    await tester.tap(find.text('周榜'));
    await _pumpRankingFrame(tester);

    final query = fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankingsPlayback)
        .last
        .uri
        .queryParameters;
    expect(query['filter_by'], 'high_score');
    expect(query['period'], 'weekly');
  });

  testWidgets('综合排行榜周期胶囊紧凑并撑满屏幕', (tester) async {
    await _pumpRankings(tester);
    await _showTab(tester, 2);

    final filter = find.byKey(const Key('rank-period-filter'));
    expect(filter, findsOneWidget);
    expect(tester.getSize(filter).width, closeTo(320 - 16, 1));

    final segmented = tester.widget<SegmentedButton<String>>(
      find.descendant(
        of: filter,
        matching: find.byType(SegmentedButton<String>),
      ),
    );
    expect(segmented.showSelectedIcon, isFalse);
    expect(segmented.expandedInsets, EdgeInsets.zero);
    expect(segmented.style?.visualDensity, VisualDensity.compact);
  });

  testWidgets('综合排行榜没有演员月榜且类型映射从 0 开始', (tester) async {
    final fixture = await _pumpRankings(tester);
    await _showTab(tester, 2);

    expect(find.text('演员月榜'), findsNothing);
    final rankingTypes = fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankings)
        .map((request) => request.uri.queryParameters['type']);
    expect(rankingTypes, contains('0'));
  });

  testWidgets('离开已加载 Tab 后返回时保留内容且不重复请求', (tester) async {
    final fixture = await _pumpRankings(tester);
    await _showTab(tester, 1);
    final playbackCount = fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankingsPlayback)
        .length;

    await _showTab(tester, 0);
    await _showTab(tester, 1);

    expect(find.text('Hot Movie'), findsOneWidget);
    expect(
      fixture.adapter.requests
          .where((request) => request.path == Endpoints.rankingsPlayback)
          .length,
      playbackCount,
    );
  });

  testWidgets('看热播筛选在窄屏大字体下不溢出', (tester) async {
    await _pumpRankings(tester, textScaleFactor: 1.5);
    await _showTab(tester, 1);

    expect(find.text('高分'), findsOneWidget);
    final range = find.byKey(const Key('hot-play-range-filter'));
    final period = find.byKey(const Key('hot-play-period-filter'));
    expect(tester.getTopLeft(range).dy, tester.getTopLeft(period).dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Top250 筛选抽屉完整展示筛选项且切换 Tab 后隐藏入口', (tester) async {
    await _pumpRankings(tester, initialTabIndex: 0);
    await _pumpRankingFrame(tester);

    expect(find.byTooltip('筛选 Top250'), findsOneWidget);
    await tester.tap(find.byTooltip('筛选 Top250'));
    await tester.pump();
    await _pumpRankingFrame(tester);

    final sheetFinder = find.byType(BottomSheet);
    expect(sheetFinder, findsOneWidget);
    expect(find.text('筛选'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '全部'), findsOneWidget);
    expect(find.text('${DateTime.now().year}'), findsOneWidget);
    expect(find.text('2008'), findsOneWidget);
    expect(
      tester.getSize(sheetFinder).height,
      closeTo(tester.view.physicalSize.height * 2 / 3, 2),
    );
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    final heightBeforeUpwardDrag = tester.getSize(sheetFinder).height;
    await tester.drag(sheetFinder, const Offset(0, -120));
    await tester.pump();
    expect(
      tester.getSize(sheetFinder).height,
      closeTo(heightBeforeUpwardDrag, 1),
    );

    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.showCheckmark, isFalse);
      expect(chip.visualDensity, VisualDensity.compact);
      expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(chip.labelPadding, const EdgeInsets.symmetric(horizontal: 6));
    }

    await _scrollFilterSheetToBottom(tester);
    expect(find.text('起始排名'), findsOneWidget);
    expect(find.text('未标「看过」'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await _pumpRankingFrame(tester);
    await _showTab(tester, 1);
    expect(find.byTooltip('筛选 Top250'), findsNothing);
  });

  testWidgets('Top250 筛选立即刷新并保持抽屉打开', (tester) async {
    final fixture = await _pumpRankings(tester, initialTabIndex: 0);
    await _pumpRankingFrame(tester);
    await tester.tap(find.byTooltip('筛选 Top250'));
    await tester.pump();
    await _pumpRankingFrame(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '欧美'));
    await _pumpRankingFrame(tester);
    var query = fixture.adapter.requests
        .where((request) => request.path == Endpoints.moviesTop)
        .last
        .uri
        .queryParameters;
    expect(query['type'], 'video_type');
    expect(query['type_value'], '2');
    expect(find.text('筛选'), findsOneWidget);

    final year = '${DateTime.now().year}';
    await tester.tap(find.widgetWithText(ChoiceChip, year));
    await _pumpRankingFrame(tester);
    query = fixture.adapter.requests
        .where((request) => request.path == Endpoints.moviesTop)
        .last
        .uri
        .queryParameters;
    expect(query['type'], 'year');
    expect(query['type_value'], year);
    expect(find.text('筛选'), findsOneWidget);

    await _scrollFilterSheetToBottom(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '51'));
    await _pumpRankingFrame(tester);
    query = fixture.adapter.requests
        .where((request) => request.path == Endpoints.moviesTop)
        .last
        .uri
        .queryParameters;
    expect(query['start_rank'], '51');

    await tester.tap(find.byType(Switch));
    await _pumpRankingFrame(tester);
    query = fixture.adapter.requests
        .where((request) => request.path == Endpoints.moviesTop)
        .last
        .uri
        .queryParameters;
    expect(query['ignore_watched'], 'true');
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await _pumpRankingFrame(tester);
    expect(tester.widget<RatingBadge>(find.byType(RatingBadge)).rank, 51);
  });

  testWidgets('Top250 未登录时不请求且登录后自动加载', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      loggedIn: false,
      initialTabIndex: 0,
    );
    await _pumpRankingFrame(tester);

    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.moviesTop,
      ),
      isEmpty,
    );

    await fixture.auth.login(token: 'token', user: {'id': 1});
    await tester.pump();
    await _pumpRankingFrame(tester);

    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.moviesTop,
      ),
      hasLength(1),
    );
    expect(find.text('Ranked Movie'), findsOneWidget);
  });

  testWidgets('Top250 滚动接近底部后按排名追加下一批', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      initialTabIndex: 0,
      top250Responses: [_top250Response(1, 50), _top250Response(51, 50)],
    );
    await _pumpRankingFrame(tester);
    fixture.adapter.responseDelay = const Duration(seconds: 1);

    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -10000),
    );
    await tester.pump();

    expect(find.text('Top Movie 50'), findsOneWidget);
    expect(find.byType(MovieListTile), findsWidgets);
    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(find.byKey(const Key('top250-loading-more')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(
      fixture.adapter.requests
          .where((request) => request.path == Endpoints.moviesTop)
          .last
          .uri
          .queryParameters['start_rank'],
      '51',
    );

    await _pumpRankingFrame(tester);
    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(find.text('Top Movie 51'), findsOneWidget);
  });

  testWidgets('Top250 首批不足 50 条时不再请求', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      initialTabIndex: 0,
      top250Responses: [_top250Response(1, 10)],
    );
    await _pumpRankingFrame(tester);
    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -10000),
    );
    await _pumpRankingFrame(tester);

    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.moviesTop,
      ),
      hasLength(1),
    );
  });

  testWidgets('Top250 从 201 开始时加载一批后停止', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      initialTabIndex: 0,
      top250Responses: [_top250Response(1, 1), _top250Response(201, 50)],
    );
    await _pumpRankingFrame(tester);
    await tester.tap(find.byTooltip('筛选 Top250'));
    await tester.pump();
    await _pumpRankingFrame(tester);
    await _scrollFilterSheetToBottom(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '201'));
    await _pumpRankingFrame(tester);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -10000),
    );
    await _pumpRankingFrame(tester);

    final topRequests = fixture.adapter.requests.where(
      (request) => request.path == Endpoints.moviesTop,
    );
    expect(topRequests, hasLength(2));
    expect(topRequests.last.uri.queryParameters['start_rank'], '201');
  });

  testWidgets('Top250 从 51 开始时继续请求 101 且排名连续', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      initialTabIndex: 0,
      top250Responses: [
        _top250Response(1, 1),
        _top250Response(51, 50),
        _top250Response(101, 50),
      ],
    );
    await _pumpRankingFrame(tester);
    await tester.tap(find.byTooltip('筛选 Top250'));
    await tester.pump();
    await _pumpRankingFrame(tester);
    await _scrollFilterSheetToBottom(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '51'));
    await _pumpRankingFrame(tester);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -10000),
    );
    await _pumpRankingFrame(tester);
    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -200),
    );
    await tester.pump();

    final startRanks = fixture.adapter.requests
        .where((request) => request.path == Endpoints.moviesTop)
        .map((request) => request.uri.queryParameters['start_rank'])
        .toList();
    expect(startRanks, ['1', '51', '101']);
    expect(find.text('Top Movie 101'), findsOneWidget);
    final appendedTile = find.ancestor(
      of: find.text('Top Movie 101'),
      matching: find.byType(MovieListTile),
    );
    expect(
      tester
          .widget<RatingBadge>(
            find.descendant(
              of: appendedTile,
              matching: find.byType(RatingBadge),
            ),
          )
          .rank,
      101,
    );
  });

  testWidgets('Top250 追加失败时保留列表并可重试同一批', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      initialTabIndex: 0,
      top250Responses: [
        _top250Response(1, 50),
        {'success': 0, 'message': 'next page failed'},
        _top250Response(51, 50),
      ],
    );
    await _pumpRankingFrame(tester);

    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -10000),
    );
    await _pumpRankingFrame(tester);

    expect(find.text('Top Movie 50'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('top250-load-more-retry')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('top250-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('top250-load-more-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('top250-load-more-retry')));
    await _pumpRankingFrame(tester);
    await tester.drag(
      find.byKey(const Key('top250-list')),
      const Offset(0, -200),
    );
    await tester.pump();

    final startRanks = fixture.adapter.requests
        .where((request) => request.path == Endpoints.moviesTop)
        .map((request) => request.uri.queryParameters['start_rank'])
        .toList();
    expect(startRanks, ['1', '51', '51']);
    expect(find.text('Top Movie 51'), findsOneWidget);
  });

  testWidgets('Top250 列表影片点击进入详情页', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      withRouter: true,
      initialTabIndex: 0,
    );
    await _pumpRankingFrame(tester);

    await tester.tap(find.text('Ranked Movie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fixture.router!.state.uri.path, '/movie/top-movie');
    expect(find.byKey(const Key('movie-detail-placeholder')), findsOneWidget);
  });

  testWidgets('看热播网格影片点击进入详情页', (tester) async {
    final fixture = await _pumpRankings(tester, withRouter: true);
    await _showTab(tester, 1);

    await tester.tap(find.text('Hot Movie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fixture.router!.state.uri.path, '/movie/hot-movie');
    expect(find.byKey(const Key('movie-detail-placeholder')), findsOneWidget);
  });

  testWidgets('综合排行榜网格影片点击进入详情页', (tester) async {
    final fixture = await _pumpRankings(tester, withRouter: true);
    await _showTab(tester, 2);

    await tester.tap(find.text('Ranked Movie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fixture.router!.state.uri.path, '/movie/ranked-movie');
    expect(find.byKey(const Key('movie-detail-placeholder')), findsOneWidget);
  });
}
