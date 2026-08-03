import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';

abstract interface class SearchMovieDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  });
}

class SearchMovieService implements SearchMovieDataSource {
  SearchMovieService(this._api);

  static const pageSize = 48;

  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.searchV2,
      queryParameters: {
        'q': query,
        'type': 'movie',
        'movie_type': filter.type.value,
        'movie_filter_by': filter.availability.value,
        'movie_sort_by': filter.sort.value,
        'page': page,
        'limit': pageSize,
      },
    );
    final data = apiMap(response.data);
    final items = apiList(data, const ['movies'])
        .map(normalizeMovieSummaryJson)
        .map(MovieSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    final totalPages = data['total_pages'] == null
        ? currentPage + (items.length >= pageSize ? 1 : 0)
        : apiInt(data['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}

class UnavailableSearchMovieDataSource implements SearchMovieDataSource {
  const UnavailableSearchMovieDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
