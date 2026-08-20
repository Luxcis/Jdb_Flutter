# 「我的收藏」+ 收藏按钮 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现「我的-我的收藏」6 个子页面（演员/片商/系列/导演/番号/清单）真实数据 + 左滑取消收藏 + 演员批量取关 + 清单排序，并在 common-list 与演员详情页导航栏添加爱心收藏按钮。

**架构：** 新增 `FavoritesDataSource` 服务层（列表/取消收藏/批量/详情状态），复用现有 `PaginationController`/`PaginatedListView`/`ActorGridView`/`Slidable`/`EntityListTile`/`ListSummaryTile` 组件；`ActorGridView`/`ActorCard` 增加可选选择模式；`CommonListPage`/`ActorDetailPage` 接入 `FavoriteButton`。

**技术栈：** Flutter / Provider / go_router / dio（FakeAdapter 测试）/ flutter_slidable / json_serializable

**规格：** `docs/superpowers/specs/2026-08-20-my-collections-design.md`

---

## 文件结构

**创建：**
- `lib/features/profile/services/collections_service.dart` — FavoritesDataSource/Service/Unavailable
- `lib/features/profile/screens/collected_actors_page.dart` — 收藏的演员页（4 Tab + 编辑批量取关）
- `lib/features/profile/screens/collected_entities_page.dart` — 通用实体收藏页 + 收藏的清单页
- `lib/core/widgets/favorite_button.dart` — 共用爱心按钮
- `test/features/profile/collections_service_test.dart`
- `test/features/profile/collected_actors_page_test.dart`
- `test/features/profile/collected_entities_page_test.dart`
- `test/features/profile/collected_lists_page_test.dart`
- `test/core/widgets/favorite_button_test.dart`

**修改：**
- `lib/features/profile/screens/profile_sub_pages.dart` — 「清单」→「收藏的清单」
- `lib/core/router/app_router.dart` — 5 个占位路由改真实页面
- `lib/core/widgets/actor_grid_view.dart` — 选择模式参数
- `lib/core/widgets/actor_card.dart` — 选中角标
- `lib/core/models/actor.dart` + `actor.g.dart` — `ActorDetail.hasCollected`
- `lib/core/network/api_data.dart` — `normalizeActorDetailJson` 补 `has_collected`
- `lib/features/common/screens/common_list_page.dart` — 爱心按钮
- `lib/features/actors/screens/actor_detail_screen.dart` — 爱心按钮
- `lib/features/profile/index.dart` — 导出新页面
- `lib/core/network/endpoints.dart` — 补充收藏相关端点常量（collect_actions / batch_uncollection）

---

### 任务 1：端点常量

**文件：**
- 修改：`lib/core/network/endpoints.dart`

- [ ] **步骤 1：添加端点常量**

在 `Endpoints` 类中追加：

```dart
  // ── 收藏 ──
  static const String usersCollectedActors = '/api/v1/users/collected_actors';
  static const String usersCollectedCodes = '/api/v1/users/collected_codes';
  static const String usersCollectedDirectors =
      '/api/v1/users/collected_directors';
  static const String usersCollectedLists = '/api/v1/users/collected_lists';
  static const String usersCollectedMakers = '/api/v1/users/collected_makers';
  static const String usersCollectedSeries = '/api/v1/users/collected_series';
  static const String actorsBatchUncollection =
      '/api/v1/actors/batch_uncollection';
```

> 注：`usersCollected*` 6 个常量已存在于文件顶部（第 27-34 行），
> 本任务只需**补充** `actorsBatchUncollection` 一个常量。
> 现有 6 个已声明，直接复用，勿重复声明。

- [ ] **步骤 2：验证编译**

运行：`dart analyze lib/core/network/endpoints.dart`
预期：No issues found

- [ ] **步骤 3：Commit**

```bash
git add lib/core/network/endpoints.dart
git commit -m "feat(profile): add batch uncollection endpoint constant"
```

---

### 任务 2：`ActorDetail.hasCollected` + 解析

**文件：**
- 修改：`lib/core/models/actor.dart`
- 修改：`lib/core/models/actor.g.dart`（手写生成代码，与 `build_runner` 输出一致）
- 修改：`lib/core/network/api_data.dart`

- [ ] **步骤 1：模型加字段**

`lib/core/models/actor.dart` 的 `ActorDetail` 增加：

```dart
  /// 当前用户是否已收藏该演员（来自详情接口 `has_collected`）。
  final bool hasCollected;
```

构造函数参数（`super.gender` 之后）增加 `this.hasCollected = false,`。

- [ ] **步骤 2：手写生成代码**

`lib/core/models/actor.g.dart` 的 `_$ActorDetailFromJson` 增加一行
（在 `type:` 行之后）：

```dart
  hasCollected: json['has_collected'] as bool? ?? false,
```

`_$ActorDetailToJson` 增加 `'has_collected': instance.hasCollected,`。

- [ ] **步骤 3：解析归一化**

`lib/core/network/api_data.dart` 的 `normalizeActorDetailJson` 返回 map
增加：

```dart
    'has_collected': apiBool(actor['has_collected'] ?? root['has_collected'], false),
```

