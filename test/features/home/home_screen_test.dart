import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/features/home/screens/history_recommend_page.dart';
import 'package:jade/features/home/screens/home_screen.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FakeAdapter> _prepareApi(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  List<Map<String, dynamic>>? latestBodies,
  List<Map<String, dynamic>> recommends = const [
    {
      'id': 'recommend',
      'number': 'R-1',
      'title': 'Recommend',
      'cover_url': 'recommend.jpg',
    },
  ],
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'key_baseurl': 'https://jdforrepam.com',
    'key_api_domains': ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: auth.logout,
  );
  final adapter = FakeAdapter()..responseDelay = responseDelay;
  api.setAdapterForTest(adapter);
  adapter.enqueue(Endpoints.moviesRecommend, {
    'success': 1,
    'data': {'movies': recommends},
  });
  if (latestBodies != null) {
    adapter.enqueueSequence(Endpoints.moviesLatest, latestBodies);
  } else {
    adapter.enqueue(Endpoints.moviesLatest, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'home-movie',
            'number': 'H-1',
            'title': 'Home Movie',
            'cover_url': 'home.jpg',
          },
        ],
      },
    });
  }
  return adapter;
}

Future<FakeAdapter> _pumpHome(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  List<Map<String, dynamic>>? latestBodies,
  List<Map<String, dynamic>> recommends = const [
    {
      'id': 'recommend',
      'number': 'R-1',
      'title': 'Recommend',
      'cover_url': 'recommend.jpg',
    },
  ],
  bool settle = true,
}) async {
  final adapter = await _prepareApi(
    tester,
    responseDelay: responseDelay,
    latestBodies: latestBodies,
    recommends: recommends,
  );

  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  await tester.pump();
  if (settle) {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }
  return adapter;
}

