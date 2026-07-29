import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';

abstract interface class CategoryDataSource {
  Future<List<CategoryTagGroup>> getTags({required int type});

  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<CategoryFilterGroupOrder> groupOrder,
    int page = 1,
  });
}

class UnavailableCategoryDataSource implements CategoryDataSource {
  const UnavailableCategoryDataSource();

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async => const [];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<CategoryFilterGroupOrder> groupOrder,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}

class CategoryService implements CategoryDataSource {
  CategoryService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async {
    final response = await _api.get(
      Endpoints.tagsV2,
      queryParameters: {'type': type},
    );
    return apiList(response.data, const [
      'tags',
    ]).map(CategoryTagGroup.fromJson).toList(growable: false);
  }

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<CategoryFilterGroupOrder> groupOrder,
    int page = 1,
  }) async {
    final query = <String, dynamic>{
      'filter_by': filter.toFilterBy(type, groupOrder),
      'sort_by': filter.sort.value,
      if (filter.sort == CategorySort.release) 'order_by': filter.orderBy,
      'page': page,
      'limit': _pageSize,
    };
    final response = await _api.get(
      Endpoints.moviesTags,
      queryParameters: query,
    );
    final data = apiMap(response.data);
    final items = apiList(data, const ['movies', 'items'])
        .map(normalizeMovieSummaryJson)
        .map(MovieSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    final totalPages = data['total_pages'] == null
        ? currentPage + (items.length >= _pageSize ? 1 : 0)
        : apiInt(data['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}
