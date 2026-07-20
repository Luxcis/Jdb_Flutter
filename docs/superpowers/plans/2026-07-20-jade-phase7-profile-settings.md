# Jade Phase 7 — 我的 + 收藏子页 + 个人资料 + 设置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 §11 我的/个人中心全功能：ProfileService API 层、ProfilePage 登录/未登录双态、我想看的/我看过的（Tab+MovieGridView）、我的关注（Tab+MovieListTile）、我的收藏（6 子项入口+各子页面）、我的清单、近期浏览、个人资料（修改密码/用户名）、设置扩展（外观/线路/默认筛选标签/清除缓存）。

**Architecture:** `lib/features/profile/` 下新增 `services/profile_service.dart`、`models/user_additional_info.dart`、各子页面 `screens/*.dart`。ProfileService 封装全部 13 个 profile 相关 API。ProfilePage 拆分为 `_LoggedInView` / `_LoggedOutView` 两个私有组件。所有子页面使用 `PaginationController` + `MovieGridView` / `ActorGridView` / `MovieListTile`，与现有 categories 页同一 TabBar 模式。路由注册在 `app_router.dart`，protectedRoutes 拦截所有 `/profile/*` 路径，未登录重定向到 `/login?from=...`。设置页复用现有 `features/settings/` 并以 `SettingItem` pattern 扩展新子页。

**Tech Stack:** Dart 3.8+, Flutter, provider ^6.1.5, dio ^5.7.0, go_router ^14.6.2, json_serializable, cached_network_image, shared_preferences.

## Global Constraints

- Material Design 3；ThemeMode.system；ColorScheme.fromSeed()；系统字体；无 google_fonts。
- 不做本地化，所有文案中文硬编码；不使用 .arb/flutter_localizations。
- Feature-First：core/ 放公共层；feature 只依赖 core。
- JSON 序列化用 json_serializable，fieldRename: FieldRename.snake。
- CDN 图片域名 https://tp.spfcas.com/rhe951l4q/（AppConstants.imageCdnBase）。
- 状态管理优先内置 + provider。
- 测试：widget test 验证组件渲染，unit test 验证 service 逻辑。
- Git 提交前设置代理：export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
- 不使用触觉反馈。
- 所有代码完整可运行，无 TODO、无占位符。

## Key Architecture Decisions

1. **Service 层：** `ProfileService` 统一管理所有 profile API，按功能分组成方法组（用户信息、收藏、影片回顾、清单、密码/用户名变更）。方法签名以参数对象形式传参，返回 `PagedResult<T>` 或 `void`。

2. **子页面 Tab 模式：** "我想看的"/"我看过的" 使用 `TabBar + TabBarView` 模式（与 `categories_screen.dart` 一致），Tab 为全部/有码/无码/欧美/FC2/动漫，type 参数分别传入 null/1/2/3/5/6。

3. **路由保护：** `AppRoutes.protectedRoutes` 新增所有 `/profile/*` 路径。`AppRouter.buildForTest()` 中添加 `redirect` 逻辑：未登录访问 protectedRoute → `Navigator.replace('/login?from=${state.uri}')`。

4. **"我的关注" 数据流：** `GET /users` 返回 `following_tags` 数组（`[{name, value}]`），每个 tag 对应一个 Tab。点击 Tab 后调用 `GET /v2/tags?type=xxx&page=1`（或使用 `GET /api/v1/movies/tags` 接口传入 tag 参数），以 `MovieListTile` 渲染。

5. **收藏子页路由：** 收藏 hub 页 `/profile/favorites` 展示 6 个 Cell 入口；各子页独立路由 `/profile/favorites/actors` 等。收藏的演员使用 `ActorGridView`；片商/系列/导演/番号使用 `ListView` + 对应模型渲染；收藏的清单使用 `ListTile` + `ListModel`。

6. **设置页扩展：** 新建 `profile_settings_screen.dart`（`/profile/settings`）作为 hub，列出外观/线路/默认筛选标签/清除缓存 4 个 `SettingItem`。现有 `settings_screen.dart` 重命名为 `appearance_screen.dart`（`/settings/appearance`）。新增 `line_screen.dart` 和 `default_filter_screen.dart`。

7. **修改密码/用户名：** 在"个人资料"页中以 `showDialog` 弹出 `AlertDialog` + `TextField`，调用 `ProfileService.changePassword` / `changeUsername`，成功后 `showSnackBar`。

8. **清除缓存：** 调用 `CachedNetworkImage.evictFromCache('*')` 或使用 `imageCache.clear()` + `PaintingBinding.instance.imageCache.clear()`，弹窗确认。

---

## Task 1: 创建 ProfileService — 封装全部 profile API

### Files

| Action | Path |
|--------|------|
| Modify | `lib/core/network/endpoints.dart` |
| Create | `lib/features/profile/services/profile_service.dart` |
| Create | `lib/features/profile/models/user_additional_info.dart` |
| Create | `test/features/profile/services/profile_service_test.dart` |

### Interfaces

**Consumes:**
- `ApiClient.get(path, queryParameters?)` — 已有
- `ApiClient.post(path, data)` — 已有

**Produces:**
- `ProfileService(ApiClient)` — 构造函数
- `Future<Map<String, dynamic>> fetchUser()` — `GET /users`，返回 raw user map（含 want_watch_count/watched_count/following_tags）
- `Future<UserAdditionalInfo> fetchUserAdditional()` — `GET /users/additional`
- `Future<PagedResult<MovieSummary>> getReviewMovies({required String status, int? type, String sortBy = 'date', String orderBy = 'desc', int page = 1, int limit = 20})` — `GET /v2/users/review_movies`
- `Future<PagedResult<ActorSummary>> getCollectedActors({int? type, int page = 1, int limit = 20})` — `GET /users/collected_actors`
- `Future<PagedResult<Maker>> getCollectedMakers({int page = 1, int limit = 20})` — `GET /users/collected_makers`
- `Future<PagedResult<Series>> getCollectedSeries({int page = 1, int limit = 20})` — `GET /users/collected_series`
- `Future<PagedResult<Director>> getCollectedDirectors({int page = 1, int limit = 20})` — `GET /users/collected_directors`
- `Future<PagedResult<Code>> getCollectedCodes({int page = 1, int limit = 20})` — `GET /users/collected_codes`
- `Future<PagedResult<ListModel>> getCollectedLists({int page = 1, int limit = 20})` — `GET /users/collected_lists`
- `Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1, int limit = 20})` — `GET /users/recent_viewed`
- `Future<PagedResult<ListModel>> getLists({String sortBy = 'date', int page = 1, int limit = 20})` — `GET /lists`
- `Future<PagedResult<MovieSummary>> getFollowingTagMovies({required int type, int page = 1, int limit = 20})` — `GET /movies/tags`（按关注的 tag type 拉片）
- `Future<void> changePassword({required String oldPassword, required String newPassword})` — `POST /users/change_password`
- `Future<void> changeUsername({required String username})` — `POST /users/change_username`
- `Future<List<Map<String, dynamic>>> getFollowingTags()` — 取 `fetchUser()` 结果中的 `following_tags`

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建 `test/features/profile/services/profile_service_test.dart`，用 `FakeAdapter` stub 所有 profile API，编写成功/失败用例。
- [ ] **2. 验证测试失败** — `flutter test test/features/profile/services/profile_service_test.dart`，预期 FAIL（文件/方法不存在）。
- [ ] **3. 写实现** — 创建 `ProfileService` + `UserAdditionalInfo` 模型 + `endpoints.dart` 补全，`dart run build_runner build --delete-conflicting-outputs`。
- [ ] **4. 验证测试通过** — `flutter test test/features/profile/services/profile_service_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 4 个文件，commit message: `feat(profile): add ProfileService with all profile/collection/review/list APIs`。

### 完整实现代码

#### `lib/features/profile/models/user_additional_info.dart`

```dart
import 'package:json_annotation/json_annotation.dart';
part 'user_additional_info.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class UserAdditionalInfo {
  const UserAdditionalInfo({
    this.email,
    this.reportsCount = 0,
    this.deletedCommentsCount = 0,
    this.mutedCount = 0,
    this.maxMutedCount = 0,
    this.uncorrectedCount = 0,
    this.correctionsCount = 0,
  });
  final String? email;
  final int reportsCount;
  final int deletedCommentsCount;
  final int mutedCount;
  final int maxMutedCount;
  final int uncorrectedCount;
  final int correctionsCount;

  factory UserAdditionalInfo.fromJson(Map<String, dynamic> json) =>
      _$UserAdditionalInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UserAdditionalInfoToJson(this);
}
```

#### `lib/core/network/endpoints.dart`（追加常量）

在现有 `Endpoints` 类中追加以下常量（文件末尾 `}` 前）：

```dart
  static const String usersCollectedActors = '/api/v1/users/collected_actors';
  static const String usersCollectedCodes = '/api/v1/users/collected_codes';
  static const String usersCollectedDirectors = '/api/v1/users/collected_directors';
  static const String usersCollectedLists = '/api/v1/users/collected_lists';
  static const String usersCollectedMakers = '/api/v1/users/collected_makers';
  static const String usersCollectedSeries = '/api/v1/users/collected_series';
  static const String usersRecentViewed = '/api/v1/users/recent_viewed';
  static const String usersReviewMovies = '/api/v2/users/review_movies';
  static const String usersChangePassword = '/api/v1/users/change_password';
  static const String usersChangeUsername = '/api/v1/users/change_username';
  static const String followingTags = '/api/v1/following_tags';
