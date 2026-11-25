import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/actors/screens/actor_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpTokenProvider implements TokenProvider {
  const _NoOpTokenProvider();

  @override
  String? get token => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeAdapter> setupAdapter() async {
    final prefs = await SharedPreferences.getInstance();
    // ActorDetailScreen 通过 instanceOrNull 读取单例，必须走 create。
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: const _NoOpTokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    return adapter;
  }

  void enqueueActorDetail(FakeAdapter adapter) {
    adapter.enqueue('${Endpoints.actors}/a1', {
      'success': 1,
      'data': {
        'actor': {
          'id': 'a1',
          'name': '三上悠亜',
          'avatar': '',
          'type': 0,
          'age': 25,
          'movie_count': 12,
        },
        'has_collected': false,
        'filter_tags': [
          {'id': 'f1', 'name': '名称筛选', 'videos_count': 2},
        ],
        'tags': [
          {'id': 't1', 'name': '巨乳', 'videos_count': 64},
        ],
      },
    });
  }

  void enqueueMovies(FakeAdapter adapter) {
    adapter.enqueue(Endpoints.moviesTags, {
      'success': 1,
      'data': {
        'movies': [
          {'id': 'm1', 'number': 'M-1', 'title': '影片一', 'cover_url': ''},
        ],
        'current_page': 1,
        'total_pages': 1,
      },
    });
  }

  // 页面含 CachedImage 头像，占位 spinner 永不停止，用有界 pump 序列推进。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpDetailPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ActorDetailScreen(id: 'a1')),
    );
    await settle(tester);
  }

  Future<void> openFilterSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('筛选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  List<RequestOptions> movieRequests(FakeAdapter adapter) => adapter.requests
      .where((request) => request.path == Endpoints.moviesTags)
      .toList();

  testWidgets('点击筛选勾选标签后按 filter_by_tags 重新请求影片', (tester) async {
    final adapter = await setupAdapter();
    enqueueActorDetail(adapter);
    enqueueMovies(adapter);

    await pumpDetailPage(tester);
    expect(find.text('影片一'), findsOneWidget);
    expect(
      movieRequests(
        adapter,
      ).single.uri.queryParameters.containsKey('filter_by_tags'),
      isFalse,
    );

    await openFilterSheet(tester);
    expect(find.text('名称筛选'), findsOneWidget);
    expect(find.text('巨乳(64)'), findsOneWidget);

    await tester.tap(find.text('巨乳(64)'));
    await settle(tester);

    final requests = adapter.requests
        .where((request) => request.path == Endpoints.moviesTags)
        .toList();
    expect(requests, hasLength(2));
    final query = requests.last.uri.queryParameters;
    expect(query['filter_by'], '0:a:a1');
    expect(query['filter_by_tags'], 't1');
    expect(query['page'], '1');
  });

  testWidgets('筛选面板取消勾选后不再携带 filter_by_tags', (tester) async {
    final adapter = await setupAdapter();
    enqueueActorDetail(adapter);
    enqueueMovies(adapter);

    await pumpDetailPage(tester);
    await openFilterSheet(tester);

    await tester.tap(find.text('巨乳(64)'));
    await settle(tester);
    await tester.tap(find.text('巨乳(64)'));
    await settle(tester);

    final requests = adapter.requests
        .where((request) => request.path == Endpoints.moviesTags)
        .toList();
    expect(requests, hasLength(3));
    expect(requests[1].uri.queryParameters['filter_by_tags'], 't1');
    expect(
      requests.last.uri.queryParameters.containsKey('filter_by_tags'),
      isFalse,
    );
  });

  testWidgets('点击更多信息展示 -- 占位符与 N 岁后缀', (tester) async {
    final adapter = await setupAdapter();
    enqueueActorDetail(adapter);
    enqueueMovies(adapter);

    await pumpDetailPage(tester);

    await tester.tap(find.text('更多信息'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('12 部影片'), findsOneWidget);
    expect(find.text('25 岁'), findsOneWidget);
    // 生日/出生地/罩杯/胸围/腰围/臀围缺失时统一展示 --。
    expect(find.text('--'), findsWidgets);
  });
}
