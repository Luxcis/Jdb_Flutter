import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/review.dart';

class MovieDetailService {
  MovieDetailService(this._api);
  final ApiClient _api;

  Future<MovieDetail> getDetail(String id) async {
    final resp = await _api.get('/api/v4/movies/$id');
    return MovieDetail.fromJson(normalizeMovieDetailJson(resp.data));
  }

  Future<List<Magnet>> getMagnets(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/magnets');
    return apiList(resp.data, const [
      'magnets',
      'items',
    ]).map((j) => Magnet.fromJson(normalizeMagnetJson(j))).toList();
  }

  Future<List<Review>> getReviews(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/reviews');
    return apiList(resp.data, const [
      'reviews',
      'items',
    ]).map((j) => Review.fromJson(normalizeReviewJson(j))).toList();
  }

  Future<List<ListModel>> getRelatedLists(String id) async {
    final resp = await _api.get(
      Endpoints.listsRelated,
      queryParameters: {'movie_id': id},
    );
    return apiList(resp.data, const [
      'lists',
      'items',
    ]).map((json) => ListModel.fromJson(normalizeListModelJson(json))).toList();
  }
}