> `has_collected` 位于响应 data 顶层（`ActorInfoEntity`），非 actor 对象内。

- [ ] **步骤 4：验证**

运行：`dart analyze lib/core/models/actor.dart lib/core/network/api_data.dart`
预期：No issues

- [ ] **步骤 5：Commit**

```bash
git add lib/core/models/actor.dart lib/core/models/actor.g.dart lib/core/network/api_data.dart
git commit -m "feat(actors): add has_collected to actor detail"
```

---

### 任务 3：`FavoritesDataSource` 服务层（含测试）

**文件：**
- 创建：`lib/features/profile/services/collections_service.dart`
- 测试：`test/features/profile/collections_service_test.dart`

- [ ] **步骤 1：编写失败的测试**

`test/features/profile/collections_service_test.dart`（参照
`user_lists_service_test.dart` 的 fixture 模式）：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/collections_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({FakeAdapter adapter, FavoritesService service})>
buildFavoritesFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: FavoritesService(api));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getCollectedActors 携带 type 参数并解析 actors', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedActors, {
      'success': 1,
      'data': {
        'actors': [
          {'id': 'a1', 'name_zht': '三上悠亜', 'avatar': 'http://img/a1.jpg'},
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });

    final result = await fixture.service.getCollectedActors(
      type: '1',
      page: 1,
    );

    expect(result.items.single.id, 'a1');
    expect(result.items.single.name, '三上悠亜');
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '1',
      'page': 1,
      'limit': 48,
    });
  });

  test('getCollectedMakers 解析 makers 分页', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedMakers, {
      'success': 1,
      'data': {
        'makers': [
          {'id': 'm1', 'name': 'SOD', 'type': 0, 'movie_count': 9},
        ],
        'current_page': 1,
        'total_pages': 1,
      },
    });

    final result = await fixture.service.getCollectedMakers();

    expect(result.items.single.id, 'm1');
    expect(result.items.single.name, 'SOD');
    expect(result.items.single.movieCount, 9);
    expect(fixture.adapter.requests.single.path, Endpoints.usersCollectedMakers);
  });

  test('getCollectedSeries 解析 series', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedSeries, {
      'success': 1,
      'data': {
        'series': [
          {'id': 's1', 'name': 'S1', 'type': 0, 'movie_count': 5},
        ],
      },
    });

    final result = await fixture.service.getCollectedSeries();

    expect(result.items.single.id, 's1');
    expect(result.items.single.name, 'S1');
  });

  test('getCollectedDirectors 解析 directors', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedDirectors, {
      'success': 1,
      'data': {
        'directors': [
          {'id': 'd1', 'name': '北野武', 'movie_count': 2},
        ],
      },
    });

    final result = await fixture.service.getCollectedDirectors();

    expect(result.items.single.id, 'd1');
    expect(result.items.single.name, '北野武');
  });

  test('getCollectedCodes 解析 codes', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedCodes, {
      'success': 1,
      'data': {
        'codes': [
          {'id': 'c1', 'name': 'IPZZ-001', 'movie_count': 3},
        ],
      },
    });

    final result = await fixture.service.getCollectedCodes();

    expect(result.items.single.id, 'c1');
    expect(result.items.single.number, 'IPZZ-001');
  });

  test('getCollectedLists 携带必填 sort_by 并解析 lists', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedLists, {
      'success': 1,
      'data': {
        'lists': [
          {'id': 'l1', 'name': '收藏精选', 'movies_count': 3},
        ],
      },
    });

    final result = await fixture.service.getCollectedLists(sortBy: 'recently');

    expect(result.items.single.id, 'l1');
    expect(fixture.adapter.requests.single.queryParameters, {
      'sort_by': 'recently',
      'page': 1,
      'limit': 48,
    });
  });

  test('uncollectActor 发送 POST collect_actions body uncollect', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue('${Endpoints.actors}/a1/collect_actions', {
      'success': 1,
      'data': null,
    });

    await fixture.service.uncollectActor('a1');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '${Endpoints.actors}/a1/collect_actions');
    expect(request.data, {'name': 'uncollect'});
  });

  test('uncollectMaker/Series/Director/Code/List 发送对应 POST', () async {
    final fixture = await buildFavoritesFixture();
    const targets = {
      '/api/v1/makers/m1/collect_actions': 'uncollectMaker',
      '/api/v1/series/s1/collect_actions': 'uncollectSeries',
      '/api/v1/directors/d1/collect_actions': 'uncollectDirector',
      '/api/v1/codes/c1/collect_actions': 'uncollectCode',
      '/api/v1/lists/l1/collect_actions': 'uncollectList',
    };
    for (final entry in targets.entries) {
      fixture.adapter.requests.clear();
      fixture.adapter.enqueue(entry.key, {
        'success': 1,
        'data': null,
      });
      switch (entry.value) {
        case 'uncollectMaker':
          await fixture.service.uncollectMaker('m1');
        case 'uncollectSeries':
          await fixture.service.uncollectSeries('s1');
        case 'uncollectDirector':
          await fixture.service.uncollectDirector('d1');
        case 'uncollectCode':
          await fixture.service.uncollectCode('c1');
        case 'uncollectList':
          await fixture.service.uncollectList('l1');
      }
      final request = fixture.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, entry.key);
      expect(request.data, {'name': 'uncollect'});
    }
  });

  test('batchUncollectActors 发送 DELETE body ids 逗号拼接', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.actorsBatchUncollection, {
      'success': 1,
      'data': null,
    });

    await fixture.service.batchUncollectActors(['1', '2', '3']);

    final request = fixture.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, Endpoints.actorsBatchUncollection);
    expect(request.data, {'ids': '1,2,3'});
  });

  test('getHasCollected 按 category 解析 has_collected', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue('/api/v1/lists/l1', {
      'success': 1,
      'data': {'has_collected': true, 'list': {'id': 'l1'}},
    });

    final result = await fixture.service.getHasCollected('l', 'l1');

    expect(result, isTrue);
    expect(fixture.adapter.requests.single.path, '/api/v1/lists/l1');
  });

  test('getHasCollected 未知 category 返回 null', () async {
    final fixture = await buildFavoritesFixture();
    final result = await fixture.service.getHasCollected('p', 'x1');
    expect(result, isNull);
    expect(fixture.adapter.requests, isEmpty);
  });

  test('setCollected 发送 collect/uncollect body', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue('/api/v1/actors/a1/collect_actions', {
      'success': 1,
      'data': null,
    });

    await fixture.service.setCollected('a', 'a1', true);

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/actors/a1/collect_actions');
    expect(request.data, {'name': 'collect'});
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/profile/collections_service_test.dart`
预期：编译失败，报错 "collections_service.dart not found" / 类不存在

- [ ] **步骤 3：实现服务层**

`lib/features/profile/services/collections_service.dart`：

```dart
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
    fromJson: (json) =>
        ActorSummary.fromJson(normalizeActorSummaryJson(json)),
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
      _postCollect(Endpoints.codes, id, 'uncollect');

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
    'c': Endpoints.codes,
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
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) =>
      _empty(page);

  @override
  Future<PagedResult<Series>> getCollectedSeries({int page = 1}) =>
      _empty(page);

  @override
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1}) =>
      _empty(page);

  @override
  Future<PagedResult<Code>> getCollectedCodes({int page = 1}) =>
      _empty(page);

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
```

> 注意：`Endpoints.codes` 常量不存在（番号端点文档标注不可用）。
> 若 `Endpoints.codes` 未声明，请改用字面量 `'/api/v1/codes'` 或先补充常量。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/profile/collections_service_test.dart`
预期：全部 PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/services/collections_service.dart test/features/profile/collections_service_test.dart
git commit -m "feat(profile): add favorites data source and service"
```

---

### 任务 4：`FavoriteButton` 共用组件（含测试）

**文件：**
- 创建：`lib/core/widgets/favorite_button.dart`
- 测试：`test/core/widgets/favorite_button_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/favorite_button.dart';

