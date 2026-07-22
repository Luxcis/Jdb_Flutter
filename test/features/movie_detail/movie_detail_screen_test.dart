import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/storage/storage_keys.dart';
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
        'score': 4.2,
        'want_watch_count': 12,
        'watched_count': 8,
        'actors': [
          {'id': 'a1', 'name': '测试演员', 'avatar_url': 'actors/test.jpg'},
        ],
        'preview_images': [
          {'url': 'screenshots/test.jpg'},
        ],
        'tags': [
          {'name': '剧情'},
        ],
      },
    },
  });
  adapter.enqueue('/api/v1/movies/m1/magnets', {
    'success': 1,
    'data': {'magnets': <Map<String, dynamic>>[]},
  });
  adapter.enqueue('/api/v1/movies/m1/reviews', {
    'success': 1,
    'data': {'reviews': <Map<String, dynamic>>[]},
  });
  adapter.enqueue('/api/v1/movies/may_also_like', {
    'success': 1,
    'data': {
      'movies': [
        {
          'id': 'm2',
          'number': 'ABC-001',
          'title': '推荐影片',
          'cover_url': 'covers/recommended.jpg',
        },
      ],
    },
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
    expect(find.text('番号: SSIS-001'), findsOneWidget);
    expect(find.text('类别:'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('预告片 / 剧照'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('预告片 / 剧照'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('你可能也喜欢'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TA还出演过'), findsOneWidget);
    expect(find.text('你可能也喜欢'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
