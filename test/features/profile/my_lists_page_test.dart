import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/screens/my_lists_page.dart';
import 'package:jade/features/profile/services/user_lists_service.dart';

class _FakeUserListsDataSource implements UserListsDataSource {
  _FakeUserListsDataSource({this.lists = const []});

  final List<ListModel> lists;
  final sortRequests = <String>[];
  final renamed = <({String id, String name})>[];
  final deleted = <String>[];
  var failRename = false;
  var failDelete = false;

  @override
  Future<PagedResult<ListModel>> getMyLists({
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
  Future<void> renameList({required String id, required String name}) async {
    if (failRename) throw StateError('rename failed');
    renamed.add((id: id, name: name));
  }

  @override
  Future<void> deleteList(String id) async {
    if (failDelete) throw StateError('delete failed');
    deleted.add(id);
  }
}

List<ListModel> _sampleLists() => [
  ListModel(id: 'l1', name: '收藏精选', movieCount: 3, viewedCount: 10),
  ListModel(id: 'l2', name: '待看片单', movieCount: 5, viewedCount: 20),
];

Future<_FakeUserListsDataSource> _pumpPage(
  WidgetTester tester, {
  List<ListModel>? lists,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _FakeUserListsDataSource(lists: lists ?? _sampleLists());
  await tester.pumpWidget(
    MaterialApp(
      home: MyListsPage(dataSource: source),
    ),
  );
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

  testWidgets('编辑改名成功更新列表项名称', (tester) async {
    final source = await _pumpPage(tester);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新片单名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(source.renamed, [(id: 'l1', name: '新片单名')]);
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
    expect(find.text('收藏精选'), findsNothing);
  });
}