Future<void> _pumpRequest(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首页内容使用 SafeArea 避免状态栏遮挡', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('首页显示参考样式的两个换一组控件', (tester) async {
    await _pumpHome(tester);

    expect(find.text('最新上架'), findsOneWidget);
    expect(find.text('近期磁链更新'), findsOneWidget);
    expect(find.text('换一组'), findsNWidgets(2));
    expect(find.byIcon(Icons.refresh), findsNWidgets(2));
  });

  testWidgets('首页豆腐块上方显示整行搜索入口', (tester) async {
    await _pumpHome(tester);

    expect(find.byType(HomeSearchBar), findsOneWidget);
    expect(find.text('输入演员或番号等关键字'), findsOneWidget);
    final searchTop = tester.getTopLeft(find.byType(HomeSearchBar)).dy;
    final tofuTop = tester.getTopLeft(find.byType(TofuScroll)).dy;
    expect(searchTop, lessThan(tofuTop));
  });

  testWidgets('佳片推荐在首页每 5 秒自动显示下一张', (tester) async {
    await _pumpHome(
      tester,
      recommends: const [
        {
          'id': 'recommend-a',
          'number': 'R-1',
          'title': 'Recommend A',
          'cover_url': 'recommend-a.jpg',
        },
        {
          'id': 'recommend-b',
          'number': 'R-2',
          'title': 'Recommend B',
          'cover_url': 'recommend-b.jpg',
        },
      ],
    );
    final carousel = find.byKey(const Key('home-recommend-carousel'));

    expect(
      tester.getCenter(find.text('Recommend A')).dx,
      closeTo(tester.getCenter(carousel).dx, 5),
    );
    await tester.pump(const Duration(seconds: 5));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      tester.getCenter(find.text('Recommend B')).dx,
      closeTo(tester.getCenter(carousel).dx, 5),
    );
  });

  testWidgets('最新上架换一组仅请求 can_play 第 2 页', (tester) async {
    final adapter = await _pumpHome(tester);
    final before = adapter.requests.length;

    await tester.tap(find.byKey(const Key('home-latest-shuffle')));
    await _pumpRequest(tester);

    final added = adapter.requests.skip(before).toList();
    expect(added, hasLength(1));
    expect(added.single.uri.queryParameters['filter_by'], 'can_play');
    expect(added.single.uri.queryParameters['page'], '2');
  });

  testWidgets('近期磁链换一组仅请求 magnets 第 2 页', (tester) async {
    final adapter = await _pumpHome(tester);
    final before = adapter.requests.length;

    await tester.tap(find.byKey(const Key('home-magnets-shuffle')));
    await _pumpRequest(tester);

    final added = adapter.requests.skip(before).toList();
    expect(added, hasLength(1));
    expect(added.single.uri.queryParameters['filter_by'], 'magnets');
    expect(added.single.uri.queryParameters['page'], '2');
  });

  testWidgets('换一组失败时保留页面并显示重试提示', (tester) async {
    final adapter = await _pumpHome(tester);
    adapter.enqueue(Endpoints.moviesLatest, {
      'success': 0,
      'message': 'network',
    });

    await tester.tap(find.byKey(const Key('home-latest-shuffle')));
    await _pumpRequest(tester);

    expect(find.text('Home Movie'), findsWidgets);
    expect(find.text('换一组失败，请重试'), findsOneWidget);
  });

  testWidgets('首屏立即显示搜索栏、豆腐块与分区标题，不整页转圈', (tester) async {
    await _pumpHome(
      tester,
      responseDelay: const Duration(milliseconds: 300),
      settle: false,
    );

    expect(find.byType(HomeSearchBar), findsOneWidget);
    expect(find.byType(TofuScroll), findsOneWidget);
    expect(find.text('佳片推荐'), findsOneWidget);
    expect(find.text('最新上架'), findsOneWidget);
    expect(find.text('近期磁链更新'), findsOneWidget);
    expect(find.byKey(const Key('home-loading-recommends')), findsOneWidget);
    expect(find.byKey(const Key('home-loading-latest')), findsOneWidget);
    expect(find.byKey(const Key('home-loading-magnets')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byKey(const Key('home-loading-recommends')), findsNothing);
    expect(find.byKey(const Key('home-loading-latest')), findsNothing);
    expect(find.byKey(const Key('home-loading-magnets')), findsNothing);
    expect(find.text('Home Movie'), findsWidgets);
  });

  testWidgets('最新上架分区失败显示分区错误与重试，其余分区正常', (tester) async {
    await _pumpHome(
      tester,
      latestBodies: [
        {'success': 0, 'message': 'network'},
        {
          'success': 1,
          'data': {
            'movies': [
              {
                'id': 'home-movie',
                'number': 'H-1',
                'title': 'Home Movie',
                'cover_url': 'home.jpg',
              },
            ],
          },
        },
      ],
    );

    expect(find.text('最新上架'), findsOneWidget);
    expect(find.text('近期磁链更新'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('Home Movie'), findsWidgets);
    expect(find.text('Recommend'), findsOneWidget);
  });

  testWidgets('点击分区重试仅重发失败分区并恢复', (tester) async {
    final adapter = await _pumpHome(
      tester,
      latestBodies: [
        {'success': 0, 'message': 'network'},
        {
          'success': 1,
          'data': {
            'movies': [
              {
                'id': 'home-movie',
                'number': 'H-1',
                'title': 'Home Movie',
                'cover_url': 'home.jpg',
              },
            ],
          },
        },
        {
          'success': 1,
          'data': {
            'movies': [
              {
                'id': 'home-movie',
                'number': 'H-1',
                'title': 'Home Movie',
                'cover_url': 'home.jpg',
              },
            ],
          },
        },
      ],
    );
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await _pumpRequest(tester);

    expect(find.text('重试'), findsNothing);
    expect(find.text('Home Movie'), findsWidgets);
    final recommendRequests = adapter.requests
        .where((r) => r.path == Endpoints.moviesRecommend)
        .length;
    expect(recommendRequests, 1);
  });

  testWidgets('点击佳片推荐右侧往期推荐进入往期推荐列表页', (tester) async {
    final adapter = await _prepareApi(tester);
    adapter.enqueue(Endpoints.moviesRecommendPeriods, {
      'success': 1,
      'data': {
        'periods': [
          {
            'period': 586,
            'movies_count': 10,
            'views_count': 0,
            'created_at': '2026-08-17T00:30:02.367Z',
          },
        ],
        'current_page': 1,
      },
    });
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: AppRoutes.historyRecommend,
          builder: (_, _) => const HistoryRecommendPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await tester.tap(find.text('往期推荐'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, AppRoutes.historyRecommend);
    expect(find.text('往期推荐'), findsWidgets);
  });

  testWidgets('点击最新上架全部跳转最新影片页', (tester) async {
    await _prepareApi(tester);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: AppRoutes.latestMovies,
          builder: (_, _) => Scaffold(body: Text('最新影片页')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await tester.tap(find.text('全部').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, AppRoutes.latestMovies);
    expect(router.state.uri.queryParameters['section'], 'latest');
    expect(find.text('最新影片页'), findsOneWidget);
  });

  testWidgets('点击近期磁链更新全部跳转磁链页', (tester) async {
    await _prepareApi(tester);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: AppRoutes.latestMovies,
          builder: (_, _) => Scaffold(body: Text('磁链更新页')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await tester.tap(find.text('全部').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, AppRoutes.latestMovies);
    expect(router.state.uri.queryParameters['section'], 'magnets');
    expect(find.text('磁链更新页'), findsOneWidget);
  });
}
