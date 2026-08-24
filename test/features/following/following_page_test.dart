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
  @override
  Future<FollowTagItem> follow({required String name, required String value}) async =>
      FollowTagItem(id: 'n', name: name, value: value);
  @override
  Future<void> unfollow(String id) async {}
  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
}

void main() {
  testWidgets('空态展示暂无关注标签', (tester) async {
    final provider = FollowingTagsProvider(store: _MemoryStore(), dataSource: _FakeData());
    await provider.initialize();
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: provider)],
      child: const MaterialApp(home: FollowingPage()),
    ));
    expect(find.text('暂无关注标签'), findsOneWidget);
  });

  testWidgets('列表展示标签', (tester) async {
    final provider = FollowingTagsProvider(store: _MemoryStore(), dataSource: _FakeData());
    await provider.initialize();
    await provider.syncFromLogin(const [
      FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
    ]);
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: provider)],
      child: const MaterialApp(home: FollowingPage()),
    ));
    expect(find.text('有碼,森螢'), findsOneWidget);
    expect(find.text('0:a:g1Q'), findsOneWidget);
  });
}
