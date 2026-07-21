import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';

class RankingService {
  RankingService(this._api);
  final ApiClient _api;

  Future<PagedResult<MovieSummary>> getTop250({
    int page = 1,
    int limit = 20,
    String? year,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (year != null) params['year'] = year;
    final resp = await _api.get(Endpoints.moviesTop, queryParameters: params);
    return _parseMoviePage(resp.data);
  }

  Future<PagedResult<MovieSummary>> getPlayback({
    String filterBy = 'day',
    String period = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      Endpoints.rankingsPlayback,
      queryParameters: {'filter_by': filterBy, 'period': period},
    );
    return _parseMoviePage(resp.data);
  }

  Future<PagedResult<MovieSummary>> getRanking({
    required Object type,
    String period = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      Endpoints.rankings,
      queryParameters: {'type': type, 'period': period},
    );
    return _parseMoviePage(resp.data);
  }

  Future<PagedResult<ActorSummary>> getActorRanking({
    required String type,
    String period = 'month',
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      Endpoints.rankingsActors,
      queryParameters: {'type': type, 'period': period},
    );
    final data = resp.data as Map<String, dynamic>;
    final items = apiList(data, const [
      'actors',
      'items',
    ]).map((j) => ActorSummary.fromJson(normalizeActorSummaryJson(j))).toList();
    return PagedResult(
      items: items,
      currentPage: apiInt(data['current_page'], page),
      totalPages: apiInt(data['total_pages'], 1),
      total: apiInt(data['total'], 0),
    );
  }

  PagedResult<MovieSummary> _parseMoviePage(dynamic data) {
    final m = data as Map<String, dynamic>;
    final items = apiList(m, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
    return PagedResult(
      items: items,
      currentPage: apiInt(m['current_page'], 1),
      totalPages: apiInt(m['total_pages'], 1),
      total: apiInt(m['total'], 0),
    );
  }
}
