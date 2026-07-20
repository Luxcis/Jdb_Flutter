# Jade Phase 5 — 影片详情 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善 MovieDetailPage，补全 Service 缺失接口、引入 MovieDetailProvider（ChangeNotifier）替代 setState，实现"想看/看过/存入清单"按钮、剧照横向滚轮、TA还出演过、底部抽屉三 Tab（磁链复制、短评撰写、相关清单）。

**Architecture:** `lib/features/movie_detail/` 下新增 `providers/movie_detail_provider.dart`，扩展 `services/movie_detail_service.dart` 补全 API 调用，重构 `screens/movie_detail_screen.dart` 使用 Provider 管理状态。所有子模块错误各自降级（try-catch 吞异常，不阻塞主流程）。

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

## Key Architecture Decisions

1. **Provider vs setState：** 当前 `MovieDetailPage` 是 `StatefulWidget` + `setState`，需要重构为使用 `MovieDetailProvider`（ChangeNotifier）统一管理详情、磁链、短评、相关清单、你可能也喜欢等所有子数据。Provider 在 `MovieDetailPage` 内部通过 `ChangeNotifierProvider` 注入，生命周期与页面绑定。

2. **错误降级策略：** 详情接口失败 → 全屏 `ErrorRetryWidget`（重试仅重拉详情）；子模块（磁链/短评/你可能也喜欢/相关清单）各自独立 try-catch，失败时对应区域不渲染，不影响其他区域。

3. **"想看/看过" 接口：** 使用现有 `ApiClient.post` 调用 `/api/v2/users/review_movies`，body 为 `{movie_id, status}`（status: "want"/"watched"）。

4. **"存入清单"：** 点击后弹出底部 sheet 列出用户清单（需先获取 `GET /lists/related`），选择后调用 `POST /lists/{id}/movie_actions`，body 为 `{movie_id, action: "add"}`。

5. **磁链复制：** 使用 Flutter 内置 `Clipboard`（`services/clipboard.dart`），无需额外依赖。

6. **TA还出演过：** 取详情返回的 actors 列表中第一位演员，调用 `GET /movies/{actor_id}/movies`（若 Service 无此接口则新增）；或直接复用 `GET /movies/may_also_like` 逻辑——但 spec 明确说"演员的其他作品"，所以需要新接口 `getActorMovies(actorId)`。简化方案：为每位演员调用 `/api/v1/actors/{actorId}/movies`，取第一个有作品的演员展示。

7. **短评撰写：** 底部弹出 `showModalBottomSheet`，包含 score（1-5星选择）、content（TextField）、提交按钮（`POST /movies/{id}/reviews`），提交成功后关闭 sheet 并刷新短评列表。

---

## Task 1: 扩展 MovieDetailService — 添加缺失 API 方法

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/movie_detail/services/movie_detail_service.dart` |
| Create | `test/features/movie_detail/services/movie_detail_service_test.dart` |

### Interfaces

**Consumes:**
- `ApiClient.get(path, queryParameters?)` — 已有
- `ApiClient.post(path, data)` — 已有

**Produces（新增方法）:**

```dart
// 获取相关清单
Future<List<ListModel>> getRelatedLists(String movieId) async { ... }

// 发表短评
Future<void> postReview({required String movieId, required double score, required String content, String status = 'public'}) async { ... }

// "想看/看过" 状态切换
Future<void> reviewMovie({required String movieId, required String status}) async { ... }

// 清单操作（添加/移除影片）
Future<void> listMovieAction({required String listId, required String movieId, required String action}) async { ... }

// （可选）获取演员作品列表 — 用于 "TA还出演过"
Future<List<MovieSummary>> getActorMovies(String actorId) async { ... }
```

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建 `test/features/movie_detail/services/movie_detail_service_test.dart`，用 `FakeAdapter` stub 每个新方法，编写成功/失败用例。
- [ ] **2. 验证测试失败** — `flutter test test/features/movie_detail/services/movie_detail_service_test.dart`，预期：`No tests ran` 或全部 FAIL（方法不存在）。
- [ ] **3. 写实现** — 在 `MovieDetailService` 中新增 `getRelatedLists`、`postReview`、`reviewMovie`、`listMovieAction`、`getActorMovies` 方法。
- [ ] **4. 验证测试通过** — `flutter test test/features/movie_detail/services/movie_detail_service_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 仅改动的 2 个文件，commit message: `feat(movie_detail): add getRelatedLists, postReview, reviewMovie, listMovieAction, getActorMovies to MovieDetailService`。

### 完整实现代码

#### `lib/features/movie_detail/services/movie_detail_service.dart`（替换整个文件）

```dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/models/list_model.dart';

class MovieDetailService {
  MovieDetailService(this._api);
  final ApiClient _api;

  Future<MovieDetail> getDetail(String id) async {
    final resp = await _api.get('/api/v4/movies/$id');
    return MovieDetail.fromJson(resp.data);
  }

  Future<List<Magnet>> getMagnets(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/magnets');
    return ((resp.data as List?) ?? [])
        .map((j) => Magnet.fromJson(j))
        .toList();
  }

  Future<List<Review>> getReviews(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/reviews');
    return ((resp.data as List?) ?? [])
        .map((j) => Review.fromJson(j))
        .toList();
  }

  Future<List<MovieSummary>> getMayAlsoLike(String id) async {
    final resp = await _api.get('/api/v1/movies/$id/may_also_like');
    return ((resp.data as List?) ?? [])
        .map((j) => MovieSummary.fromJson(j))
        .toList();
  }

  /// 获取该影片相关的用户清单列表。
  Future<List<ListModel>> getRelatedLists(String movieId) async {
    final resp = await _api.get('/api/v1/lists/related',
        queryParameters: {'movie_id': movieId});
    final data = resp.data;
    if (data is List) {
      return data.map((j) => ListModel.fromJson(j)).toList();
    }
    return [];
  }

  /// 发表短评。
  Future<void> postReview({
    required String movieId,
    required double score,
    required String content,
    String status = 'public',
  }) async {
    await _api.post('/api/v1/movies/$movieId/reviews', data: {
      'score': score,
      'content': content,
      'status': status,
    });
  }

  /// "想看/看过" 状态切换。
  /// [status] 取值 "want" 或 "watched"。
  Future<void> reviewMovie({
    required String movieId,
    required String status,
  }) async {
    await _api.post('/api/v2/users/review_movies', data: {
      'movie_id': movieId,
      'status': status,
    });
  }

  /// 清单操作（添加/移除影片）。
  /// [action] 取值 "add" 或 "remove"。
  Future<void> listMovieAction({
    required String listId,
    required String movieId,
    required String action,
  }) async {
    await _api.post('/api/v1/lists/$listId/movie_actions', data: {
      'movie_id': movieId,
      'action': action,
    });
  }

  /// 获取某演员的作品列表。
  Future<List<MovieSummary>> getActorMovies(String actorId) async {
    final resp =
        await _api.get('/api/v1/actors/$actorId/movies');
    final data = resp.data;
    if (data is List) {
      return data.map((j) => MovieSummary.fromJson(j)).toList();
    }
    return [];
  }
}
```

