import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/screens/following_page.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:provider/provider.dart';

class _MemoryStore implements FollowingTagsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<List<FollowTagItem>> load() async => const [];
  @override
  Future<void> save(List<FollowTagItem> tags) async {}
}

class _FakeData implements FollowingTagsDataSource {
  _FakeData({this.unfollowError});
  final Object? unfollowError;
  @override
  Future<FollowTagItem> follow({required String name, required String value}) async =>
      FollowTagItem(id: 'n', name: name, value: value);
  @override
  Future<void> unfollow(String id) async {
    if (unfollowError != null) throw unfollowError!;
  }
  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
}

Future<FollowingTagsProvider> _pumpPage(
  WidgetTester tester, {
  FollowingTagsDataSource? dataSource,
  List<FollowTagItem> tags = const [],
}) async {
  // 与「我的收藏」页测试一致：固定视口尺寸，确保 Slidable 左滑触发。
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = FollowingTagsProvider(
    store: _MemoryStore(),
    dataSource: dataSource ?? _FakeData(),
  );
  await provider.initialize();
  if (tags.isNotEmpty) {
    await provider.syncFromLogin(tags);
  }
  await tester.pumpWidget(MultiProvider(
    providers: [ChangeNotifierProvider.value(value: provider)],
    child: const MaterialApp(home: FollowingPage()),
  ));
  return provider;
}

/// 左滑露出「取消关注」按钮，点击后在确认框中选择确定/取消。
Future<void> _swipeAndConfirm(
  WidgetTester tester, {
  required String name,
  required bool confirm,
}) async {
  await tester.drag(find.text(name), const Offset(-200, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('取消关注'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(confirm ? '确定' : '取消'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('空态展示暂无关注标签', (tester) async {
    await _pumpPage(tester);
    expect(find.text('暂无关注标签'), findsOneWidget);
  });

  testWidgets('列表展示标签', (tester) async {
    await _pumpPage(tester, tags: const [
      FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
    ]);
    expect(find.text('有碼,森螢'), findsOneWidget);
    expect(find.text('0:a:g1Q'), findsOneWidget);
  });

  testWidgets('左滑取消关注成功：确认后该项被移除', (tester) async {
    final provider = await _pumpPage(tester, tags: const [
      FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
    ]);
    expect(find.text('有碼,森螢'), findsOneWidget);
    // 标签项无数量字段，不显示 (count)。
    expect(find.textContaining('(0)'), findsNothing);

    await _swipeAndConfirm(tester, name: '有碼,森螢', confirm: true);

    expect(provider.tags, isEmpty);
    expect(find.text('有碼,森螢'), findsNothing);
  });

  testWidgets('左滑取消关注失败：确认后项保留且无运行时断言', (tester) async {
    final provider = await _pumpPage(
      tester,
      dataSource: _FakeData(unfollowError: StateError('boom')),
      tags: const [
        FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
      ],
    );
    expect(find.text('有碼,森螢'), findsOneWidget);

    await _swipeAndConfirm(tester, name: '有碼,森螢', confirm: true);

    // 网络失败：项保留在列表，且无运行时断言。
    expect(provider.tags, hasLength(1));
    expect(find.text('有碼,森螢'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消关注：确认框点取消后项保留', (tester) async {
    final provider = await _pumpPage(tester, tags: const [
      FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
    ]);

    await _swipeAndConfirm(tester, name: '有碼,森螢', confirm: false);

    expect(provider.tags, hasLength(1));
    expect(find.text('有碼,森螢'), findsOneWidget);
  });
}
