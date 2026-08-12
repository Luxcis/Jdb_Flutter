import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/movie_screenshot_image.dart';
import 'package:jade/core/widgets/star_rating.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/screens/movie_detail_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

Future<FakeAdapter> _setupApiClient({VoidCallback? onAuthError}) async {
  final adapter = FakeAdapter();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.baseUrl, 'https://jdforrepam.com');
  await prefs.setStringList(StorageKeys.apiDomains, ['https://jdforrepam.com']);
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TokenProvider(),
    onAuthError: onAuthError ?? () {},
  );
  api.setAdapterForTest(adapter);
  return adapter;
}

void _mockPathProvider(WidgetTester tester) {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (_) async => '/tmp/jade_flutter_test',
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

Future<void> _pumpUntilRequest(
  WidgetTester tester,
  FakeAdapter adapter,
  String path,
) async {
  for (var i = 0; i < 20; i++) {
    if (adapter.requests.any((request) => request.path == path)) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpUntilText(WidgetTester tester, String text) async {
  for (var i = 0; i < 20; i++) {
    if (find.text(text).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollUntilFound(
  WidgetTester tester, {
  required Finder target,
  required Finder scrollable,
}) async {
  for (var i = 0; i < 10 && target.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
  }
}

void _enqueueCompleteMovieDetail(
  FakeAdapter adapter, {
  String? previewVideoUrl,
  List<Object?> previewImages = const [
    {'url': 'screenshots/test.jpg'},
    {'url': 'screenshots/test-2.jpg'},
  ],
}) {
  adapter.enqueue('/api/v4/movies/m1', {
    'success': 1,
    'data': {
      'movie': {
        'id': 'm1',
        'type': '1',
        'number': 'SSIS-001',
        'number_letter': 'SSIS',
        'title': '测试影片',
        'cover_url': 'covers/test.jpg',
        'preview_video_url': ?previewVideoUrl,
        'release_date': '2026-07-22',
        'duration': 120,
        'director_id': 'director-1',
        'director_name': '测试&导演#1',
        'maker_id': 'maker-1',
        'maker_name': '测试片商',
        'publisher_id': 'publisher-1',
        'publisher_name': '测试发行商',
        'series_id': 'series-1',
        'series_name': '测试系列',
        'score': '4.33',
        'want_watch_count': 12,
        'watched_count': 8,
        'actors': [
          {'id': 'a1', 'name': '测试演员', 'avatar_url': 'actors/test.jpg'},
        ],
        'preview_images': previewImages,
        'actor_movies': [
          {
            'id': 'actor-movie',
            'number': 'ACT-001',
            'thumb_url': 'thumbs/actor.jpg',
          },
        ],
        'relative_movies': [
          {
            'id': 'relative-movie',
            'number': 'REL-001',
            'thumb_url': 'thumbs/relative.jpg',
          },
        ],
        'tags': [
          {'id': 'tag-1', 'name': '剧情&爱情#1', 'value': 'plot'},
          {'name': '漫画游戏改编'},
          {'name': '中文字幕'},
          {'name': '角色扮演'},
          {'name': '高画质'},
        ],
      },
    },
  });
  adapter.enqueue('/api/v1/movies/m1/magnets', {
    'success': 1,
    'data': {
      'magnets': [
        {
          'name': '测试磁链.torrent',
          'hash': 'hash-1',
          'size': 9910,
          'hd': true,
          'created_at': '2026-07-22',
        },
        {
          'name': '第二条磁链',
          'hash': 'hash-2',
          'size': 2048,
          'files_count': 2,
          'created_at': '2026-07-23',
        },
      ],
    },
  });
  adapter.enqueueSequence('/api/v1/movies/m1/reviews', [
    {
      'success': 1,
      'data': {
        'reviews': [
          {
            'id': 1,
            'username': 'reequasew',
            'watched_count': 2060,
            'score': 8,
            'content': '两大女优的联手果然是很震撼的',
            'likes_count': 17,
            'created_at': '2016-09-24',
          },
          {
            'id': 2,
            'username': 'manoyitahieh',
            'watched_count': 2119,
            'content': '不错。喜欢上下双洞齐插的',
            'likes_count': 8,
            'created_at': '2015-05-22',
          },
        ],
      },
    },
    {
      'success': 1,
      'data': {
        'reviews': [
          {
            'id': 3,
            'username': 'recent-user',
            'watched_count': 91,
            'score': 10,
            'content': '最新短评内容',
            'likes_count': 3,
            'created_at': '2025-02-08',
          },
        ],
      },
    },
  ]);
  adapter.enqueue(Endpoints.listsRelated, {
    'success': 1,
    'data': {
      'lists': [
        {
          'id': 'list-1',
          'name': '测试相关清单',
          'movies_count': 12,
          'views_count': 34,
        },
        {
          'id': 'list-2',
          'name': '第二个相关清单',
          'movies_count': 3,
          'views_count': 4,
        },
      ],
    },
  });
}

void _enqueueMinimalDetail(FakeAdapter adapter) {
  adapter.enqueue('/api/v4/movies/m1', {
    'success': 1,
    'data': {
      'movie': {
        'id': 'm1',
        'number': 'SSIS-001',
        'title': '测试影片',
        'cover_url': 'covers/test.jpg',
        'actors': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      },
    },
  });
  adapter.enqueue('/api/v1/movies/m1/reviews', {
    'success': 1,
    'data': {'reviews': <Map<String, dynamic>>[]},
  });
}

GoRouter _buildMovieDetailRouter({ValueChanged<Object?>? onPreviewExtra}) {
  return GoRouter(
    initialLocation: '/movie/m1',
    routes: [
      GoRoute(
        path: '/movie/:id/preview',
        builder: (_, state) {
          onPreviewExtra?.call(state.extra);
          return const Scaffold(body: Center(child: Text('预告播放页')));
        },
      ),
      GoRoute(
        path: AppRoutes.movieDetail,
        builder: (_, state) => MovieDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.commonList,
        builder: (_, state) {
          final query = state.uri.queryParameters;
          return CommonListPage(
            title: query['title'] ?? '',
            type: int.tryParse(query['type'] ?? '') ?? 0,
            category: query['category'] ?? '',
            id: query['id'] ?? '',
            dataSource: const UnavailableTagMoviesDataSource(),
          );
        },
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MovieDetailPage 主详情成功时附属接口失败不影响渲染', (tester) async {
    final adapter = await _setupApiClient();
    adapter.enqueue('/api/v4/movies/m1', {
      'success': 1,
      'data': {
        'movie': {
          'id': 'm1',
          'number': 'SSIS-001',
          'title': '测试影片',
          'cover_url': 'covers/test.jpg',
          'actors': [],
          'tags': [
            {'name': '剧情'},
          ],
        },
      },
    });

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('测试影片'), findsOneWidget);
    expect(find.text('番号:'), findsOneWidget);
    expect(find.text('SSIS-001'), findsOneWidget);
    final innerScrollable = find
        .descendant(
          of: find.byType(TabBarView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('剧情'),
      200,
      scrollable: innerScrollable,
    );
    expect(find.text('剧情'), findsOneWidget);
  });

  testWidgets('有预告片时封面入口位于第一项并具有播放语义', (tester) async {
    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(
      adapter,
      previewVideoUrl: 'https://media.example.com/preview.m3u8',
    );

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final innerScrollable = find
        .descendant(
          of: find.byType(TabBarView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('预告片 / 剧照'),
      300,
      scrollable: innerScrollable,
    );

    final preview = find.byKey(const Key('movie-detail-preview'));
    final playIcon = find.byKey(const Key('movie-detail-preview-play-icon'));
    final firstScreenshot = find.byKey(const Key('movie-detail-screenshot-0'));
    expect(preview, findsOneWidget);
    expect(playIcon, findsOneWidget);
    expect(firstScreenshot, findsOneWidget);
    expect(
      tester.getTopLeft(preview).dx,
      lessThan(tester.getTopLeft(firstScreenshot).dx),
    );
    expect(find.bySemanticsLabel('播放《测试影片》预告片'), findsOneWidget);
  });

  testWidgets('只有预告片时仍显示预告片剧照区域', (tester) async {
    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(
      adapter,
      previewVideoUrl: 'https://media.example.com/preview.m3u8',
      previewImages: const [],
    );

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final innerScrollable = find
        .descendant(
          of: find.byType(TabBarView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    final preview = find.byKey(const Key('movie-detail-preview'));
    await _scrollUntilFound(
      tester,
      target: preview,
      scrollable: innerScrollable,
    );

    expect(find.text('预告片 / 剧照'), findsOneWidget);
    expect(preview, findsOneWidget);
    expect(find.byType(MovieScreenshotImage), findsNothing);
  });

  testWidgets('没有预告片时保持普通剧照列表', (tester) async {
    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(adapter);

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final innerScrollable = find
        .descendant(
          of: find.byType(TabBarView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('movie-detail-screenshot-1')),
      300,
      scrollable: innerScrollable,
    );

    expect(find.byKey(const Key('movie-detail-preview')), findsNothing);
    expect(find.byKey(const Key('movie-detail-screenshot-0')), findsOneWidget);
    expect(find.byKey(const Key('movie-detail-screenshot-1')), findsOneWidget);
  });

  testWidgets('点击预告入口传递播放参数', (tester) async {
    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(
      adapter,
      previewVideoUrl:
          'https://media.example.com/preview.m3u8?sign=a%2Bb%3Dc&t=123',
    );
    Object? capturedArgs;
    final router = _buildMovieDetailRouter(
      onPreviewExtra: (extra) => capturedArgs = extra,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final innerScrollable = find
        .descendant(
          of: find.byType(TabBarView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    final preview = find.byKey(const Key('movie-detail-preview'));
    await _scrollUntilFound(
      tester,
      target: preview,
      scrollable: innerScrollable,
    );
    expect(preview, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(preview), alignment: 0.5);
    await tester.pump();
    await tester.tap(preview);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.state.uri.path, '/movie/m1/preview');
    expect(capturedArgs, isA<MoviePreviewArgs>());
    final args = capturedArgs! as MoviePreviewArgs;
    expect(args.movieId, 'm1');
    expect(args.title, '测试影片');
    expect(
      args.videoUrl,
      'https://jdforrepam.com/preview.m3u8?sign=a%2Bb%3Dc&t=123',
    );
  });

  for (final target in [
    (
      label: '番号',
      value: 'SSIS-001',
      title: '番号 - SSIS',
      category: 'c',
      id: 'SSIS',
    ),
    (
      label: '导演',
      value: '测试&导演#1',
      title: '导演 - 测试&导演#1',
      category: 'd',
      id: 'director-1',
    ),
    (
      label: '片商',
      value: '测试片商',
      title: '片商 - 测试片商',
      category: 'm',
      id: 'maker-1',
    ),
    (
      label: '发行商',
      value: '测试发行商',
      title: '发行商 - 测试发行商',
      category: 'p',
      id: 'publisher-1',
    ),
    (
      label: '系列',
      value: '测试系列',
      title: '系列 - 测试系列',
      category: 's',
      id: 'series-1',
    ),
  ]) {
    testWidgets('点击${target.label}经 router 打开对应通用列表并可返回', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = await _setupApiClient();
      _enqueueCompleteMovieDetail(adapter);
      final router = _buildMovieDetailRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpUntilText(tester, target.value);
      final label = find.text('${target.label}:');
      final value = find.text(target.value);
      expect(label, findsOneWidget);
      expect(value, findsOneWidget);
      expect(
        find.ancestor(of: label, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.ancestor(of: value, matching: find.byType(InkWell)),
        findsOneWidget,
      );
      final colorScheme = Theme.of(tester.element(value)).colorScheme;
      expect(tester.widget<Text>(label).style?.color, colorScheme.onSurface);
      final valueStyle = tester.widget<Text>(value).style;
      expect(valueStyle?.color, colorScheme.onSurface);
      expect(valueStyle?.decoration, TextDecoration.underline);
      expect(
        find.bySemanticsLabel('查看${target.value}的${target.label}影片列表'),
        findsOneWidget,
      );
      await tester.ensureVisible(value);
      await tester.tap(value);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(router.state.uri.path, AppRoutes.commonList);
      expect(router.state.uri.queryParameters, {
        'title': target.title,
        'type': '1',
        'category': target.category,
        'id': target.id,
      });
      final page = tester.widget<CommonListPage>(find.byType(CommonListPage));
      expect(page.title, target.title);
      expect(page.type, 1);
      expect(page.category, target.category);
      expect(page.id, target.id);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.state.uri.path, '/movie/m1');
      expect(find.text('${target.label}:'), findsOneWidget);
      expect(find.text(target.value), findsOneWidget);
    });
  }

  testWidgets('点击带 ID 的类别经 router 打开通用列表并可返回', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(adapter);
    final router = _buildMovieDetailRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _pumpUntilText(tester, '剧情&爱情#1');

    final chip = tester.widget<TagChip>(
      find.ancestor(of: find.text('剧情&爱情#1'), matching: find.byType(TagChip)),
    );
    expect(chip.onTap, isNotNull);

    await tester.ensureVisible(find.text('剧情&爱情#1'));
    await tester.tap(find.text('剧情&爱情#1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters, {
      'title': '类别 - 剧情&爱情#1',
      'type': '1',
      'category': 't',
      'id': 'tag-1',
    });
    final page = tester.widget<CommonListPage>(find.byType(CommonListPage));
    expect(page.title, '类别 - 剧情&爱情#1');
    expect(page.type, 1);
    expect(page.category, 't');
    expect(page.id, 'tag-1');

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.state.uri.path, '/movie/m1');
    expect(find.text('剧情&爱情#1'), findsOneWidget);
  });

  testWidgets('缺少 ID 的类别仍展示但不可点击', (tester) async {
    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(adapter);
    final router = _buildMovieDetailRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _pumpUntilText(tester, '漫画游戏改编');

    final chipFinder = find.byWidgetPredicate(
      (widget) => widget is TagChip && widget.label == '漫画游戏改编',
      skipOffstage: false,
    );
    final chip = tester.widget<TagChip>(chipFinder);
    expect(chip.onTap, isNull);
    expect(router.state.uri.path, '/movie/m1');
  });

  testWidgets('基础信息缺少实体 ID 时保留文本且不可点击', (tester) async {
    final adapter = await _setupApiClient();
    adapter.enqueue('/api/v4/movies/m1', {
      'success': 1,
      'data': {
        'movie': {
          'id': 'm1',
          'number': 'SSIS-001',
          'title': '测试影片',
          'cover_url': '',
          'director_name': '测试导演',
          'maker_name': '测试片商',
          'publisher_name': '测试发行商',
          'series_name': '测试系列',
        },
      },
    });
    final router = _buildMovieDetailRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _pumpUntilText(tester, 'SSIS-001');

    for (final item in [
      (label: '番号', value: 'SSIS-001'),
      (label: '导演', value: '测试导演'),
      (label: '片商', value: '测试片商'),
      (label: '发行商', value: '测试发行商'),
      (label: '系列', value: '测试系列'),
    ]) {
      final label = find.text('${item.label}:');
      final value = find.text(item.value);
      expect(label, findsOneWidget);
      expect(value, findsOneWidget);
      expect(
        find.ancestor(of: label, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.ancestor(of: value, matching: find.byType(InkWell)),
        findsNothing,
      );
      await tester.ensureVisible(value);
      await tester.tap(value);
      await tester.pump();
      expect(router.state.uri.path, '/movie/m1');
    }
  });

  testWidgets('320px 暗色大字体下非空演员区域不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adapter = await _setupApiClient();
    adapter.enqueue('/api/v4/movies/m1', {
      'success': 1,
      'data': {
        'movie': {
          'id': 'm1',
          'number': 'A-1',
          'title': '测试影片',
          'cover_url': '',
          'actors': [
            {'id': 'a1', 'name': '很长很长的演员名称', 'avatar_url': ''},
          ],
          'tags': <Map<String, dynamic>>[],
        },
      },
    });
    adapter.enqueue('/api/v1/movies/m1/reviews', {
      'success': 1,
      'data': {'reviews': <Map<String, dynamic>>[]},
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const MovieDetailPage(id: 'm1'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ActorCard), findsOneWidget);
    expect(find.text('很长很长的演员名称'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('影片详情按参考顺序展示且正文不被常驻抽屉遮挡', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(adapter);

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byType(NestedScrollView), findsOneWidget);
    final pinnedHeader = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(pinnedHeader.pinned, isTrue);

    const tabLabels = ['基本信息', '磁链下载', '短评', '相关清单'];
    for (final label in tabLabels) {
      expect(find.text(label), findsOneWidget);
    }

    final tabBar = find.byKey(const Key('movie-detail-tab-bar'));
    expect(tabBar, findsOneWidget);
    expect(
      find.ancestor(of: tabBar, matching: find.byType(Card)),
      findsNothing,
    );
    expect(
      tester.getTopLeft(tabBar).dy,
      greaterThan(tester.getTopLeft(find.byType(MovieCoverImage)).dy),
    );

    expect(find.text('番号:'), findsOneWidget);
    expect(find.text('SSIS-001'), findsOneWidget);
    expect(find.text('4.33'), findsOneWidget);
    expect(find.text('4.3'), findsNothing);
    expect(find.text('类别:'), findsOneWidget);
    expect(find.byType(StarRating), findsOneWidget);
    expect(tester.takeException(), isNull);

    final infoColumn = tester.widget<Column>(
      find.byKey(const Key('movie-detail-info-column')),
    );
    expect(infoColumn.spacing, 6);
    final actionsDivider = tester.widget<Divider>(
      find.byKey(const Key('movie-detail-actions-divider')),
    );
    expect(actionsDivider.height, 12);

    final actions = find.byKey(const Key('movie-detail-actions'));
    expect(actions, findsOneWidget);
    expect(
      find.descendant(of: actions, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    expect(find.text('想看'), findsNothing);
    expect(find.text('看过'), findsNothing);
    expect(find.text('存入清单'), findsOneWidget);
    for (final button in tester.widgetList<FilledButton>(
      find.descendant(of: actions, matching: find.byType(FilledButton)),
    )) {
      expect(button.style?.minimumSize?.resolve({}), const Size(0, 32));
      expect(button.style?.visualDensity, VisualDensity.compact);
      expect(
        button.style?.padding?.resolve({}),
        const EdgeInsets.symmetric(horizontal: 12),
      );
    }

    final categoryChip = tester.widget<TagChip>(
      find
          .descendant(
            of: find.byKey(const Key('movie-detail-categories')),
            matching: find.byType(TagChip),
          )
          .first,
    );
    expect(categoryChip.compact, isTrue);
    final categoryScroller = tester.widget<Scrollable>(
      find
          .descendant(
            of: find.byKey(const Key('movie-detail-categories')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(categoryScroller.axisDirection, AxisDirection.right);
    expect(
      find.descendant(
        of: find.byKey(const Key('movie-detail-categories')),
        matching: find.byType(Scrollbar),
      ),
      findsNothing,
    );

    final innerScrollable = find
        .descendant(
          of: find.byType(TabBarView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('演员'),
      300,
      scrollable: innerScrollable,
    );
    expect(find.text('演员'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('movie-detail-screenshot-1')),
      300,
      scrollable: innerScrollable,
    );
    expect(find.text('预告片 / 剧照'), findsOneWidget);
    expect(find.text('全部 2 ›'), findsNothing);
    expect(find.byType(MovieScreenshotImage), findsNWidgets(2));

    await tester.scrollUntilVisible(
      find.text('ACT-001'),
      500,
      scrollable: innerScrollable,
    );
    expect(find.text('TA还出演过'), findsOneWidget);
    expect(find.text('ACT-001'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('REL-001'),
      500,
      scrollable: innerScrollable,
    );
    expect(find.text('你可能也喜欢'), findsOneWidget);
    expect(find.text('REL-001'), findsOneWidget);
    for (final card in tester.widgetList<MovieCard>(find.byType(MovieCard))) {
      expect(card.showTitle, isFalse);
    }
    expect(
      adapter.requests.where(
        (request) => request.path == Endpoints.moviesMayAlsoLike,
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('磁链下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('测试磁链.torrent'), findsOneWidget);
    expect(find.text('高清'), findsOneWidget);
    expect(find.text('1 个文件 / 9.68 GB'), findsOneWidget);
    expect(find.text('2026-07-22'), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('测试磁链.torrent')).dy,
      lessThan(tester.getBottomLeft(tabBar).dy + 30),
    );
    final magnetDividers = tester.widgetList<Divider>(find.byType(Divider));
    expect(magnetDividers, hasLength(1));
    expect(magnetDividers.single.height, 1);
    expect(magnetDividers.single.indent, 16);
    expect(magnetDividers.single.endIndent, 16);

    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final firstMagnetTile = find.ancestor(
      of: find.text('测试磁链.torrent'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(firstMagnetTile).onTap!();
    await tester.pump();
    expect(clipboardCall?.arguments, {'text': 'magnet:?xt=urn:btih:hash-1'});
    expect(find.text('磁力链接已复制'), findsOneWidget);

    await tester.tap(find.text('短评'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('最热'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('最热')).dy,
      lessThan(tester.getBottomLeft(tabBar).dy + 24),
    );
    expect(find.text('reequasew'), findsOneWidget);
    expect(find.text('看过2060部影片'), findsOneWidget);
    expect(find.text('两大女优的联手果然是很震撼的'), findsOneWidget);
    expect(find.text('manoyitahieh'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('2016-09-24'), findsOneWidget);
    expect(find.byType(StarRating), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    var reviewDividers = tester.widgetList<Divider>(find.byType(Divider));
    expect(reviewDividers, hasLength(2));
    for (final divider in reviewDividers) {
      expect(divider.height, 1);
      expect(divider.indent, 16);
      expect(divider.endIndent, 16);
    }
    expect(
      adapter.requests
          .where((request) => request.path == '/api/v1/movies/m1/reviews')
          .first
          .uri
          .queryParameters['sort_by'],
      'hotly',
    );

    adapter.responseDelay = const Duration(milliseconds: 200);
    final recentlyButton = find.ancestor(
      of: find.text('最新'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(recentlyButton).onTap!();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final disabledSortControl = tester.widgetList<SegmentedButton>(
      find.byWidgetPredicate((widget) => widget is SegmentedButton),
    );
    expect(disabledSortControl.single.onSelectionChanged, isNull);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('最新短评内容'), findsOneWidget);
    expect(
      adapter.requests
          .where((request) => request.path == '/api/v1/movies/m1/reviews')
          .last
          .uri
          .queryParameters['sort_by'],
      'recently',
    );

    await tester.tap(find.text('相关清单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('测试相关清单'), findsOneWidget);
    expect(find.text('12 部影片，被查看 34 次'), findsOneWidget);
    expect(find.byType(ListSummaryTile), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('测试相关清单')).dy,
      lessThan(tester.getBottomLeft(tabBar).dy + 30),
    );
    final relatedDividers = tester.widgetList<Divider>(find.byType(Divider));
    expect(relatedDividers, hasLength(1));
    expect(relatedDividers.single.height, 1);
    expect(relatedDividers.single.indent, 16);
    expect(relatedDividers.single.endIndent, 16);
  });

  testWidgets('点击存入清单打开弹窗并按 has_movie 勾选清单', (tester) async {
    _mockPathProvider(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(adapter);
    adapter.enqueue(Endpoints.listsSimple, {
      'success': 1,
      'data': {
        'lists': [
          {
            'id': 'list-1',
            'name': '已加入清单',
            'movies_count': 2,
            'views_count': 10,
            'has_movie': true,
          },
          {
            'id': 'list-2',
            'name': '未加入清单',
            'movies_count': 0,
            'views_count': 1,
            'has_movie': false,
          },
        ],
      },
    });

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    adapter.responseDelay = const Duration(milliseconds: 200);
    await tester.tap(find.byKey(const Key('movie-save-to-list-button')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const Key('movie-save-to-list-loading-overlay')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-list-name-field')), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);

    await _pumpUntilRequest(tester, adapter, Endpoints.listsSimple);
    await _pumpUntilText(tester, '已加入清单');
    expect(
      find.byKey(const Key('movie-save-to-list-loading-overlay')),
      findsNothing,
    );

    final simpleRequest = adapter.requests.lastWhere(
      (request) => request.path == Endpoints.listsSimple,
    );
    expect(simpleRequest.uri.queryParameters['movie_id'], 'm1');
    expect(simpleRequest.uri.queryParameters['page'], '1');
    expect(simpleRequest.uri.queryParameters['limit'], '48');
    expect(find.text('已加入清单'), findsOneWidget);
    expect(find.text('未加入清单'), findsOneWidget);

    final checked = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('已加入清单'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    final unchecked = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('未加入清单'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(checked.value, isTrue);
    expect(unchecked.value, isFalse);
  });

  testWidgets('存入清单 simple 接口未登录时触发全局认证处理且不打开弹窗', (tester) async {
    _mockPathProvider(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var authCalled = false;
    final adapter = await _setupApiClient(onAuthError: () => authCalled = true);
    _enqueueCompleteMovieDetail(adapter);
    adapter.enqueue(Endpoints.listsSimple, {
      'success': 0,
      'action': 'JWTVerificationError',
      'message': '請登錄帳號',
    }, statusCode: 401);
    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('movie-save-to-list-button')));
    await _pumpUntilRequest(tester, adapter, Endpoints.listsSimple);
    await tester.pump();

    expect(find.byKey(const Key('movie-list-name-field')), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(authCalled, isTrue);
  });

  testWidgets('在清单弹窗中切换清单并创建新清单', (tester) async {
    _mockPathProvider(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(adapter);
    adapter.enqueueSequence(Endpoints.listsSimple, [
      {
        'success': 1,
        'data': {
          'lists': [
            {
              'id': 'list-1',
              'name': '未加入清单',
              'movies_count': 0,
              'views_count': 1,
              'has_movie': false,
            },
          ],
        },
      },
      {
        'success': 1,
        'data': {
          'lists': [
            {
              'id': 'list-2',
              'name': '新清单',
              'movies_count': 1,
              'views_count': 0,
              'has_movie': true,
            },
          ],
        },
      },
    ]);
    adapter.enqueue('${Endpoints.lists}/list-1/movie_actions', {
      'success': 1,
      'data': {},
    });
    adapter.enqueue(Endpoints.lists, {'success': 1, 'data': {}});

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('movie-save-to-list-button')));
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpUntilRequest(tester, adapter, Endpoints.listsSimple);
    await tester.pump();

    final listTile = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('未加入清单'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    listTile.onChanged!(true);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final toggleRequest = adapter.requests.last;
    expect(toggleRequest.path, '${Endpoints.lists}/list-1/movie_actions');
    expect(toggleRequest.method, 'POST');

    await tester.enterText(
      find.byKey(const Key('movie-list-name-field')),
      '新清单',
    );
    await tester.tap(find.byKey(const Key('movie-list-create-button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      adapter.requests.any(
        (request) =>
            request.method == 'POST' && request.path == Endpoints.lists,
      ),
      isTrue,
    );
    expect(find.text('新清单'), findsOneWidget);
  });

  testWidgets('磁链失败可独立重试且不重新请求主详情和相关清单', (tester) async {
    final adapter = await _setupApiClient();
    _enqueueMinimalDetail(adapter);
    adapter.enqueueSequence(
      '/api/v1/movies/m1/magnets',
      [
        {'success': 0, 'message': '磁链失败'},
        {
          'success': 1,
          'data': {
            'magnets': [
              {'hash': 'retry-hash', 'name': '磁链重试成功', 'size': 100},
            ],
          },
        },
      ],
      codes: [500, 200],
    );
    adapter.enqueue(Endpoints.listsRelated, {
      'success': 1,
      'data': {'lists': <Map<String, dynamic>>[]},
    });

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('磁链下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('磁链加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('磁链重试成功'), findsOneWidget);
    expect(
      adapter.requests.where(
        (request) => request.path == '/api/v1/movies/m1/magnets',
      ),
      hasLength(2),
    );
    expect(
      adapter.requests.where(
        (request) => request.path == Endpoints.listsRelated,
      ),
      hasLength(1),
    );
    expect(
      adapter.requests.where((request) => request.path == '/api/v4/movies/m1'),
      hasLength(1),
    );
  });

  testWidgets('相关清单失败可独立重试且不重新请求主详情和磁链', (tester) async {
    final adapter = await _setupApiClient();
    _enqueueMinimalDetail(adapter);
    adapter.enqueue('/api/v1/movies/m1/magnets', {
      'success': 1,
      'data': {'magnets': <Map<String, dynamic>>[]},
    });
    adapter.enqueueSequence(
      Endpoints.listsRelated,
      [
        {'success': 0, 'message': '清单失败'},
        {
          'success': 1,
          'data': {
            'lists': [
              {
                'id': 'retry-list',
                'name': '清单重试成功',
                'movies_count': 2,
                'views_count': 3,
              },
            ],
          },
        },
      ],
      codes: [500, 200],
    );

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('相关清单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('相关清单加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('清单重试成功'), findsOneWidget);
    expect(
      adapter.requests.where(
        (request) => request.path == Endpoints.listsRelated,
      ),
      hasLength(2),
    );
    expect(
      adapter.requests.where(
        (request) => request.path == '/api/v1/movies/m1/magnets',
      ),
      hasLength(1),
    );
    expect(
      adapter.requests.where((request) => request.path == '/api/v4/movies/m1'),
      hasLength(1),
    );
  });

  testWidgets('从第二张剧照打开 PhotoView 图库并可翻页关闭', (tester) async {
    _mockPathProvider(tester);
    final adapter = await _setupApiClient();
    _enqueueCompleteMovieDetail(
      adapter,
      previewVideoUrl: 'https://media.example.com/preview.m3u8',
    );

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final innerScrollable = find
        .descendant(
          of: find.byType(TabBarView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('预告片 / 剧照'),
      300,
      scrollable: innerScrollable,
    );
    final secondScreenshot = find.byKey(const Key('movie-detail-screenshot-1'));
    expect(secondScreenshot, findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(secondScreenshot),
      alignment: 0.5,
    );
    await tester.pump();

    await tester.tap(secondScreenshot);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('image-gallery-viewer')), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byType(PhotoViewGallery), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);

    final currentScreenshot = find.byKey(const Key('image-gallery-page-1'));
    expect(currentScreenshot, findsOneWidget);
    final currentPhotoView = find.ancestor(
      of: currentScreenshot,
      matching: find.byType(PhotoView),
    );
    expect(currentPhotoView, findsOneWidget);
    final controller = tester.widget<PhotoView>(currentPhotoView).controller!;
    final initialScale = controller.value.scale!;
    expect(initialScale, closeTo(0.5, 0.01));

    Future<void> doubleTapScreenshot() async {
      await tester.tap(currentPhotoView);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(currentPhotoView);
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await doubleTapScreenshot();

    expect(controller.value.scale, closeTo(initialScale * 2, 0.01));

    await doubleTapScreenshot();

    expect(controller.value.scale, closeTo(initialScale, 0.01));

    await tester.drag(find.byType(PhotoViewGallery), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('image-gallery-viewer')), findsNothing);
  });
}
