import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';

class ActorService {
  ActorService(this._api);
  final ApiClient _api;

  Future<PagedResult<ActorSummary>> getActors(
      {int? type, int page = 1, int limit = 20}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null) params['type'] = type;
    final resp = await _api.get(Endpoints.actors, queryParameters: params);
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: (m['items'] as List?)
              ?.map((j) => ActorSummary.fromJson(j))
              .toList() ??
          [],
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<List<ActorSummary>> getRecommends() async {
    final resp = await _api.get(Endpoints.actorsRecommend);
    final list = (resp.data as List?) ?? [];
    return list.map((j) => ActorSummary.fromJson(j)).toList();
  }

  Future<PagedResult<ActorSummary>> getRankingActors(
      {String period = 'monthly', int page = 1, int limit = 20}) async {
    final resp = await _api.get(Endpoints.rankingsActors,
        queryParameters: {'period': period, 'page': page, 'limit': limit});
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: (m['items'] as List?)
              ?.map((j) => ActorSummary.fromJson(j))
              .toList() ??
          [],
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<ActorDetail> getDetail(String id,
      {int page = 1, int limit = 20}) async {
    final resp = await _api.get('${Endpoints.actors}/$id',
        queryParameters: {'page': page, 'limit': limit});
    return ActorDetail.fromJson(resp.data);
  }

  Future<PagedResult<MovieSummary>> getActorMovies(String id,
      {int page = 1, int limit = 20}) async {
    final resp = await _api.get('${Endpoints.actors}/$id',
        queryParameters: {'page': page, 'limit': limit});
    final m = resp.data as Map<String, dynamic>;
    final movies = (m['movies'] as List?)
            ?.map((j) => MovieSummary.fromJson(j))
            .toList() ??
        (m['items'] as List?)
            ?.map((j) => MovieSummary.fromJson(j))
            .toList() ??
        [];
    return PagedResult(
      items: movies,
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }
}
