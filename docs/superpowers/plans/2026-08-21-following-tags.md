# 我的-我的关注 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现「我的-我的关注」标签关注/取消关注功能，含本地缓存、启动同步、类别页快捷关注入口、我的关注列表页与按标签 value 筛选的影片列表页。

**架构：** 新建 `lib/features/following/` feature，内含 `FollowTagItem` 模型、`FollowingTagsStore`（SharedPreferences 缓存）、`FollowingTagsService`（网络 API）、`FollowingTagsProvider`（全局状态 ChangeNotifier）、`FollowingPage`（我的关注页）、`FollowTagMoviesPage`（影片列表页）、`FollowingTagsButton`（类别页按钮）。数据流：登录缓存 → 启动 batch_push 覆盖 → 类别页关注/取消 → 我的关注页左滑取消。

**技术栈：** Flutter + Dart，Dio（ApiClient），SharedPreferences（缓存），provider（状态管理），json_serializable（模型）。

---

## 文件结构

**新建文件：**
- `lib/features/following/models/follow_tag.dart` — `FollowTagItem` 模型 + `fromJson`
- `lib/features/following/services/following_tags_store.dart` — `FollowingTagsStore` 缓存抽象 + SharedPreferences 实现
- `lib/features/following/services/following_tags_service.dart` — `FollowingTagsDataSource` 抽象 + `FollowingTagsService` 网络实现 + `UnavailableFollowingTagsDataSource`
- `lib/features/following/services/following_tags_provider.dart` — 全局状态 `FollowingTagsProvider`
- `lib/features/following/widgets/following_tags_button.dart` — 类别页可见性按钮
- `lib/features/following/screens/following_page.dart` — 我的关注页
- `lib/features/following/screens/follow_tag_movies_page.dart` — 按标签 value 的影片列表页
- `lib/features/following/index.dart` — 对外入口

**修改文件：**
- `lib/core/network/endpoints.dart` — 新增 following_tags 端点常量
- `lib/core/storage/storage_keys.dart` — 新增 `followingTags` key
- `lib/main.dart` — 注册 `FollowingTagsProvider`
- `lib/features/categories/screens/categories_screen.dart` — 类别页 AppBar 插入关注按钮
- `lib/features/auth/screens/login_screen.dart` — 登录时解析 `following_tags` 写入 provider
- `lib/features/startup/screens/startup_screen.dart` — 启动已登录时 `syncFromRemote`
- `lib/core/router/app_router.dart` — 首页顶栏等无需改；我的关注页已挂载（`/profile/following`）
- `lib/features/profile/screens/profile_sub_pages.dart` — `ProfileFollowingPage` 改为复用/委托给 `FollowingPage`
- `lib/core/providers/auth_provider.dart` — 注意：`logout()` 时触发清空（从 consumer 侧接入，不改 AuthProvider 内部——见 Task 5）

**测试文件（新建）：**
- `test/features/following/following_tags_store_test.dart`
- `test/features/following/following_tags_service_test.dart`
- `test/features/following/following_tags_provider_test.dart`
- `test/features/following/following_tags_button_test.dart`
- `test/features/following/following_page_test.dart`
- `test/features/following/follow_tag_movies_page_test.dart`
- `test/features/auth/login_screen_following_tags_test.dart`
- `test/features/startup/startup_following_sync_test.dart`

---

## 任务 1：端点常量与存储 key

**文件：**
- 修改：`lib/core/network/endpoints.dart`
- 修改：`lib/core/storage/storage_keys.dart`

**背景：** following_tags 相关接口端点已由 openapi 确认，但 `Endpoints` 尚未声明这些常量。

- [ ] **步骤 1：在 `Endpoints` 增加常量**

在 `lib/core/network/endpoints.dart` 的「标签」分组后追加：

```dart
  // ── 关注标签 (需 BearerAuth) ──
  static const String followingTags = '/api/v1/following_tags';
  static const String followingTagsBatchPush = '/api/v1/following_tags/batch_push';
```

- [ ] **步骤 2：在 `StorageKeys` 增加 key**

在 `lib/core/storage/storage_keys.dart` 的 `StorageKeys` 类中追加：

```dart
  static const String followingTags = 'key_following_tags';
```

- [ ] **步骤 3：Commit**

```bash
git add lib/core/network/endpoints.dart lib/core/storage/storage_keys.dart
git commit -m "feat(following): add following_tags endpoints and storage key"
```

---

## 任务 2：FollowTagItem 模型

**文件：**
- 创建：`lib/features/following/models/follow_tag.dart`

**背景：** `POST /following_tags` 返回 `data` 含真实 `id`；login/batch_push 返回 `following_tags` 数组。字段：`id`（openapi 标 int，统一存 String）、`name`、`value`、`priority`（num?）。

- [ ] **步骤 1：编写模型文件**

创建 `lib/features/following/models/follow_tag.dart`：

```dart
import 'package:jade/core/network/api_data.dart';

/// 标签关注项，对应 API 的 FollowTagItem / 关注返回的 data 对象。
class FollowTagItem {
  const FollowTagItem({
    required this.id,
    required this.name,
    required this.value,
    this.priority,
  });

  /// 标签 id（openapi 标为 int，统一存 String 便于缓存与 DELETE 路径拼接）。
  final String id;

  /// 已选中标签名称，用 ',' 拼接。
  final String name;

  /// filter_by 片段（也作为 /api/v1/movies/tags 的 filter_by 参数值）。
  final String value;

  /// 优先级权重（可空）。
  final num? priority;

  factory FollowTagItem.fromJson(Map<String, dynamic> json) => FollowTagItem(
    id: apiString(json['id']) ?? '',
    name: apiString(json['name']) ?? '',
    value: apiString(json['value']) ?? '',
    priority: json['priority'] is num ? (json['priority'] as num?) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    if (priority != null) 'priority': priority,
  };
}
```

