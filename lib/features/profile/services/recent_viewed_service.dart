import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

/// 近期浏览数据源抽象，便于测试注入。
abstract interface class RecentViewedDataSource {
  /// 取得一页近期浏览影片；[page] 从 1 开始计数。
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1});

  /// 清空当前用户的全部近期浏览记录。
  Future<void> clearRecentViewed();
}

/// 基于 API 客户端的近期浏览数据源实现。
class RecentViewedService implements RecentViewedDataSource {
  /// 创建使用给定 API 客户端请求近期浏览的数据源。
  RecentViewedService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  /// 从 API 取得一页近期浏览影片。
  @override
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1}) async {
    final response = await _api.get(
      Endpoints.usersRecentViewed,
      queryParameters: {'page': page, 'limit': _pageSize},
    );
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) =>
          MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }

  /// 清空当前用户的全部近期浏览记录。
  @override
  Future<void> clearRecentViewed() async {
    await _api.delete(Endpoints.usersRecentViewed);
  }
}

/// 在 API 客户端不可用时返回空分页结果、清空为空操作的数据源。
class UnavailableRecentViewedDataSource implements RecentViewedDataSource {
  /// 创建不发起网络请求的空数据源。
  const UnavailableRecentViewedDataSource();

  /// 返回指定页码的空影片结果。
  @override
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1}) async =>
      PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);

  /// 不发起请求的空清空操作。
  @override
  Future<void> clearRecentViewed() async {}
}
