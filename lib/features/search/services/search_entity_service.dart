import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class SearchEntityDataSource {
  Future<PagedResult<ActorSummary>> getActors({
    required String query,
    int page = 1,
  });

  Future<PagedResult<Series>> getSeries({required String query, int page = 1});

  Future<PagedResult<Maker>> getMakers({required String query, int page = 1});

  Future<PagedResult<Director>> getDirectors({
    required String query,
    int page = 1,
  });

  Future<PagedResult<ListModel>> getLists({
    required String query,
    int page = 1,
  });

  Future<PagedResult<Code>> getCodes({required String query, int page = 1});
}

class SearchEntityService implements SearchEntityDataSource {
  SearchEntityService(this._api);

  static const pageSize = 48;

  final ApiClient _api;

  Future<PagedResult<T>> _getPage<T>({
    required String query,
    required String type,
    required String collectionKey,
    required int page,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _api.get(
      Endpoints.searchV2,
      queryParameters: {
        'q': query,
        'type': type,
        'page': page,
        'limit': pageSize,
      },
    );
    return apiPageResult(
      response.data,
      keys: [collectionKey],
      page: page,
      pageSize: pageSize,
      fromJson: fromJson,
    );
  }

  @override
  Future<PagedResult<ActorSummary>> getActors({
    required String query,
    int page = 1,
  }) => _getPage(
    query: query,
    type: 'actor',
    collectionKey: 'actors',
    page: page,
    fromJson: (json) => ActorSummary.fromJson(normalizeActorSummaryJson(json)),
  );

  @override
  Future<PagedResult<Series>> getSeries({
    required String query,
    int page = 1,
  }) => _getPage(
    query: query,
    type: 'series',
    collectionKey: 'series',
    page: page,
    fromJson: (json) => Series.fromJson(_namedEntityJson(json)),
  );

  @override
  Future<PagedResult<Maker>> getMakers({required String query, int page = 1}) =>
      _getPage(
        query: query,
        type: 'maker',
        collectionKey: 'makers',
        page: page,
        fromJson: (json) => Maker.fromJson(normalizeMakerJson(json)),
      );

  @override
  Future<PagedResult<Director>> getDirectors({
    required String query,
    int page = 1,
  }) => _getPage(
    query: query,
    type: 'director',
    collectionKey: 'directors',
    page: page,
    fromJson: (json) => Director.fromJson(normalizeDirectorJson(json)),
  );

  @override
  Future<PagedResult<ListModel>> getLists({
    required String query,
    int page = 1,
  }) => _getPage(
    query: query,
    type: 'list',
    collectionKey: 'lists',
    page: page,
    fromJson: (json) => ListModel.fromJson(normalizeListModelJson(json)),
  );

  @override
  Future<PagedResult<Code>> getCodes({required String query, int page = 1}) =>
      _getPage(
        query: query,
        type: 'code',
        collectionKey: 'codes',
        page: page,
        fromJson: (json) => Code.fromJson(_codeJson(json)),
      );
}

Map<String, dynamic> _namedEntityJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};

Map<String, dynamic> _codeJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id'] ?? json['name'] ?? json['number']) ?? '',
  'number': apiString(json['number'] ?? json['name'] ?? json['id']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};

class UnavailableSearchEntityDataSource implements SearchEntityDataSource {
  const UnavailableSearchEntityDataSource();

  Future<PagedResult<T>> _empty<T>(int page) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<PagedResult<ActorSummary>> getActors({
    required String query,
    int page = 1,
  }) => _empty(page);

  @override
  Future<PagedResult<Series>> getSeries({
    required String query,
    int page = 1,
  }) => _empty(page);

  @override
  Future<PagedResult<Maker>> getMakers({required String query, int page = 1}) =>
      _empty(page);

  @override
  Future<PagedResult<Director>> getDirectors({
    required String query,
    int page = 1,
  }) => _empty(page);

  @override
  Future<PagedResult<ListModel>> getLists({
    required String query,
    int page = 1,
  }) => _empty(page);

  @override
  Future<PagedResult<Code>> getCodes({required String query, int page = 1}) =>
      _empty(page);
}