> 说明：`apiString` 已能处理 int->string 转换吗？需确认。`apiString` 定义在 `api_data.dart:65`。若它只接受 String，则 `id` 为数字时需要先 `toString()`。为避免依赖 `apiString` 的类型约束，`id` 解析改用 `(json['id'] ?? '').toString()`，见步骤 2 修正。

- [ ] **步骤 2：修正 id 解析为类型安全的字符串化**

将 `id` 行改为：

```dart
  factory FollowTagItem.fromJson(Map<String, dynamic> json) => FollowTagItem(
    id: (json['id'] ?? '').toString(),
    name: apiString(json['name']) ?? '',
    value: apiString(json['value']) ?? '',
    priority: json['priority'] is num ? (json['priority'] as num?) : null,
  );
```

- [ ] **步骤 3：编写 fromJson 单测**

创建 `test/features/following/following_tags_model_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';

void main() {
  test('fromJson 解析 id 为字符串且容忍数字 id', () {
    final item = FollowTagItem.fromJson({
      'id': 13384922,
      'name': '有碼,森螢',
      'value': '0:a:g1Q',
      'priority': 6.0,
    });
    expect(item.id, '13384922');
    expect(item.name, '有碼,森螢');
    expect(item.value, '0:a:g1Q');
    expect(item.priority, 6.0);
  });

  test('fromJson 缺省 priority 为 null', () {
    final item = FollowTagItem.fromJson({'id': '1', 'name': 'n', 'value': 'v'});
    expect(item.priority, isNull);
  });

  test('toJson 往返保留字段', () {
    final item = FollowTagItem(
      id: '1',
      name: 'n',
      value: 'v',
      priority: 2,
    );
    expect(item.toJson(), {'id': '1', 'name': 'n', 'value': 'v', 'priority': 2});
  });
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/following/following_tags_model_test.dart`
预期：PASS，3 个测试通过。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/following/models/follow_tag.dart test/features/following/following_tags_model_test.dart
git commit -m "feat(following): add FollowTagItem model"
```

---

## 任务 3：FollowingTagsStore 缓存

**文件：**
- 创建：`lib/features/following/services/following_tags_store.dart`

**背景：** 用 `SharedPreferences` 存 JSON 数组；提供 load/save/clear。抽象出接口便于测试注入。

- [ ] **步骤 1：编写缓存抽象与实现**

创建 `lib/features/following/services/following_tags_store.dart`：

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/features/following/models/follow_tag.dart';

/// 关注标签本地缓存抽象，便于测试注入。
abstract interface class FollowingTagsStore {
  Future<List<FollowTagItem>> load();
  Future<void> save(List<FollowTagItem> tags);
  Future<void> clear();
}

/// 基于 [SharedPreferences] 的默认实现，以 JSON 数组持久化。
class PrefsFollowingTagsStore implements FollowingTagsStore {
  PrefsFollowingTagsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<FollowTagItem>> load() async {
    final raw = _prefs.getString(StorageKeys.followingTags);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => FollowTagItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    } catch (_) {
      // 畸形 JSON 视作空列表，避免启动崩溃。
      return const [];
    }
  }

  @override
  Future<void> save(List<FollowTagItem> tags) async {
    await _prefs.setString(
      StorageKeys.followingTags,
      jsonEncode(tags.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(StorageKeys.followingTags);
  }
}
```

- [ ] **步骤 2：编写缓存单测**

创建 `test/features/following/following_tags_store_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save 后可 load 出相同数据', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsFollowingTagsStore(prefs);
    await store.save(const [
      FollowTagItem(id: '1', name: 'a', value: 'v1', priority: 2),
      FollowTagItem(id: '2', name: 'b', value: 'v2'),
    ]);

    final loaded = await store.load();
    expect(loaded.length, 2);
    expect(loaded[0].id, '1');
    expect(loaded[0].name, 'a');
    expect(loaded[0].priority, 2);
    expect(loaded[1].priority, isNull);
  });

  test('无缓存时返回空列表', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsFollowingTagsStore(prefs);
    expect(await store.load(), isEmpty);
  });

  test('畸形 JSON 返回空列表而不抛异常', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('key_following_tags', 'not-valid-json');
    final store = PrefsFollowingTagsStore(prefs);
    expect(await store.load(), isEmpty);
  });

  test('clear 后加载为空', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsFollowingTagsStore(prefs);
    await store.save(const [FollowTagItem(id: '1', name: 'a', value: 'v')]);
    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
```

- [ ] **步骤 3：运行测试验证通过**

运行：`flutter test test/features/following/following_tags_store_test.dart`
预期：PASS，4 个测试通过。

- [ ] **步骤 4：Commit**

```bash
git add lib/features/following/services/following_tags_store.dart test/features/following/following_tags_store_test.dart
git commit -m "feat(following): add FollowingTagsStore cache"
```

---

## 任务 4：FollowingTagsService 网络层

**文件：**
- 创建：`lib/features/following/services/following_tags_service.dart`

**背景：** 提供 follow / unfollow / batchPush 三个网络方法。follow 返回新建的 `FollowTagItem`（含 id）；batchPush 返回远程 `following_tags` 列表。

- [ ] **步骤 1：编写数据源抽象与实现**

创建 `lib/features/following/services/following_tags_service.dart`：

```dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/following/models/follow_tag.dart';

/// 关注标签数据源抽象，便于测试注入与 API 不可用时降级。
abstract interface class FollowingTagsDataSource {
  /// 关注单个标签，返回含真实 id 的新建关注项。
  Future<FollowTagItem> follow({required String name, required String value});

  /// 取消关注指定 id 的标签。
  Future<void> unfollow(String id);

  /// 批量同步：推送本地标签，返回服务端权威关注列表。
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags);
}

/// 默认 API 实现，全部需 BearerAuth（由 ApiClient 拦截器注入）。
class FollowingTagsService implements FollowingTagsDataSource {
  FollowingTagsService(this._api);

  final ApiClient _api;

  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async {
    final response = await _api.post(
      Endpoints.followingTags,
      data: {'name': name, 'value': value},
    );
    final data = apiMap(apiMap(response.data)['data']);
    return FollowTagItem.fromJson(data);
  }

  @override
  Future<void> unfollow(String id) async {
    await _api.delete('${Endpoints.followingTags}/$id');
  }

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async {
    final response = await _api.post(
      Endpoints.followingTagsBatchPush,
      data: {
        'tags': [
          for (final tag in tags)
            {'name': tag.name, 'value': tag.value, if (tag.priority != null) 'priority': tag.priority},
        ],
      },
    );
    final list = apiList(apiMap(response.data), const ['following_tags']);
    return list.map(FollowTagItem.fromJson).toList(growable: false);
  }
}

/// ApiClient 未初始化时的空实现。
class UnavailableFollowingTagsDataSource implements FollowingTagsDataSource {
  const UnavailableFollowingTagsDataSource();

  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async => const FollowTagItem(id: '', name: name, value: value);

  @override
  Future<void> unfollow(String id) async {}

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
}
```

> 说明：`apiList(root, keys)` 会在 `root` 中查 `following_tags`。`batchPush` 响应结构是 `{success, data: {following_tags: [...]}}`，故用 `apiList(apiMap(response.data), ['following_tags'])`，其中 `apiMap(response.data)` 取到 `data` 层。若 `apiList` 是作用于 `data` 层之上，需确认其 keys 查找路径——见步骤 2 修正依赖 `api_data` 的行为。

- [ ] **步骤 2：确认 `api_list` 走查**

`apiList(dynamic value, List<String> keys)` 定义在 `api_data.dart:9`。它会沿 `keys` 在嵌套对象中取值。调用 `apiList(apiMap(response.data), ['following_tags'])` 意味着从 `data` 对象中取 `following_tags`。若实际响应 `data` 层含 `following_tags`，此调用正确。若 `batch_push` 的 `data` 直接用 `data.following_tags`，上述成立。**实现时以响应结构为准，优先用单测锁定。**

- [ ] **步骤 3：编写服务单测**

创建 `test/features/following/following_tags_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({FakeAdapter adapter, FollowingTagsService service})>
buildFollowingFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: FollowingTagsService(api));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('follow 发送 name/value 并解析返回 data 为 FollowTagItem', () async {
    final fixture = await buildFollowingFixture();
    fixture.adapter.enqueue(Endpoints.followingTags, {
      'success': 1,
      'data': {'id': 13384922, 'name': '有碼,森螢', 'value': '0:a:g1Q', 'priority': 6.0},
    });

    final item = await fixture.service.follow(name: '有碼,森螢', value: '0:a:g1Q');

    expect(item.id, '13384922');
    expect(item.name, '有碼,森螢');
    expect(item.value, '0:a:g1Q');
    expect(fixture.adapter.requests.single.data, {
      'name': '有碼,森螢',
      'value': '0:a:g1Q',
    });
  });

  test('unfollow 调用 DELETE 且路径拼接 id', () async {
    final fixture = await buildFollowingFixture();
    fixture.adapter.enqueue('${Endpoints.followingTags}/12345', {
      'success': 1,
    });

    await fixture.service.unfollow('12345');

    expect(fixture.adapter.requests.single.path, '${Endpoints.followingTags}/12345');
  });

  test('batchPush 发送 tags 数组并解析远程 following_tags', () async {
    final fixture = await buildFollowingFixture();
    fixture.adapter.enqueue(Endpoints.followingTagsBatchPush, {
      'success': 1,
      'data': {'following_tags': [
        {'id': 1, 'name': 'a', 'value': 'v1'},
        {'id': 2, 'name': 'b', 'value': 'v2'},
      ]},
    });

    final result = await fixture.service.batchPush(const [
      FollowTagItemForService(id: '1', name: 'a', value: 'v1'),
    ] as List, ); // 见步骤 4 修正：用 FollowTagItem

    expect(result.length, 2);
    expect(result[0].id, '1');
    expect(result[1].id, '2');
  });
}
```

> 注意：测试里第三个用例的入参错误（`FollowTagItemForService` 不存在）。步骤 4 给出正确版本，避免占位符。

- [ ] **步骤 4：修正第三个用例为正确的 FollowTagItem 入参**

将 `batchPush` 用例改为：

```dart
    final result = await fixture.service.batchPush(const [
      FollowTagItem(id: '1', name: 'a', value: 'v1'),
    ]);

    expect(result.length, 2);
    expect(result[0].id, '1');
    expect(result[1].id, '2');
    expect(fixture.adapter.requests.single.data['tags'], [
      {'name': 'a', 'value': 'v1'},
    ]);
```

并补上 `import 'package:jade/features/following/models/follow_tag.dart';`。

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/features/following/following_tags_service_test.dart`
预期：PASS，3 个测试通过。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/following/services/following_tags_service.dart test/features/following/following_tags_service_test.dart
git commit -m "feat(following): add FollowingTagsService network layer"
```

---

## 任务 5：FollowingTagsProvider 全局状态

**文件：**
- 创建：`lib/features/following/services/following_tags_provider.dart`

