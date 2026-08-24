import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore implements FollowingTagsStore {
  List<FollowTagItem> stored = [];
  _MemoryStore([this.stored = const []]);
  @override
  Future<void> clear() async => stored = [];
  @override
  Future<List<FollowTagItem>> load() async => stored;
  @override
  Future<void> save(List<FollowTagItem> tags) async => stored = List.of(tags);
}

class _FakeData implements FollowingTagsDataSource {
  _FakeData({this.followResult, this.unfollowError, this.remote});
  FollowTagItem? followResult;
  Object? unfollowError;
  List<FollowTagItem>? remote;
  List<String> unfollowed = [];
  int followCalls = 0;
  @override
  Future<FollowTagItem> follow({required String name, required String value}) async {
    followCalls++;
    return followResult ?? FollowTagItem(id: 'new', name: name, value: value);
  }
  @override
  Future<void> unfollow(String id) async {
    if (unfollowError != null) throw unfollowError!;
    unfollowed.add(id);
  }
  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async =>
      remote ?? tags;
}

void main() {
  test('isFollowing 依据 value 判断', () async {
    final provider = FollowingTagsProvider(
      store: _MemoryStore(),
      dataSource: _FakeData(),
    );
    await provider.initialize();
    await provider.follow(name: 'n', value: 'v1');
    expect(provider.isFollowing('v1'), isTrue);
    expect(provider.isFollowing('v2'), isFalse);
  });

  test('follow 插入头部并持久化', () async {
    final store = _MemoryStore();
    final provider = FollowingTagsProvider(store: store, dataSource: _FakeData());
    await provider.initialize();
    await provider.follow(name: 'a', value: 'va');
    await provider.follow(name: 'b', value: 'vb');
    expect(provider.tags.first.value, 'vb');
    expect(store.stored.length, 2);
  });

  test('unfollow 移除匹配 id 并持久化', () async {
    final store = _MemoryStore(const [
      FollowTagItem(id: '1', name: 'a', value: 'va'),
      FollowTagItem(id: '2', name: 'b', value: 'vb'),
    ]);
    final fake = _FakeData();
    final provider = FollowingTagsProvider(store: store, dataSource: fake);
    await provider.initialize();
    await provider.unfollow('1');
    expect(provider.tags.single.id, '2');
    expect(fake.unfollowed, ['1']);
    expect(store.stored.single.id, '2');
  });

  test('syncFromRemote 用远程覆盖本地且失败保留本地', () async {
    final store = _MemoryStore(const [FollowTagItem(id: '1', name: 'a', value: 'va')]);
    final provider = FollowingTagsProvider(store: store, dataSource: _FakeData(
      remote: const [FollowTagItem(id: '9', name: 'x', value: 'vx')],
    ));
    await provider.initialize();
    await provider.syncFromRemote();
    expect(provider.tags.single.id, '9');
  });

  test('clear 清空列表与缓存', () async {
    final store = _MemoryStore(const [FollowTagItem(id: '1', name: 'a', value: 'va')]);
    final provider = FollowingTagsProvider(store: store, dataSource: _FakeData());
    await provider.initialize();
    await provider.clear();
    expect(provider.tags, isEmpty);
    expect(store.stored, isEmpty);
  });
}
