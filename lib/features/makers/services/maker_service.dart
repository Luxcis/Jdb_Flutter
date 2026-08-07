import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class MakerDataSource {
  Future<PagedResult<Maker>> getMakers({
    required int type,
    int page = 1,
    int limit = 48,
  });
}

class MakerService implements MakerDataSource {
  MakerService(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<Maker>> getMakers({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.makers,
      queryParameters: {'type': '$type', 'page': page, 'limit': limit},
    );
    return apiPageResult(
      response.data,
      keys: ['makers'],
      page: page,
      pageSize: limit,
      fromJson: (json) => Maker.fromJson(normalizeMakerJson(json)),
    );
  }
}

class UnavailableMakerDataSource implements MakerDataSource {
  const UnavailableMakerDataSource();

  @override
  Future<PagedResult<Maker>> getMakers({
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
