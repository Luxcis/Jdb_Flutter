import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/features/profile/screens/collected_entities_page.dart';
import 'package:jade/features/profile/services/collections_service.dart';

class _FakeFavoritesDataSource implements FavoritesDataSource {
  _FakeFavoritesDataSource({List<Maker>? makers})
    : makers = List<Maker>.of(makers ?? const []);

  final List<Maker> makers;
  final uncollected = <String>[];
  var failUncollect = false;
  var failGet = false;

  @override
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) async {
    if (failGet) throw StateError('GET failed');
    return PagedResult(
      items: makers,
      currentPage: page,
      totalPages: 1,
      total: makers.length,
    );
  }

  @override
  Future<void> uncollectMaker(String id) async {
    if (failUncollect) throw StateError('uncollect failed');
    uncollected.add(id);
    makers.removeWhere((m) => m.id == id);
  }

  // 其余方法抛 UnimplementedError（页面不会调用）。
  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) => throw UnimplementedError();
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
  Future<void> uncollectSeries(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectDirector(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectCode(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectList(String id) => throw UnimplementedError();
  @override
  Future<void> batchUncollectActors(List<String> ids) =>
      throw UnimplementedError();
  @override
  Future<bool?> getHasCollected(String category, String id) async => false;
  @override
  Future<void> setCollected(String category, String id, bool collect) async {}
}

List<Maker> _sampleMakers() => [
  Maker(id: 'm1', name: 'SOD', movieCount: 9),
  Maker(id: 'm2', name: 'TMA', movieCount: 4),
];

void main() {
  testWidgets('收藏的片商列表展示并左滑取消收藏', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeFavoritesDataSource(makers: _sampleMakers());
    await tester.pumpWidget(
      MaterialApp(
        home: CollectedEntitiesPage(
          category: 'm',
          title: '收藏的片商',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏的片商'), findsOneWidget);
    expect(find.text('SOD'), findsOneWidget);
    expect(find.text('(9)'), findsOneWidget);

    await tester.drag(find.text('SOD'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('取消收藏'), findsOneWidget);

    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();
    expect(find.text('取消收藏片商？'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(source.uncollected, ['m1']);
    expect(find.text('SOD'), findsNothing);
    expect(find.text('TMA'), findsOneWidget);
  });

  testWidgets('取消收藏失败提示且条目保留', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeFavoritesDataSource(makers: _sampleMakers());
    source.failUncollect = true;
    await tester.pumpWidget(
      MaterialApp(
        home: CollectedEntitiesPage(
          category: 'm',
          title: '收藏的片商',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('SOD'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('取消收藏失败'), findsOneWidget);
    expect(find.text('SOD'), findsOneWidget);
  });
}
