import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/screens/my_lists_page.dart';
import 'package:jade/features/profile/services/user_lists_service.dart';

class _FakeUserListsDataSource implements UserListsDataSource {
  _FakeUserListsDataSource({List<ListModel>? lists, this.totalPages = 1})
    : lists = List<ListModel>.of(lists ?? const []);

  /// 服务端数据，rename/delete 会就地更新，使 refresh 从「服务器」重载生效。
  final List<ListModel> lists;
  final int totalPages;
  final sortRequests = <String>[];
  final renamed = <({String id, String name})>[];
  final deleted = <String>[];
  var failRename = false;
  var failDelete = false;
  var failPage2 = false;

  @override
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  }) async {
    sortRequests.add(sortBy);
    if (failPage2 && page >= 2) throw StateError('page 2 failed');
    final pageSize = lists.isEmpty ? 1 : (lists.length / totalPages).ceil();
    final start = math.min((page - 1) * pageSize, lists.length);
    final end = math.min(start + pageSize, lists.length);
    return PagedResult(
      items: lists.sublist(start, end),
      currentPage: page,
      totalPages: totalPages,
      total: lists.length,
    );
  }

  @override
  Future<void> renameList({required String id, required String name}) async {
    if (failRename) throw StateError('rename failed');
    renamed.add((id: id, name: name));
    final index = lists.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final old = lists[index];
    lists[index] = ListModel(
      id: old.id,
      name: name,
      movieCount: old.movieCount,
      viewedCount: old.viewedCount,
      hasMovie: old.hasMovie,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteList(String id) async {
    if (failDelete) throw StateError('delete failed');
    deleted.add(id);
    lists.removeWhere((item) => item.id == id);
  }
}

List<ListModel> _sampleLists() => [
  ListModel(id: 'l1', name: '收藏精选', movieCount: 3, viewedCount: 10),
  ListModel(id: 'l2', name: '待看片单', movieCount: 5, viewedCount: 20),
];

Future<_FakeUserListsDataSource> _pumpPage(
  WidgetTester tester, {
  List<ListModel>? lists,
  int totalPages = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _FakeUserListsDataSource(
    lists: lists ?? _sampleLists(),
    totalPages: totalPages,
  );
  await tester.pumpWidget(MaterialApp(home: MyListsPage(dataSource: source)));
  await tester.pumpAndSettle();
  return source;
}

void main() {
  testWidgets('初始加载显示清单列表且默认按更新时间排序', (tester) async {
    final source = await _pumpPage(tester);

    expect(find.text('我的清单'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
    expect(find.text('待看片单'), findsOneWidget);
    expect(find.text('3 部影片，被查看 10 次'), findsOneWidget);
    expect(source.sortRequests, ['updated_at']);
  });

  testWidgets('点击排序图标切换为创建时间并重新请求', (tester) async {
    final source = await _pumpPage(tester);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    expect(source.sortRequests, ['updated_at', 'created_at']);
  });

  testWidgets('左滑出现编辑和删除操作', (tester) async {
    await _pumpPage(tester);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('编辑改名成功提交服务器并刷新列表', (tester) async {
    final source = await _pumpPage(tester);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新片单名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(source.renamed, [(id: 'l1', name: '新片单名')]);
    // 服务器为准：rename 成功后刷新重载，新名称来自数据源而非本地补丁。
    expect(find.text('新片单名'), findsOneWidget);
    expect(find.text('收藏精选'), findsNothing);
  });

  testWidgets('删除确认后移除条目，取消则保留', (tester) async {
    final source = await _pumpPage(tester);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('删除清单？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.deleted, isEmpty);
    expect(find.text('收藏精选'), findsOneWidget);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定删除'));
    await tester.pumpAndSettle();

    expect(source.deleted, ['l1']);
    // 删除成功后刷新重载：服务端（fake 内部）已移除该条，列表不再显示。
    expect(find.text('收藏精选'), findsNothing);
    expect(find.text('待看片单'), findsOneWidget);
  });

  testWidgets('编辑改名失败提示重命名失败且列表不变', (tester) async {
    final source = await _pumpPage(tester);
    source.failRename = true;

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新片单名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('重命名失败'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
    expect(find.text('新片单名'), findsNothing);
  });

  testWidgets('删除失败提示删除失败且条目保留', (tester) async {
    final source = await _pumpPage(tester);
    source.failDelete = true;

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除失败'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
  });

  testWidgets('两页数据删除后刷新：无幽灵重试且条目数正确', (tester) async {
    final source = await _pumpPage(
      tester,
      lists: [
        ListModel(id: 'l1', name: '第一页清单', movieCount: 1, viewedCount: 1),
        ListModel(id: 'l2', name: '第二页清单', movieCount: 1, viewedCount: 1),
      ],
      totalPages: 2,
    );
    // 第二页尚未加载时触发一次失败，留下 error != null 的「幽灵重试」条件。
    source.failPage2 = true;
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('list-tail-retry')), findsOneWidget);

    // 恢复第二页可用，滚动触发 fetchMore 加载第 2 页条目。
    source.failPage2 = false;
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('第二页清单'), findsOneWidget);

    // 左滑删除第一页条目并确认。
    await tester.drag(find.text('第一页清单'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定删除'));
    await tester.pumpAndSettle();

    expect(source.deleted, ['l1']);
    // 删除成功后 refresh 从服务器重载第一页：服务端只剩「第二页清单」，
    // 它现在排在第 1 页——列表回顶后显示该剩余条目，且没有幽灵「重试」按钮。
    expect(find.byKey(const Key('list-tail-retry')), findsNothing);
    expect(find.text('第一页清单'), findsNothing);
    expect(find.text('第二页清单'), findsOneWidget);
  });
}
