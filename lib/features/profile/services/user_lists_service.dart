import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

/// 「我的清单」数据源抽象，便于测试注入与 API 不可用时降级。
abstract interface class UserListsDataSource {
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  });

  Future<void> renameList({required String id, required String name});

  Future<void> deleteList(String id);
}

/// 默认 API 实现。全部接口需 BearerAuth（由 ApiClient 拦截器注入）。
class UserListsService implements UserListsDataSource {
  UserListsService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  @override
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.lists,
      queryParameters: {'sort_by': sortBy, 'page': page, 'limit': _pageSize},
    );
    return apiPageResult(
      response.data,
      keys: const ['lists', 'items'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) => ListModel.fromJson(normalizeListModelJson(json)),
    );
  }

  @override
  Future<void> renameList({required String id, required String name}) async {
    await _api.put('${Endpoints.lists}/$id', data: {'name': name});
  }

  @override
  Future<void> deleteList(String id) async {
    await _api.delete('${Endpoints.lists}/$id');
  }
}

/// ApiClient 未初始化时的空实现（页面数据源注入缺省值）。
class UnavailableUserListsDataSource implements UserListsDataSource {
  const UnavailableUserListsDataSource();

  @override
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<void> renameList({required String id, required String name}) async {}

  @override
  Future<void> deleteList(String id) async {}
}