void main() {
  testWidgets('未收藏显示空心爱心，点击回调', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoriteButton(
            hasCollected: false,
            onPressed: () => pressed++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    await tester.tap(find.byType(FavoriteButton));
    expect(pressed, 1);
  });

  testWidgets('已收藏显示实心爱心', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoriteButton(
            hasCollected: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('busy 时禁用点击', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoriteButton(
            hasCollected: false,
            busy: true,
            onPressed: () => pressed++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FavoriteButton), warnIfMissed: false);
    expect(pressed, 0);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/widgets/favorite_button_test.dart`
预期：编译失败，favorite_button.dart 不存在

- [ ] **步骤 3：实现组件**

```dart
import 'package:flutter/material.dart';

/// 导航栏爱心收藏按钮：空心=未收藏，实心=已收藏，busy 时禁用。
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.hasCollected,
    this.busy = false,
    required this.onPressed,
  });

  final bool hasCollected;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: hasCollected ? '取消收藏' : '收藏',
      onPressed: busy ? null : onPressed,
      icon: Icon(
        hasCollected ? Icons.favorite : Icons.favorite_border,
        color: hasCollected ? Colors.redAccent : null,
      ),
    );
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/core/widgets/favorite_button_test.dart`
预期：全部 PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/core/widgets/favorite_button.dart test/core/widgets/favorite_button_test.dart
git commit -m "feat(widgets): add favorite button"
```

---

### 任务 5：`ActorGridView` 选择模式 + `ActorCard` 选中角标

**文件：**
- 修改：`lib/core/widgets/actor_grid_view.dart`
- 修改：`lib/core/widgets/actor_card.dart`

- [ ] **步骤 1：ActorCard 增加选中角标**

`lib/core/widgets/actor_card.dart` 构造函数增加 `this.selected = false`：

```dart
  const ActorCard({super.key, required this.actor, this.onTap, this.selected = false});
  final bool selected;
```

build 中在 `Column` 外包一层 `Stack`（现有 Column 逻辑不变）：

```dart
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: actor.name,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ActorAvatarImage(
                    actor,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: _labelSpacing),
                Text(
                  actor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.check_circle, size: 20, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
```

- [ ] **步骤 2：ActorGridView 增加选择模式参数**

`lib/core/widgets/actor_grid_view.dart` 构造函数增加：

