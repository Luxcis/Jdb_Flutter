import 'package:dio/dio.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/features/movie_detail/models/movie_review_status.dart';

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

  Future<List<Review>> getReviews(String id, {String? sortBy}) async {
    final resp = await _api.get(
      '/api/v1/movies/$id/reviews',
      queryParameters: {
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
      },
    );
    return apiList(resp.data, const [
      'reviews',
      'items',
    ]).map((j) => Review.fromJson(normalizeReviewJson(j))).toList();
  }

  /// 创建或更新影片影评。
  ///
  /// `watched` 状态下的无效评分或评论内容会抛出 [ArgumentError]；响应
  /// 缺少 `review` 或其值不是对象时会抛出 [FormatException]。
  Future<Review> createOrUpdateReview({
    required String movieId,
    required MovieReviewStatus status,
    int? score,
    String? content,
  }) async {
    final data = switch (status) {
      MovieReviewStatus.wantWatch => <String, dynamic>{
        'status': status.wireValue,
      },
      MovieReviewStatus.watched => _watchedReviewData(
        status: status,
        score: score,
        content: content,
      ),
    };
    final response = await _api.post(
      '/api/v1/movies/$movieId/reviews',
      data: data,
    );
    final review = apiMap(response.data)['review'];
    if (review is! Map) {
      throw const FormatException('影评响应缺少 review');
    }
    return Review.fromJson(
      normalizeReviewJson(Map<String, dynamic>.from(review)),
    );
  }

  /// Deletes a review belonging to the specified movie.
  Future<void> deleteReview({
    required String movieId,
    required String reviewId,
  }) async {
    await _api.delete('/api/v1/movies/$movieId/reviews/$reviewId');
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

  Future<List<ListModel>> getSimpleLists(
    String movieId, {
    int page = 1,
    int limit = 48,
  }) async {
    final resp = await _api.get(
      Endpoints.listsSimple,
      queryParameters: {'movie_id': movieId, 'page': page, 'limit': limit},
    );
    return apiList(resp.data, const [
      'lists',
      'items',
    ]).map((json) => ListModel.fromJson(normalizeListModelJson(json))).toList();
  }

  /// 向片单添加或移除影片。
  ///
  /// `action` 取值为 `add` 或 `remove`，对应接口的 `name` 字段；客户端
  /// 调用前已做乐观更新（切换 has_movie、更新 movies_count）。
  Future<void> toggleMovieInList({
    required String listId,
    required String movieId,
    required String action,
  }) async {
    await _api.post(
      '${Endpoints.lists}/$listId/movie_actions',
      data: FormData.fromMap({'movie_id': movieId, 'name': action}),
    );
  }

  Future<void> createListWithMovie({
    required String name,
    required String movieId,
  }) async {
    await _api.post(
      Endpoints.lists,
      data: FormData.fromMap({'name': name, 'movie_id': movieId}),
    );
  }

  Map<String, dynamic> _watchedReviewData({
    required MovieReviewStatus status,
    required int? score,
    required String? content,
  }) {
    if (score == null || score < 1 || score > 5) {
      throw ArgumentError.value(score, 'score', '评分必须为 1 到 5');
    }
    final trimmedContent = content?.trim();
    if (trimmedContent == null || trimmedContent.isEmpty) {
      throw ArgumentError.value(content, 'content', '评论不能为空');
    }
    return {
      'score': score,
      'content': trimmedContent,
      'status': status.wireValue,
    };
  }
}
