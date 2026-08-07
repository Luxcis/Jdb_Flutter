import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class DirectorDataSource {
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  });
}

class DirectorService implements DirectorDataSource {
  DirectorService(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.directors,
      queryParameters: {'type': '$type', 'page': page, 'limit': limit},
    );
    return apiPageResult(
      response.data,
      keys: ['directors'],
      page: page,
      pageSize: limit,
      fromJson: (json) => Director.fromJson(normalizeDirectorJson(json)),
    );
  }
}

class UnavailableDirectorDataSource implements DirectorDataSource {
  const UnavailableDirectorDataSource();

  @override
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
