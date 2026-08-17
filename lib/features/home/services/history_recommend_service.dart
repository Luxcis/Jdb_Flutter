import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/home/models/recommend_period.dart';

/// 往期推荐数据源。
abstract interface class RecommendPeriodDataSource {
  /// 分页获取推荐周期列表。
  Future<PagedResult<RecommendPeriod>> getPeriods({
    int page = 1,
    int limit = 48,
  });

  /// 获取某一期推荐的影片列表。
  Future<List<MovieSummary>> getMovies(String period);
}

class HistoryRecommendService implements RecommendPeriodDataSource {
  HistoryRecommendService(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<RecommendPeriod>> getPeriods({
    int page = 1,
    int limit = 48,
  }) async {
    final resp = await _api.get(
      Endpoints.moviesRecommendPeriods,
      queryParameters: {'page': page, 'limit': limit},
    );
    return apiPageResult(
      resp.data,
      keys: const ['periods'],
      page: page,
      pageSize: limit,
      fromJson: RecommendPeriod.fromJson,
    );
  }

  @override
  Future<List<MovieSummary>> getMovies(String period) async {
    final resp = await _api.get(
      Endpoints.moviesRecommend,
      queryParameters: {'period': period},
    );
    return apiList(resp.data, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
  }
}

class UnavailableRecommendPeriodDataSource
    implements RecommendPeriodDataSource {
  const UnavailableRecommendPeriodDataSource();

  @override
  Future<PagedResult<RecommendPeriod>> getPeriods({
    int page = 1,
    int limit = 48,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<List<MovieSummary>> getMovies(String period) async => const [];
}
