import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class LatestMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  });
}

class LatestMoviesService implements LatestMoviesDataSource {
  LatestMoviesService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.moviesLatest,
      queryParameters: {
        'type': type,
        'filter_by': filterBy,
        'sort_by': sortBy,
        'page': page,
        'limit': _pageSize,
      },
    );
    return apiPageResult(
      response.data,
      keys: const ['movies', 'items'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) =>
          MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}

class UnavailableLatestMoviesDataSource implements LatestMoviesDataSource {
  const UnavailableLatestMoviesDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
