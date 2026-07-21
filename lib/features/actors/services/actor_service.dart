import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';

class ActorService {
  ActorService(this._api);
  final ApiClient _api;

  Future<PagedResult<ActorSummary>> getActors({
    required String type,
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      Endpoints.actors,
      queryParameters: {'type': type, 'limit': limit},
    );
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: apiList(m, const [
        'actors',
        'items',
      ]).map(ActorSummary.fromJson).toList(),
      currentPage: apiInt(m['current_page'], 1),
      totalPages: apiInt(m['total_pages'], 1),
      total: apiInt(m['total'], 0),
    );
  }

  Future<List<ActorSummary>> getRecommends() async {
    final resp = await _api.get(Endpoints.actorsRecommend);
    if (resp.data is Map) {
      final actors = [
        ...apiList(resp.data, const ['new_actors']),
        ...apiList(resp.data, const ['monthly_actors']),
        ...apiList(resp.data, const ['recommend_actors']),
      ];
      if (actors.isNotEmpty) return actors.map(ActorSummary.fromJson).toList();
    }
    return apiList(resp.data, const [
      'actors',
      'items',
    ]).map(ActorSummary.fromJson).toList();
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
      items: apiList(m, const [
        'actors',
        'items',
      ]).map(ActorSummary.fromJson).toList(),
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

  Future<PagedResult<MovieSummary>> getActorMovies(
    String id, {
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      '${Endpoints.actors}/$id',
      queryParameters: {'page': page, 'limit': limit},
    );
    final m = resp.data as Map<String, dynamic>;
    final movies = apiList(m, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
    return PagedResult(
      items: movies,
      currentPage: apiInt(m['current_page'], 1),
      totalPages: apiInt(m['total_pages'], 1),
      total: apiInt(m['total'], 0),
    );
  }
}