```dart
  const ActorGridView({
    super.key,
    required this.controller,
    this.onActorTap,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
  });

  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(ActorSummary)? onToggleSelect;
```

`itemBuilder` 中 ActorCard 调用改为：

```dart
  return ActorCard(
    actor: controller.items[index],
    onTap: selectionMode
        ? (onToggleSelect == null
              ? null
              : () => onToggleSelect!(controller.items[index]))
        : onActorTap != null
        ? () => onActorTap!(controller.items[index])
        : null,
    selected: selectionMode &&
        selectedIds.contains(controller.items[index].id),
  );
```

- [ ] **步骤 3：验证现有测试不回归**

运行：`flutter test test/core/widgets/actor_grid_view_test.dart test/core/widgets/actor_card_test.dart 2>/dev/null || flutter test test/core/widgets/actor_grid_view_test.dart`
预期：PASS（现有测试未传新参数，走默认分支）

- [ ] **步骤 4：Commit**

```bash
git add lib/core/widgets/actor_grid_view.dart lib/core/widgets/actor_card.dart
git commit -m "feat(widgets): add selection mode to actor grid and card"
```

---

### 任务 6：收藏的实体页 + 清单页（含测试）

**文件：**
- 创建：`lib/features/profile/screens/collected_entities_page.dart`
- 测试：`test/features/profile/collected_entities_page_test.dart`
- 测试：`test/features/profile/collected_lists_page_test.dart`

- [ ] **步骤 1：编写失败的测试**

`test/features/profile/collected_entities_page_test.dart`：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/screens/collected_entities_page.dart';
import 'package:jade/features/profile/services/collections_service.dart';

class _FakeFavoritesDataSource implements FavoritesDataSource {
  _FakeFavoritesDataSource({List<Maker>? makers})
    : makers = List<Maker>.of(makers ?? const []);

  final List<Maker> makers;
  final uncollected = <String>[];
  var failUncollect = false;
  var failGet = false;

