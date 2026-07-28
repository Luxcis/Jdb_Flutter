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
    return _parseMoviePage(response.data, fallbackPage: 1);
  }

  Future<PagedResult<MovieSummary>> getPlayback({
    String filterBy = 'high_score',
    String period = 'daily',
  }) async {
    final response = await _api.get(
      Endpoints.rankingsPlayback,
      queryParameters: {'filter_by': filterBy, 'period': period},
    );
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
    return _parseMoviePage(response.data, fallbackPage: page);
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
  }) {
    final m = data as Map<String, dynamic>;
    final items = apiList(m, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
    return PagedResult(
      items: items,
      currentPage: apiInt(m['current_page'], fallbackPage),
      totalPages: apiInt(m['total_pages'], fallbackPage),
      total: apiInt(m['total'], items.length),
    );
  }
}
