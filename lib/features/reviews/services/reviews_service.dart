import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/reviews/models/review_period.dart';

class ReviewsService {
  ReviewsService(this._api);

  /// 从全局 ApiClient 单例创建服务；未初始化（无连接）时返回 null，
  /// 由调用方按未登录/无连接错误处理。
  static ReviewsService? tryCreate() {
    final api = ApiClient.instanceOrNull;
    return api == null ? null : ReviewsService(api);
  }

  static const pageSize = 20;

  final ApiClient _api;

  Future<PagedResult<Review>> getHotReviews({
    required ReviewPeriod period,
    int page = 1,
    int limit = pageSize,
  }) async {
    final response = await _api.get(
      Endpoints.reviewsHotly,
      queryParameters: {'period': period.value, 'page': page, 'limit': limit},
    );
    final data = apiMap(response.data);
    final items = apiList(data, const [
      'reviews',
    ]).map(normalizeReviewJson).map(Review.fromJson).toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    // 接口不返回 total_pages，用「返回条数不足 limit 即到底」推断。
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: items.length < limit ? currentPage : currentPage + 1,
      total: items.length,
    );
  }
}