**背景：** 全局 ChangeNotifier 持有 `List<FollowTagItem>`，提供 `isFollowing(value)`、`follow`、`unfollow`、`syncFromLogin`、`syncFromRemote`、`clear`。初始化时从 store 加载。

- [ ] **步骤 1：编写 Provider**

创建 `lib/features/following/services/following_tags_provider.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';

/// 全局关注标签状态，负责缓存与远程同步。
class FollowingTagsProvider extends ChangeNotifier {
  FollowingTagsProvider({
    required FollowingTagsStore store,
    required FollowingTagsDataSource dataSource,
  }) : _store = store,
       _dataSource = dataSource;

  final FollowingTagsStore _store;
  final FollowingTagsDataSource _dataSource;

  List<FollowTagItem> _tags = const [];
  bool _initialized = false;

  List<FollowTagItem> get tags => List.unmodifiable(_tags);
  bool get initialized => _initialized;

  /// 是否已关注具备该 value 的标签。
  bool isFollowing(String value) =>
      _tags.any((tag) => tag.value == value);

  /// 初始化：从本地缓存加载。幂等。
  Future<void> initialize() async {
    if (_initialized) return;
    _tags = await _store.load();
    _initialized = true;
    notifyListeners();
  }

  /// 关注单个标签；成功后写缓存。
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async {
    final item = await _dataSource.follow(name: name, value: value);
    _tags = [item, ..._tags];
    await _persist();
    notifyListeners();
    return item;
  }

  /// 取消关注；成功后写缓存。
  Future<void> unfollow(String id) async {
    await _dataSource.unfollow(id);
    _tags = _tags.where((tag) => tag.id != id).toList(growable: false);
    await _persist();
    notifyListeners();
  }

  /// 登录时从接口刷入。
  Future<void> syncFromLogin(List<FollowTagItem> tags) async {
    _tags = List.unmodifiable(tags);
    await _persist();
    notifyListeners();
  }

  /// 启动时 batch_push 用远程覆盖本地。
  Future<void> syncFromRemote() async {
    try {
      final remote = await _dataSource.batchPush(_tags);
      _tags = List.unmodifiable(remote);
      await _persist();
      notifyListeners();
    } catch (error, stackTrace) {
      // 网络错误保留本地缓存，不抛出以免打断启动。
      debugPrint('FollowingTags sync failed: $error');
    }
  }

  /// 登出时清空。
  Future<void> clear() async {
    _tags = const [];
    await _store.clear();
    notifyListeners();
  }

  Future<void> _persist() => _store.save(_tags);
}
```

- [ ] **步骤 2：编写 Provider 单测**

创建 `test/features/following/following_tags_provider_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore implements FollowingTagsStore {
  List<FollowTagItem> stored = [];
  _MemoryStore([this.stored = const []]);
  @override
  Future<void> clear() async => stored = [];
  @override
  Future<List<FollowTagItem>> load() async => stored;
  @override
  Future<void> save(List<FollowTagItem> tags) async => stored = List.of(tags);
}

class _FakeData implements FollowingTagsDataSource {
  _FakeData({this.followResult, this.unfollowError, this.remote});
  FollowTagItem? followResult;
  Object? unfollowError;
  List<FollowTagItem>? remote;
  List<String> unfollowed = [];
  int followCalls = 0;
  @override
  Future<FollowTagItem> follow({required String name, required String value}) async {
    followCalls++;
    return followResult ?? FollowTagItem(id: 'new', name: name, value: value);
  }
  @override
  Future<void> unfollow(String id) async {
    if (unfollowError != null) throw unfollowError!;
    unfollowed.add(id);
  }
  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async =>
      remote ?? tags;
}

void main() {
  test('isFollowing 依据 value 判断', () async {
    final provider = FollowingTagsProvider(
      store: _MemoryStore(),
      dataSource: _FakeData(),
    );
    await provider.initialize();
    await provider.follow(name: 'n', value: 'v1');
    expect(provider.isFollowing('v1'), isTrue);
    expect(provider.isFollowing('v2'), isFalse);
  });

  test('follow 插入头部并持久化', () async {
    final store = _MemoryStore();
    final provider = FollowingTagsProvider(store: store, dataSource: _FakeData());
    await provider.initialize();
    await provider.follow(name: 'a', value: 'va');
    await provider.follow(name: 'b', value: 'vb');
    expect(provider.tags.first.value, 'vb');
    expect(store.stored.length, 2);
  });

  test('unfollow 移除匹配 id 并持久化', () async {
    final store = _MemoryStore(const [
      FollowTagItem(id: '1', name: 'a', value: 'va'),
      FollowTagItem(id: '2', name: 'b', value: 'vb'),
    ]);
    final fake = _FakeData();
    final provider = FollowingTagsProvider(store: store, dataSource: fake);
    await provider.initialize();
    await provider.unfollow('1');
    expect(provider.tags.single.id, '2');
    expect(fake.unfollowed, ['1']);
    expect(store.stored.single.id, '2');
  });

  test('syncFromRemote 用远程覆盖本地且失败保留本地', () async {
    final store = _MemoryStore(const [FollowTagItem(id: '1', name: 'a', value: 'va')]);
    final provider = FollowingTagsProvider(store: store, dataSource: _FakeData(
      remote: const [FollowTagItem(id: '9', name: 'x', value: 'vx')],
    ));
    await provider.initialize();
    await provider.syncFromRemote();
    expect(provider.tags.single.id, '9');
  });

  test('clear 清空列表与缓存', () async {
    final store = _MemoryStore(const [FollowTagItem(id: '1', name: 'a', value: 'va')]);
    final provider = FollowingTagsProvider(store: store, dataSource: _FakeData());
    await provider.initialize();
    await provider.clear();
    expect(provider.tags, isEmpty);
    expect(store.stored, isEmpty);
  });
}
```

