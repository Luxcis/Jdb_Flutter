import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

/// 为评鉴影片分页查询提供数据的抽象来源。
abstract interface class ReviewMoviesDataSource {
  /// 按评鉴状态、影片类型及排序条件取得一页影片。
  ///
  /// [status] 使用 `want_watch`；[type] 使用 `all` 或 `0` 至 `4`；[sortBy]
  /// 使用 `create` 或 `release`；[orderBy] 使用 `desc` 或 `asc`；[page] 从 1
  /// 开始计数。
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  });
}

/// 基于 API 客户端的评鉴影片数据源实现。
class ReviewMoviesService implements ReviewMoviesDataSource {
  /// 创建使用给定 API 客户端请求评鉴影片的数据源。
  ReviewMoviesService(this._api);

  static const _pageSize = 24;

  final ApiClient _api;

  /// 按评鉴状态、影片类型及排序条件从 API 取得一页影片。
  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.usersReviewMoviesV2,
      queryParameters: {
        'status': status,
        'type': type,
        'sort_by': sortBy,
        'order_by': orderBy,
        'page': page,
        'limit': _pageSize,
      },
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
}

/// 在 API 客户端不可用时返回空分页结果的数据源。
class UnavailableReviewMoviesDataSource implements ReviewMoviesDataSource {
  /// 创建不发起网络请求的空数据源。
  const UnavailableReviewMoviesDataSource();

  /// 返回指定页码的空影片结果。
  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