#### `test/features/movie_detail/services/movie_detail_service_test.dart`（新建）

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class _FakeTokenProvider implements TokenProvider {
  @override
  String? get token => 'fake-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  late FakeAdapter adapter;
  late MovieDetailService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _FakeTokenProvider(),
      onAuthError: () {},
    );
    adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    svc = MovieDetailService(api);
  });

  group('getDetail', () {
    test('解析 MovieDetail', () async {
      adapter.enqueue('/api/v4/movies/1', {
        'id': '1',
        'number': 'SSIS-001',
        'title': 'Test',
        'cover_url': 'covers/x.jpg',
        'release_date': '2024-01-01',
        'duration': 120,
        'score': 8.5,
        'director': 'Dir',
        'maker': 'Maker',
        'series': 'Series',
        'actors': [
          {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
        ],
        'screenshots': ['s1.jpg', 's2.jpg'],
        'tags': ['Tag1', 'Tag2'],
        'magnet_count': 3,
        'want_watch_count': 10,
        'watched_count': 5,
        'playable': true,
        'has_subtitle': false,
      });
      final detail = await svc.getDetail('1');
      expect(detail.id, '1');
      expect(detail.title, 'Test');
      expect(detail.actors.length, 1);
      expect(detail.screenshots.length, 2);
      expect(detail.tags, ['Tag1', 'Tag2']);
    });
  });

  group('getMagnets', () {
    test('解析 magnet 列表', () async {
      adapter.enqueue('/api/v1/movies/1/magnets', [
        {'hash': 'abc', 'title': 'M1', 'size': '1.2GB', 'publish_date': '2024-01-01', 'is_high_definition': true},
      ]);
      final list = await svc.getMagnets('1');
      expect(list.length, 1);
      expect(list.first.hash, 'abc');
      expect(list.first.isHighDefinition, isTrue);
    });
  });

  group('getReviews', () {
    test('解析 review 列表', () async {
      adapter.enqueue('/api/v1/movies/1/reviews', [
        {'id': 'r1', 'score': 4.0, 'content': 'Good', 'status': 'public', 'liked_count': 2},
      ]);
      final list = await svc.getReviews('1');
      expect(list.length, 1);
      expect(list.first.content, 'Good');
    });
  });

  group('getMayAlsoLike', () {
    test('解析 你可能也喜欢 列表', () async {
      adapter.enqueue('/api/v1/movies/1/may_also_like', [
        {'id': '2', 'number': 'ABC-001', 'title': 'Related', 'cover_url': 'c.jpg'},
      ]);
      final list = await svc.getMayAlsoLike('1');
      expect(list.length, 1);
      expect(list.first.title, 'Related');
    });
  });

  group('getRelatedLists', () {
    test('解析相关清单列表', () async {
      adapter.enqueue('/api/v1/lists/related?movie_id=1', [
        {'id': 'l1', 'name': 'MyList', 'movie_count': 10, 'viewed_count': 5},
      ]);
      final list = await svc.getRelatedLists('1');
      expect(list.length, 1);
      expect(list.first.name, 'MyList');
    });

    test('空列表返回 []', () async {
      adapter.enqueue('/api/v1/lists/related?movie_id=1', []);
      final list = await svc.getRelatedLists('1');
      expect(list, isEmpty);
    });
  });

  group('postReview', () {
    test('发送正确 body', () async {
      adapter.enqueue('/api/v1/movies/1/reviews', {'success': 1});
      await svc.postReview(movieId: '1', score: 4.5, content: 'Nice');
      expect(adapter.requests.last.path, '/api/v1/movies/1/reviews');
    });
  });

  group('reviewMovie', () {
    test('发送正确 body', () async {
      adapter.enqueue('/api/v2/users/review_movies', {'success': 1});
      await svc.reviewMovie(movieId: '1', status: 'want');
      expect(adapter.requests.last.path, '/api/v2/users/review_movies');
    });
  });

  group('listMovieAction', () {
    test('发送正确 body', () async {
      adapter.enqueue('/api/v1/lists/l1/movie_actions', {'success': 1});
      await svc.listMovieAction(listId: 'l1', movieId: '1', action: 'add');
      expect(adapter.requests.last.path, '/api/v1/lists/l1/movie_actions');
    });
  });

  group('getActorMovies', () {
    test('解析演员作品列表', () async {
      adapter.enqueue('/api/v1/actors/a1/movies', [
        {'id': 'm1', 'number': 'SSIS-002', 'title': 'Actor Movie', 'cover_url': 'c.jpg'},
      ]);
      final list = await svc.getActorMovies('a1');
      expect(list.length, 1);
      expect(list.first.title, 'Actor Movie');
    });
  });
}
```

### 终端命令

```bash
# 1. 运行测试（预期全部失败，因为方法还不存在）
flutter test test/features/movie_detail/services/movie_detail_service_test.dart

# 2. 复制实现代码后重新运行
flutter test test/features/movie_detail/services/movie_detail_service_test.dart
# 预期：All tests passed!

# 3. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/movie_detail/services/movie_detail_service.dart test/features/movie_detail/services/movie_detail_service_test.dart
git commit -m "$(cat <<'EOF'
feat(movie_detail): add getRelatedLists, postReview, reviewMovie, listMovieAction, getActorMovies to MovieDetailService
EOF
)"
```

---

## Task 2: 创建 MovieDetailProvider（ChangeNotifier）

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/movie_detail/providers/movie_detail_provider.dart` |
| Modify | `lib/features/movie_detail/index.dart`（追加 export） |
| Create | `test/features/movie_detail/providers/movie_detail_provider_test.dart` |

