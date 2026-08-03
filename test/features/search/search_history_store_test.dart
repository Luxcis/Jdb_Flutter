import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('保存时去重、最近优先并最多保留 20 条', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.searchHistory: jsonEncode([
        for (var index = 0; index < 20; index++) '关键词$index',
      ]),
    });
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    final history = await store.save('  关键词5  ');

    expect(history, [
      '关键词5',
      '关键词0',
      '关键词1',
      '关键词2',
      '关键词3',
      '关键词4',
      ...[for (var index = 6; index < 20; index++) '关键词$index'],
    ]);
    expect(store.load(), history);
  });

  test('无效 JSON 按空历史处理', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.searchHistory: '{invalid',
    });
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    expect(store.load(), isEmpty);
  });

  test('包含非字符串项的缓存按空历史处理', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.searchHistory: jsonEncode(['有效', 1]),
    });
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    expect(store.load(), isEmpty);
  });

  test('清空时删除持久化历史', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.searchHistory: jsonEncode(['历史番号']),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SearchHistoryStore(prefs);

    await store.clear();

    expect(store.load(), isEmpty);
    expect(prefs.containsKey(StorageKeys.searchHistory), isFalse);
  });
}
