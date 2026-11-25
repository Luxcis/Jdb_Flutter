import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';

class RankingService {
  RankingService(this._api);
  final ApiClient _api;

  /// `/api/v1/rankings` 与 `/api/v1/rankings/playback` 不接受 `limit` 参数，
  /// 服务端按自身默认页大小分页（历史客户端固定传 limit=20）。
  /// 响应缺少 `total_pages` 时用该值判断「本页是否满页」。
  static const int defaultRankingPageSize = 20;

  /// 从全局 ApiClient 单例创建服务；未初始化（未登录/无连接）时返回 null，
  /// 由调用方按空态处理。
  static RankingService? tryCreate() {
    final api = ApiClient.instanceOrNull;
    return api == null ? null : RankingService(api);
  }

  Future<PagedResult<MovieSummary>> getTop250({
    int startRank = 1,
    String type = 'all',
    String typeValue = '',
    bool ignoreWatched = false,
    int limit = 50,
  }) async {
    final response = await _api.get(
      Endpoints.moviesTop,
      queryParameters: {
        'start_rank': startRank,
        'type': type,
        'type_value': typeValue,
        'ignore_watched': ignoreWatched.toString(),
        'limit': limit,
      },
    );
    return _parseMoviePage(response.data, fallbackPage: 1, pageSize: limit);
  }

  Future<PagedResult<MovieSummary>> getPlayback({
    String filterBy = 'high_score',
    String period = 'daily',
  }) async {
    final response = await _api.get(
      Endpoints.rankingsPlayback,
      queryParameters: {'filter_by': filterBy, 'period': period},
    );
    // 播放榜请求不携带页码，只能取第一页；不做「满页则还有下一页」推断。
    return _parseMoviePage(response.data, fallbackPage: 1);
  }

  Future<PagedResult<MovieSummary>> getRanking({
    required String type,
    String period = 'daily',
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.rankings,
      queryParameters: {'type': type, 'period': period, 'page': page},
    );
    return _parseMoviePage(
      response.data,
      fallbackPage: page,
      pageSize: defaultRankingPageSize,
    );
  }

  Future<PagedResult<ActorSummary>> getActorRanking({required int type}) async {
    final response = await _api.get(
      Endpoints.rankingsActors,
      queryParameters: {'type': type},
    );
    final data = response.data as Map<String, dynamic>;
    final items = apiList(data, const [
      'actors',
      'items',
    ]).map((j) => ActorSummary.fromJson(normalizeActorSummaryJson(j))).toList();
    return PagedResult(
      items: items,
      currentPage: 1,
      totalPages: apiInt(data['total_pages'], 1),
      total: apiInt(data['total'], items.length),
    );
  }

  PagedResult<MovieSummary> _parseMoviePage(
    dynamic data, {
    required int fallbackPage,
    int? pageSize,
  }) {
    final m = data as Map<String, dynamic>;
    final items = apiList(m, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
    // 服务端 current_page 前移时以服务端值为准，避免重复或漏页。
    final currentPage = apiInt(m['current_page'], fallbackPage);
    // 缺少 total_pages 时按「本页满页则还有下一页」推断（对齐 apiPageResult）；
    // pageSize 为 null 表示该接口不分页（如无法翻页的播放榜）。
    final rawTotalPages = m['total_pages'];
    final totalPages = rawTotalPages == null
        ? (pageSize == null
              ? currentPage
              : currentPage + (items.length >= pageSize ? 1 : 0))
        : apiInt(rawTotalPages, currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(m['total'], items.length),
    );
  }
}