### Interfaces

**Consumes:**
- `MovieDetailService` — 所有公开方法
- `ChangeNotifier` — provider 基类

**Produces:**

```dart
class MovieDetailProvider extends ChangeNotifier {
  // 状态
  MovieDetail? get detail;
  List<Magnet> get magnets;
  List<Review> get reviews;
  List<MovieSummary> get mayAlsoLike;
  List<ListModel> get relatedLists;
  List<MovieSummary> get actorOtherMovies;
  bool get isLoading;
  String? get error;

  // 操作
  Future<void> load(String movieId);
  Future<void> reviewMovie(String movieId, String status);
  Future<void> postReview(String movieId, double score, String content);
  Future<void> listMovieAction(String listId, String movieId, String action);
  Future<void> loadRelatedLists(String movieId);
  Future<void> refreshMagnets(String movieId);
  Future<void> refreshReviews(String movieId);
  void retry();
}
```

### 5-Step Checklist

- [ ] **1. 写测试先跑失败** — 创建 Provider 单元测试，验证 `load` 后 `detail` 非空、`reviewMovie` 调用后状态更新、错误态设置 `error`。
- [ ] **2. 验证测试失败** — `flutter test test/features/movie_detail/providers/movie_detail_provider_test.dart`，全部 FAIL。
- [ ] **3. 写实现** — 在 `lib/features/movie_detail/providers/movie_detail_provider.dart` 中实现 `MovieDetailProvider`，`load` 内并行调用 Service 各方法，各自 try-catch 降级。
- [ ] **4. 验证测试通过** — `flutter test test/features/movie_detail/providers/movie_detail_provider_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 改动的 2 个文件 + index.dart。

### 完整实现代码

#### `lib/features/movie_detail/providers/movie_detail_provider.dart`（新建）

```dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';

class MovieDetailProvider extends ChangeNotifier {
  MovieDetailProvider();

  MovieDetailService? _svc;
  String? _movieId;

  MovieDetail? _detail;
  final List<Magnet> _magnets = [];
  final List<Review> _reviews = [];
  final List<MovieSummary> _mayAlsoLike = [];
  final List<ListModel> _relatedLists = [];
  final List<MovieSummary> _actorOtherMovies = [];
  bool _isLoading = false;
  String? _error;

  MovieDetail? get detail => _detail;
  List<Magnet> get magnets => List.unmodifiable(_magnets);
  List<Review> get reviews => List.unmodifiable(_reviews);
  List<MovieSummary> get mayAlsoLike => List.unmodifiable(_mayAlsoLike);
  List<ListModel> get relatedLists => List.unmodifiable(_relatedLists);
  List<MovieSummary> get actorOtherMovies =>
      List.unmodifiable(_actorOtherMovies);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 初始化加载全部数据。
  Future<void> load(String movieId) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    _svc = MovieDetailService(api);
    _movieId = movieId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _detail = await _svc!.getDetail(movieId);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = false;
    notifyListeners();

