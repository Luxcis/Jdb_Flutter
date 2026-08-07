import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class TagMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  });
}

class TagMoviesService implements TagMoviesDataSource {
  TagMoviesService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  }) async {
    final filterBy = filter.isEmpty
        ? '$type:$category:$id'
        : '$type:$category:$id:$filter';
    final query = <String, dynamic>{
      'filter_by': filterBy,
      'sort_by': sortBy,
      if (sortBy == 'release') 'order_by': orderBy,
      'page': page,
      'limit': _pageSize,
    };
    final response = await _api.get(
      Endpoints.moviesTags,
      queryParameters: query,
    );
    return apiPageResult(
      response.data,
      keys: const ['movies', 'items'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) => MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}

class UnavailableTagMoviesDataSource implements TagMoviesDataSource {
  const UnavailableTagMoviesDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
