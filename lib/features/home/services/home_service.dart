import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';

class HomeService {
  HomeService(this._api);
  final ApiClient _api;

  Future<List<MovieSummary>> getRecommends({String? period}) async {
    final resp = await _api.get(
      Endpoints.moviesRecommend,
      queryParameters: period != null ? {'period': period} : {},
    );
    return apiList(resp.data, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
  }

  Future<List<String>> getRecommendPeriods() async {
    final resp = await _api.get(Endpoints.moviesRecommendPeriods);
    final data = resp.data;
    final list = data is Map ? data['periods'] : data;
    if (list is! List) return const [];
    return list
        .map((item) {
          if (item is Map) {
            return apiString(item['period'] ?? item['value'] ?? item['name']);
          }
          return apiString(item);
        })
        .whereType<String>()
        .toList();
  }

  Future<List<MovieSummary>> getLatest({int page = 1, int limit = 9}) async {
    final resp = await _api.get(
      Endpoints.moviesLatest,
      queryParameters: {
        'type': 'all',
        'filter_by': 'can_play',
        'sort_by': 'update',
        'order_by': 'desc',
        'limit': limit,
        'page': page,
      },
    );
    return apiList(resp.data, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
  }

  Future<List<MovieSummary>> getMagnetUpdates({
    int page = 1,
    int limit = 9,
  }) async {
    final resp = await _api.get(
      Endpoints.moviesLatest,
      queryParameters: {
        'type': 'all',
        'filter_by': 'magnets',
        'sort_by': 'update',
        'order_by': 'desc',
        'limit': limit,
        'page': page,
      },
    );
    return apiList(resp.data, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
  }
}
