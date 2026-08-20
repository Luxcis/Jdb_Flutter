import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/features/profile/screens/collected_actors_page.dart';
import 'package:jade/features/profile/services/collections_service.dart';

class _FakeActorsFavoritesDataSource implements FavoritesDataSource {
  _FakeActorsFavoritesDataSource({List<ActorSummary>? actors})
    : actors = List<ActorSummary>.of(actors ?? const []);

  final List<ActorSummary> actors;
  final typeRequests = <String>[];
  final batchUncollected = <List<String>>[];
  var failBatch = false;

  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) async {
    typeRequests.add(type);
    return PagedResult(
      items: actors,
      currentPage: page,
      totalPages: 1,
      total: actors.length,
    );
  }

  @override
  Future<void> batchUncollectActors(List<String> ids) async {
    if (failBatch) throw StateError('batch failed');
    batchUncollected.add(ids);
    actors.removeWhere((a) => ids.contains(a.id));
  }

  @override
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Series>> getCollectedSeries({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Code>> getCollectedCodes({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  }) => throw UnimplementedError();
  @override
  Future<void> uncollectActor(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectMaker(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectSeries(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectDirector(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectCode(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectList(String id) => throw UnimplementedError();
  @override
  Future<bool?> getHasCollected(String category, String id) async => false;
  @override
  Future<void> setCollected(String category, String id, bool collect) async {}
}

void main() {
  // 页面含 CachedImage 头像，其占位 spinner 在 widget 测试中永不停止
  // （图片请求不会完成），pumpAndSettle 会超时。按项目既有约定
  // （actor_card / actor_grid_view / actors_screen 测试）用有界 pump
  // 序列推进帧，断言不变。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('演员 Tab 加载 type 参数且默认全部', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeActorsFavoritesDataSource(
      actors: [ActorSummary(id: 'a1', name: '三上悠亜', avatarUrl: '')],
    );
    await tester.pumpWidget(
      MaterialApp(home: CollectedActorsPage(dataSource: source)),
    );
    await settle(tester);

    expect(find.text('收藏的演员'), findsOneWidget);
    expect(find.text('三上悠亜'), findsOneWidget);
    expect(source.typeRequests, ['all']);
  });

  testWidgets('编辑模式选中演员并批量取关', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeActorsFavoritesDataSource(
      actors: [
        ActorSummary(id: 'a1', name: '三上悠亜', avatarUrl: ''),
        ActorSummary(id: 'a2', name: '深田詠美', avatarUrl: ''),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: CollectedActorsPage(dataSource: source)),
    );
    await settle(tester);

    // 进入编辑模式
    await tester.tap(find.byKey(const Key('collected-actors-edit-button')));
    await settle(tester);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('取消收藏(0)'), findsOneWidget);

    // 选中两个演员
    await tester.tap(find.text('三上悠亜'));
    await settle(tester);
    await tester.tap(find.text('深田詠美'));
    await settle(tester);
    expect(find.text('取消收藏(2)'), findsOneWidget);

    // 确认批量取关
    await tester.tap(find.text('取消收藏(2)'));
    await settle(tester);
    await tester.tap(find.text('确定'));
    await settle(tester);

    expect(source.batchUncollected, [
      ['a1', 'a2'],
    ]);
    expect(find.text('完成'), findsNothing);
    expect(find.text('三上悠亜'), findsNothing);
    expect(find.text('深田詠美'), findsNothing);
  });

  testWidgets('批量取关失败保留选择并提示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeActorsFavoritesDataSource(
      actors: [ActorSummary(id: 'a1', name: '三上悠亜', avatarUrl: '')],
    );
    source.failBatch = true;
    await tester.pumpWidget(
      MaterialApp(home: CollectedActorsPage(dataSource: source)),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('collected-actors-edit-button')));
    await settle(tester);
    await tester.tap(find.text('三上悠亜'));
    await settle(tester);
    await tester.tap(find.text('取消收藏(1)'));
    await settle(tester);
    await tester.tap(find.text('确定'));
    await settle(tester);

    expect(find.text('批量取关失败'), findsOneWidget);
    expect(find.text('取消收藏(1)'), findsOneWidget);
  });

  testWidgets('无收藏演员时显示空态提示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeActorsFavoritesDataSource(actors: const []);
    await tester.pumpWidget(
      MaterialApp(home: CollectedActorsPage(dataSource: source)),
    );
    await settle(tester);

    expect(find.text('暂无收藏的演员'), findsOneWidget);
  });
}
