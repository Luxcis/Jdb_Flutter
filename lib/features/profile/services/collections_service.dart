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

/// 番号端点路径字面量：`Endpoints.codes` 未声明（番号端点文档标注不可用）。
const String _codesPath = '/api/v1/codes';

/// 我的收藏数据源抽象，便于测试注入与 API 不可用时降级。
abstract interface class FavoritesDataSource {
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  });
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1});
  Future<PagedResult<Series>> getCollectedSeries({int page = 1});
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1});
  Future<PagedResult<Code>> getCollectedCodes({int page = 1});
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  });

  Future<void> uncollectActor(String id);
  Future<void> uncollectMaker(String id);
  Future<void> uncollectSeries(String id);
  Future<void> uncollectDirector(String id);
  Future<void> uncollectCode(String id);
  Future<void> uncollectList(String id);
  Future<void> batchUncollectActors(List<String> ids);

  /// 实体详情收藏状态；未知 category 或请求失败返回 null（页面隐藏按钮）。
  Future<bool?> getHasCollected(String category, String id);
  Future<void> setCollected(String category, String id, bool collect);
}

/// 默认 API 实现。全部接口需 BearerAuth（由 ApiClient 拦截器注入）。
class FavoritesService implements FavoritesDataSource {
  FavoritesService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  Future<PagedResult<T>> _getPage<T>({
    required String path,
    required Map<String, dynamic> query,
    required List<String> keys,
    required int page,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _api.get(
      path,
      queryParameters: {...query, 'page': page, 'limit': _pageSize},
    );
    return apiPageResult(
      response.data,
      keys: keys,
      page: page,
      pageSize: _pageSize,
      fromJson: fromJson,
    );
  }

  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) => _getPage(
    path: Endpoints.usersCollectedActors,
    query: {'type': type},
    keys: const ['actors', 'items'],
    page: page,
    fromJson: (json) => ActorSummary.fromJson(normalizeActorSummaryJson(json)),
  );

  @override
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) => _getPage(
    path: Endpoints.usersCollectedMakers,
    query: const {},
    keys: const ['makers', 'items'],
    page: page,
    fromJson: (json) => Maker.fromJson(normalizeMakerJson(json)),
  );

  @override
  Future<PagedResult<Series>> getCollectedSeries({int page = 1}) => _getPage(
    path: Endpoints.usersCollectedSeries,
    query: const {},
    keys: const ['series', 'items'],
    page: page,
    fromJson: (json) => Series.fromJson(_namedEntityJson(json)),
  );

  @override
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1}) =>
      _getPage(
        path: Endpoints.usersCollectedDirectors,
        query: const {},
        keys: const ['directors', 'items'],
        page: page,
        fromJson: (json) => Director.fromJson(normalizeDirectorJson(json)),
      );

  @override
  Future<PagedResult<Code>> getCollectedCodes({int page = 1}) => _getPage(
    path: Endpoints.usersCollectedCodes,
    query: const {},
    keys: const ['codes', 'items'],
    page: page,
    fromJson: (json) => Code.fromJson(_codeJson(json)),
  );

  @override
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  }) => _getPage(
    path: Endpoints.usersCollectedLists,
    query: {'sort_by': sortBy},
    keys: const ['lists', 'items'],
    page: page,
    fromJson: (json) => ListModel.fromJson(normalizeListModelJson(json)),
  );

  @override
  Future<void> uncollectActor(String id) =>
      _postCollect(Endpoints.actors, id, 'uncollect');

  @override
  Future<void> uncollectMaker(String id) =>
      _postCollect(Endpoints.makers, id, 'uncollect');

  @override
  Future<void> uncollectSeries(String id) =>
      _postCollect(Endpoints.series, id, 'uncollect');

  @override
  Future<void> uncollectDirector(String id) =>
      _postCollect(Endpoints.directors, id, 'uncollect');

  @override
  Future<void> uncollectCode(String id) =>
      _postCollect(_codesPath, id, 'uncollect');

  @override
  Future<void> uncollectList(String id) =>
      _postCollect(Endpoints.lists, id, 'uncollect');

  Future<void> _postCollect(String entityPath, String id, String name) async {
    await _api.post('$entityPath/$id/collect_actions', data: {'name': name});
  }

  @override
  Future<void> batchUncollectActors(List<String> ids) async {
    await _api.delete(
      Endpoints.actorsBatchUncollection,
      data: {'ids': ids.join(',')},
    );
  }

  static const _detailPathByCategory = {
    'm': Endpoints.makers,
    's': Endpoints.series,
    'd': Endpoints.directors,
    'c': _codesPath,
    'l': Endpoints.lists,
    'a': Endpoints.actors,
  };

  @override
  Future<bool?> getHasCollected(String category, String id) async {
    final entityPath = _detailPathByCategory[category];
    if (entityPath == null) return null;
    try {
      final response = await _api.get('$entityPath/$id');
      return apiBool(apiMap(response.data)['has_collected'], false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setCollected(String category, String id, bool collect) async {
    final entityPath = _detailPathByCategory[category];
    if (entityPath == null) return;
    await _postCollect(entityPath, id, collect ? 'collect' : 'uncollect');
  }
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

/// ApiClient 未初始化时的空实现（页面数据源注入缺省值）。
class UnavailableFavoritesDataSource implements FavoritesDataSource {
  const UnavailableFavoritesDataSource();

  Future<PagedResult<T>> _empty<T>(int page) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) => _empty(page);

  @override
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) => _empty(page);

  @override
  Future<PagedResult<Series>> getCollectedSeries({int page = 1}) =>
      _empty(page);

  @override
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1}) =>
      _empty(page);

  @override
  Future<PagedResult<Code>> getCollectedCodes({int page = 1}) => _empty(page);

  @override
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  }) => _empty(page);

  @override
  Future<void> uncollectActor(String id) async {}

  @override
  Future<void> uncollectMaker(String id) async {}

  @override
  Future<void> uncollectSeries(String id) async {}

  @override
  Future<void> uncollectDirector(String id) async {}

  @override
  Future<void> uncollectCode(String id) async {}

  @override
  Future<void> uncollectList(String id) async {}

  @override
  Future<void> batchUncollectActors(List<String> ids) async {}

  @override
  Future<bool?> getHasCollected(String category, String id) async => null;

  @override
  Future<void> setCollected(String category, String id, bool collect) async {}
}
