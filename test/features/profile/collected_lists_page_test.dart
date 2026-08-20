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

class _FakeListFavoritesDataSource implements FavoritesDataSource {
  _FakeListFavoritesDataSource({List<ListModel>? lists})
    : lists = List<ListModel>.of(lists ?? const []);

  final List<ListModel> lists;
  final sortRequests = <String>[];

  @override
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  }) async {
    sortRequests.add(sortBy);
    return PagedResult(
      items: lists,
      currentPage: page,
      totalPages: 1,
      total: lists.length,
    );
  }

  @override
  Future<void> uncollectList(String id) async {}

  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) => throw UnimplementedError();
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
  Future<void> batchUncollectActors(List<String> ids) =>
      throw UnimplementedError();
  @override
  Future<bool?> getHasCollected(String category, String id) async => false;
  @override
  Future<void> setCollected(String category, String id, bool collect) async {}
}

void main() {
  testWidgets('收藏的清单默认按更新时间排序，点击切换创建时间', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeListFavoritesDataSource(
      lists: [ListModel(id: 'l1', name: '收藏精选', movieCount: 3)],
    );
    await tester.pumpWidget(
      MaterialApp(home: CollectedListsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏的清单'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
    expect(source.sortRequests, ['recently']);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    expect(source.sortRequests, ['recently', 'release']);
  });
}
