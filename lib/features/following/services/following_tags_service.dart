import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/following/models/follow_tag.dart';

/// 关注标签数据源抽象，便于测试注入与 API 不可用时降级。
abstract interface class FollowingTagsDataSource {
  /// 关注单个标签，返回含真实 id 的新建关注项。
  Future<FollowTagItem> follow({required String name, required String value});

  /// 取消关注指定 id 的标签。
  Future<void> unfollow(String id);

  /// 批量同步：推送本地标签，返回服务端权威关注列表。
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags);
}

/// 默认 API 实现，全部需 BearerAuth（由 ApiClient 拦截器注入）。
class FollowingTagsService implements FollowingTagsDataSource {
  FollowingTagsService(this._api);

  final ApiClient _api;

  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async {
    final response = await _api.post(
      Endpoints.followingTags,
      data: {'name': name, 'value': value},
    );
    // ResponseInterceptor 已在成功时把 response.data 解包为 data 层
    // （{success, data} -> data），因此直接解析，不要再嵌 ['data']。
    final item = FollowTagItem.fromJson(apiMap(response.data));
    return item;
  }

  @override
  Future<void> unfollow(String id) async {
    await _api.delete('${Endpoints.followingTags}/$id');
  }

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async {
    final response = await _api.post(
      Endpoints.followingTagsBatchPush,
      data: {
        'tags': [
          for (final tag in tags)
            {
              'name': tag.name,
              'value': tag.value,
              if (tag.priority != null) 'priority': tag.priority,
            },
        ],
      },
    );
    final list = apiList(apiMap(response.data), const ['following_tags']);
    return list.map(FollowTagItem.fromJson).toList(growable: false);
  }
}

/// ApiClient 未初始化时的空实现。
class UnavailableFollowingTagsDataSource implements FollowingTagsDataSource {
  const UnavailableFollowingTagsDataSource();

  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async => FollowTagItem(id: '', name: name, value: value);

  @override
  Future<void> unfollow(String id) async {}

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
}