- [ ] **步骤 3：运行测试验证通过**

运行：`flutter test test/features/following/following_tags_provider_test.dart`
预期：PASS，5 个测试通过。

- [ ] **步骤 4：Commit**

```bash
git add lib/features/following/services/following_tags_provider.dart test/features/following/following_tags_provider_test.dart
git commit -m "feat(following): add FollowingTagsProvider global state"
```

---

## 任务 6：注册 Provider 与登录/启动/登出联动

**文件：**
- 修改：`lib/main.dart`
- 修改：`lib/features/auth/screens/login_screen.dart`
- 修改：`lib/features/startup/screens/startup_screen.dart`
- 修改：`lib/features/profile/screens/profile_sub_pages.dart`（登出触发清空）——经 `ProfilePage` 里的退出按钮实现，见步骤 4

**背景：** 把 `FollowingTagsProvider` 挂进 `MultiProvider`；登录/启动/登出时联动。

- [ ] **步骤 1：在 main.dart 注册 Provider**

修改 `lib/main.dart` 的 `_buildEntry`，在 `ChangeNotifierProvider.value(value: authProvider)` 附近新建 store/datasource，并加进 `providers` 列表：

```dart
final followingStore = PrefsFollowingTagsStore(prefs);
final followingProvider = FollowingTagsProvider(
  store: followingStore,
  dataSource: switch (ApiClient.instanceOrNull) {
    final api? => FollowingTagsService(api),
    null => const UnavailableFollowingTagsDataSource(),
  },
);
```

并在 `providers` 列表中加入：

```dart
ChangeNotifierProvider.value(value: followingProvider),
```

并在返回前 `unawaited(followingProvider.initialize());`（加载缓存）。

> 依赖：需 `import 'package:jade/features/following/services/following_tags_provider.dart';` 与 `following_tags_service.dart`、`following_tags_store.dart`。

- [ ] **步骤 2：登录时写入 following_tags**

修改 `lib/features/auth/screens/login_screen.dart` 的 `_login()`，在成功登录后（`context.read<AuthProvider>().login(...)` 之后）解析 `following_tags`：

```dart
final following = data['following_tags'];
if (following is List) {
  final tags = following
      .map((e) => FollowTagItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(growable: false);
  await context
      .read<FollowingTagsProvider>()
      .syncFromLogin(tags);
}
```

并补 import：`import 'package:jade/features/following/models/follow_tag.dart';` 与 `import 'package:jade/features/following/services/following_tags_provider.dart';`。

- [ ] **步骤 3：启动已登录时 batch_push 同步**

修改 `lib/features/startup/screens/startup_screen.dart` 的 `_refreshSessionThenNavigate()`，在 `status == success && auth.isLogged` 分支、`context.go(AppRoutes.home)` 之前：

```dart
await context.read<FollowingTagsProvider>().syncFromRemote();
```

并补 import：`import 'package:jade/features/following/services/following_tags_provider.dart';`。

> 注意：`syncFromRemote` 内部 catch 了网络错误，不会抛异常打断导航，因此放在 `context.go` 之前安全。

- [ ] **步骤 4：登出时清空**

`ProfilePage` 的退出登录按钮在 `profile_sub_pages.dart` 的 `ProfilePage`（实际在 `profile_screen.dart`）。确认退出入口位置后，在退出前调用 `context.read<FollowingTagsProvider>().clear();`。若 `ProfilePage` 直接调 `AuthProvider.logout()`，则在 `logout()` 调用前置一行 `await context.read<FollowingTagsProvider>().clear();`。

> 同时，`onAuthError`（token 过期）在 `main.dart` 触发 `authProvider.logout()`，需在登出路径也清空。为集中处理，本设计选择：在登出的 UI 出口清空缓存（`ProfilePage`），并补充 `onAuthError` 场景——实现时若 `onAuthError` 也需清空，可在 `main.dart` 的 `onAuthError` 回调里加 `unawaited(followingProvider.clear());`。

- [ ] **步骤 5：Commit**

```bash
git add lib/main.dart lib/features/auth/screens/login_screen.dart lib/features/startup/screens/startup_screen.dart
git commit -m "feat(following): wire provider into login/startup/logout"
```

---

## 任务 7：FollowingTagsButton 类别页按钮

**文件：**
- 创建：`lib/features/following/widgets/following_tags_button.dart`
- 修改：`lib/features/categories/screens/categories_screen.dart`

**背景：** 类别页 AppBar 中「筛选」按钮之前插入关注按钮。未关注 `Icons.visibility`，已关注 `Icons.visibility_off`；返回一个决定其状态（isFollowing / 是否可点 / 点击行为）的回调。

- [ ] **步骤 1：编写按钮组件**

创建 `lib/features/following/widgets/following_tags_button.dart`：

```dart
import 'package:flutter/material.dart';

/// 类别页导航栏「关注标签」按钮。
/// [following] 是否已关注；[enabled] 是否有可关注的已选标签；[busy] 请求中禁用。
class FollowingTagsButton extends StatelessWidget {
  const FollowingTagsButton({
    super.key,
    required this.following,
    required this.enabled,
    this.busy = false,
    required this.onPressed,
  });

  final bool following;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: following ? '取消关注' : '关注',
      onPressed: busy || !enabled ? null : onPressed,
      icon: Icon(following ? Icons.visibility_off : Icons.visibility),
    );
  }
}
```

- [ ] **步骤 2：在类别页插入按钮**

