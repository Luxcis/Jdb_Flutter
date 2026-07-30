import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/features/actors/screens/actors_screen.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({ActorService service, FakeAdapter adapter})>
createActorService() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(prefs);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (service: ActorService(api), adapter: adapter);
}

void enqueueEmptyRecommend(FakeAdapter adapter) {
  adapter.enqueue(Endpoints.actorsRecommend, {
    'success': 1,
    'data': {
      'new_actors': <Map<String, dynamic>>[],
      'monthly_actors': <Map<String, dynamic>>[],
      'recommend_actors': <Map<String, dynamic>>[],
    },
  });
}

void enqueueEmptyActorPage(FakeAdapter adapter) {
  adapter.enqueue(Endpoints.actors, {
    'success': 1,
    'data': {'actors': <Map<String, dynamic>>[], 'current_page': 1},
  });
}

Future<void> pumpAsyncUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> switchTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await pumpAsyncUi(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('演员页展示设计需求中的六个 Tab', (tester) async {
    final fixture = await createActorService();
    enqueueEmptyRecommend(fixture.adapter);

    await tester.pumpWidget(
      MaterialApp(home: ActorsPage(service: fixture.service)),
    );
    await pumpAsyncUi(tester);

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('有码(女)'), findsOneWidget);
    expect(find.text('有码(男)'), findsOneWidget);
    expect(find.text('无码'), findsOneWidget);
    expect(find.text('欧美(女)'), findsOneWidget);
    expect(find.text('欧美(男)'), findsOneWidget);
  });

  testWidgets('未登录推荐页展示三个独立推荐分区', (tester) async {
    final fixture = await createActorService();
    fixture.adapter.enqueue(Endpoints.actorsRecommend, {
      'success': 1,
      'data': {
        'new_actors': [
          {'id': 'n1', 'name': '新人演员', 'avatar_url': ''},
        ],
        'monthly_actors': [
          {'id': 'm1', 'name': '月榜演员', 'avatar_url': ''},
        ],
        'recommend_actors': [
          {'id': 'd1', 'name': 'DMM演员', 'avatar_url': ''},
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(home: ActorsPage(service: fixture.service)),
    );
    await pumpAsyncUi(tester);

    expect(find.text('登录后可查看演员推荐'), findsNothing);
    expect(find.text('新人演员'), findsOneWidget);
    expect(find.text('月榜演员'), findsOneWidget);
    for (final actorName in ['新人演员', '月榜演员']) {
      expect(
        find.ancestor(
          of: find.text(actorName),
          matching: find.byType(ActorCard),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('全部'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    final trailing = tester.widget<InkWell>(
      find.ancestor(of: find.text('全部'), matching: find.byType(InkWell)),
    );
    expect(trailing.onTap, isNotNull);

    await tester.scrollUntilVisible(
      find.text('DMM演员'),
      300,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.ancestor(of: find.text('DMM演员'), matching: find.byType(ActorCard)),
      findsOneWidget,
    );
  });

  testWidgets('筛选入口仅在有码女显示并应用后重载第 1 页', (tester) async {
    final fixture = await createActorService();
    enqueueEmptyRecommend(fixture.adapter);
    enqueueEmptyActorPage(fixture.adapter);

    await tester.pumpWidget(
      MaterialApp(home: ActorsPage(service: fixture.service)),
    );
    await switchTab(tester, '有码(女)');

    expect(find.byTooltip('筛选演员'), findsOneWidget);
    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.actors,
      ),
      hasLength(1),
    );

    await tester.tap(find.byTooltip('筛选演员'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('年龄'), findsOneWidget);

    final ageSlider = tester.widget<RangeSlider>(
      find.byType(RangeSlider).first,
    );
    ageSlider.onChanged!(const RangeValues(20, 65));
    await tester.pump();
    await tester.ensureVisible(find.text('应用筛选'));
    await tester.tap(find.text('应用筛选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await pumpAsyncUi(tester);

    final actorRequests = fixture.adapter.requests
        .where((request) => request.path == Endpoints.actors)
        .toList();
    expect(actorRequests, hasLength(2));
    expect(actorRequests.last.uri.queryParameters['page'], '1');
    expect(actorRequests.last.uri.queryParameters['age'], '20,65');

    await switchTab(tester, '有码(男)');
    expect(find.byTooltip('筛选演员'), findsNothing);
  });

  testWidgets('关闭筛选或应用相等筛选不刷新列表', (tester) async {
    final fixture = await createActorService();
    enqueueEmptyRecommend(fixture.adapter);
    enqueueEmptyActorPage(fixture.adapter);

    await tester.pumpWidget(
      MaterialApp(home: ActorsPage(service: fixture.service)),
    );
    await switchTab(tester, '有码(女)');
    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.actors,
      ),
      hasLength(1),
    );

    await tester.tap(find.byTooltip('筛选演员'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byTooltip('筛选演员'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('应用筛选'));
    await tester.tap(find.text('应用筛选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await pumpAsyncUi(tester);

    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.actors,
      ),
      hasLength(1),
    );
  });

  testWidgets('筛选刷新期间保留原演员直到新第 1 页返回', (tester) async {
    final fixture = await createActorService();
    enqueueEmptyRecommend(fixture.adapter);
    fixture.adapter.enqueueSequence(Endpoints.actors, [
      {
        'success': 1,
        'data': {
          'actors': [
            {'id': 'old', 'name': '原演员', 'avatar_url': ''},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'actors': [
            {'id': 'new', 'name': '新演员', 'avatar_url': ''},
          ],
          'current_page': 1,
        },
      },
    ]);

    await tester.pumpWidget(
      MaterialApp(home: ActorsPage(service: fixture.service)),
    );
    await switchTab(tester, '有码(女)');
    expect(find.text('原演员'), findsOneWidget);

    fixture.adapter.responseDelay = const Duration(seconds: 1);
    await tester.tap(find.byTooltip('筛选演员'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final ageSlider = tester.widget<RangeSlider>(
      find.byType(RangeSlider).first,
    );
    ageSlider.onChanged!(const RangeValues(20, 65));
    await tester.pump();
    await tester.ensureVisible(find.text('应用筛选'));
    await tester.tap(find.text('应用筛选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('原演员'), findsOneWidget);
    expect(find.text('新演员'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await pumpAsyncUi(tester);
    expect(find.text('原演员'), findsNothing);
    expect(find.text('新演员'), findsOneWidget);
  });

  testWidgets('五个分类各自请求且切回时保留状态', (tester) async {
    final fixture = await createActorService();
    enqueueEmptyRecommend(fixture.adapter);
    enqueueEmptyActorPage(fixture.adapter);

    await tester.pumpWidget(
      MaterialApp(home: ActorsPage(service: fixture.service)),
    );

    for (final tab in ['有码(女)', '有码(男)', '无码', '欧美(女)', '欧美(男)']) {
      await switchTab(tester, tab);
    }

    final actorRequests = fixture.adapter.requests
        .where((request) => request.path == Endpoints.actors)
        .toList();
    expect(actorRequests, hasLength(5));
    expect(
      actorRequests
          .map(
            (request) =>
                '${request.uri.queryParameters['type']}:'
                '${request.uri.queryParameters['gender']}',
          )
          .toSet(),
      {'0:0', '0:1', '1:all', '2:0', '2:1'},
    );

    await switchTab(tester, '有码(女)');
    expect(
      fixture.adapter.requests.where(
        (request) => request.path == Endpoints.actors,
      ),
      hasLength(5),
    );
    expect(find.byTooltip('筛选演员'), findsOneWidget);
  });

  testWidgets('分类 Tab 切换后各自保留独立滚动位置', (tester) async {
    final fixture = await createActorService();
    enqueueEmptyRecommend(fixture.adapter);
    fixture.adapter.enqueue(Endpoints.actors, {
      'success': 1,
      'data': {
        'actors': List.generate(
          30,
          (index) => {
            'id': 'actor-$index',
            'name': '演员 $index',
            'avatar_url': '',
          },
        ),
        'current_page': 1,
      },
    });

    await tester.pumpWidget(
      MaterialApp(home: ActorsPage(service: fixture.service)),
    );
    await switchTab(tester, '有码(女)');
    await tester.drag(find.byType(GridView), const Offset(0, -600));
    await tester.pump();

    ScrollPosition visibleGridPosition() {
      final scrollable = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      );
      return tester.state<ScrollableState>(scrollable).position;
    }

    final censoredFemaleOffset = visibleGridPosition().pixels;
    expect(censoredFemaleOffset, greaterThan(0));

    await switchTab(tester, '欧美(男)');
    expect(visibleGridPosition().pixels, 0);

    await switchTab(tester, '有码(女)');
    expect(visibleGridPosition().pixels, closeTo(censoredFemaleOffset, 0.1));
  });

  testWidgets('月排名全部不跳转且点击演员进入详情', (tester) async {
    final fixture = await createActorService();
    fixture.adapter.enqueue(Endpoints.actorsRecommend, {
      'success': 1,
      'data': {
        'new_actors': [
          {'id': 'n1', 'name': '可点击演员', 'avatar_url': ''},
        ],
        'monthly_actors': <Map<String, dynamic>>[],
        'recommend_actors': <Map<String, dynamic>>[],
      },
    });
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/actors',
      routes: [
        GoRoute(
          path: '/actors',
          builder: (_, _) => ActorsPage(service: fixture.service),
        ),
        GoRoute(
          path: '/actor/:id',
          builder: (_, state) =>
              Scaffold(body: Text('演员详情 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await pumpAsyncUi(tester);

    await tester.tap(find.text('全部'));
    await tester.pump();
    expect(router.state.uri.path, '/actors');

    await tester.tap(find.text('可点击演员'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(router.state.uri.path, '/actor/n1');
    expect(find.text('演员详情 n1'), findsOneWidget);
  });

  testWidgets('窄屏暗色推荐页无布局溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final fixture = await createActorService();
    fixture.adapter.enqueue(Endpoints.actorsRecommend, {
      'success': 1,
      'data': {
        'new_actors': [
          {'id': 'n1', 'name': '很长很长的新人演员名称', 'avatar_url': ''},
        ],
        'monthly_actors': [
          {'id': 'm1', 'name': '很长很长的月榜演员名称', 'avatar_url': ''},
        ],
        'recommend_actors': [
          {'id': 'd1', 'name': '很长很长的推荐演员名称', 'avatar_url': ''},
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ActorsPage(service: fixture.service),
      ),
    );
    await pumpAsyncUi(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ActorCard), findsNWidgets(3));
  });
}