```

#### `lib/features/profile/services/profile_service.dart`

```dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/models/user_additional_info.dart';

class ProfileService {
  ProfileService(this._api);
  final ApiClient _api;

  /// GET /users — 获取当前用户信息。
  Future<Map<String, dynamic>> fetchUser() async {
    final resp = await _api.get(Endpoints.users,
        queryParameters: {'app_channel': 'google'});
    final data = resp.data as Map<String, dynamic>;
    return data;
  }

  /// GET /users/additional — 用户附加信息。
  Future<UserAdditionalInfo> fetchUserAdditional() async {
    final resp = await _api.get(Endpoints.usersAdditional);
    final data = resp.data as Map<String, dynamic>;
    return UserAdditionalInfo.fromJson(data);
  }

  /// 从 fetchUser 结果提取 following_tags。
  List<Map<String, dynamic>> extractFollowingTags(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>?;
    final tags = data['following_tags'] as List<dynamic>? ??
        user?['following_tags'] as List<dynamic>? ??
        [];
    return tags.cast<Map<String, dynamic>>();
  }

  /// GET /v2/users/review_movies — 已评价/想看/看过影片。
  Future<PagedResult<MovieSummary>> getReviewMovies({
    required String status,
    int? type,
    String sortBy = 'date',
    String orderBy = 'desc',
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'status': status,
      'sort_by': sortBy,
      'order_by': orderBy,
      'page': page,
      'limit': limit,
    };
    if (type != null) params['type'] = type;
    final resp = await _api.get(Endpoints.usersReviewMovies,
        queryParameters: params);
    return _parsePaged(resp.data, MovieSummary.fromJson);
  }

  /// GET /users/collected_actors — 收藏的演员。
  Future<PagedResult<ActorSummary>> getCollectedActors({
    int? type,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null) params['type'] = type;
    final resp = await _api.get(Endpoints.usersCollectedActors,
        queryParameters: params);
    return _parsePaged(resp.data, ActorSummary.fromJson);
  }

  /// GET /users/collected_makers — 收藏的片商。
  Future<PagedResult<Maker>> getCollectedMakers({
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.usersCollectedMakers,
        queryParameters: {'page': page, 'limit': limit});
    return _parsePaged(resp.data, Maker.fromJson);
  }

  /// GET /users/collected_series — 收藏的系列。
  Future<PagedResult<Series>> getCollectedSeries({
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.usersCollectedSeries,
        queryParameters: {'page': page, 'limit': limit});
    return _parsePaged(resp.data, Series.fromJson);
  }

  /// GET /users/collected_directors — 收藏的导演。
  Future<PagedResult<Director>> getCollectedDirectors({
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.usersCollectedDirectors,
        queryParameters: {'page': page, 'limit': limit});
    return _parsePaged(resp.data, Director.fromJson);
  }

  /// GET /users/collected_codes — 收藏的番号。
  Future<PagedResult<Code>> getCollectedCodes({
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.usersCollectedCodes,
        queryParameters: {'page': page, 'limit': limit});
    return _parsePaged(resp.data, Code.fromJson);
  }

  /// GET /users/collected_lists — 收藏的清单。
  Future<PagedResult<ListModel>> getCollectedLists({
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.usersCollectedLists,
        queryParameters: {'page': page, 'limit': limit});
    return _parsePaged(resp.data, ListModel.fromJson);
  }

  /// GET /users/recent_viewed — 近期浏览。
  Future<PagedResult<MovieSummary>> getRecentViewed({
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.usersRecentViewed,
        queryParameters: {'page': page, 'limit': limit});
    return _parsePaged(resp.data, MovieSummary.fromJson);
  }

  /// GET /lists — 我的清单列表。
  Future<PagedResult<ListModel>> getLists({
    String sortBy = 'date',
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.lists,
        queryParameters: {'sort_by': sortBy, 'page': page, 'limit': limit});
    return _parsePaged(resp.data, ListModel.fromJson);
  }

