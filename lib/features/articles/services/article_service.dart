import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/articles/models/article.dart';

class ArticleService {
  ArticleService(this._api);

  /// 从全局 ApiClient 单例创建服务；未初始化（无连接）时返回 null，
  /// 由调用方按未登录/无连接空态处理。
  static ArticleService? tryCreate() {
    final api = ApiClient.instanceOrNull;
    return api == null ? null : ArticleService(api);
  }

  static const _pageSize = 48;
  final ApiClient _api;

  Future<PagedResult<ArticleSummary>> getArticles({int page = 1}) async {
    final response = await _api.get(
      Endpoints.articles,
      queryParameters: {'page': page, 'limit': _pageSize},
    );
    final data = apiMap(response.data);
    final items = apiList(data, const ['articles'])
        .map(normalizeArticleSummaryJson)
        .map(ArticleSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: currentPage + (items.length >= _pageSize ? 1 : 0),
      total: apiInt(data['total'], items.length),
    );
  }

  Future<ArticleDetail> getArticleDetail(String id) async {
    final response = await _api.get('${Endpoints.articles}/$id');
    return ArticleDetail.fromJson(normalizeArticleDetailJson(response.data));
  }
}
