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

  Future<PagedResult<ActorSummary>> getRankingActors({
    required String type,
    String period = 'month',
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      Endpoints.rankingsActors,
      queryParameters: {'type': type, 'period': period},
    );
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: apiList(m, const ['actors', 'items'])
          .map((j) => ActorSummary.fromJson(normalizeActorSummaryJson(j)))
          .toList(),
      currentPage: apiInt(m['current_page'], 1),
      totalPages: apiInt(m['total_pages'], 1),
      total: apiInt(m['total'], 0),
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
    final data = apiMap(response.data);
    final items = apiList(data, const ['movies', 'items'])
        .map(normalizeMovieSummaryJson)
        .map(MovieSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    final totalPages = data['total_pages'] == null
        ? currentPage + (items.length >= limit ? 1 : 0)
        : apiInt(data['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}