修改 `lib/features/categories/screens/categories_screen.dart` 的 `build`，在 `actions` 的「筛选」`IconButton` **之前**插入 `FollowingTagsButton`，状态跟随当前选中 Tab 的 `_controllers[_selectedIndex]`：

```dart
actions: [
  ListenableBuilder(
    listenable: _controllers[_selectedIndex],
    builder: (context, _) {
      final controller = _controllers[_selectedIndex];
      final followed = context.watch<FollowingTagsProvider>();
      final value = controller.filter.toFilterBy(
        controller.type,
        controller._groupOrder, // 需为公开，或改用公开 API
      );
      final enabled = /* 已选中标签非空 */;
      return FollowingTagsButton(
        following: followed.isFollowing(value),
        enabled: enabled,
        onPressed: () => _toggleFollowing(controller, value),
      );
    },
  ),
  IconButton(key: const Key('categories-filter-button'), ...),
  const SearchIconButton(),
],
```

> 注意：`controller._groupOrder` 是私有。需在 `CategoryTabController` 暴露一个公开 getter（如 `List<CategoryFilterGroupOrder> get groupOrder`），或在按钮处用 `controller.filter.toFilterBy(controller.type, controller.groupOrder)`。**实现时在 `CategoryTabController` 加公开 `groupOrder` getter**。同理判断「已选中标签非空」需一个公开方法，例如 `bool get hasSelectedTags => filter.extraByCategory.values.any((s) => s.isNotEmpty)` 或复用 `filter` 的选中集合。

- [ ] **步骤 3：实现 `_toggleFollowing`**

在 `_CategoriesPageState` 中新增：

```dart
Future<void> _toggleFollowing(CategoryTabController controller, String value) async {
  final provider = context.read<FollowingTagsProvider>();
  if (provider.isFollowing(value)) {
    final tag = provider.tags.firstWhere((t) => t.value == value);
    try {
      await provider.unfollow(tag.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消关注')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
    }
  } else {
    final name = _selectedTagNames(controller);
    try {
      await provider.follow(name: name, value: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已关注')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
    }
  }
}

String _selectedTagNames(CategoryTabController controller) {
  final names = <String>[];
  for (final group in controller.groups) {
    final selected = controller.filter.selectedValues(group.categoryId);
    for (final item in group.tags) {
      if (selected.contains(item.id)) names.add(item.name);
    }
  }
  return names.join(',');
}
```

> `name` 用已选中标签名称拼接；`value` 用 `toFilterBy(type, groupOrder)`。符合需求「将当前选中的标签名称使用,拼接为 name，构建的 filter_by 作为 value」。

- [ ] **步骤 4：编写按钮 widget 测试**

创建 `test/features/following/following_tags_button_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/widgets/following_tags_button.dart';

void main() {
  testWidgets('未关注显示 visibility 图标', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FollowingTagsButton(
        following: false,
        enabled: true,
        onPressed: () {},
      )),
    ));
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsNothing);
  });

  testWidgets('已关注显示 visibility_off 图标', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FollowingTagsButton(
        following: true,
        enabled: true,
        onPressed: () {},
      )),
    ));
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('enabled=false 时禁用按钮', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FollowingTagsButton(
        following: false,
        enabled: false,
        onPressed: () => pressed = true,
      )),
    ));
    await tester.tap(find.byType(IconButton));
    expect(pressed, isFalse);
  });
}
```

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/features/following/following_tags_button_test.dart`
预期：PASS，3 个测试通过。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/following/widgets/following_tags_button.dart lib/features/categories/screens/categories_screen.dart test/features/following/following_tags_button_test.dart
git commit -m "feat(following): add category page following button"
```

---

## 任务 8：FollowingPage 我的关注页

**文件：**
- 创建：`lib/features/following/screens/following_page.dart`
- 修改：`lib/features/profile/screens/profile_sub_pages.dart`（`ProfileFollowingPage` 委托/替换为 `FollowingPage`）

**背景：** 展示已关注标签列表；左滑取消；点击跳转影片列表页；空态提示。

- [ ] **步骤 1：编写页面**

创建 `lib/features/following/screens/following_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/screens/follow_tag_movies_page.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:provider/provider.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  Future<void> _unfollow(FollowTagItem tag) async {
    final provider = context.read<FollowingTagsProvider>();
    try {
      await provider.unfollow(tag.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消关注')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FollowingTagsProvider>();
    final tags = provider.tags;
    return Scaffold(
      appBar: AppBar(title: const Text('我的关注')),
      body: tags.isEmpty
          ? const Center(child: Text('暂无关注标签'))
          : ListView.builder(
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Dismissible(
                  key: ValueKey(tag.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _unfollow(tag),
                  child: ListTile(
                    title: Text(tag.name),
                    subtitle: Text(tag.value),
                    onTap: () => context.push(
                      '/following/tag/${Uri.encodeComponent(tag.value)}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
```

> 路由：`/following/tag/:value` 需在 `AppRouter` 注册，或复用现有 `CommonListPage` 路径。本设计采用新路由 `FollowTagMoviesPage`。

- [ ] **步骤 2：将 ProfileFollowingPage 委托为 FollowingPage**

修改 `lib/features/profile/screens/profile_sub_pages.dart` 中 `ProfileFollowingPage`，改为：

```dart
class ProfileFollowingPage extends StatelessWidget {
  const ProfileFollowingPage({super.key});

  @override
  Widget build(BuildContext context) => const FollowingPage();
}
```

并补 import：`import 'package:jade/features/following/screens/following_page.dart';`。

- [ ] **步骤 3：编写页面 widget 测试**

