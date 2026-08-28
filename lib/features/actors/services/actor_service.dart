import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/actors/models/actor_filter.dart';
import 'package:jade/features/actors/models/actor_recommend.dart';

class ActorService {
  ActorService(this._api);
  final ApiClient _api;

  Future<PagedResult<ActorSummary>> getActors({
    required ActorListCategory category,
    required int page,
    ActorFilter filter = const ActorFilter(),
  }) async {
    final query = <String, dynamic>{
      'type': category.type,
      'gender': category.gender,
      'page': page,
      'limit': 60,
      if (category.supportsFilter) ...filter.toQueryParameters(),
    };
    final response = await _api.get(Endpoints.actors, queryParameters: query);
    final data = apiMap(response.data);
    final items = apiList(data, const ['actors'])
        .map(normalizeActorSummaryJson)
        .map(ActorSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: currentPage + (items.length == 60 ? 1 : 0),
      total: apiInt(data['total'], 0),
    );
  }

  Future<ActorRecommend> getRecommends() async {
    final response = await _api.get(Endpoints.actorsRecommend);
    return ActorRecommend.fromJson(apiMap(response.data));
  }

  /// 获取演员月榜（非分页）。
  ///
  /// 对应 `GET /api/v1/rankings/actors`。实测/反编译确认仅接受整数
  /// `type`（0=有码, 1=无码, 2=欧美），无 `period`/`page`/`limit` 参数。
  /// 返回单页 `PagedResult` 以便复用现有网格控件，但不会触发分页加载。
  Future<PagedResult<ActorSummary>> getRankingActors({
    required int type,
  }) async {
    final resp = await _api.get(
      Endpoints.rankingsActors,
      queryParameters: {'type': type},
    );
    final data = apiMap(resp.data);
    final items = apiList(data, const ['actors'])
        .map(normalizeActorSummaryJson)
        .map(ActorSummary.fromJson)
        .toList(growable: false);
    return PagedResult(
      items: items,
      currentPage: 1,
      totalPages: 1,
      total: items.length,
    );
  }

  Future<ActorDetail> getDetail(
    String id, {
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      '${Endpoints.actors}/$id',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ActorDetail.fromJson(normalizeActorDetailJson(resp.data));
  }

  /// 获取演员出演的影片列表（分页）。
  ///
  /// 使用 [Endpoints.moviesTags] 端点，以演员模式
  /// `filter_by={type}:a:{id}` 查询该演员的影片。
  /// 配合 [filterByTags] 可进一步按标签过滤。
  Future<PagedResult<MovieSummary>> getActorMovies(
    String id, {
    required int type,
    String? filterByTags,
    int page = 1,
    int limit = 48,
    String sortBy = 'release',
    String orderBy = 'desc',
  }) async {
    final query = <String, dynamic>{
      'filter_by': '$type:a:$id',
      'sort_by': sortBy,
      'order_by': orderBy,
      'page': page,
      'limit': limit,
      if (filterByTags != null && filterByTags.isNotEmpty)
        'filter_by_tags': filterByTags,
    };
    final response = await _api.get(
      Endpoints.moviesTags,
      queryParameters: query,
    );
    return apiPageResult(
      response.data,
      keys: const ['movies', 'items'],
      page: page,
      pageSize: limit,
      fromJson: (json) =>
          MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}
