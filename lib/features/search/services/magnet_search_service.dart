import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/search/models/magnet_search_sort.dart';

abstract interface class MagnetSearchDataSource {
  Future<PagedResult<Magnet>> getMagnets({
    required String query,
    required MagnetSearchSort sort,
    required bool fromRecent,
    int page = 1,
  });
}

class MagnetSearchService implements MagnetSearchDataSource {
  MagnetSearchService(this._api);

  static const pageSize = 48;

  final ApiClient _api;

  @override
  Future<PagedResult<Magnet>> getMagnets({
    required String query,
    required MagnetSearchSort sort,
    required bool fromRecent,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.searchMagnet,
      queryParameters: {
        'q': query,
        'sort_by': sort.apiValue,
        'from_recent': fromRecent.toString(),
        'page': page,
        'limit': pageSize,
      },
    );
    final data = apiMap(response.data);
    final items = apiList(data, const [
      'magnets',
    ]).map(normalizeMagnetJson).map(Magnet.fromJson).toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: items.length >= pageSize ? currentPage + 1 : currentPage,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}