创建 `test/features/following/following_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/screens/following_page.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:provider/provider.dart';

class _MemoryStore implements FollowingTagsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<List<FollowTagItem>> load() async => const [];
  @override
  Future<void> save(List<FollowTagItem> tags) async {}
}

class _FakeData implements FollowingTagsDataSource {
  @override
  Future<FollowTagItem> follow({required String name, required String value}) async =>
      FollowTagItem(id: 'n', name: name, value: value);
  @override
  Future<void> unfollow(String id) async {}
  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
}

void main() {
  testWidgets('空态展示暂无关注标签', (tester) async {
    final provider = FollowingTagsProvider(store: _MemoryStore(), dataSource: _FakeData());
    await provider.initialize();
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: provider)],
      child: const MaterialApp(home: FollowingPage()),
    ));
    expect(find.text('暂无关注标签'), findsOneWidget);
  });

  testWidgets('列表展示标签且点击跳转', (tester) async {
    final provider = FollowingTagsProvider(store: _MemoryStore(), dataSource: _FakeData());
    await provider.initialize();
    await provider.syncFromLogin(const [
      FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
    ]);
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: provider)],
      child: const MaterialApp(home: FollowingPage()),
    ));
    expect(find.text('有碼,森螢'), findsOneWidget);
    expect(find.text('0:a:g1Q'), findsOneWidget);
  });
}
```

> 点击跳转若依赖 `context.push` 与路由，widget 测试可能需要路由包装。步骤 4 说明如何处理：若 `push` 在无 `GoRouter` 时抛错，可仅测列表渲染，跳转逻辑留 integration/手动验证。

- [ ] **步骤 4：补充跳转路由**

在 `lib/core/router/app_router.dart` 注册 `/following/tag/:value`，指向 `FollowTagMoviesPage`。由于 `FollowTagMoviesPage` 需从路由参数取 `value`，在页面构造时传入 `value`。

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/features/following/following_page_test.dart`
预期：PASS。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/following/screens/following_page.dart lib/features/profile/screens/profile_sub_pages.dart lib/core/router/app_router.dart test/features/following/following_page_test.dart
git commit -m "feat(following): add following page with dismiss to unfollow"
```

---

## 任务 9：FollowTagMoviesPage 影片列表页

**文件：**
- 创建：`lib/features/following/screens/follow_tag_movies_page.dart`

**背景：** `GET /api/v1/movies/tags`，`filter_by = tag.value`，排序仅「更新日期(update)」「发布日期(release)」。复用 `PaginationController` + `MovieGridView` + `SortSegmented`。

- [ ] **步骤 1：扩展数据源以直接传 filter_by（可选，或在页面内直接调 ApiClient）**

最简做法：`FollowTagMoviesPage` 内部直接持有 `ApiClient`，构造 `PaginationController` 的 fetch 大调 `_api.get(Endpoints.moviesTags, queryParameters: {filter_by, sort_by, order_by, page, limit})`，用 `apiPageResult` 解析。为便于测试，页面接收一个 `Future<PagedResult<MovieSummary>> Function(int page, String sortBy, String orderBy)` 数据方法或一个 `TagMoviesDataSource` 变体。

- [ ] **步骤 2：编写页面**

创建 `lib/features/following/screens/follow_tag_movies_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';

typedef _SortOption = ({String label, String value});

class FollowTagMoviesPage extends StatefulWidget {
  const FollowTagMoviesPage({super.key, required this.value});

  final String value;

  @override
  State<FollowTagMoviesPage> createState() => _FollowTagMoviesPageState();
}

class _FollowTagMoviesPageState extends State<FollowTagMoviesPage> {
  static const _sortOptions = [
    (label: '更新日期', value: 'update'),
    (label: '发布日期', value: 'release'),
  ];

  late final PaginationController<MovieSummary> _ctrl;
  late String _sort;
  late String _orderBy;

  @override
  void initState() {
    super.initState();
    _sort = 'update';
    _orderBy = 'desc';
    _ctrl = PaginationController<MovieSummary>(fetch: _fetchPage)..fetchMore();
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);
    }
    final query = <String, dynamic>{
      'filter_by': widget.value,
      'sort_by': _sort,
      if (_sort == 'release') 'order_by': _orderBy,
      'page': page,
      'limit': 48,
    };
    final response = await api.get(Endpoints.moviesTags, queryParameters: query);
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: 48,
      fromJson: (json) => MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }

  void _changeSort(String? value) {
    if (value == null || value == _sort) return;
    setState(() => _sort = value);
    _ctrl.reloadWith(_fetchPage);
  }

  void _toggleOrder() {
    setState(() => _orderBy = _orderBy == 'asc' ? 'desc' : 'asc');
    _ctrl.reloadWith(_fetchPage);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('标签影片')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SortSegmented<String>(
                  key: const Key('follow-tag-sort'),
                  compact: true,
                  options: _sortOptions,
                  value: _sort,
                  onChanged: _changeSort,
                ),
                IconButton(
                  key: const Key('follow-tag-order-toggle'),
                  tooltip: _orderBy == 'asc' ? '倒序' : '正序',
                  onPressed: _sort == 'release' ? _toggleOrder : null,
                  icon: Icon(_orderBy == 'asc' ? Icons.arrow_upward : Icons.arrow_downward),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: MovieGridView(controller: _ctrl)),
        ],
      ),
    );
  }
}
```

- [ ] **步骤 3：编写页面 widget 测试**

