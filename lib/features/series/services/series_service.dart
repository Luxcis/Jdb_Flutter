import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/series/models/series_letter.dart';

abstract interface class SeriesDataSource {
  Future<PagedResult<SeriesLetter>> getLetters({int page = 1, int limit = 48});

  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  });
}

class SeriesService implements SeriesDataSource {
  SeriesService(this._api);

  /// 从全局 ApiClient 单例解析数据源；未初始化（无连接）时返回
  /// [UnavailableSeriesDataSource]，由其返回空态页。
  static SeriesDataSource resolve() {
    final api = ApiClient.instanceOrNull;
    return api == null
        ? const UnavailableSeriesDataSource()
        : SeriesService(api);
  }

  final ApiClient _api;

  @override
  Future<PagedResult<SeriesLetter>> getLetters({
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.seriesLetters,
      queryParameters: {'page': page, 'limit': limit},
    );
    return apiPageResult(
      response.data,
      keys: const ['letters'],
      page: page,
      pageSize: limit,
      fromJson: SeriesLetter.fromJson,
    );
  }

  @override
  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.series,
      queryParameters: {'type': type, 'page': page, 'limit': limit},
    );
    return apiPageResult(
      response.data,
      keys: const ['series'],
      page: page,
      pageSize: limit,
      fromJson: (json) => Series.fromJson(_seriesJson(json)),
    );
  }
}

Map<String, dynamic> _seriesJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};

class UnavailableSeriesDataSource implements SeriesDataSource {
  const UnavailableSeriesDataSource();

  Future<PagedResult<T>> _empty<T>(int page) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<PagedResult<SeriesLetter>> getLetters({
    int page = 1,
    int limit = 48,
  }) => _empty(page);

  @override
  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  }) => _empty(page);
}