  @override
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) async {
    if (failGet) throw StateError('GET failed');
    return PagedResult(
      items: makers,
      currentPage: page,
      totalPages: 1,
      total: makers.length,
    );
  }

  @override
  Future<void> uncollectMaker(String id) async {
    if (failUncollect) throw StateError('uncollect failed');
    uncollected.add(id);
    makers.removeWhere((m) => m.id == id);
  }

  // 其余方法抛 UnimplementedError（页面不会调用）。
  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) => throw UnimplementedError();
  @override
  Future<PagedResult<Series>> getCollectedSeries({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Code>> getCollectedCodes({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  }) => throw UnimplementedError();
  @override
  Future<void> uncollectActor(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectSeries(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectDirector(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectCode(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectList(String id) => throw UnimplementedError();
  @override
  Future<void> batchUncollectActors(List<String> ids) =>
      throw UnimplementedError();
  @override
  Future<bool?> getHasCollected(String category, String id) async => false;
  @override
  Future<void> setCollected(String category, String id, bool collect) async {}
}

List<Maker> _sampleMakers() => [
  Maker(id: 'm1', name: 'SOD', movieCount: 9),
  Maker(id: 'm2', name: 'TMA', movieCount: 4),
];

void main() {
  testWidgets('收藏的片商列表展示并左滑取消收藏', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeFavoritesDataSource(makers: _sampleMakers());
    await tester.pumpWidget(
      MaterialApp(
        home: CollectedEntitiesPage(
          category: 'm',
          title: '收藏的片商',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏的片商'), findsOneWidget);
    expect(find.text('SOD'), findsOneWidget);
    expect(find.text('(9)'), findsOneWidget);

    await tester.drag(find.text('SOD'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('取消收藏'), findsOneWidget);

    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();
    expect(find.text('取消收藏片商？'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(source.uncollected, ['m1']);
    expect(find.text('SOD'), findsNothing);
    expect(find.text('TMA'), findsOneWidget);
  });

  testWidgets('取消收藏失败提示且条目保留', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeFavoritesDataSource(makers: _sampleMakers());
    source.failUncollect = true;
    await tester.pumpWidget(
      MaterialApp(
        home: CollectedEntitiesPage(
          category: 'm',
          title: '收藏的片商',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('SOD'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('取消收藏失败'), findsOneWidget);
    expect(find.text('SOD'), findsOneWidget);
  });
}
```

`test/features/profile/collected_lists_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/screens/collected_entities_page.dart';
import 'package:jade/features/profile/services/collections_service.dart';

class _FakeListFavoritesDataSource implements FavoritesDataSource {
  _FakeListFavoritesDataSource({List<ListModel>? lists})
    : lists = List<ListModel>.of(lists ?? const []);

  final List<ListModel> lists;
  final sortRequests = <String>[];

  @override
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  }) async {
    sortRequests.add(sortBy);
    return PagedResult(
      items: lists,
      currentPage: page,
      totalPages: 1,
      total: lists.length,
    );
  }

  @override
  Future<void> uncollectList(String id) async {}

  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) => throw UnimplementedError();
  @override
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Series>> getCollectedSeries({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Code>> getCollectedCodes({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<void> uncollectActor(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectMaker(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectSeries(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectDirector(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectCode(String id) => throw UnimplementedError();
  @override
  Future<void> batchUncollectActors(List<String> ids) =>
      throw UnimplementedError();
  @override
  Future<bool?> getHasCollected(String category, String id) async => false;
  @override
  Future<void> setCollected(String category, String id, bool collect) async {}
}

void main() {
  testWidgets('收藏的清单默认按更新时间排序，点击切换创建时间', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeListFavoritesDataSource(
      lists: [ListModel(id: 'l1', name: '收藏精选', movieCount: 3)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CollectedListsPage(dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏的清单'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
    expect(source.sortRequests, ['recently']);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    expect(source.sortRequests, ['recently', 'release']);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/profile/collected_entities_page_test.dart test/features/profile/collected_lists_page_test.dart`
预期：编译失败，页面文件不存在

- [ ] **步骤 3：实现页面**

`lib/features/profile/screens/collected_entities_page.dart`（核心结构）：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/collections_service.dart';

/// 收藏的实体（片商/系列/导演/番号）分页页：左滑取消收藏，点击进影片列表。
class CollectedEntitiesPage extends StatefulWidget {
  const CollectedEntitiesPage({
    super.key,
    required this.category,
    required this.title,
    this.dataSource,
  });

  final String category; // m / s / d / c
  final String title;
  final FavoritesDataSource? dataSource;

  @override
  State<CollectedEntitiesPage> createState() => _CollectedEntitiesPageState();
}

class _CollectedEntitiesPageState extends State<CollectedEntitiesPage> {
  late final FavoritesDataSource _dataSource;
  late final PaginationController<dynamic> _controller;
  var _busy = false;

  Future<PagedResult<dynamic>> _fetchPage(int page) {
    final source = _dataSource;
    return switch (widget.category) {
      'm' => source.getCollectedMakers(page: page),
      's' => source.getCollectedSeries(page: page),
      'd' => source.getCollectedDirectors(page: page),
      'c' => source.getCollectedCodes(page: page),
      _ => Future.value(const PagedResult(
          items: [], currentPage: 1, totalPages: 1, total: 0)),
    };
  }

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableFavoritesDataSource()
            : FavoritesService(api));
    _controller = PaginationController<dynamic>(fetch: _fetchPage)
      ..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _uncollect(dynamic item) async {
    final id = _idOf(item);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('取消收藏${widget.category == 'c' ? '番号' : '${_entityLabel()}？'}'),
        content: Text('确定取消收藏「${_nameOf(item)}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      try {
        await _uncollectById(id);
      } catch (error, stackTrace) {
        developer.log('取消收藏失败', name: 'collected-entities', error: error, stackTrace: stackTrace);
        if (!mounted) return;
        _showMessage('取消收藏失败');
        return;
      }
      if (!mounted) return;
      await _controller.reloadWith(_fetchPage);
      if (!mounted) return;
      _showMessage('已取消收藏');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // _idOf/_nameOf/_uncollectById/_entityLabel/_openList 按 category 分发
  // _openList: 与搜索页一致跳 common-list（category: m/s/d/c, title: '片商 - X' 等）

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: PaginatedListView<dynamic>(
            controller: _controller,
            emptyMessage: '暂无${_entityLabel()}',
            itemBuilder: (context, item) => Slidable(
              key: ValueKey('slidable-${_idOf(item)}'),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => unawaited(_uncollect(item)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    icon: Icons.delete_outline,
                    label: '取消收藏',
                  ),
                ],
              ),
              child: EntityListTile(
                name: _nameOf(item),
                count: _countOf(item),
                onTap: () => _openList(item),
              ),
            ),
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x73000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// 收藏的清单页：排序切换 + 左滑取消收藏。
class CollectedListsPage extends StatefulWidget {
  const CollectedListsPage({super.key, this.dataSource});

  final FavoritesDataSource? dataSource;

  @override
  State<CollectedListsPage> createState() => _CollectedListsPageState();
}

class _CollectedListsPageState extends State<CollectedListsPage> {
  static const _sortByRecently = 'recently';
  static const _sortByRelease = 'release';

  late final FavoritesDataSource _dataSource;
  late final PaginationController<ListModel> _controller;
  var _sortBy = _sortByRecently;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableFavoritesDataSource()
            : FavoritesService(api));
    _controller = PaginationController<ListModel>(
      fetch: (page) => _dataSource.getCollectedLists(
        sortBy: _sortBy,
        page: page,
      ),
    )..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSort() {
    setState(() {
      _sortBy = _sortBy == _sortByRecently ? _sortByRelease : _sortByRecently;
    });
    _controller.reloadWith(
      (page) => _dataSource.getCollectedLists(sortBy: _sortBy, page: page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortLabel = _sortBy == _sortByRecently ? '更新时间' : '创建时间';
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏的清单'),
        actions: [
          IconButton(
            key: const Key('collected-lists-sort-button'),
            tooltip: '排序：$sortLabel',
            onPressed: _toggleSort,
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: PaginatedListView<ListModel>(
        controller: _controller,
        emptyMessage: '暂无清单',
        itemBuilder: (context, list) => Slidable(
          key: ValueKey('slidable-${list.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => unawaited(_uncollectList(list)),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                icon: Icons.delete_outline,
                label: '取消收藏',
              ),
            ],
          ),
          child: ListSummaryTile(
            list: list,
            onTap: () => context.push(
              Uri(
                path: AppRoutes.commonList,
                queryParameters: {
                  'title': '清单 - ${list.name}',
                  'type': '0',
                  'category': 'l',
                  'id': list.id,
                },
              ).toString(),
            ),
          ),
        ),
      ),
    );
  }
}
```

`_CollectedListsPageState` 还需 `_uncollectList`（确认弹窗 +
`uncollectList` + reload，模式同 `_uncollect`）、`_showMessage` 与
`_busy` 遮罩（Stack 包裹 Scaffold），参照 `MyListsPage._deleteList`
完整实现。通用实体页的 `_idOf`/`_nameOf`/`_countOf`/`_uncollectById`/
`_openList` 按 category 分发（m/s/d/c → Maker/Series/Director/Code 的
id/name(或 number)/movieCount，跳转 `common-list?category=X&type=item.type`）；
需 import `dart:developer`、`entity_list_tile.dart`、
`list_summary_tile.dart`、`paginated_list_view.dart`、
`go_router`、`routes.dart` 与 `collections_service.dart`。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/profile/collected_entities_page_test.dart test/features/profile/collected_lists_page_test.dart`
预期：全部 PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/screens/collected_entities_page.dart test/features/profile/collected_entities_page_test.dart test/features/profile/collected_lists_page_test.dart
git commit -m "feat(profile): add collected entities and lists pages"
```

---

### 任务 7：收藏的演员页（含测试）

**文件：**
- 创建：`lib/features/profile/screens/collected_actors_page.dart`
- 测试：`test/features/profile/collected_actors_page_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/screens/collected_actors_page.dart';
import 'package:jade/features/profile/services/collections_service.dart';

class _FakeActorsFavoritesDataSource implements FavoritesDataSource {
  _FakeActorsFavoritesDataSource({List<ActorSummary>? actors})
    : actors = List<ActorSummary>.of(actors ?? const []);

  final List<ActorSummary> actors;
  final typeRequests = <String>[];
  final batchUncollected = <List<String>>[];
  var failBatch = false;

  @override
  Future<PagedResult<ActorSummary>> getCollectedActors({
    required String type,
    int page = 1,
  }) async {
    typeRequests.add(type);
    return PagedResult(
      items: actors,
      currentPage: page,
      totalPages: 1,
      total: actors.length,
    );
  }

  @override
  Future<void> batchUncollectActors(List<String> ids) async {
    if (failBatch) throw StateError('batch failed');
    batchUncollected.add(ids);
    actors.removeWhere((a) => ids.contains(a.id));
  }

  @override
  Future<PagedResult<Maker>> getCollectedMakers({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Series>> getCollectedSeries({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Director>> getCollectedDirectors({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<Code>> getCollectedCodes({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<PagedResult<ListModel>> getCollectedLists({
    required String sortBy,
    int page = 1,
  }) => throw UnimplementedError();
  @override
  Future<void> uncollectActor(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectMaker(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectSeries(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectDirector(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectCode(String id) => throw UnimplementedError();
  @override
  Future<void> uncollectList(String id) => throw UnimplementedError();
  @override
  Future<bool?> getHasCollected(String category, String id) async => false;
  @override
  Future<void> setCollected(String category, String id, bool collect) async {}
}

void main() {
  testWidgets('演员 Tab 加载 type 参数且默认全部', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeActorsFavoritesDataSource(
      actors: [ActorSummary(id: 'a1', name: '三上悠亜', avatarUrl: '')],
    );
    await tester.pumpWidget(
      MaterialApp(home: CollectedActorsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏的演员'), findsOneWidget);
    expect(find.text('三上悠亜'), findsOneWidget);
    expect(source.typeRequests, ['all']);
  });

  testWidgets('编辑模式选中演员并批量取关', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeActorsFavoritesDataSource(
      actors: [
        ActorSummary(id: 'a1', name: '三上悠亜', avatarUrl: ''),
        ActorSummary(id: 'a2', name: '深田詠美', avatarUrl: ''),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: CollectedActorsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    // 进入编辑模式
    await tester.tap(find.byKey(const Key('collected-actors-edit-button')));
    await tester.pumpAndSettle();
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('取消收藏(0)'), findsOneWidget);

    // 选中两个演员
    await tester.tap(find.text('三上悠亜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深田詠美'));
    await tester.pumpAndSettle();
    expect(find.text('取消收藏(2)'), findsOneWidget);

    // 确认批量取关
    await tester.tap(find.text('取消收藏(2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(source.batchUncollected, [
      ['a1', 'a2'],
    ]);
    expect(find.text('完成'), findsNothing);
    expect(find.text('三上悠亜'), findsNothing);
    expect(find.text('深田詠美'), findsNothing);
  });

  testWidgets('批量取关失败保留选择并提示', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeActorsFavoritesDataSource(
      actors: [ActorSummary(id: 'a1', name: '三上悠亜', avatarUrl: '')],
    );
    source.failBatch = true;
    await tester.pumpWidget(
      MaterialApp(home: CollectedActorsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('collected-actors-edit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三上悠亜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消收藏(1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('批量取关失败'), findsOneWidget);
    expect(find.text('取消收藏(1)'), findsOneWidget);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/profile/collected_actors_page_test.dart`
预期：编译失败，页面文件不存在

- [ ] **步骤 3：实现页面**

`lib/features/profile/screens/collected_actors_page.dart`（核心结构）：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/collections_service.dart';
import 'package:go_router/go_router.dart';

/// 收藏的演员页：4 Tab（全部/有码/无码/欧美）+ 编辑批量取关。
class CollectedActorsPage extends StatefulWidget {
  const CollectedActorsPage({super.key, this.dataSource});

  final FavoritesDataSource? dataSource;

  @override
  State<CollectedActorsPage> createState() => _CollectedActorsPageState();
}

class _CollectedActorsPageState extends State<CollectedActorsPage>
    with TickerProviderStateMixin {
  static const _tabs = [
    (label: '全部', type: 'all'),
    (label: '有码', type: '0'),
    (label: '无码', type: '1'),
    (label: '欧美', type: '2'),
  ];

  late final FavoritesDataSource _dataSource;
  late final TabController _tabController;
  late final List<PaginationController<ActorSummary>> _controllers;
  final _selectedIds = <String>{};
  var _editing = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableFavoritesDataSource()
            : FavoritesService(api));
    _tabController = TabController(length: _tabs.length, vsync: this);
    _controllers = [
      for (final tab in _tabs)
        PaginationController<ActorSummary>(
          fetch: (page) => _dataSource.getCollectedActors(
            type: tab.type,
            page: page,
          ),
        )..fetchMore(),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _editing = !_editing;
      if (!_editing) _selectedIds.clear();
    });
  }

  void _toggleSelect(ActorSummary actor) {
    setState(() {
      if (!_selectedIds.add(actor.id)) _selectedIds.remove(actor.id);
    });
  }

  Future<void> _batchUncollect() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消收藏演员？'),
        content: Text('确定取消收藏选中的 ${ids.length} 位演员吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      try {
        await _dataSource.batchUncollectActors(ids);
      } catch (_) {
        if (!mounted) return;
        _showMessage('批量取关失败');
        return;
      }
      if (!mounted) return;
      final index = _tabController.index;
      final controller = _controllers[index];
      await controller.reloadWith(
        (page) => _dataSource.getCollectedActors(
          type: _tabs[index].type,
          page: page,
        ),
      );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _selectedIds.clear();
      });
      _showMessage('已取消收藏 ${ids.length} 位演员');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('收藏的演员'),
            actions: [
              if (!_editing)
                IconButton(
                  key: const Key('collected-actors-edit-button'),
                  tooltip: '编辑',
                  onPressed: _toggleEdit,
                  icon: const Icon(Icons.edit_outlined),
                )
              else
                TextButton(
                  key: const Key('collected-actors-done-button'),
                  onPressed: _toggleEdit,
                  child: const Text('完成'),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: _tabs
                  .map((tab) => Tab(text: tab.label))
                  .toList(growable: false),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                ActorGridView(
                  controller: _controllers[i],
                  onActorTap: _editing
                      ? null
                      : (actor) => context.push('/actor/${actor.id}'),
                  selectionMode: _editing,
                  selectedIds: _selectedIds,
                  onToggleSelect: _editing ? _toggleSelect : null,
                ),
            ],
          ),
          bottomNavigationBar: _editing
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      key: const Key('collected-actors-batch-button'),
                      onPressed: _selectedIds.isEmpty ? null : _batchUncollect,
                      icon: const Icon(Icons.delete_outline),
                      label: Text('取消收藏(${_selectedIds.length})'),
                    ),
                  ),
                )
              : null,
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x73000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/profile/collected_actors_page_test.dart`
预期：全部 PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/screens/collected_actors_page.dart test/features/profile/collected_actors_page_test.dart
git commit -m "feat(profile): add collected actors page with batch uncollect"
```

---

### 任务 8：路由接线 + 入口标题

**文件：**
- 修改：`lib/features/profile/screens/profile_sub_pages.dart`
- 修改：`lib/core/router/app_router.dart`
- 修改：`lib/features/profile/index.dart`

- [ ] **步骤 1：入口标题改「收藏的清单」**

`lib/features/profile/screens/profile_sub_pages.dart` 的
`ProfileFavoritesPage` 中：

```dart
        _ProfileCell(
          title: '收藏的清单',
          subtitle: '0部影片，被查看0次',
          icon: Icons.list_alt,
          route: AppRoutes.profileFavoritesLists,
        ),
```

- [ ] **步骤 2：路由改为真实页面**

`lib/core/router/app_router.dart` 的 `profileFavorites*` 5 个路由：

```dart
    GoRoute(
      path: AppRoutes.profileFavoritesActors,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesActors,
        child: const CollectedActorsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesMakers,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesMakers,
        child: const CollectedEntitiesPage(category: 'm', title: '收藏的片商'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesSeries,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesSeries,
        child: const CollectedEntitiesPage(category: 's', title: '收藏的系列'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesDirectors,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesDirectors,
        child: const CollectedEntitiesPage(category: 'd', title: '收藏的导演'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesCodes,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesCodes,
        child: const CollectedEntitiesPage(category: 'c', title: '收藏的番号'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesLists,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesLists,
        child: const CollectedListsPage(),
      ),
    ),
```

> 需在 `app_router.dart` 顶部 import
> `package:jade/features/profile/screens/collected_actors_page.dart` 与
> `collected_entities_page.dart`。

- [ ] **步骤 3：index.dart 导出新页面**

`lib/features/profile/index.dart` 增加：

```dart
export 'screens/collected_actors_page.dart';
export 'screens/collected_entities_page.dart';
```

- [ ] **步骤 4：验证编译 + 全量测试**

运行：`dart analyze lib && flutter test`
预期：No issues；全部 PASS（现有 60+ 测试不回归）

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart lib/core/router/app_router.dart lib/features/profile/index.dart
git commit -m "feat(profile): wire collected pages into routes"
```

---

### 任务 9：CommonListPage 爱心按钮

**文件：**
- 修改：`lib/features/common/screens/common_list_page.dart`

- [ ] **步骤 1：实现收藏按钮逻辑**

在 `_CommonListPageState` 增加：

```dart
  late final FavoritesDataSource _favorites;
  bool? _hasCollected;
  var _favoriteBusy = false;

  @override
  void initState() {
    // ...现有逻辑
    _favorites =
        widget.favoritesDataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => FavoritesService(api),
          null => const UnavailableFavoritesDataSource(),
        };
    _loadCollected();
  }

  Future<void> _loadCollected() async {
    final supported = const {'m', 's', 'd', 'c', 'l', 'a'}.contains(widget.category);
    if (!supported) return;
    final result = await _favorites.getHasCollected(widget.category, widget.id);
    if (!mounted) return;
    setState(() => _hasCollected = result);
  }

  Future<void> _toggleFavorite() async {
    final current = _hasCollected;
    if (current == null || _favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      try {
        await _favorites.setCollected(widget.category, widget.id, !current);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
        return;
      }
      if (!mounted) return;
      setState(() => _hasCollected = !current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(current ? '已取消收藏' : '已收藏')),
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }
```

`CommonListPage` 构造函数增加 `this.favoritesDataSource`（`FavoritesDataSource?`），
并 import `collections_service.dart` 与 `favorite_button.dart`；AppBar
`actions`：

```dart
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_hasCollected != null)
            FavoriteButton(
              hasCollected: _hasCollected!,
              busy: _favoriteBusy,
              onPressed: _toggleFavorite,
            ),
        ],
      ),
```

- [ ] **步骤 2：验证编译**

运行：`dart analyze lib/features/common/screens/common_list_page.dart`
预期：No issues

- [ ] **步骤 3：Commit**

```bash
git add lib/features/common/screens/common_list_page.dart
git commit -m "feat(common): add favorite button to common list page"
```

---

### 任务 10：ActorDetailPage 爱心按钮

**文件：**
- 修改：`lib/features/actors/screens/actor_detail_screen.dart`

- [ ] **步骤 1：实现收藏按钮逻辑**

`_ActorDetailPageState` 增加：

```dart
  var _favoriteBusy = false;

  Future<void> _toggleFavorite() async {
    final detail = _detail;
    if (detail == null || _favoriteBusy) return;
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    setState(() => _favoriteBusy = true);
    try {
      try {
        await FavoritesService(api).setCollected('a', widget.id, !detail.hasCollected);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
        return;
      }
      if (!mounted) return;
      setState(() {
        _detail = ActorDetail(
          id: detail.id,
          name: detail.name,
          avatarUrl: detail.avatarUrl,
          gender: detail.gender,
          hasCollected: !detail.hasCollected,
          // ...其余字段透传
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail.hasCollected ? '已取消收藏' : '已收藏')),
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }
```

AppBar `actions` 在筛选按钮左侧加：

```dart
        actions: [
          FavoriteButton(
            hasCollected: detail.hasCollected,
            busy: _favoriteBusy,
            onPressed: _toggleFavorite,
          ),
          IconButton(
            tooltip: '筛选',
            onPressed: _showFilter,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
```

> `ActorDetail` 字段较多，可用 `ActorDetail.fromJson(detail.toJson())`
> 重建后替换 `has_collected`，或为 `ActorDetail` 增加
> `copyWith({bool? hasCollected})`。

- [ ] **步骤 2：验证编译**

运行：`dart analyze lib/features/actors/screens/actor_detail_screen.dart`
预期：No issues

- [ ] **步骤 3：Commit**

```bash
git add lib/features/actors/screens/actor_detail_screen.dart
git commit -m "feat(actors): add favorite button to actor detail page"
```

---

### 任务 11：全量验证 + 收尾

**文件：**
- 无新文件

- [ ] **步骤 1：全量静态分析**

运行：`dart analyze lib test`
预期：No issues found

- [ ] **步骤 2：全量测试**

运行：`flutter test`
预期：全部 PASS（含新增 4 个测试文件）

- [ ] **步骤 3：最终 Commit（如有未提交变更）**

```bash
git add -A
git commit -m "chore: finalize my-collections feature"
```

> 若步骤 1/2 全部通过且无未提交变更，此步可跳过。
