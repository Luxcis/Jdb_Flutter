import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class ReviewMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  });
}

class ReviewMoviesService implements ReviewMoviesDataSource {
  ReviewMoviesService(this._api);

  static const _pageSize = 24;

  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.usersReviewMoviesV2,
      queryParameters: {
        'status': status,
        'type': type,
        'sort_by': sortBy,
        'order_by': orderBy,
        'page': page,
        'limit': _pageSize,
      },
    );
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) =>
          MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}

class UnavailableReviewMoviesDataSource implements ReviewMoviesDataSource {
  const UnavailableReviewMoviesDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
