import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';

/// 评论相关 API 封装（core 层，供通用组件复用）。
class ReviewApi {
  ReviewApi(this._api);

  final ApiClient _api;

  /// 为指定评论点赞（幂等）。
  Future<void> likeReview({
    required String movieId,
    required String reviewId,
  }) async {
    await _api.post(
      Endpoints.reviewLike
          .replaceAll('{movie_id}', movieId)
          .replaceAll('{review_id}', reviewId),
    );
  }
}
