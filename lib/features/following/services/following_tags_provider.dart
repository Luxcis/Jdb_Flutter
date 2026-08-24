import 'package:flutter/foundation.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';

/// 全局关注标签状态，负责缓存与远程同步。
class FollowingTagsProvider extends ChangeNotifier {
  FollowingTagsProvider({
    required FollowingTagsStore store,
    required FollowingTagsDataSource dataSource,
  }) : _store = store,
       _dataSource = dataSource;

  final FollowingTagsStore _store;
  final FollowingTagsDataSource _dataSource;

  List<FollowTagItem> _tags = const [];
  bool _initialized = false;

  List<FollowTagItem> get tags => List.unmodifiable(_tags);
  bool get initialized => _initialized;

  /// 是否已关注具备该 value 的标签。
  bool isFollowing(String value) =>
      _tags.any((tag) => tag.value == value);

  /// 初始化：从本地缓存加载。幂等。
  Future<void> initialize() async {
    if (_initialized) return;
    _tags = await _store.load();
    _initialized = true;
    notifyListeners();
  }

  /// 关注单个标签；成功后写缓存。
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async {
    final item = await _dataSource.follow(name: name, value: value);
    _tags = [item, ..._tags];
    await _persist();
    notifyListeners();
    return item;
  }

  /// 取消关注；成功后写缓存。
  Future<void> unfollow(String id) async {
    await _dataSource.unfollow(id);
    _tags = _tags.where((tag) => tag.id != id).toList(growable: false);
    await _persist();
    notifyListeners();
  }

  /// 登录时从接口刷入。
  Future<void> syncFromLogin(List<FollowTagItem> tags) async {
    _tags = List.unmodifiable(tags);
    await _persist();
    notifyListeners();
  }

  /// 启动时 batch_push 用远程覆盖本地。
  Future<void> syncFromRemote() async {
    try {
      final remote = await _dataSource.batchPush(_tags);
      _tags = List.unmodifiable(remote);
      await _persist();
      notifyListeners();
    } catch (error) {
      // 网络错误保留本地缓存，不抛出以免打断启动。
      debugPrint('FollowingTags sync failed: $error');
    }
  }

  /// 登出时清空。
  Future<void> clear() async {
    _tags = const [];
    await _store.clear();
    notifyListeners();
  }

  Future<void> _persist() => _store.save(_tags);
}
