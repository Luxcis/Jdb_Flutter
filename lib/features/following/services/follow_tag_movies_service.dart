import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

/// 关注标签影片取数服务（`GET /api/v1/movies/tags`）。
class FollowTagMoviesService {
  FollowTagMoviesService(this._api);

  final ApiClient _api;

  /// 装配点判空：未登录/无连接时返回 null，由调用方保留空态分支。
  static FollowTagMoviesService? resolve() => switch (ApiClient.instanceOrNull) {
    final api? => FollowTagMoviesService(api),
    null => null,
  };

  /// 按关注标签的 `filter_by` 表达式分页取影片。
  Future<PagedResult<MovieSummary>> getMovies({
    required String filterBy,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
    int limit = 48,
  }) async {
    final query = <String, dynamic>{
      'filter_by': filterBy,
      'sort_by': sortBy,
      if (sortBy == 'release') 'order_by': orderBy,
      'page': page,
      'limit': limit,
    };
    final response = await _api.get(Endpoints.moviesTags, queryParameters: query);
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: limit,
      fromJson: (json) => MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}