    // 子模块并行加载，各自降级
    await Future.wait([
      _loadMagnets(),
      _loadReviews(),
      _loadMayAlsoLike(),
      _loadRelatedLists(),
      _loadActorMovies(),
    ]);
  }

  Future<void> _loadMagnets() async {
    try {
      final list = await _svc!.getMagnets(_movieId!);
      _magnets
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    try {
      final list = await _svc!.getReviews(_movieId!);
      _reviews
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadMayAlsoLike() async {
    try {
      final list = await _svc!.getMayAlsoLike(_movieId!);
      _mayAlsoLike
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadRelatedLists() async {
    try {
      final list = await _svc!.getRelatedLists(_movieId!);
      _relatedLists
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadActorMovies() async {
    try {
      final actors = _detail?.actors ?? [];
      if (actors.isEmpty) return;
      // 为第一个有作品的演员加载作品列表
      final movies = await _svc!.getActorMovies(actors.first.id);
      _actorOtherMovies
        ..clear()
        ..addAll(movies);
      notifyListeners();
    } catch (_) {}
  }

  /// "想看/看过" 操作。
  Future<void> reviewMovie(String status) async {
    await _svc?.reviewMovie(movieId: _movieId!, status: status);
  }

  /// 发表短评。
  Future<void> postReview(double score, String content) async {
    await _svc?.postReview(movieId: _movieId!, score: score, content: content);
    // 重新加载短评列表
    await _loadReviews();
  }

  /// 清单操作。
  Future<void> listMovieAction(String listId, String action) async {
    await _svc?.listMovieAction(
        listId: listId, movieId: _movieId!, action: action);
  }

  /// 重新加载磁链。
  Future<void> refreshMagnets() async {
    if (_movieId == null) return;
    await _loadMagnets();
  }

  /// 重新加载短评。
  Future<void> refreshReviews() async {
    if (_movieId == null) return;
    await _loadReviews();
  }

  /// 重新加载相关清单。
  Future<void> refreshRelatedLists() async {
    if (_movieId == null) return;
    await _loadRelatedLists();
  }

  /// 重试（详情加载失败时）。
  Future<void> retry() async {
    if (_movieId == null) return;
    await load(_movieId!);
  }
}
```

#### `test/features/movie_detail/providers/movie_detail_provider_test.dart`（新建）

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/movie_detail/providers/movie_detail_provider.dart';
import 'package:flutter/foundation.dart';

class _FakeTokenProvider implements TokenProvider {
  @override
  String? get token => 't';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  late FakeAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _FakeTokenProvider(),
      onAuthError: () {},
    );
    adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
  });

  test('load 成功后 detail 非空，子模块为空列表（无 stub 降级）', () async {
    adapter.enqueue('/api/v4/movies/1', {
      'id': '1',
      'number': 'N',
      'title': 'T',
      'cover_url': 'c.jpg',
    });
    // 子模块 stub 返回空数组
    adapter.enqueue('/api/v1/movies/1/magnets', []);
    adapter.enqueue('/api/v1/movies/1/reviews', []);
    adapter.enqueue('/api/v1/movies/1/may_also_like', []);
    adapter.enqueue('/api/v1/lists/related?movie_id=1', []);

    final provider = MovieDetailProvider();
    await provider.load('1');

    expect(provider.detail, isNotNull);
    expect(provider.detail!.title, 'T');
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
    expect(provider.magnets, isEmpty);
    expect(provider.reviews, isEmpty);
    expect(provider.mayAlsoLike, isEmpty);
    expect(provider.relatedLists, isEmpty);
  });

  test('load 失败时 error 非空', () async {
    adapter.enqueue('/api/v4/movies/1', {}, statusCode: 500);

    final provider = MovieDetailProvider();
    await provider.load('1');

    expect(provider.detail, isNull);
    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
  });

  test('reviewMovie 调用 service', () async {
    adapter.enqueue('/api/v4/movies/1', {
      'id': '1',
      'number': 'N',
      'title': 'T',
      'cover_url': 'c.jpg',
    });
    adapter.enqueue('/api/v1/movies/1/magnets', []);
    adapter.enqueue('/api/v1/movies/1/reviews', []);
    adapter.enqueue('/api/v1/movies/1/may_also_like', []);
    adapter.enqueue('/api/v1/lists/related?movie_id=1', []);
    adapter.enqueue('/api/v2/users/review_movies', {'success': 1});

    final provider = MovieDetailProvider();
    await provider.load('1');
    await provider.reviewMovie('want');

    final reviewReq = adapter.requests
        .where((r) => r.path == '/api/v2/users/review_movies');
    expect(reviewReq, isNotEmpty);
  });
}
```

### 终端命令

```bash
# 1. 运行测试
flutter test test/features/movie_detail/providers/movie_detail_provider_test.dart
# 预期：All tests passed!

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/movie_detail/providers/movie_detail_provider.dart lib/features/movie_detail/index.dart test/features/movie_detail/providers/movie_detail_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(movie_detail): add MovieDetailProvider with parallel sub-module loading and error degradation
EOF
)"
```

---

## Task 3: 完善信息卡 — "想看/看过/存入清单"按钮

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/movie_detail/screens/movie_detail_screen.dart`（改信息卡按钮区域、引入 Provider） |

### 背景

当前按钮组的 `onPressed` 为空：
```dart
ElevatedButton(onPressed: () {}, child: const Text('想看')),
ElevatedButton(onPressed: () {}, child: const Text('看过')),
```
缺少"存入清单"按钮。

### Interfaces

**Consumes:**
- `MovieDetailProvider.reviewMovie(status)` — 想看/看过
- `MovieDetailProvider.relatedLists` — 已加载的相关清单
- `MovieDetailProvider.listMovieAction(listId, action)` — 添加到清单

**Produces:**
- UI：信息卡区域新增"存入清单"按钮，三个按钮均有功能

### 5-Step Checklist

- [ ] **1. 创建 widget test** — `test/features/movie_detail/screens/movie_detail_screen_test.dart`，验证三个按钮存在且可点击。
- [ ] **2. 验证测试失败** — `flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart`，预期 FAIL（按钮 onPressed 为空或不存在）。
- [ ] **3. 重构信息卡部分** — 用 `Consumer<MovieDetailProvider>` 包裹按钮组，实现 `onPressed` 逻辑；新增"存入清单"按钮，点击弹出清单选择底部 sheet。
- [ ] **4. 验证测试通过** — `flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 改动的文件。

### 完整实现代码

> **注意：** 本 Task 只改信息卡区域的按钮部分，其余页面结构暂时保留（完整重构见 Task 6）。这里展示信息卡内的按钮代码块片段。

在 `_MovieDetailPageState.build()` 的信息卡区域中，将按钮组替换为：

```dart
Consumer<MovieDetailProvider>(
  builder: (context, provider, _) {
    final lists = provider.relatedLists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 影片信息字段 ...
        Text('番号: ${d.number}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        if (d.releaseDate != null) Text('发行日期: ${d.releaseDate}'),
        if (d.duration != null) Text('时长: ${d.duration}分钟'),
        if (d.director != null) Text('导演: ${d.director}'),
        if (d.maker != null) Text('片商: ${d.maker}'),
        if (d.series != null) Text('系列: ${d.series}'),
        if (d.score != null) Text('评分: ${d.score}'),
        const SizedBox(height: 12),
        // 按钮组
        Row(
          children: [
            ElevatedButton(
              onPressed: () => provider.reviewMovie('want'),
              child: const Text('想看'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => provider.reviewMovie('watched'),
              child: const Text('看过'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _showListPicker(context, provider),
              child: const Text('存入清单'),
            ),
          ],
        ),
        Text(
          '${d.wantWatchCount}人想看, ${d.watchedCount}人看过',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  },
),
```

#### `_showListPicker` 辅助方法（添加到 `_MovieDetailPageState`）

```dart
void _showListPicker(BuildContext context, MovieDetailProvider provider) {
  final lists = provider.relatedLists;
  if (lists.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暂无可用的清单，请先创建')),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    builder: (ctx) => ListView.builder(
      shrinkWrap: true,
      itemCount: lists.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(lists[i].name),
        subtitle: Text('${lists[i].movieCount} 部影片'),
        onTap: () {
          provider.listMovieAction(lists[i].id, 'add');
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已添加到「${lists[i].name}」')),
          );
        },
      ),
    ),
  );
}
```

#### `test/features/movie_detail/screens/movie_detail_screen_test.dart`（新建）

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/movie_detail/providers/movie_detail_provider.dart';
import 'package:jade/features/movie_detail/screens/movie_detail_screen.dart';
import 'package:flutter/foundation.dart';

class _FakeTokenProvider implements TokenProvider {
  @override
  String? get token => 't';
}

Widget _buildTestApp(String movieId) {
  return MaterialApp(
    home: MovieDetailPage(id: movieId),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  late FakeAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _FakeTokenProvider(),
      onAuthError: () {},
    );
    adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
  });

  testWidgets('信息卡按钮都存在且可点击', (tester) async {
    adapter.enqueue('/api/v4/movies/1', {
      'id': '1',
      'number': 'SSIS-001',
      'title': 'Test Movie',
      'cover_url': 'cover.jpg',
      'release_date': '2024-01-01',
      'duration': 120,
      'score': 8.5,
      'director': 'Dir',
      'maker': 'Maker',
      'series': 'S1',
      'actors': [
        {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
      ],
      'screenshots': [],
      'tags': ['Tag1'],
      'want_watch_count': 100,
      'watched_count': 50,
    });
    adapter.enqueue('/api/v1/movies/1/magnets', []);
    adapter.enqueue('/api/v1/movies/1/reviews', []);
    adapter.enqueue('/api/v1/movies/1/may_also_like', []);
    adapter.enqueue('/api/v1/lists/related?movie_id=1', []);

    await tester.pumpWidget(_buildTestApp('1'));
    await tester.pumpAndSettle();

    expect(find.text('想看'), findsOneWidget);
    expect(find.text('看过'), findsOneWidget);
    expect(find.text('存入清单'), findsOneWidget);
    expect(find.text('100人想看, 50人看过'), findsOneWidget);

    // 点击"想看"按钮
    adapter.enqueue('/api/v2/users/review_movies', {'success': 1});
    await tester.tap(find.text('想看'));
    await tester.pumpAndSettle();
  });

  testWidgets('存入清单弹出底部 sheet', (tester) async {
    adapter.enqueue('/api/v4/movies/1', {
      'id': '1',
      'number': 'N',
      'title': 'T',
      'cover_url': 'c.jpg',
    });
    adapter.enqueue('/api/v1/movies/1/magnets', []);
    adapter.enqueue('/api/v1/movies/1/reviews', []);
    adapter.enqueue('/api/v1/movies/1/may_also_like', []);
    adapter.enqueue('/api/v1/lists/related?movie_id=1', [
      {'id': 'l1', 'name': 'Favorites', 'movie_count': 10, 'viewed_count': 5},
    ]);

    await tester.pumpWidget(_buildTestApp('1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('存入清单'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
  });
}
```

### 终端命令

```bash
# 1. 运行测试（预期 FAIL）
flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart

# 2. 修改代码后重新运行
flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart
# 预期：All tests passed!

# 3. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/screens/movie_detail_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(movie_detail): implement want-watch/watched/add-to-list buttons with list picker bottom sheet
EOF
)"
```

---

## Task 4: 添加剧照横向滚轮 + "TA还出演过"

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/movie_detail/screens/movie_detail_screen.dart`（添加两个 SliverToBoxAdapter 区域） |

### Interfaces

**Consumes:**
- `MovieDetail.detail.screenshots` — `List<String>`，剧照 URL
- `MovieDetailProvider.actorOtherMovies` — `List<MovieSummary>`，TA还出演过作品

**Produces:**
- UI：演员区域下方增加剧照横向滚轮、再下方增加"TA还出演过"横向 `MovieCard` 列表

### 5-Step Checklist

- [ ] **1. 更新 widget test** — 在 `test/features/movie_detail/screens/movie_detail_screen_test.dart` 中新增：验证剧照区域渲染、验证 TA还出演过 渲染。
- [ ] **2. 验证测试失败** — 现有 widget test 无变化应通过（无回归），新增用例待实现后通过。
- [ ] **3. 写实现** — 在 `_MovieDetailPageState.build()` 中添加两个 `SliverToBoxAdapter`：
  - 剧照：`d.screenshots.isNotEmpty` 时横向 `ListView.builder`，每个 item 为 `SizedBox(width: 160)` 包裹的 `CachedImage`。
  - TA还出演过：`provider.actorOtherMovies.isNotEmpty` 时横向 `ListView.builder`，每个 item 为 `SizedBox(width: 130)` 包裹的 `MovieCard`。
- [ ] **4. 验证测试通过** — `flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 改动的文件。

### 完整实现代码

在 `CustomScrollView` 的 slivers 中，演员区域之后，插入以下两个区域：

```dart
// 剧照横向滚轮
if (d.screenshots.isNotEmpty)
  SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('剧照',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: d.screenshots.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 160,
                  child: CachedImage(d.screenshots[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),

// TA还出演过
Consumer<MovieDetailProvider>(
  builder: (context, provider, _) {
    final movies = provider.actorOtherMovies;
    if (movies.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('TA还出演过',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (_, i) => SizedBox(
                width: 130,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: MovieCard(
                    movie: movies[i],
                    onTap: () => context.go('/movie/${movies[i].id}'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  },
),
```

#### 更新 `test/features/movie_detail/screens/movie_detail_screen_test.dart`（追加以下用例到 main() 中）

```dart
testWidgets('剧照区域渲染', (tester) async {
  adapter.enqueue('/api/v4/movies/1', {
    'id': '1',
    'number': 'N',
    'title': 'T',
    'cover_url': 'c.jpg',
    'screenshots': ['shot1.jpg', 'shot2.jpg'],
    'actors': [],
    'tags': [],
  });
  adapter.enqueue('/api/v1/movies/1/magnets', []);
  adapter.enqueue('/api/v1/movies/1/reviews', []);
  adapter.enqueue('/api/v1/movies/1/may_also_like', []);
  adapter.enqueue('/api/v1/lists/related?movie_id=1', []);

  await tester.pumpWidget(_buildTestApp('1'));
  await tester.pumpAndSettle();

  expect(find.text('剧照'), findsOneWidget);
});

testWidgets('TA还出演过区域渲染', (tester) async {
  adapter.enqueue('/api/v4/movies/1', {
    'id': '1',
    'number': 'N',
    'title': 'T',
    'cover_url': 'c.jpg',
    'actors': [
      {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
    ],
    'screenshots': [],
    'tags': [],
  });
  adapter.enqueue('/api/v1/movies/1/magnets', []);
  adapter.enqueue('/api/v1/movies/1/reviews', []);
  adapter.enqueue('/api/v1/movies/1/may_also_like', []);
  adapter.enqueue('/api/v1/lists/related?movie_id=1', []);
  adapter.enqueue('/api/v1/actors/a1/movies', [
    {'id': 'm1', 'number': 'SSIS-002', 'title': 'Actor Movie', 'cover_url': 'c.jpg'},
  ]);

  await tester.pumpWidget(_buildTestApp('1'));
  await tester.pumpAndSettle();

  expect(find.text('TA还出演过'), findsOneWidget);
});
```

### 终端命令

```bash
# 1. 运行测试
flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart
# 预期：All tests passed!

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/screens/movie_detail_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(movie_detail): add screenshots horizontal scroll and actor-other-movies section
EOF
)"
```

---

## Task 5: 完善底部抽屉三 Tab — 磁链复制、短评撰写、相关清单

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/movie_detail/screens/movie_detail_screen.dart`（重写 bottomSheet 内容） |

### Interfaces

**Consumes:**
- `MovieDetailProvider.magnets` — 磁链列表
- `MovieDetailProvider.reviews` — 短评列表
- `MovieDetailProvider.relatedLists` — 相关清单列表
- `MovieDetailProvider.refreshMagnets()` — 下拉刷新磁链
- `MovieDetailProvider.refreshReviews()` — 下拉刷新短评
- `MovieDetailProvider.refreshRelatedLists()` — 下拉刷新清单
- `MovieDetailProvider.postReview(score, content)` — 提交短评
- Flutter 内置 `Clipboard` — `services/clipboard.dart` 的 `Clipboard.setData`

**Produces:**
- UI：磁链 Tab 支持点击复制 hash、显示 HD 标/大小/日期；短评 Tab 显示评分+内容+撰写按钮；相关清单 Tab 显示清单列表可点击跳转

### 5-Step Checklist

- [ ] **1. 更新 widget test** — 新增：测试磁链列表渲染、粘贴板调用；短评撰写 sheet 弹出。
- [ ] **2. 验证测试失败** — 当前 widget test 可能失败（某些用例需要调整）。
- [ ] **3. 写实现** — 替换底部 `DraggableScrollableSheet` 内的三个 TabView 子项为完整实现。
- [ ] **4. 验证测试通过** — `flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 改动的文件。

### 完整实现代码

替换 `bottomSheet` 内 `TabBarView` 的 `children` 数组：

```dart
TabBarView(children: [
  // Tab 1: 磁链下载
  Consumer<MovieDetailProvider>(
    builder: (context, provider, _) {
      final magnets = provider.magnets;
      if (magnets.isEmpty) {
        return const Center(child: Text('暂无磁链'));
      }
      return RefreshIndicator(
        onRefresh: () => provider.refreshMagnets(),
        child: ListView.builder(
          itemCount: magnets.length,
          itemBuilder: (_, i) {
            final m = magnets[i];
            return ListTile(
              leading: m.isHighDefinition
                  ? Chip(
                      label: const Text('HD',
                          style: TextStyle(fontSize: 10)),
                      backgroundColor: Colors.amber.shade100,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              title: Text(
                m.title ?? m.hash,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text([
                if (m.size != null) m.size!,
                if (m.publishDate != null) m.publishDate!,
              ].join('  ')),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.hash));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('磁链已复制')),
                );
              },
            );
          },
        ),
      );
    },
  ),

  // Tab 2: 短评
  Consumer<MovieDetailProvider>(
    builder: (context, provider, _) {
      final reviews = provider.reviews;
      return Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${reviews.length} 条短评',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton.icon(
                  onPressed: () =>
                      _showReviewComposer(context, provider),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('写短评'),
                ),
              ],
            ),
          ),
          Expanded(
            child: reviews.isEmpty
                ? const Center(child: Text('暂无短评'))
                : RefreshIndicator(
                    onRefresh: () => provider.refreshReviews(),
                    child: ListView.builder(
                      itemCount: reviews.length,
                      itemBuilder: (_, i) {
                        final r = reviews[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              '${r.score ?? '?'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(
                            r.content ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            r.author?.name ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      );
    },
  ),

  // Tab 3: 相关清单
  Consumer<MovieDetailProvider>(
    builder: (context, provider, _) {
      final lists = provider.relatedLists;
      if (lists.isEmpty) {
        return const Center(child: Text('暂无相关清单'));
      }
      return RefreshIndicator(
        onRefresh: () => provider.refreshRelatedLists(),
        child: ListView.builder(
          itemCount: lists.length,
          itemBuilder: (_, i) {
            final lm = lists[i];
            return ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(lm.name),
              subtitle: Text(
                  '${lm.movieCount} 部影片  ${lm.viewedCount} 人看过'),
              onTap: () => context.go('/list/${lm.id}'),
            );
          },
        ),
      );
    },
  ),
]),
```

#### `_showReviewComposer` 辅助方法（添加到 `_MovieDetailPageState`）

```dart
void _showReviewComposer(
    BuildContext context, MovieDetailProvider provider) {
  double selectedScore = 5.0;
  final contentController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('写短评',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('评分: '),
                DropdownButton<double>(
                  value: selectedScore,
                  items: [1.0, 2.0, 3.0, 4.0, 5.0]
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('$s 星'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setSheetState(() => selectedScore = v);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '写下你的短评...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final content = contentController.text.trim();
                  if (content.isEmpty) return;
                  await provider.postReview(selectedScore, content);
                  if (ctx.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('短评已发表')),
                  );
                },
                child: const Text('提交'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

#### 更新 `test/features/movie_detail/screens/movie_detail_screen_test.dart`（追加）

```dart
testWidgets('磁链列表渲染并点击复制', (tester) async {
  adapter.enqueue('/api/v4/movies/1', {
    'id': '1',
    'number': 'N',
    'title': 'T',
    'cover_url': 'c.jpg',
  });
  adapter.enqueue('/api/v1/movies/1/magnets', [
    {
      'hash': 'abc123',
      'title': 'Best Version',
      'size': '2.1GB',
      'publish_date': '2024-01-01',
      'is_high_definition': true,
    },
  ]);
  adapter.enqueue('/api/v1/movies/1/reviews', []);
  adapter.enqueue('/api/v1/movies/1/may_also_like', []);
  adapter.enqueue('/api/v1/lists/related?movie_id=1', []);

  await tester.pumpWidget(_buildTestApp('1'));
  await tester.pumpAndSettle();

  // 向上拖动底部抽屉
  final finder = find.text('磁链');
  await tester.tap(finder);
  await tester.pumpAndSettle();

  expect(find.text('Best Version'), findsOneWidget);
  expect(find.text('HD'), findsOneWidget);
});

testWidgets('短评列表渲染', (tester) async {
  adapter.enqueue('/api/v4/movies/1', {
    'id': '1',
    'number': 'N',
    'title': 'T',
    'cover_url': 'c.jpg',
  });
  adapter.enqueue('/api/v1/movies/1/magnets', []);
  adapter.enqueue('/api/v1/movies/1/reviews', [
    {
      'id': 'r1',
      'score': 4.0,
      'content': 'Great movie!',
      'status': 'public',
      'author': {'name': 'User1'},
    },
  ]);
  adapter.enqueue('/api/v1/movies/1/may_also_like', []);
  adapter.enqueue('/api/v1/lists/related?movie_id=1', []);

  await tester.pumpWidget(_buildTestApp('1'));
  await tester.pumpAndSettle();

  expect(find.text('写短评'), findsOneWidget);
});

testWidgets('相关清单渲染', (tester) async {
  adapter.enqueue('/api/v4/movies/1', {
    'id': '1',
    'number': 'N',
    'title': 'T',
    'cover_url': 'c.jpg',
  });
  adapter.enqueue('/api/v1/movies/1/magnets', []);
  adapter.enqueue('/api/v1/movies/1/reviews', []);
  adapter.enqueue('/api/v1/movies/1/may_also_like', []);
  adapter.enqueue('/api/v1/lists/related?movie_id=1', [
    {'id': 'l1', 'name': 'My Favorites', 'movie_count': 10, 'viewed_count': 5},
  ]);

  await tester.pumpWidget(_buildTestApp('1'));
  await tester.pumpAndSettle();

  expect(find.text('My Favorites'), findsOneWidget);
});
```

### 终端命令

```bash
# 1. 运行测试
flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart
# 预期：All tests passed!

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/screens/movie_detail_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(movie_detail): complete bottom drawer tabs - magnet copy, review compose, related lists
EOF
)"
```

---

## Task 6: 重构 MovieDetailPage 使用 Provider + 集成 widget test

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/movie_detail/screens/movie_detail_screen.dart`（完整重写为使用 Provider） |
| Modify | `test/features/movie_detail/screens/movie_detail_screen_test.dart`（最终整理） |

### 目标

将 `MovieDetailPage` 从 `StatefulWidget` + `setState` 完全重构为使用 `ChangeNotifierProvider<MovieDetailProvider>`。页面本身保持 `StatefulWidget`（用于 `initState` 触发加载），但状态全部从 Provider 读取。

### 5-Step Checklist

- [ ] **1. 更新所有 widget test** — 确保 Task 3/4/5 中写的所有测试用例在重构后仍然通过。
- [ ] **2. 验证测试失败** — 重构前运行一次确保基线，重构后验证。
- [ ] **3. 重构 MovieDetailPage** — 用 `ChangeNotifierProvider` 包裹 `Scaffold`，移除所有 `_detail`/`_magnets`/等手动 state，改为 `Consumer<MovieDetailProvider>` 读取。错误态和加载态从 Provider 读取。
- [ ] **4. 验证测试通过** — `flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 最终改动的文件。

### 完整实现代码

#### `lib/features/movie_detail/screens/movie_detail_screen.dart`（完整替换）

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/providers/movie_detail_provider.dart';

class MovieDetailPage extends StatefulWidget {
  final String id;
  const MovieDetailPage({super.key, required this.id});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  @override
  void initState() {
    super.initState();
    // 延迟到下一帧以确保 Provider 已挂载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MovieDetailProvider>().load(widget.id);
    });
  }

  void _showListPicker(
      BuildContext context, MovieDetailProvider provider) {
    final lists = provider.relatedLists;
    if (lists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可用的清单，请先创建')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: lists.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(lists[i].name),
          subtitle: Text('${lists[i].movieCount} 部影片'),
          onTap: () {
            provider.listMovieAction(lists[i].id, 'add');
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已添加到「${lists[i].name}」')),
            );
          },
        ),
      ),
    );
  }

  void _showReviewComposer(
      BuildContext context, MovieDetailProvider provider) {
    double selectedScore = 5.0;
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('写短评',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('评分: '),
                  DropdownButton<double>(
                    value: selectedScore,
                    items: [1.0, 2.0, 3.0, 4.0, 5.0]
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('$s 星'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => selectedScore = v);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '写下你的短评...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final content = contentController.text.trim();
                    if (content.isEmpty) return;
                    await provider.postReview(selectedScore, content);
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('短评已发表')),
                    );
                  },
                  child: const Text('提交'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MovieDetailProvider(),
      child: Consumer<MovieDetailProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (provider.error != null) {
            return Scaffold(
              body: ErrorRetryWidget(
                message: provider.error!,
                onRetry: () => provider.retry(),
              ),
            );
          }
          final d = provider.detail!;
          return Scaffold(
            appBar: AppBar(
              title: Text(d.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            body: CustomScrollView(
              slivers: [
                // 影片封面
                SliverToBoxAdapter(
                  child: SizedBox(
                      height: 300, child: CachedImage(d.coverUrl)),
                ),
                // 信息卡
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('番号: ${d.number}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        const SizedBox(height: 4),
                        if (d.releaseDate != null)
                          Text('发行日期: ${d.releaseDate}'),
                        if (d.duration != null)
                          Text('时长: ${d.duration}分钟'),
                        if (d.director != null)
                          Text('导演: ${d.director}'),
                        if (d.maker != null) Text('片商: ${d.maker}'),
                        if (d.series != null) Text('系列: ${d.series}'),
                        if (d.score != null) Text('评分: ${d.score}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () =>
                                  provider.reviewMovie('want'),
                              child: const Text('想看'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  provider.reviewMovie('watched'),
                              child: const Text('看过'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _showListPicker(
                                  context, provider),
                              child: const Text('存入清单'),
                            ),
                          ],
                        ),
                        Text(
                          '${d.wantWatchCount}人想看, ${d.watchedCount}人看过',
                          style:
                              const TextStyle(color: Colors.grey),
                        ),
                        if (d.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 4,
                              children: d.tags
                                  .map((t) => TagChip(label: t))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 演员
                if (d.actors.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('演员',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        SizedBox(
                          height: 110,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: d.actors.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: ActorCard(
                                actor: d.actors[i],
                                onTap: () => context
                                    .go('/actor/${d.actors[i].id}'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 剧照
                if (d.screenshots.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('剧照',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: d.screenshots.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 160,
                                  child: CachedImage(
                                      d.screenshots[i]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // TA还出演过
                if (provider.actorOtherMovies.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('TA还出演过',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                provider.actorOtherMovies.length,
                            itemBuilder: (_, i) => SizedBox(
                              width: 130,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4),
                                child: MovieCard(
                                  movie: provider
                                      .actorOtherMovies[i],
                                  onTap: () => context.go(
                                      '/movie/${provider.actorOtherMovies[i].id}'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 你可能也喜欢
                if (provider.mayAlsoLike.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('你可能也喜欢',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                provider.mayAlsoLike.length,
                            itemBuilder: (_, i) => SizedBox(
                              width: 130,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4),
                                child: MovieCard(
                                  movie: provider.mayAlsoLike[i],
                                  onTap: () => context.go(
                                      '/movie/${provider.mayAlsoLike[i].id}'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: 60)),
              ],
            ),
            bottomSheet: DraggableScrollableSheet(
              initialChildSize: 0.06,
              minChildSize: 0.06,
              maxChildSize: 0.5,
              builder: (_, scroll) => Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    height: 4,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: '磁链'),
                              Tab(text: '短评'),
                              Tab(text: '清单'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // 磁链 Tab
                                _buildMagnetTab(provider),
                                // 短评 Tab
                                _buildReviewTab(provider),
                                // 清单 Tab
                                _buildListTab(provider),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMagnetTab(MovieDetailProvider provider) {
    final magnets = provider.magnets;
    if (magnets.isEmpty) {
      return const Center(child: Text('暂无磁链'));
    }
    return RefreshIndicator(
      onRefresh: () => provider.refreshMagnets(),
      child: ListView.builder(
        itemCount: magnets.length,
        itemBuilder: (_, i) {
          final m = magnets[i];
          return ListTile(
            leading: m.isHighDefinition
                ? Chip(
                    label: const Text('HD',
                        style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.amber.shade100,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
            title: Text(
              m.title ?? m.hash,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text([
              if (m.size != null) m.size!,
              if (m.publishDate != null) m.publishDate!,
            ].join('  ')),
            trailing: const Icon(Icons.copy, size: 18),
            onTap: () {
              Clipboard.setData(ClipboardData(text: m.hash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('磁链已复制')),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReviewTab(MovieDetailProvider provider) {
    final reviews = provider.reviews;
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${reviews.length} 条短评',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: () =>
                    _showReviewComposer(context, provider),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('写短评'),
              ),
            ],
          ),
        ),
        Expanded(
          child: reviews.isEmpty
              ? const Center(child: Text('暂无短评'))
              : RefreshIndicator(
                  onRefresh: () => provider.refreshReviews(),
                  child: ListView.builder(
                    itemCount: reviews.length,
                    itemBuilder: (_, i) {
                      final r = reviews[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            '${r.score ?? '?'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          r.content ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          r.author?.name ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildListTab(MovieDetailProvider provider) {
    final lists = provider.relatedLists;
    if (lists.isEmpty) {
      return const Center(child: Text('暂无相关清单'));
    }
    return RefreshIndicator(
      onRefresh: () => provider.refreshRelatedLists(),
      child: ListView.builder(
        itemCount: lists.length,
        itemBuilder: (_, i) {
          final lm = lists[i];
          return ListTile(
            leading: const Icon(Icons.list_alt),
            title: Text(lm.name),
            subtitle:
                Text('${lm.movieCount} 部影片  ${lm.viewedCount} 人看过'),
            onTap: () => context.go('/list/${lm.id}'),
          );
        },
      ),
    );
  }
}
```

#### `test/features/movie_detail/screens/movie_detail_screen_test.dart`（最终整理版，替换整个文件）

由于 Task 3/4/5 中逐步追加了测试用例，最终整理版将所有用例合并——仅当需要替换时才执行。每个 Task 独立完成时不需回到此文件替换，只需追加即可。

### 终端命令

```bash
# 1. 运行全部 widget test
flutter test test/features/movie_detail/screens/movie_detail_screen_test.dart
# 预期：All tests passed!

# 2. 运行全部 movie_detail 相关测试
flutter test test/features/movie_detail/
# 预期：All tests passed!

# 3. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/movie_detail/screens/movie_detail_screen.dart lib/features/movie_detail/providers/movie_detail_provider.dart lib/features/movie_detail/services/movie_detail_service.dart lib/features/movie_detail/index.dart test/features/movie_detail/
git commit -m "$(cat <<'EOF'
feat(movie_detail): complete refactor with Provider, all buttons, screenshots, actor movies, bottom drawer tabs
EOF
)"
```

---

## 依赖关系与执行顺序

```
Task 1 (Service) ──┐
                   ├──> Task 3 (信息卡) ──┐
                   │                      ├──> Task 6 (重构完成)
Task 2 (Provider) ─┘                      │
                   ┌──> Task 4 (剧照+TA) ─┘
                   │
                   └──> Task 5 (底部抽屉)
```

- Task 1 和 Task 2 可并行执行。
- Task 3、4、5 依赖 Task 1+2 完成后才可开始，但它们之间可并行。
- Task 6 依赖 Task 3+4+5 完成（需要整合所有改动）。

---

## 验证检查项

- [ ] `flutter analyze lib/features/movie_detail/` 无 error
- [ ] `flutter test test/features/movie_detail/` 全部 PASS
- [ ] `flutter test` 全项目无回归
- [ ] 详情页顶部标题超长省略
- [ ] 封面大图正常加载
- [ ] 信息卡显示番号/日期/时长/导演/片商/系列/评分
- [ ] 想看/看过/存入清单 按钮可点击并调用 API
- [ ] 类别 TagChip 横滚
- [ ] 演员 ActorCard 横向列表可点击跳转
- [ ] 剧照横向滚轮正常渲染
- [ ] TA还出演过 横向 MovieCard 可点击跳转
- [ ] 你可能也喜欢 横向 MovieCard 可点击跳转
- [ ] 底部抽屉磁链 Tab：列表渲染、HD 标显示、点击复制
- [ ] 底部抽屉短评 Tab：列表渲染、撰写入口弹出、提交后刷新
- [ ] 底部抽屉清单 Tab：列表渲染、点击跳转
- [ ] 详情接口失败显示 ErrorRetryWidget + 重试
- [ ] 子模块失败各自降级（不阻塞其他区域）
