import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';

class HomeService {
  HomeService(this._api);
  final ApiClient _api;

  Future<List<MovieSummary>> getRecommends({String? period}) async {
    final resp = await _api.get(Endpoints.moviesRecommend,
      queryParameters: period != null ? {'period': period} : {},
    );
    final list = (resp.data as List?) ?? [];
    return list.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<String>> getRecommendPeriods() async {
    final resp = await _api.get(Endpoints.moviesRecommendPeriods);
    final list = (resp.data as List?) ?? [];
    return list.cast<String>();
  }

  Future<List<MovieSummary>> getLatest({int page = 1, int limit = 9}) async {
    final resp = await _api.get(Endpoints.moviesLatest,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = resp.data;
    final items = (data is Map ? data['items'] ?? [] : []) as List;
    return items.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<MovieSummary>> getMagnetUpdates({int limit = 9}) async {
    final resp = await _api.get(Endpoints.moviesTags,
      queryParameters: {'sort_by': 'magnet_date', 'limit': limit},
    );
    final data = resp.data;
    final items = (data is Map ? data['items'] ?? [] : []) as List;
    return items.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>)).toList();
  }
}