  /// GET /movies/tags — 按 type 拉取关注的标签影片。
  Future<PagedResult<MovieSummary>> getFollowingTagMovies({
    required int type,
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(Endpoints.moviesTags, queryParameters: {
      'type': type,
      'sort_by': 'date',
      'order_by': 'desc',
      'page': page,
      'limit': limit,
    });
    return _parsePaged(resp.data, MovieSummary.fromJson);
  }

  /// POST /users/change_password — 修改密码。
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.post(Endpoints.usersChangePassword, data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// POST /users/change_username — 修改用户名。
  Future<void> changeUsername({required String username}) async {
    await _api.post(Endpoints.usersChangeUsername, data: {
      'username': username,
    });
  }

  /// 通用分页解析。
  PagedResult<T> _parsePaged<T>(
      dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final m = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final items = (m['items'] as List<dynamic>?)
            ?.map((j) => fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
    return PagedResult(
      items: items,
      currentPage: m['current_page'] as int? ?? 1,
      totalPages: m['total_pages'] as int? ?? 1,
      total: m['total'] as int? ?? 0,
    );
  }
}
```

#### `test/features/profile/services/profile_service_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/features/profile/services/profile_service.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

void main() {
  late FakeAdapter fakeAdapter;
  late ApiClient apiClient;
  late ProfileService service;

  setUp(() {
    fakeAdapter = FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.api'));
    dio.httpClientAdapter = fakeAdapter;
    apiClient = ApiClient._(dio: dio, domainManager: _FakeDM());
    service = ProfileService(apiClient);
  });

  test('fetchUser returns user map with want_watch_count', () async {
    fakeAdapter.stub(
      'GET',
      '/api/v1/users',
      {
        'user': {'id': 1, 'want_watch_count': 5, 'watched_count': 3},
        'following_tags': [
          {'name': '标签1', 'value': '1'}
        ],
      },
      200,
    );
    final data = await service.fetchUser();
    expect(data['user']['want_watch_count'], 5);
    expect(data['user']['watched_count'], 3);
  });

  test('extractFollowingTags returns tag list', () {
    final data = {
      'user': {'id': 1},
      'following_tags': [
        {'name': 'A', 'value': '1'},
        {'name': 'B', 'value': '2'},
      ],
    };
    final tags = service.extractFollowingTags(data);
    expect(tags.length, 2);
    expect(tags[0]['name'], 'A');
  });

  test('getReviewMovies returns paged movies', () async {
    fakeAdapter.stub(
      'GET',
      '/api/v2/users/review_movies',
      {
        'items': [
          {
            'id': '1',
            'number': 'ABC-001',
            'title': 'Test Movie',
            'cover_url': 'https://tp.spfcas.com/rhe951l4q/c.jpg',
          }
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
      200,
    );
    final result = await service.getReviewMovies(status: 'want');
    expect(result.items.length, 1);
    expect(result.items[0].number, 'ABC-001');
  });

  test('getCollectedActors returns paged actors', () async {
    fakeAdapter.stub(
      'GET',
      '/api/v1/users/collected_actors',
      {
        'items': [
          {
            'id': '1',
            'name': 'Actress A',
            'avatar_url': 'https://tp.spfcas.com/rhe951l4q/a.jpg',
          }
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
      200,
    );
    final result = await service.getCollectedActors();
    expect(result.items.length, 1);
    expect(result.items[0].name, 'Actress A');
  });

  test('getCollectedMakers returns paged makers', () async {
    fakeAdapter.stub(
      'GET',
      '/api/v1/users/collected_makers',
      {
        'items': [
          {'id': '1', 'name': 'Studio X', 'movie_count': 10}
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
      200,
    );
    final result = await service.getCollectedMakers();
    expect(result.items.length, 1);
    expect(result.items[0].name, 'Studio X');
  });

  test('changePassword calls POST', () async {
    fakeAdapter.stub('POST', '/api/v1/users/change_password', {}, 200);
    await service.changePassword(
        oldPassword: 'old', newPassword: 'new');
    // 不抛异常即通过
  });

  test('fetchUserAdditional returns additional info', () async {
    fakeAdapter.stub(
      'GET',
      '/api/v1/users/additional',
      {
        'email': 'test@test.com',
        'reports_count': 3,
        'deleted_comments_count': 1,
        'muted_count': 0,
        'max_muted_count': 5,
        'uncorrected_count': 2,
        'corrections_count': 10,
      },
      200,
    );
    final info = await service.fetchUserAdditional();
    expect(info.email, 'test@test.com');
    expect(info.reportsCount, 3);
    expect(info.mutedCount, 0);
  });
}

class _FakeDM extends Fake implements dynamic {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
```

### 终端命令

```bash
# 1. 创建模型文件后运行 build_runner
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
dart run build_runner build --delete-conflicting-outputs

# 2. 运行 service 测试
flutter test test/features/profile/services/profile_service_test.dart

# 3. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/profile/services/profile_service.dart \
        lib/features/profile/models/user_additional_info.dart \
        lib/features/profile/models/user_additional_info.g.dart \
        lib/core/network/endpoints.dart \
        test/features/profile/services/profile_service_test.dart
git commit -m "feat(profile): add ProfileService with all profile/collection/review/list APIs"
```

---

## Task 2: 重构 ProfilePage — 登录态计数显示 + Cell 导航 + 路由保护

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/profile/screens/profile_screen.dart` |
| Modify | `lib/core/router/routes.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/profile_screen_test.dart` |

### Interfaces

**Consumes:**
- `AuthProvider` — `isLogged`、`user`（含 `want_watch_count`/`watched_count`）
- `ProfileService` — `fetchUser()` 刷新用户数据
- `go_router` — `context.go()` 导航

**Produces:**
- `ProfilePage` 重构为三部分：`_LoggedOutView`（大登录按钮 + 设置 Cell）、`_LoggedInView`（用户信息头 + 计数 Cell 列表 + 退出登录）
- `AppRoutes.protectedRoutes` 含所有 `/profile/*` 路径
- `AppRouter.buildForTest()` 含 `redirect` 逻辑

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建 `test/features/profile/profile_screen_test.dart`，验证未登录态渲染"登录"按钮、已登录态渲染"我想看的"Cell。
- [ ] **2. 验证测试失败** — `flutter test test/features/profile/profile_screen_test.dart`，预期 FAIL（功能尚未实现）。
- [ ] **3. 写实现** — 重构 `profile_screen.dart`，补全 `routes.dart` + `app_router.dart`。
- [ ] **4. 验证测试通过** — `flutter test test/features/profile/profile_screen_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 4 个文件，commit message: `feat(profile): refactor ProfilePage with counts, navigation, and route protection`。

### 完整实现代码

#### `lib/features/profile/screens/profile_screen.dart`（替换整个文件）

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const _LoggedOutView();
    }
    return const _LoggedInView();
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('登录后查看个人内容', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login?from=%2Fprofile'),
              child: const Text('登录 / 注册'),
            ),
            const SizedBox(height: 24),
            ListTile(
              title: const Text('设置'),
              leading: const Icon(Icons.settings),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/profile/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedInView extends StatelessWidget {
  const _LoggedInView();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user ?? const <String, dynamic>{};
    final email = user['email'] as String? ?? '';
    final wantCount = user['want_watch_count'] as int? ?? 0;
    final watchedCount = user['watched_count'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          // 用户信息头
          Container(
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(
                    (user['username'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['username'] as String? ?? '用户',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (email.isNotEmpty)
                        Text(email,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _Cell(
            title: '我想看的',
            subtitle: '$wantCount部影片',
            icon: Icons.bookmark_border,
            onTap: () => context.go('/profile/want-watch'),
          ),
          _Cell(
            title: '我看过的',
            subtitle: '$watchedCount部影片',
            icon: Icons.done_all,
            onTap: () => context.go('/profile/watched'),
          ),
          _Cell(
            title: '我的关注',
            icon: Icons.favorite_border,
            onTap: () => context.go('/profile/following'),
          ),
          _Cell(
            title: '我的收藏',
            icon: Icons.collections_bookmark,
            onTap: () => context.go('/profile/favorites'),
          ),
          _Cell(
            title: '我的清单',
            icon: Icons.list_alt,
            onTap: () => context.go('/profile/lists'),
          ),
          _Cell(
            title: '近期浏览',
            icon: Icons.history,
            onTap: () => context.go('/profile/recent'),
          ),
          _Cell(
            title: '个人资料',
            icon: Icons.person_outline,
            onTap: () => context.go('/profile/info'),
          ),
          const Divider(),
          _Cell(
            title: '设置',
            icon: Icons.settings,
            onTap: () => context.go('/profile/settings'),
          ),
          ListTile(
            title: const Text('退出登录'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await auth.logout();
              if (context.mounted) context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _Cell({
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        leading: Icon(icon),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
```

#### `lib/core/router/routes.dart`（替换整个文件）

```dart
class AppRoutes {
  const AppRoutes._();

  static const String home = '/home';
  static const String rankings = '/rankings';
  static const String categories = '/categories';
  static const String actors = '/actors';
  static const String profile = '/profile';
  static const String login = '/login';

  // Profile 子路由
  static const String profileWantWatch = '/profile/want-watch';
  static const String profileWatched = '/profile/watched';
  static const String profileFollowing = '/profile/following';
  static const String profileFavorites = '/profile/favorites';
  static const String profileFavoritesActors = '/profile/favorites/actors';
  static const String profileFavoritesMakers = '/profile/favorites/makers';
  static const String profileFavoritesSeries = '/profile/favorites/series';
  static const String profileFavoritesDirectors = '/profile/favorites/directors';
  static const String profileFavoritesCodes = '/profile/favorites/codes';
  static const String profileFavoritesLists = '/profile/favorites/lists';
  static const String profileLists = '/profile/lists';
  static const String profileRecent = '/profile/recent';
  static const String profileInfo = '/profile/info';
  static const String profileSettings = '/profile/settings';
  static const String settingsAppearance = '/settings/appearance';
  static const String settingsLine = '/settings/line';
  static const String settingsDefaultFilter = '/settings/default-filter';

  static const Set<String> protectedRoutes = {
    profileWantWatch,
    profileWatched,
    profileFollowing,
    profileFavorites,
    profileFavoritesActors,
    profileFavoritesMakers,
    profileFavoritesSeries,
    profileFavoritesDirectors,
    profileFavoritesCodes,
    profileFavoritesLists,
    profileLists,
    profileRecent,
    profileInfo,
  };
}
```

#### `lib/core/router/app_router.dart`（替换整个文件）

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/main_shell.dart';
import 'package:jade/features/home/index.dart';
import 'package:jade/features/rankings/index.dart';
import 'package:jade/features/categories/index.dart';
import 'package:jade/features/actors/index.dart';
import 'package:jade/features/profile/index.dart';
import 'package:jade/features/movie_detail/index.dart';
import 'package:jade/features/search/index.dart';
import 'package:jade/features/auth/index.dart';
import 'package:jade/features/actor_detail/index.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter buildForTest() {
    final navigatorKey = GlobalKey<NavigatorState>();
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: AppRoutes.home,
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        final location = state.uri.toString();
        final isProtected =
            AppRoutes.protectedRoutes.any((r) => location.startsWith(r));
        if (isProtected && !auth.isLogged) {
          return '${AppRoutes.login}?from=${Uri.encodeComponent(location)}';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (c, s) {
            final from = s.uri.queryParameters['from'];
            return LoginPage(fromRoute: from);
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.home,
                  builder: (c, s) => const HomePage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.rankings,
                  builder: (c, s) => const RankingsPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.categories,
                  builder: (c, s) => const CategoriesPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.actors,
                  builder: (c, s) => const ActorsPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.profile,
                  builder: (c, s) => const ProfilePage()),
            ]),
          ],
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (c, s) =>
              MovieDetailPage(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/search',
          builder: (c, s) => const SearchPage(),
        ),
        GoRoute(
          path: '/actor/:id',
          builder: (c, s) =>
              ActorDetailPage(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/search/magnet',
          builder: (c, s) => const MagnetSearchPage(),
        ),
        GoRoute(
          path: '/search/image',
          builder: (c, s) => const ImageSearchPage(),
        ),
        // Profile 子页面（占位路由 — 各 Task 完成后替换 builder）
        GoRoute(
            path: AppRoutes.profileWantWatch,
            builder: (c, s) => const _PlaceholderPage(title: '我想看的')),
        GoRoute(
            path: AppRoutes.profileWatched,
            builder: (c, s) => const _PlaceholderPage(title: '我看过的')),
        GoRoute(
            path: AppRoutes.profileFollowing,
            builder: (c, s) => const _PlaceholderPage(title: '我的关注')),
        GoRoute(
            path: AppRoutes.profileFavorites,
            builder: (c, s) => const _PlaceholderPage(title: '我的收藏')),
        GoRoute(
            path: AppRoutes.profileFavoritesActors,
            builder: (c, s) =>
                const _PlaceholderPage(title: '收藏的演员')),
        GoRoute(
            path: AppRoutes.profileFavoritesMakers,
            builder: (c, s) =>
                const _PlaceholderPage(title: '收藏的片商')),
        GoRoute(
            path: AppRoutes.profileFavoritesSeries,
            builder: (c, s) =>
                const _PlaceholderPage(title: '收藏的系列')),
        GoRoute(
            path: AppRoutes.profileFavoritesDirectors,
            builder: (c, s) =>
                const _PlaceholderPage(title: '收藏的导演')),
        GoRoute(
            path: AppRoutes.profileFavoritesCodes,
            builder: (c, s) =>
                const _PlaceholderPage(title: '收藏的番号')),
        GoRoute(
            path: AppRoutes.profileFavoritesLists,
            builder: (c, s) =>
                const _PlaceholderPage(title: '收藏的清单')),
        GoRoute(
            path: AppRoutes.profileLists,
            builder: (c, s) => const _PlaceholderPage(title: '我的清单')),
        GoRoute(
            path: AppRoutes.profileRecent,
            builder: (c, s) => const _PlaceholderPage(title: '近期浏览')),
        GoRoute(
            path: AppRoutes.profileInfo,
            builder: (c, s) => const _PlaceholderPage(title: '个人资料')),
        GoRoute(
            path: AppRoutes.profileSettings,
            builder: (c, s) => const _PlaceholderPage(title: '设置')),
      ],
    );
  }
}

/// 占位页面：各 Task 实现后替换为真实页面。
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: const SizedBox());
}
```

#### `test/features/profile/profile_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';

Widget _buildApp({AuthProvider? auth}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth ?? _fakeAuth(loggedIn: false),
    child: MaterialApp.router(routerConfig: AppRouter.buildForTest()),
  );
}

AuthProvider _fakeAuth({bool loggedIn = false}) {
  final auth = AuthProvider._(FakeSP());
  if (loggedIn) {
    auth.login(token: 'tok', user: {
      'id': 1,
      'username': 'testuser',
      'want_watch_count': 5,
      'watched_count': 3,
    });
  }
  return auth;
}

class FakeSP extends Fake implements SharedPreferences {
  final _map = <String, Object>{};
  @override
  String? getString(String key) => _map[key] as String?;
  @override
  Future<bool> setString(String key, String value) async {
    _map[key] = value;
    return true;
  }
  @override
  Future<bool> remove(String key) async {
    _map.remove(key);
    return true;
  }
}

void main() {
  testWidgets('未登录态显示登录按钮', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    // 导航到 profile tab（第二个 branch index 4）
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('登录 / 注册'), findsOneWidget);
  });

