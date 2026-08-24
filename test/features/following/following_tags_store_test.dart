import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save 后可 load 出相同数据', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsFollowingTagsStore(prefs);
    await store.save(const [
      FollowTagItem(id: '1', name: 'a', value: 'v1', priority: 2),
      FollowTagItem(id: '2', name: 'b', value: 'v2'),
    ]);

    final loaded = await store.load();
    expect(loaded.length, 2);
    expect(loaded[0].id, '1');
    expect(loaded[0].name, 'a');
    expect(loaded[0].priority, 2);
    expect(loaded[1].priority, isNull);
  });

  test('无缓存时返回空列表', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsFollowingTagsStore(prefs);
    expect(await store.load(), isEmpty);
  });

  test('畸形 JSON 返回空列表而不抛异常', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('key_following_tags', 'not-valid-json');
    final store = PrefsFollowingTagsStore(prefs);
    expect(await store.load(), isEmpty);
  });

  test('clear 后加载为空', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsFollowingTagsStore(prefs);
    await store.save(const [FollowTagItem(id: '1', name: 'a', value: 'v')]);
    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
