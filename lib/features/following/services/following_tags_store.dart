import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/features/following/models/follow_tag.dart';

/// 关注标签本地缓存抽象，便于测试注入。
abstract interface class FollowingTagsStore {
  Future<List<FollowTagItem>> load();
  Future<void> save(List<FollowTagItem> tags);
  Future<void> clear();
}

/// 基于 [SharedPreferences] 的默认实现，以 JSON 数组持久化。
class PrefsFollowingTagsStore implements FollowingTagsStore {
  PrefsFollowingTagsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<FollowTagItem>> load() async {
    final raw = _prefs.getString(StorageKeys.followingTags);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => FollowTagItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } catch (_) {
      // 畸形 JSON 视作空列表，避免启动崩溃。
      return const [];
    }
  }

  @override
  Future<void> save(List<FollowTagItem> tags) async {
    await _prefs.setString(
      StorageKeys.followingTags,
      jsonEncode(tags.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(StorageKeys.followingTags);
  }
}