  testWidgets('已登录态显示我想看的 Cell 及计数', (tester) async {
    await tester.pumpWidget(
        _buildApp(auth: _fakeAuth(loggedIn: true)));
    await tester.pump();
    expect(find.text('5部影片'), findsOneWidget);
    expect(find.text('3部影片'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/profile_screen_test.dart

git add lib/features/profile/screens/profile_screen.dart \
        lib/core/router/routes.dart \
        lib/core/router/app_router.dart \
        test/features/profile/profile_screen_test.dart
git commit -m "feat(profile): refactor ProfilePage with counts, navigation, and route protection"
```

---

## Task 3: 创建"我想看的"子页面 — Tab + MovieGridView + 筛选

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/want_watch_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/want_watch_screen_test.dart` |

### Interfaces

**Consumes:**
- `ApiClient.instanceOrNull` — 获取 API 客户端
- `ProfileService.getReviewMovies(status: 'want', type: ...)` — 获取想看的影片列表
- `PaginationController<MovieSummary>` — 分页控制
- `MovieGridView` — 瀑布流渲染

**Produces:**
- `WantWatchPage` — `StatefulWidget`，TabBar（全部/有码/无码/欧美/FC2/动漫）+ SortSegmented（日期/评分）+ MovieGridView

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建 `test/features/profile/want_watch_screen_test.dart`，验证 Tab 渲染和 MovieGridView 存在。
- [ ] **2. 验证测试失败** — `flutter test test/features/profile/want_watch_screen_test.dart`，预期 FAIL。
- [ ] **3. 写实现** — 创建 `want_watch_screen.dart`，更新 `app_router.dart` 中的路由 builder。
- [ ] **4. 验证测试通过** — `flutter test test/features/profile/want_watch_screen_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 3 个文件，commit message: `feat(profile): add WantWatchPage with TabBar + MovieGridView`。

### 完整实现代码

#### `lib/features/profile/screens/want_watch_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class WantWatchPage extends StatefulWidget {
  const WantWatchPage({super.key});
  @override
  State<WantWatchPage> createState() => _WantWatchPageState();
}

class _WantWatchPageState extends State<WantWatchPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  static const _tabs = ['全部', '有码', '无码', '欧美', 'FC2', '动漫'];
  static const _types = [null, 1, 2, 3, 5, 6];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PaginationController<MovieSummary> _buildCtrl(int? type) {
    final api = ApiClient.instanceOrNull;
    return PaginationController(fetch: (page) async {
      if (api == null) {
        return const PagedResult(
            items: [], currentPage: 1, totalPages: 1, total: 0);
      }
      return ProfileService(api).getReviewMovies(
        status: 'want',
        type: type,
        page: page,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我想看的'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _types
            .map((t) => MovieGridView(controller: _buildCtrl(t)))
            .toList(),
      ),
    );
  }
}
```

#### `lib/core/router/app_router.dart`（修改 want-watch 路由 builder）

将

```dart
        GoRoute(
            path: AppRoutes.profileWantWatch,
            builder: (c, s) => const _PlaceholderPage(title: '我想看的')),
```

改为

```dart
        GoRoute(
            path: AppRoutes.profileWantWatch,
            builder: (c, s) => const WantWatchPage()),
```

并在文件顶部 import 中添加：

```dart
import 'package:jade/features/profile/screens/want_watch_screen.dart';
```

#### `test/features/profile/want_watch_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/want_watch_screen.dart';

void main() {
  testWidgets('WantWatchPage 渲染 TabBar 和标题', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WantWatchPage()));
    await tester.pump();
    expect(find.text('我想看的'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('有码'), findsOneWidget);
    expect(find.text('欧美'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/want_watch_screen_test.dart

git add lib/features/profile/screens/want_watch_screen.dart \
        lib/core/router/app_router.dart \
        test/features/profile/want_watch_screen_test.dart
git commit -m "feat(profile): add WantWatchPage with TabBar + MovieGridView"
```

---

## Task 4: 创建"我看过的"子页面

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/watched_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/watched_screen_test.dart` |

### Interfaces

**Consumes:**
- `ProfileService.getReviewMovies(status: 'watched', type: ...)` — 获取看过的影片列表

**Produces:**
- `WatchedPage` — 结构与 `WantWatchPage` 相同，`status` 改为 `'watched'`

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建测试验证渲染。
- [ ] **2. 验证测试失败** — 预期 FAIL。
- [ ] **3. 写实现** — 创建 `watched_screen.dart`，更新路由。
- [ ] **4. 验证测试通过** — 全部 PASS。
- [ ] **5. 提交** — `feat(profile): add WatchedPage with TabBar + MovieGridView`。

### 完整实现代码

#### `lib/features/profile/screens/watched_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class WatchedPage extends StatefulWidget {
  const WatchedPage({super.key});
  @override
  State<WatchedPage> createState() => _WatchedPageState();
}

class _WatchedPageState extends State<WatchedPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  static const _tabs = ['全部', '有码', '无码', '欧美', 'FC2', '动漫'];
  static const _types = [null, 1, 2, 3, 5, 6];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PaginationController<MovieSummary> _buildCtrl(int? type) {
    final api = ApiClient.instanceOrNull;
    return PaginationController(fetch: (page) async {
      if (api == null) {
        return const PagedResult(
            items: [], currentPage: 1, totalPages: 1, total: 0);
      }
      return ProfileService(api).getReviewMovies(
        status: 'watched',
        type: type,
        page: page,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我看过的'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _types
            .map((t) => MovieGridView(controller: _buildCtrl(t)))
            .toList(),
      ),
    );
  }
}
```

#### `lib/core/router/app_router.dart`（修改 watched 路由 builder）

将 `_PlaceholderPage(title: '我看过的')` 改为 `WatchedPage()`，并添加 import：

```dart
import 'package:jade/features/profile/screens/watched_screen.dart';
```

#### `test/features/profile/watched_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/watched_screen.dart';

void main() {
  testWidgets('WatchedPage 渲染 TabBar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WatchedPage()));
    await tester.pump();
    expect(find.text('我看过的'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('无码'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/watched_screen_test.dart

git add lib/features/profile/screens/watched_screen.dart \
        lib/core/router/app_router.dart \
        test/features/profile/watched_screen_test.dart
git commit -m "feat(profile): add WatchedPage with TabBar + MovieGridView"
```

---

## Task 5: 创建"我的关注"子页面 — Tab（关注标签） + MovieListTile

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/following_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/following_screen_test.dart` |

### Interfaces

**Consumes:**
- `AuthProvider.user` — 获取 `following_tags`
- `ProfileService.getFollowingTagMovies(type: ...)` — 按 type 拉取影片
- `PaginationController<MovieSummary>` — 分页
- `MovieListTile` — 列表项渲染

**Produces:**
- `FollowingPage` — `StatefulWidget`，`initState` 中从 `AuthProvider` 取 `following_tags` 构建动态 Tab 列表。`following_tags` 格式 `[{name, value}]`，`value` 作为 type 参数传给 `getFollowingTagMovies`。

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建测试，用 mock AuthProvider 提供 following_tags 验证 Tab 渲染。
- [ ] **2. 验证测试失败** — 预期 FAIL。
- [ ] **3. 写实现** — 创建 `following_screen.dart`，更新路由。
- [ ] **4. 验证测试通过** — 全部 PASS。
- [ ] **5. 提交** — `feat(profile): add FollowingPage with dynamic Tab + MovieListTile`。

### 完整实现代码

#### `lib/features/profile/screens/following_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});
  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<Map<String, dynamic>> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() {
    final auth = context.read<AuthProvider>();
    final user = auth.user ?? const {};
    final tags = (user['following_tags'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    _tags = tags;
    if (_tags.isNotEmpty) {
      _tabController = TabController(length: _tags.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  PaginationController<MovieSummary> _buildCtrl(int type) {
    final api = ApiClient.instanceOrNull;
    return PaginationController(fetch: (page) async {
      if (api == null) {
        return const PagedResult(
            items: [], currentPage: 1, totalPages: 1, total: 0);
      }
      return ProfileService(api).getFollowingTagMovies(
        type: type,
        page: page,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tags.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的关注')),
        body: const Center(child: Text('暂无关注标签')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的关注'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tags
              .map((t) => Tab(text: t['name'] as String? ?? ''))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tags.map((t) {
          final type = int.tryParse(t['value']?.toString() ?? '') ?? 1;
          final ctrl = _buildCtrl(type);
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification &&
                  n.metrics.extentAfter < 200) {
                ctrl.fetchMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: ctrl.refresh,
              child: ListenableBuilder(
                listenable: ctrl,
                builder: (context, _) => ListView.builder(
                  itemCount: ctrl.items.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (_, i) => MovieListTile(
                    movie: ctrl.items[i],
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

#### `lib/core/router/app_router.dart`（修改 following 路由）

将 `_PlaceholderPage(title: '我的关注')` 改为 `FollowingPage()`，添加 import：

```dart
import 'package:jade/features/profile/screens/following_screen.dart';
```

#### `test/features/profile/following_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/profile/screens/following_screen.dart';

class _FakeAuth extends ChangeNotifier implements TokenProvider {
  String? _token = 'tok';
  @override String? get token => _token;
  bool get isLogged => true;
  Map<String, dynamic>? get user => _user;
  final Map<String, dynamic> _user;
  _FakeAuth(this._user);
  static _FakeAuth create() => _FakeAuth({
        'id': 1,
        'following_tags': [
          {'name': '标签A', 'value': '1'},
          {'name': '标签B', 'value': '2'},
        ],
      });
}

void main() {
  testWidgets('FollowingPage 渲染关注标签 Tab', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<_FakeAuth>(
        create: (_) => _FakeAuth.create(),
        child: const MaterialApp(home: FollowingPage()),
      ),
    );
    await tester.pump();
    expect(find.text('我的关注'), findsOneWidget);
    expect(find.text('标签A'), findsOneWidget);
    expect(find.text('标签B'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/following_screen_test.dart

git add lib/features/profile/screens/following_screen.dart \
        lib/core/router/app_router.dart \
        test/features/profile/following_screen_test.dart
git commit -m "feat(profile): add FollowingPage with dynamic Tab + MovieListTile"
```

---

## Task 6: 创建"我的收藏"子页面（hub + 6 收藏子页）

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/favorites_screen.dart` |
| Create | `lib/features/profile/screens/favorites_actors_screen.dart` |
| Create | `lib/features/profile/screens/favorites_makers_screen.dart` |
| Create | `lib/features/profile/screens/favorites_series_screen.dart` |
| Create | `lib/features/profile/screens/favorites_directors_screen.dart` |
| Create | `lib/features/profile/screens/favorites_codes_screen.dart` |
| Create | `lib/features/profile/screens/favorites_lists_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/favorites_screen_test.dart` |

### Interfaces

**Consumes:**
- `ProfileService.getCollectedActors/Makers/Series/Directors/Codes/Lists()` — 各收藏 API
- `PaginationController<T>` — 分页
- `ActorGridView` / `ListView` — 渲染
- `go_router` — `context.go()` 跳转到详情页

**Produces:**
- `FavoritesPage` — 6 个 Cell 列表入口页，点击跳转子页
- `FavoritesActorsPage` — Tab（全部/有码/无码/欧美）+ `ActorGridView`
- `FavoritesMakersPage` — `ListView`，`ListTile` 渲染 `Maker`（name + movieCount subtitle），点击跳 `/maker/:id`
- `FavoritesSeriesPage` — `ListView`，`ListTile` 渲染 `Series`，点击跳 `/series/:id`
- `FavoritesDirectorsPage` — `ListView`，`ListTile` 渲染 `Director`，点击跳 `/director/:id`
- `FavoritesCodesPage` — `ListView`，`ListTile` 渲染 `Code`（number + movieCount subtitle），点击跳 `/code/:id`
- `FavoritesListsPage` — `ListView`，`ListTile` 渲染 `ListModel`（name + "X部影片, 被查看X次" subtitle），点击跳 `/list/:id`

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建测试验证 hub 页 6 个 Cell 渲染、actors 页 Tab。
- [ ] **2. 验证测试失败** — 预期 FAIL。
- [ ] **3. 写实现** — 创建全部 7 个文件，更新路由。
- [ ] **4. 验证测试通过** — 全部 PASS。
- [ ] **5. 提交** — `feat(profile): add favorites hub + 6 collection sub-pages`。

### 完整实现代码

#### `lib/features/profile/screens/favorites_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: ListView(
        children: [
          _entry(context, '收藏的演员', Icons.person, '/profile/favorites/actors'),
          _entry(context, '收藏的片商', Icons.business, '/profile/favorites/makers'),
          _entry(context, '收藏的系列', Icons.collections, '/profile/favorites/series'),
          _entry(context, '收藏的导演', Icons.videocam, '/profile/favorites/directors'),
          _entry(context, '收藏的番号', Icons.tag, '/profile/favorites/codes'),
          _entry(context, '收藏的清单', Icons.list, '/profile/favorites/lists'),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      title: Text(title),
      leading: Icon(icon),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(route),
    );
  }
}
```

#### `lib/features/profile/screens/favorites_actors_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class FavoritesActorsPage extends StatefulWidget {
  const FavoritesActorsPage({super.key});
  @override
  State<FavoritesActorsPage> createState() => _FavoritesActorsPageState();
}

class _FavoritesActorsPageState extends State<FavoritesActorsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  static const _tabs = ['全部', '有码', '无码', '欧美'];
  static const _types = [null, 1, 2, 3];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PaginationController<ActorSummary> _buildCtrl(int? type) {
    final api = ApiClient.instanceOrNull;
    return PaginationController(fetch: (page) async {
      if (api == null) {
        return const PagedResult(
            items: [], currentPage: 1, totalPages: 1, total: 0);
      }
      return ProfileService(api).getCollectedActors(
        type: type,
        page: page,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏的演员'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _types
            .map((t) => ActorGridView(controller: _buildCtrl(t)))
            .toList(),
      ),
    );
  }
}
```

#### `lib/features/profile/screens/favorites_makers_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class FavoritesMakersPage extends StatefulWidget {
  const FavoritesMakersPage({super.key});
  @override
  State<FavoritesMakersPage> createState() => _FavoritesMakersPageState();
}

class _FavoritesMakersPageState extends State<FavoritesMakersPage> {
  late final PaginationController<Maker> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController(fetch: _fetch);
    _ctrl.fetchMore();
  }

  Future<PagedResult<Maker>> _fetch(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ProfileService(api).getCollectedMakers(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏的片商')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            _ctrl.fetchMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) => ListView.builder(
              itemCount: _ctrl.items.length,
              itemBuilder: (_, i) {
                final maker = _ctrl.items[i];
                return ListTile(
                  title: Text(maker.name),
                  subtitle: Text('${maker.movieCount}部影片'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/maker/${maker.id}'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

#### `lib/features/profile/screens/favorites_series_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class FavoritesSeriesPage extends StatefulWidget {
  const FavoritesSeriesPage({super.key});
  @override
  State<FavoritesSeriesPage> createState() => _FavoritesSeriesPageState();
}

class _FavoritesSeriesPageState extends State<FavoritesSeriesPage> {
  late final PaginationController<Series> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController(fetch: _fetch);
    _ctrl.fetchMore();
  }

  Future<PagedResult<Series>> _fetch(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ProfileService(api).getCollectedSeries(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏的系列')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            _ctrl.fetchMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) => ListView.builder(
              itemCount: _ctrl.items.length,
              itemBuilder: (_, i) {
                final series = _ctrl.items[i];
                return ListTile(
                  title: Text(series.name),
                  subtitle: Text('${series.movieCount}部影片'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/series/${series.id}'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

#### `lib/features/profile/screens/favorites_directors_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class FavoritesDirectorsPage extends StatefulWidget {
  const FavoritesDirectorsPage({super.key});
  @override
  State<FavoritesDirectorsPage> createState() => _FavoritesDirectorsPageState();
}

class _FavoritesDirectorsPageState extends State<FavoritesDirectorsPage> {
  late final PaginationController<Director> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController(fetch: _fetch);
    _ctrl.fetchMore();
  }

  Future<PagedResult<Director>> _fetch(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ProfileService(api).getCollectedDirectors(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏的导演')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            _ctrl.fetchMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) => ListView.builder(
              itemCount: _ctrl.items.length,
              itemBuilder: (_, i) {
                final director = _ctrl.items[i];
                return ListTile(
                  title: Text(director.name),
                  subtitle: Text('${director.movieCount}部影片'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/director/${director.id}'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

#### `lib/features/profile/screens/favorites_codes_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class FavoritesCodesPage extends StatefulWidget {
  const FavoritesCodesPage({super.key});
  @override
  State<FavoritesCodesPage> createState() => _FavoritesCodesPageState();
}

class _FavoritesCodesPageState extends State<FavoritesCodesPage> {
  late final PaginationController<Code> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController(fetch: _fetch);
    _ctrl.fetchMore();
  }

  Future<PagedResult<Code>> _fetch(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ProfileService(api).getCollectedCodes(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏的番号')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            _ctrl.fetchMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) => ListView.builder(
              itemCount: _ctrl.items.length,
              itemBuilder: (_, i) {
                final code = _ctrl.items[i];
                return ListTile(
                  title: Text(code.number),
                  subtitle: Text('${code.movieCount}部影片'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/code/${code.id}'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

#### `lib/features/profile/screens/favorites_lists_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class FavoritesListsPage extends StatefulWidget {
  const FavoritesListsPage({super.key});
  @override
  State<FavoritesListsPage> createState() => _FavoritesListsPageState();
}

class _FavoritesListsPageState extends State<FavoritesListsPage> {
  late final PaginationController<ListModel> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController(fetch: _fetch);
    _ctrl.fetchMore();
  }

  Future<PagedResult<ListModel>> _fetch(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ProfileService(api).getCollectedLists(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏的清单')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            _ctrl.fetchMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) => ListView.builder(
              itemCount: _ctrl.items.length,
              itemBuilder: (_, i) {
                final list = _ctrl.items[i];
                return ListTile(
                  title: Text(list.name),
                  subtitle: Text(
                      '${list.movieCount}部影片, 被查看${list.viewedCount}次'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/list/${list.id}'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

#### `lib/core/router/app_router.dart`（修改 6 个收藏子路由 builder）

将以下 6 个占位路由替换为真实页面：

| 路由路径 | 替换为 | import |
|----------|--------|--------|
| `profileFavorites` | `FavoritesPage()` | `favorites_screen.dart` |
| `profileFavoritesActors` | `FavoritesActorsPage()` | `favorites_actors_screen.dart` |
| `profileFavoritesMakers` | `FavoritesMakersPage()` | `favorites_makers_screen.dart` |
| `profileFavoritesSeries` | `FavoritesSeriesPage()` | `favorites_series_screen.dart` |
| `profileFavoritesDirectors` | `FavoritesDirectorsPage()` | `favorites_directors_screen.dart` |
| `profileFavoritesCodes` | `FavoritesCodesPage()` | `favorites_codes_screen.dart` |
| `profileFavoritesLists` | `FavoritesListsPage()` | `favorites_lists_screen.dart` |

#### `test/features/profile/favorites_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/favorites_screen.dart';

void main() {
  testWidgets('FavoritesPage 渲染 6 个收藏入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FavoritesPage()));
    await tester.pump();
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('收藏的演员'), findsOneWidget);
    expect(find.text('收藏的片商'), findsOneWidget);
    expect(find.text('收藏的系列'), findsOneWidget);
    expect(find.text('收藏的导演'), findsOneWidget);
    expect(find.text('收藏的番号'), findsOneWidget);
    expect(find.text('收藏的清单'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/favorites_screen_test.dart

git add lib/features/profile/screens/favorites_screen.dart \
        lib/features/profile/screens/favorites_actors_screen.dart \
        lib/features/profile/screens/favorites_makers_screen.dart \
        lib/features/profile/screens/favorites_series_screen.dart \
        lib/features/profile/screens/favorites_directors_screen.dart \
        lib/features/profile/screens/favorites_codes_screen.dart \
        lib/features/profile/screens/favorites_lists_screen.dart \
        lib/core/router/app_router.dart \
        test/features/profile/favorites_screen_test.dart
git commit -m "feat(profile): add favorites hub + 6 collection sub-pages"
```

---

## Task 7: 创建"我的清单"子页面

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/lists_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/lists_screen_test.dart` |

### Interfaces

**Consumes:**
- `ProfileService.getLists()` — 获取用户创建的清单
- `PaginationController<ListModel>` — 分页
- `ListView` — 渲染 ListTile（name + "X部影片" subtitle），点击跳 `/list/:id`

**Produces:**
- `ListsPage`

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建测试验证标题渲染。
- [ ] **2. 验证测试失败** — 预期 FAIL。
- [ ] **3. 写实现** — 创建 `lists_screen.dart`，更新路由。
- [ ] **4. 验证测试通过** — 全部 PASS。
- [ ] **5. 提交** — `feat(profile): add ListsPage for user-created lists`。

### 完整实现代码

#### `lib/features/profile/screens/lists_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});
  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  late final PaginationController<ListModel> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController(fetch: _fetch);
    _ctrl.fetchMore();
  }

  Future<PagedResult<ListModel>> _fetch(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ProfileService(api).getLists(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的清单')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
            _ctrl.fetchMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) => ListView.builder(
              itemCount: _ctrl.items.length,
              itemBuilder: (_, i) {
                final list = _ctrl.items[i];
                return ListTile(
                  title: Text(list.name),
                  subtitle: Text('${list.movieCount}部影片'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/list/${list.id}'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

#### `lib/core/router/app_router.dart`（修改 lists 路由）

将 `_PlaceholderPage(title: '我的清单')` 改为 `ListsPage()`，添加 import：

```dart
import 'package:jade/features/profile/screens/lists_screen.dart';
```

#### `test/features/profile/lists_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/lists_screen.dart';

void main() {
  testWidgets('ListsPage 渲染标题', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ListsPage()));
    await tester.pump();
    expect(find.text('我的清单'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/lists_screen_test.dart

git add lib/features/profile/screens/lists_screen.dart \
        lib/core/router/app_router.dart \
        test/features/profile/lists_screen_test.dart
git commit -m "feat(profile): add ListsPage for user-created lists"
```

---

## Task 8: 创建"近期浏览"子页面

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/recent_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/recent_screen_test.dart` |

### Interfaces

**Consumes:**
- `ProfileService.getRecentViewed()` — 获取近期浏览的影片
- `PaginationController<MovieSummary>` — 分页
- `MovieGridView` — 瀑布流渲染

**Produces:**
- `RecentPage`

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建测试验证标题和 MovieGridView 存在。
- [ ] **2. 验证测试失败** — 预期 FAIL。
- [ ] **3. 写实现** — 创建 `recent_screen.dart`，更新路由。
- [ ] **4. 验证测试通过** — 全部 PASS。
- [ ] **5. 提交** — `feat(profile): add RecentPage with MovieGridView`。

### 完整实现代码

#### `lib/features/profile/screens/recent_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});
  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  late final PaginationController<MovieSummary> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController(fetch: _fetch);
    _ctrl.fetchMore();
  }

  Future<PagedResult<MovieSummary>> _fetch(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ProfileService(api).getRecentViewed(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('近期浏览')),
      body: MovieGridView(controller: _ctrl),
    );
  }
}
```

#### `lib/core/router/app_router.dart`（修改 recent 路由）

将 `_PlaceholderPage(title: '近期浏览')` 改为 `RecentPage()`，添加 import：

```dart
import 'package:jade/features/profile/screens/recent_screen.dart';
```

#### `test/features/profile/recent_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/recent_screen.dart';

void main() {
  testWidgets('RecentPage 渲染标题', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RecentPage()));
    await tester.pump();
    expect(find.text('近期浏览'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/recent_screen_test.dart

git add lib/features/profile/screens/recent_screen.dart \
        lib/core/router/app_router.dart \
        test/features/profile/recent_screen_test.dart
git commit -m "feat(profile): add RecentPage with MovieGridView"
```

---

## Task 9: 创建"个人资料"子页面（修改密码/用户名）

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/info_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/profile/info_screen_test.dart` |

### Interfaces

**Consumes:**
- `ProfileService.fetchUser()` — 获取 email
- `ProfileService.fetchUserAdditional()` — 获取附加信息（reportsCount/deletedCommentsCount/mutedCount/maxMutedCount/uncorrectedCount/correctionsCount）
- `ProfileService.changePassword(...)` / `changeUsername(...)` — 修改密码/用户名
- `showDialog` + `TextField` — 弹窗输入

**Produces:**
- `InfoPage` — `StatefulWidget`，`initState` 加载 `fetchUser` + `fetchUserAdditional`，展示 Cell 列表：电子邮箱、短评被举报次数、短评被删次数、禁言次数（subtitle: 超最大次数封号）、待审核/已通过订正数（subtitle: 订正来自网页版影片详情）、修改密码、修改用户名。修改密码/用户名点击弹出 `AlertDialog`。

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建测试验证基本 Cell 渲染（不需要真实 API）。
- [ ] **2. 验证测试失败** — 预期 FAIL。
- [ ] **3. 写实现** — 创建 `info_screen.dart`，更新路由。
- [ ] **4. 验证测试通过** — 全部 PASS。
- [ ] **5. 提交** — `feat(profile): add InfoPage with change password/username dialogs`。

### 完整实现代码

#### `lib/features/profile/screens/info_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/features/profile/models/user_additional_info.dart';
import 'package:jade/features/profile/services/profile_service.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String? _email;
  UserAdditionalInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    final service = ProfileService(api);
    try {
      final userData = await service.fetchUser();
      final user = userData['user'] as Map<String, dynamic>?;
      _email = user?['email'] as String?;
    } catch (_) {}
    try {
      _info = await service.fetchUserAdditional();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '旧密码'),
            ),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密码'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (result == true) {
      final api = ApiClient.instanceOrNull;
      if (api == null) return;
      try {
        await ProfileService(api).changePassword(
          oldPassword: oldCtrl.text,
          newPassword: newCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('密码修改成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('修改失败: $e')));
        }
      }
    }
    oldCtrl.dispose();
    newCtrl.dispose();
  }

  Future<void> _changeUsername() async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改用户名'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '新用户名'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (result == true) {
      final api = ApiClient.instanceOrNull;
      if (api == null) return;
      try {
        await ProfileService(api).changeUsername(username: ctrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('用户名修改成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('修改失败: $e')));
        }
      }
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: const Text('电子邮箱'),
                  subtitle: Text(_email ?? '未设置'),
                ),
                ListTile(
                  title: const Text('短评被举报次数'),
                  subtitle: Text('${_info?.reportsCount ?? 0}'),
                ),
                ListTile(
                  title: const Text('短评被删次数'),
                  subtitle: Text('${_info?.deletedCommentsCount ?? 0}'),
                ),
                ListTile(
                  title: const Text('禁言次数'),
                  subtitle: Text('${_info?.mutedCount ?? 0} / ${_info?.maxMutedCount ?? 0}（超最大次数封号）'),
                ),
                ListTile(
                  title: const Text('订正数'),
                  subtitle: Text(
                      '待审核 ${_info?.uncorrectedCount ?? 0} / 已通过 ${_info?.correctionsCount ?? 0}\n（订正来自网页版影片详情）'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('修改密码'),
                  leading: const Icon(Icons.lock_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
                ListTile(
                  title: const Text('修改用户名'),
                  leading: const Icon(Icons.edit),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changeUsername,
                ),
              ],
            ),
    );
  }
}
```

#### `lib/core/router/app_router.dart`（修改 info 路由）

将 `_PlaceholderPage(title: '个人资料')` 改为 `InfoPage()`，添加 import：

```dart
import 'package:jade/features/profile/screens/info_screen.dart';
```

#### `test/features/profile/info_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/info_screen.dart';

void main() {
  testWidgets('InfoPage 渲染基本 Cell', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InfoPage()));
    await tester.pump();
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('电子邮箱'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('修改用户名'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/profile/info_screen_test.dart

git add lib/features/profile/screens/info_screen.dart \
        lib/core/router/app_router.dart \
        test/features/profile/info_screen_test.dart
git commit -m "feat(profile): add InfoPage with change password/username dialogs"
```

---

## Task 10: 扩展设置页 — 外观/线路选择/默认筛选标签/清除缓存

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/profile/screens/profile_settings_screen.dart` |
| Create（重命名） | `lib/features/settings/screens/appearance_screen.dart`（从 `settings_screen.dart` 复制并重构） |
| Create | `lib/features/settings/screens/line_screen.dart` |
| Create | `lib/features/settings/screens/default_filter_screen.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Modify | `lib/features/settings/index.dart` |
| Create | `test/features/settings/settings_test.dart` |

### Interfaces

**Consumes:**
- `ThemeProvider` — `setThemeMode()` / `themeMode`
- `StartupProvider` — `apiDomains`（域名列表）
- `ApiClient.domainManager` — `swapBaseUrl()` + `SharedPreferences.setString(StorageKeys.baseUrl, url)`
- `SettingsProvider` — `defaultFilterTags` / `setDefaultFilterTags()`
- `cached_network_image` — `CachedNetworkImage.evictFromCache()` 或 Flutter 内置 `imageCache.clear()`
- `SettingItem` — 复用现有组件

**Produces:**
- `ProfileSettingsPage` — hub 页，4 个 `SettingItem`（外观模式、线路选择、默认筛选标签、清除缓存），点击跳对应子页
- `AppearancePage` — 现有 settings_screen.dart 重构版（`/settings/appearance`），使用 `SettingItem` + `DropdownButton<ThemeMode>`
- `LinePage` — 列出 `apiDomains`，当前选中高亮，点击切换 `SwapBaseUrl + persist`，通知 `StartupProvider`
- `DefaultFilterPage` — 两个 `DropdownButton`（type: 全部/有码/无码/欧美/FC2/动漫、sort: 最新/热门/评分），确认后写入 `SettingsProvider`
- `ProfileSettingsPage` 中"清除缓存"项点击：`showDialog` 确认 → 调用 `PaintingBinding.instance.imageCache.clear()` + `PaintingBinding.instance.imageCache.clearLiveImages()` + `showSnackBar`

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建测试验证 hub 页 4 个 Cell 渲染。
- [ ] **2. 验证测试失败** — 预期 FAIL。
- [ ] **3. 写实现** — 创建全部 4 个文件 + 重构现有 settings_screen，更新路由。
- [ ] **4. 验证测试通过** — 全部 PASS。
- [ ] **5. 提交** — `feat(settings): extend settings with appearance, line, default filter, and cache clear`。

### 完整实现代码

#### `lib/features/settings/screens/appearance_screen.dart`（从现有 settings_screen.dart 重构）

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/features/settings/widgets/setting_item.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('外观模式')),
      body: ListView(
        children: [
          SettingItem(
            title: '应用主题',
            icon: Icons.brightness_4,
            editor: DropdownButton<ThemeMode>(
              value: themeProvider.themeMode,
              items: const [
                DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
              ],
              onChanged: (v) {
                if (v != null) themeProvider.setThemeMode(v);
              },
            ),
            onTap: null,
          ),
        ],
      ),
    );
  }
}
```

#### `lib/features/settings/screens/line_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';

class LinePage extends StatelessWidget {
  const LinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final startup = context.watch<StartupProvider>();
    final dm = ApiClient.instanceOrNull?.domainManager;
    final domains = dm?.apiDomains ?? const [];
    final currentUrl = dm?.currentUrl ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('线路选择')),
      body: ListView.builder(
        itemCount: domains.length,
        itemBuilder: (_, i) {
          final domain = domains[i];
          final isSelected = domain == currentUrl;
          return RadioListTile<String>(
            title: Text(domain),
            subtitle: isSelected ? const Text('当前线路', style: TextStyle(color: Colors.green)) : null,
            value: domain,
            groupValue: currentUrl,
            onChanged: (v) async {
              if (v == null || v == currentUrl) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(StorageKeys.baseUrl, v);
              dm?.swapBaseUrl(v);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('线路已切换')),
              );
            },
          );
        },
      ),
    );
  }
}
```

#### `lib/features/settings/screens/default_filter_screen.dart`

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/settings_provider.dart';

class DefaultFilterPage extends StatefulWidget {
  const DefaultFilterPage({super.key});
  @override
  State<DefaultFilterPage> createState() => _DefaultFilterPageState();
}

class _DefaultFilterPageState extends State<DefaultFilterPage> {
  late String _selectedType;
  late String _selectedSort;

  static const _typeOptions = [
    ('全部', ''),
    ('有码', '1'),
    ('无码', '2'),
    ('欧美', '3'),
    ('FC2', '5'),
    ('动漫', '6'),
  ];

  static const _sortOptions = [
    ('最新', 'date'),
    ('热门', 'hot'),
    ('评分', 'rating'),
  ];

  @override
  void initState() {
    super.initState();
    final tags = context.read<SettingsProvider>().defaultFilterTags;
    _selectedType = tags.isNotEmpty ? tags[0] : '';
    _selectedSort = tags.length > 1 ? tags[1] : 'date';
  }

  Future<void> _save() async {
    await context
        .read<SettingsProvider>()
        .setDefaultFilterTags([_selectedType, _selectedSort]);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('默认筛选已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('默认筛选标签')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('默认类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedType,
            items: _typeOptions
                .map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1)))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v ?? ''),
          ),
          const SizedBox(height: 24),
          const Text('默认排序', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedSort,
            items: _sortOptions
                .map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1)))
                .toList(),
            onChanged: (v) => setState(() => _selectedSort = v ?? 'date'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
```

#### `lib/features/profile/screens/profile_settings_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('外观模式'),
            leading: const Icon(Icons.brightness_6),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/appearance'),
          ),
          ListTile(
            title: const Text('线路选择'),
            leading: const Icon(Icons.dns),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/line'),
          ),
          ListTile(
            title: const Text('默认筛选标签'),
            leading: const Icon(Icons.filter_alt),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/default-filter'),
          ),
          ListTile(
            title: const Text('清除缓存'),
            leading: const Icon(Icons.delete_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _clearCache(context),
          ),
        ],
      ),
    );
  }

  void _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除图片缓存吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('缓存已清除')));
    }
  }
}
```

#### `lib/features/settings/index.dart`（更新 export）

```dart
export 'screens/appearance_screen.dart';
export 'screens/line_screen.dart';
export 'screens/default_filter_screen.dart';
```

#### `lib/core/router/app_router.dart`（修改 settings 相关路由）

1. 将 `profileSettings` 占位路由改为 `ProfileSettingsPage()`：

```dart
import 'package:jade/features/profile/screens/profile_settings_screen.dart';

// 替换
GoRoute(
    path: AppRoutes.profileSettings,
    builder: (c, s) => const ProfileSettingsPage()),
```

2. 新增 settings 子路由（在 profile 子路由区域之后）：

```dart
import 'package:jade/features/settings/index.dart';

GoRoute(
    path: AppRoutes.settingsAppearance,
    builder: (c, s) => const AppearancePage()),
GoRoute(
    path: AppRoutes.settingsLine,
    builder: (c, s) => const LinePage()),
GoRoute(
    path: AppRoutes.settingsDefaultFilter,
    builder: (c, s) => const DefaultFilterPage()),
```

#### `test/features/settings/settings_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/profile_settings_screen.dart';
import 'package:jade/features/settings/screens/appearance_screen.dart';

void main() {
  testWidgets('ProfileSettingsPage 渲染 4 个设置项', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileSettingsPage()));
    await tester.pump();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('线路选择'), findsOneWidget);
    expect(find.text('默认筛选标签'), findsOneWidget);
    expect(find.text('清除缓存'), findsOneWidget);
  });

  testWidgets('AppearancePage 渲染主题选项', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppearancePage()));
    await tester.pump();
    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('应用主题'), findsOneWidget);
  });
}
```

### 终端命令

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

flutter test test/features/settings/settings_test.dart

git add lib/features/profile/screens/profile_settings_screen.dart \
        lib/features/settings/screens/appearance_screen.dart \
        lib/features/settings/screens/line_screen.dart \
        lib/features/settings/screens/default_filter_screen.dart \
        lib/features/settings/index.dart \
        lib/core/router/app_router.dart \
        test/features/settings/settings_test.dart
git commit -m "feat(settings): extend settings with appearance, line, default filter, and cache clear"
```

---

## Implementation Order

任务依赖链：

```
Task 1 (ProfileService) ──┬── Task 3 (WantWatch) ── Task 4 (Watched)
                          │
Task 2 (ProfilePage+路由) ─┼── Task 5 (Following)
                          ├── Task 6 (Favorites hub+6子页)
                          ├── Task 7 (Lists)
                          ├── Task 8 (Recent)
                          ├── Task 9 (Info)
                          └── Task 10 (Settings扩展)
```

- Task 1 和 Task 2 可并行，Task 2 依赖 Task 1 中的 `ProfileService` 完整定义
- Task 3-10 均依赖 Task 2（路由已注册），彼此完全独立可并行执行
- 推荐执行顺序：1 → 2 → (3,4,5,6,7,8,9,10 并行)

## Verification Checklist

全部任务完成后，运行：

```bash
# 1. 所有单元测试
flutter test test/features/profile/
flutter test test/features/settings/

# 2. 静态分析
flutter analyze lib/features/profile/ lib/features/settings/

# 3. build_runner
dart run build_runner build --delete-conflicting-outputs
```

预期输出：
- 所有测试 PASS
- `flutter analyze` 无 error、无 warning
- build_runner 无报错