创建 `test/features/following/follow_tag_movies_page_test.dart`，用 `FakeAdapter` 桩住 `moviesTags`，验证：

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/following/screens/follow_tag_movies_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(FakeAdapter, DomainManager)> setup() async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    final adapter = FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter
      ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
    final api = ApiClient.forTest(dio: dio, domainManager: dm);
    adapter.enqueue(Endpoints.moviesTags, {
      'success': 1,
      'data': {
        'movies': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1', 'cover_url': ''},
        ],
        'current_page': 1,
        'total_pages': 1,
      },
    });
    return (adapter, dm);
  }

  testWidgets('排序仅含更新日期与发布日期两项', (tester) async {
    await setup();
    await tester.pumpWidget(const MaterialApp(
      home: FollowTagMoviesPage(value: '0:a:g1Q'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('更新日期'), findsOneWidget);
    expect(find.text('发布日期'), findsOneWidget);
    expect(find.text('评分'), findsNothing);
  });

  testWidgets('默认排序为更新日期且请求携带 filter_by', (tester) async {
    final (adapter, _) = await setup();
    await tester.pumpWidget(const MaterialApp(
      home: FollowTagMoviesPage(value: '0:a:g1Q'),
    ));
    await tester.pumpAndSettle();

    final request = adapter.requests.first;
    expect(request.queryParameters['filter_by'], '0:a:g1Q');
    expect(request.queryParameters['sort_by'], 'update');
  });
}
```

- [ ] **步骤 4：在 app_router.dart 注册路由**

在 `AppRoutes` 加 `static const String followTagMovies = '/following/tag/:value';`，在 `AppRouter` 注册指向 `FollowTagMoviesPage`，从 `state.pathParameters['value']` 取参并 `Uri.decodeComponent`。

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/features/following/follow_tag_movies_page_test.dart`
预期：PASS。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/following/screens/follow_tag_movies_page.dart lib/core/router/app_router.dart test/features/following/follow_tag_movies_page_test.dart
git commit -m "feat(following): add followed tag movie list page"
```

---

## 任务 10：登录/启动联动测试

**文件：**
- 创建：`test/features/auth/login_screen_following_tags_test.dart`
- 创建：`test/features/startup/startup_following_sync_test.dart`

**背景：** 验证登录成功解析 `following_tags`、启动已登录时调用 `syncFromRemote`。

- [ ] **步骤 1：登录写入 following_tags 测试**

在 `test/features/auth/login_screen_following_tags_test.dart` 中，注入 fake `ApiClient`（用 `FakeAdapter` 桩住 `/api/v1/sessions` 返回含 `following_tags` 的响应），pump `LoginPage`，登录后断言 `FollowingTagsProvider.tags` 为空或已写入。参考现有 `login_screen_test.dart` 的桩方式。

> 若现有登录测试已有一套 mock，可复用其 fixture，仅新增断言点（`provider.isFollowing('0:a:g1Q')`）。

- [ ] **步骤 2：启动同步测试**

在 `test/features/startup/startup_following_sync_test.dart` 中，桩住 startup 与 `batch_push`，断言 `startup_screen` 加载后 `FollowingTagsProvider.tags` 被远程覆盖。

- [ ] **步骤 3：运行测试验证通过**

运行：
```
flutter test test/features/auth/login_screen_following_tags_test.dart
flutter test test/features/startup/startup_following_sync_test.dart
```
预期：均 PASS。

- [ ] **步骤 4：Commit**

```bash
git add test/features/auth/login_screen_following_tags_test.dart test/features/startup/startup_following_sync_test.dart
git commit -m "test(following): cover login and startup following sync"
```

---

## 任务 11：整体验证（dart analyze + flutter test）

**文件：**
- 无新增；验证整个项目。

**背景：** 验证无 lint 错误、所有测试通过。

- [ ] **步骤 1：静态分析**

运行：`flutter analyze`
预期：无 errors / warnings（若引入未使用 import 会有 warning，需清理）。

- [ ] **步骤 2：全量测试**

运行：`flutter test`
预期：全部通过（含既有测试回归）。

- [ ] **步骤 3：确认无破坏**

运行 `flutter build`（可选，若有破坏性修改）。若出现既有测试破坏，排查是否因 `ProfileFollowingPage` 改动或 provider 注册导致，修复之。

- [ ] **步骤 4：Commit**

```bash
git add -A
git commit -m "chore(following): verify analyze and tests"
```

---

## 自检

**1. 规格覆盖度：** 规格各需求对应的任务？
- 登录缓存 following_tags → 任务 6 步骤 2 ✓
- 启动 batch_push 覆盖 → 任务 6 步骤 3 ✓
- 关注 POST + 更新缓存 → 任务 5 follow + 任务 7 按钮 ✓
- 取消关注 DELETE + 更新缓存 → 任务 5 unfollow + 任务 7/_7 取消 ✓
- 影片列表 filter_by=value + 排序仅 update/release → 任务 9 ✓
- 类别页按钮 visibility/visibility_off → 任务 7 ✓
- 我的关注列表 + 左滑取消 → 任务 8 ✓
- 登出清空 → 任务 6 步骤 4 ✓

**2. 占位符扫描：** 任务 4 步骤 1/3 含占位符（`FollowTagItemForService`、`_groupOrder` 私有、`apiMap(apiMap(response.data)['data'])` 待确认），已通过步骤 2/4 修正。任务 8 步骤 4 注明了 `push` 需路由。任务 9 步骤 1 注明可选扩展。无未定义类型。

**3. 类型一致性：** `FollowTagItem` fields 全一致；`isFollowing(value)` 用 `value`；`_persist`/`clear`/`store` 一致；`FollowingTagsDataSource` 接口三方法一致。

---

## 执行交接

计划已完成并保存到 `docs/superpowers/plans/2026-08-21-following-tags.md`。两种执行方式：

**1. 子代理驱动（推荐）** - 每个任务调度一个新的子代理，任务间进行审查，快速迭代

**2. 内联执行** - 在当前会话中使用 executing-plans 执行任务，批量执行并设有检查点

选哪种方式？
