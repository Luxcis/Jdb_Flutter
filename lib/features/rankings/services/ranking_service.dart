import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';

class RankingService {
  RankingService(this._api);
  final ApiClient _api;

  Future<PagedResult<MovieSummary>> getTop250({int page = 1, int limit = 20, String? year}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (year != null) params['year'] = year;
    final resp = await _api.get(Endpoints.moviesTop, queryParameters: params);
    return _parseMoviePage(resp.data);
  }

  Future<PagedResult<MovieSummary>> getPlayback({String period = 'daily', int page = 1, int limit = 20}) async {
    final resp = await _api.get(Endpoints.rankingsPlayback, queryParameters: {'period': period, 'page': page, 'limit': limit});
    return _parseMoviePage(resp.data);
  }

  Future<PagedResult<MovieSummary>> getRanking({required int type, String period = 'daily', int page = 1, int limit = 20}) async {
    final resp = await _api.get(Endpoints.rankings, queryParameters: {'type': type, 'period': period, 'page': page, 'limit': limit});
    return _parseMoviePage(resp.data);
  }

  Future<PagedResult<ActorSummary>> getActorRanking({required int type, String period = 'monthly', int page = 1, int limit = 20}) async {
    final resp = await _api.get(Endpoints.rankingsActors, queryParameters: {'type': type, 'period': period, 'page': page, 'limit': limit});
    final data = resp.data as Map<String, dynamic>;
    final items = (data['items'] as List?)?.map((j) => ActorSummary.fromJson(j as Map<String, dynamic>)).toList() ?? [];
    return PagedResult(items: items, currentPage: data['current_page'] ?? page, totalPages: data['total_pages'] ?? 1, total: data['total'] ?? 0);
  }

  PagedResult<MovieSummary> _parseMoviePage(dynamic data) {
    final m = data as Map<String, dynamic>;
    final items = (m['items'] as List?)?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>)).toList() ?? [];
    return PagedResult(items: items, currentPage: m['current_page'] ?? 1, totalPages: m['total_pages'] ?? 1, total: m['total'] ?? 0);
  }
}
