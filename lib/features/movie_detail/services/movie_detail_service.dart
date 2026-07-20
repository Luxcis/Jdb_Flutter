import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/models/list_model.dart';

class MovieDetailService {
  MovieDetailService(this._api);
  final ApiClient _api;

  Future<MovieDetail> getDetail(String id) async {
    final resp = await _api.get('/api/v4/movies/$id');
    return MovieDetail.fromJson(resp.data);
  }

  Future<List<Magnet>> getMagnets(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/magnets');
    return ((resp.data as List?) ?? []).map((j) => Magnet.fromJson(j)).toList();
  }

  Future<List<Review>> getReviews(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/reviews');
    return ((resp.data as List?) ?? []).map((j) => Review.fromJson(j)).toList();
  }

  Future<List<MovieSummary>> getMayAlsoLike(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/may_also_like');
    return ((resp.data as List?) ?? []).map((j) => MovieSummary.fromJson(j)).toList();
  }
}
