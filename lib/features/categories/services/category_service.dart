import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';

class CategoryService {
  CategoryService(this._api);
  final ApiClient _api;

  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    String sortBy = 'date',
    String orderBy = 'desc',
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      Endpoints.moviesTags,
      queryParameters: {
        'type': type,
        'filter_by': 'categories',
        'sort_by': sortBy,
        'order_by': orderBy,
        'page': page,
        'limit': limit,
      },
    );
    final m = resp.data as Map<String, dynamic>;
    final items = apiList(m, const [
      'movies',
      'items',
    ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
    return PagedResult(
      items: items,
      currentPage: apiInt(m['current_page'], 1),
      totalPages: apiInt(m['total_pages'], 1),
      total: apiInt(m['total'], 0),
    );
  }
}
