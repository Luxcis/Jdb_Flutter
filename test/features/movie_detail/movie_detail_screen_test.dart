import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_screenshot_image.dart';
import 'package:jade/core/widgets/star_rating.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/screens/movie_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

Future<FakeAdapter> _setupApiClient() async {
  final adapter = FakeAdapter();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.baseUrl, 'https://jdforrepam.com');
  await prefs.setStringList(StorageKeys.apiDomains, ['https://jdforrepam.com']);
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TokenProvider(),
    onAuthError: () {},
  );
  api.setAdapterForTest(adapter);
  return adapter;
}

void _enqueueCompleteMovieDetail(FakeAdapter adapter) {
  adapter.enqueue('/api/v4/movies/m1', {
    'success': 1,
    'data': {
      'movie': {
        'id': 'm1',
        'number': 'SSIS-001',
        'title': '测试影片',
        'cover_url': 'covers/test.jpg',
        'release_date': '2026-07-22',
        'duration': 120,
        'director': '测试导演',
        'maker': '测试片商',
        'series': '测试系列',
        'score': '4.33',
        'want_watch_count': 12,
        'watched_count': 8,
        'actors': [
          {'id': 'a1', 'name': '测试演员', 'avatar_url': 'actors/test.jpg'},
        ],
        'preview_images': [
          {'url': 'screenshots/test.jpg'},
        ],
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
          {'name': '剧情'},
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
    expect(find.text('番号: SSIS-001'), findsOneWidget);
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

    expect(find.text('番号: SSIS-001'), findsOneWidget);
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
      findsNWidgets(3),
    );
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
      find.text('预告片 / 剧照'),
      300,
      scrollable: innerScrollable,
    );
    expect(find.text('预告片 / 剧照'), findsOneWidget);
    expect(find.byType(MovieScreenshotImage), findsOneWidget);

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

    await tester.tap(find.text('最新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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
}
