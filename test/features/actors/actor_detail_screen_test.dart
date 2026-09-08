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
    // ActorDetailPage 通过 instanceOrNull 读取单例，必须走 create 而非 forTest。
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: const _NoOpTokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    return adapter;
  }

  void enqueueActorDetail(FakeAdapter adapter, {required bool hasCollected}) {
    adapter.enqueue('${Endpoints.actors}/a1', {
      'success': 1,
      'data': {
        'actor': {'id': 'a1', 'name': '三上悠亜', 'avatar': '', 'type': 0},
        'has_collected': hasCollected,
        'filter_tags': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      },
    });
  }

  void enqueueEmptyMovies(FakeAdapter adapter) {
    adapter.enqueue(Endpoints.moviesTags, {
      'success': 1,
      'data': {
        'movies': <Map<String, dynamic>>[],
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
    await tester.pumpWidget(const MaterialApp(home: ActorDetailPage(id: 'a1')));
    await settle(tester);
  }

  testWidgets('已收藏演员进入详情页心形初始为实心', (tester) async {
    final adapter = await setupAdapter();
    enqueueActorDetail(adapter, hasCollected: true);
    enqueueEmptyMovies(adapter);

    await pumpDetailPage(tester);

    expect(find.text('三上悠亜'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('点击空心收藏按钮后请求成功并切换为实心', (tester) async {
    final adapter = await setupAdapter();
    enqueueActorDetail(adapter, hasCollected: false);
    enqueueEmptyMovies(adapter);
    adapter.enqueue('${Endpoints.actors}/a1/collect_actions', {
      'success': 1,
      'data': null,
    });

    await pumpDetailPage(tester);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byTooltip('收藏'));
    await settle(tester);

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('已收藏'), findsOneWidget);

    final request = adapter.requests.singleWhere(
      (r) => r.path == '${Endpoints.actors}/a1/collect_actions',
    );
    expect(request.method, 'POST');
    expect(request.data, isA<FormData>());
    expect(
      Map.fromEntries((request.data as FormData).fields),
      {'name': 'collect'},
    );
  });

  testWidgets('点击实心收藏按钮后取消收藏并切换为空心', (tester) async {
    final adapter = await setupAdapter();
    enqueueActorDetail(adapter, hasCollected: true);
    enqueueEmptyMovies(adapter);
    adapter.enqueue('${Endpoints.actors}/a1/collect_actions', {
      'success': 1,
      'data': null,
    });

    await pumpDetailPage(tester);

    await tester.tap(find.byTooltip('取消收藏'));
    await settle(tester);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('已取消收藏'), findsOneWidget);

    final request = adapter.requests.singleWhere(
      (r) => r.path == '${Endpoints.actors}/a1/collect_actions',
    );
    expect(
      Map.fromEntries((request.data as FormData).fields),
      {'name': 'uncollect'},
    );
  });

  testWidgets('收藏请求失败时状态不切换并提示', (tester) async {
    final adapter = await setupAdapter();
    enqueueActorDetail(adapter, hasCollected: false);
    enqueueEmptyMovies(adapter);
    adapter.throwFirst(
      '${Endpoints.actors}/a1/collect_actions',
      DioException(
        requestOptions: RequestOptions(
          path: '${Endpoints.actors}/a1/collect_actions',
        ),
        error: 'ParameterInvalid: name',
      ),
    );

    await pumpDetailPage(tester);

    await tester.tap(find.byTooltip('收藏'));
    await settle(tester);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.text('操作失败，请重试'), findsOneWidget);
  });
}
