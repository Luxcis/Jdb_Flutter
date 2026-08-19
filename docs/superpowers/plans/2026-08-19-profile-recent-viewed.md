# 我的-近期浏览页面实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现「我的-近期浏览」页面：三列 `MovieCard` 宫格 + 自动分页加载 + 顶部删除按钮（确认后清空并刷新）。

**架构：** 新增 `RecentViewedDataSource` 抽象接口 + `RecentViewedService` API 实现（复用 `apiPageResult` 满页推断），新增 `ProfileRecentViewedPage` 页面（持有 `PaginationController` + 复用 `MovieGridView`），修改 `/profile/recent` 路由指向新页面。

**技术栈：** Flutter、provider（`AuthProvider`）、go_router、dio、`package:json_annotation`（模型复用现有 `MovieSummary`）、flutter_test。

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 创建 | `lib/features/profile/services/recent_viewed_service.dart` | 近期浏览数据源抽象 + API 实现（分页查询 + 清空） |
| 创建 | `lib/features/profile/screens/profile_recent_viewed_page.dart` | 页面：AppBar（删除按钮）+ `MovieGridView` 三列宫格 |
| 修改 | `lib/features/profile/index.dart` | 导出新增的两个文件 |
| 修改 | `lib/core/router/app_router.dart:317-323` | `/profile/recent` 的 child 改为 `ProfileRecentViewedPage()` |
| 创建 | `test/features/profile/recent_viewed_service_test.dart` | service 单测（fake adapter） |
| 创建 | `test/features/profile/profile_recent_viewed_page_test.dart` | 页面 widget 测试（fake 数据源） |

> 复用现有：`Endpoints.usersRecentViewed`（endpoints.dart 第 35 行）、`MovieGridView`、`PaginationController`、`apiPageResult`、`normalizeMovieSummaryJson`、`MovieSummary`、`LoginGuideCard`、`_AuthGuard`。不新增依赖。

---

### 任务 1：Service —— 分页查询与清空

**文件：**
- 创建：`lib/features/profile/services/recent_viewed_service.dart`
- 测试：`test/features/profile/recent_viewed_service_test.dart`

- [ ] **步骤 1：编写失败的 service 测试**

创建 `test/features/profile/recent_viewed_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/recent_viewed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getRecentViewed 发送 page 与 limit=48 查询参数', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': {'movies': [], 'current_page': 1},
    });

    await fixture.service.getRecentViewed(page: 2);

    expect(fixture.adapter.requests.single.path, Endpoints.usersRecentViewed);
    expect(fixture.adapter.requests.single.queryParameters, {
      'page': 2,
      'limit': 48,
    });
  });

  test('getRecentViewed 解析 movies 并保留影片摘要字段', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'm1',
            'number': 'SSIS-001',
            'title': '测试影片',
            'thumb_url': 'thumb.jpg',
            'cover_url': 'cover.jpg',
            'release_date': '2026-08-01',
          },
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getRecentViewed();

    expect(result.items.single.id, 'm1');
    expect(result.items.single.number, 'SSIS-001');
    expect(result.items.single.thumbUrl, 'thumb.jpg');
    expect(result.currentPage, 1);
  });

  test('getRecentViewed 缺少 total_pages 时以 48 条为满页阈值', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': {
        'movies': [
          for (var index = 0; index < 48; index++)
            {
              'id': 'm$index',
              'number': 'N$index',
              'title': '影片 $index',
              'cover_url': '',
            },
        ],
        'current_page': 1,
      },
    });
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': {
        'movies': [
          {'id': 'm48', 'number': 'N48', 'title': '影片 48', 'cover_url': ''},
        ],
        'current_page': 2,
      },
    });

    final fullPage = await fixture.service.getRecentViewed();
    final partialPage = await fixture.service.getRecentViewed(page: 2);

    expect(fullPage.totalPages, 2);
    expect(partialPage.totalPages, 2);
  });

  test('clearRecentViewed 发送 DELETE 请求', () async {
    final fixture = await _buildFixture();
    // FakeAdapter 按 path 匹配、不区分 method；DELETE 响应同样入队。
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': null,
    });

    await fixture.service.clearRecentViewed();

    final request = fixture.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, Endpoints.usersRecentViewed);
  });
}

Future<({FakeAdapter adapter, RecentViewedService service})>
_buildFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: RecentViewedService(api));
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/features/profile/recent_viewed_service_test.dart`
预期：FAIL（`RecentViewedService` 未定义，编译错误）。

- [ ] **步骤 3：创建 service 实现**

创建 `lib/features/profile/services/recent_viewed_service.dart`：

```dart
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

/// 近期浏览数据源抽象，便于测试注入。
abstract interface class RecentViewedDataSource {
  /// 取得一页近期浏览影片；[page] 从 1 开始计数。
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1});

  /// 清空当前用户的全部近期浏览记录。
  Future<void> clearRecentViewed();
}

/// 基于 API 客户端的近期浏览数据源实现。
class RecentViewedService implements RecentViewedDataSource {
  /// 创建使用给定 API 客户端请求近期浏览的数据源。
  RecentViewedService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  /// 从 API 取得一页近期浏览影片。
  @override
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1}) async {
    final response = await _api.get(
      Endpoints.usersRecentViewed,
      queryParameters: {'page': page, 'limit': _pageSize},
    );
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) =>
          MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }

  /// 清空当前用户的全部近期浏览记录。
  @override
  Future<void> clearRecentViewed() async {
    await _api.delete(Endpoints.usersRecentViewed);
  }
}

/// 在 API 客户端不可用时返回空分页结果、清空为空操作的数据源。
class UnavailableRecentViewedDataSource implements RecentViewedDataSource {
  /// 创建不发起网络请求的空数据源。
  const UnavailableRecentViewedDataSource();

  /// 返回指定页码的空影片结果。
  @override
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1}) async =>
      PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);

  /// 不发起请求的空清空操作。
  @override
  Future<void> clearRecentViewed() async {}
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/features/profile/recent_viewed_service_test.dart`
预期：PASS（4 个测试全过）。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/services/recent_viewed_service.dart test/features/profile/recent_viewed_service_test.dart
git commit -m "feat(profile): add recent viewed service"
```

---

### 任务 2：页面 —— ProfileRecentViewedPage

**文件：**
- 创建：`lib/features/profile/screens/profile_recent_viewed_page.dart`
- 修改：`lib/features/profile/index.dart`
- 测试：`test/features/profile/profile_recent_viewed_page_test.dart`

- [ ] **步骤 1：编写失败的 widget 测试**

创建 `test/features/profile/profile_recent_viewed_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/profile/screens/profile_recent_viewed_page.dart';
import 'package:jade/features/profile/services/recent_viewed_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecentViewedSource implements RecentViewedDataSource {
  _FakeRecentViewedSource({this.multiplePages = false});

  final bool multiplePages;
  int pageRequests = 0;
  int clearCalls = 0;

  @override
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1}) async {
    pageRequests++;
    final itemCount = multiplePages && page == 1 ? 48 : 1;
    return PagedResult(
      items: [
        for (var index = 0; index < itemCount; index++)
          MovieSummary(
            id: 'm$page-$index',
            number: 'N-$page-$index',
            title: '影片 $page-$index',
            coverUrl: '',
          ),
      ],
      currentPage: page,
      totalPages: multiplePages ? 2 : 1,
      total: multiplePages ? 49 : 1,
    );
  }

  @override
  Future<void> clearRecentViewed() async {
    clearCalls++;
  }
}

Future<_FakeRecentViewedSource> _pumpPage(
  WidgetTester tester, {
  bool multiplePages = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  await auth.login(token: 'token', user: {'id': 1, 'username': 'tester'});
  final source = _FakeRecentViewedSource(multiplePages: multiplePages);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: ProfileRecentViewedPage(dataSource: source),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return source;
}

void main() {
  testWidgets('加载后显示标题删除按钮与三列 MovieCard 宫格', (tester) async {
    final source = await _pumpPage(tester);

    expect(find.text('近期浏览'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byType(MovieGridView), findsOneWidget);
    expect(find.byType(MovieCard), findsOneWidget);
    expect(source.pageRequests, 1);
  });

  testWidgets('点删除后取消不调用清空接口', (tester) async {
    final source = await _pumpPage(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('清空近期浏览？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.clearCalls, 0);
    expect(find.text('近期浏览'), findsOneWidget);
  });

  testWidgets('点删除确认后调用清空接口并刷新为空态', (tester) async {
    final source = await _pumpPage(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(source.clearCalls, 1);
    // 刷新后空态 + SnackBar
    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.text('已清空近期浏览'), findsOneWidget);
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/features/profile/profile_recent_viewed_page_test.dart`
预期：FAIL（`ProfileRecentViewedPage` 未定义）。

- [ ] **步骤 3：创建页面实现**

创建 `lib/features/profile/screens/profile_recent_viewed_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/recent_viewed_service.dart';
import 'package:provider/provider.dart';

/// 展示当前用户近期浏览影片的页面。
///
/// 三列 `MovieCard` 宫格，自动分页加载；AppBar 右侧删除按钮可清空全部记录。
/// 可通过 [dataSource] 注入数据源以复用页面或替换默认 API 实现。
class ProfileRecentViewedPage extends StatefulWidget {
  /// 创建使用可选 [dataSource] 的近期浏览页面。
  const ProfileRecentViewedPage({super.key, this.dataSource});

  /// 可选的近期浏览数据源；未提供时使用默认 API 数据源。
  final RecentViewedDataSource? dataSource;

  @override
  State<ProfileRecentViewedPage> createState() =>
      _ProfileRecentViewedPageState();
}

class _ProfileRecentViewedPageState extends State<ProfileRecentViewedPage> {
  late final RecentViewedDataSource _dataSource;
  late final PaginationController<MovieSummary> _controller;
  var _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableRecentViewedDataSource()
            : RecentViewedService(api));
    _controller = PaginationController(fetch: _fetchPage)..fetchMore();
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) =>
      _dataSource.getRecentViewed(page: page);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLogged = context.watch<AuthProvider>().isLogged;
    if (isLogged && !_wasLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.read<AuthProvider>().isLogged) return;
        _controller.reloadWith(_fetchPage);
      });
    }
    _wasLoggedIn = isLogged;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmAndClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空近期浏览？'),
        content: const Text('将删除全部浏览记录，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _dataSource.clearRecentViewed();
      if (!mounted) return;
      _controller.reloadWith(_fetchPage);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空近期浏览')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('清空失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogged = context.watch<AuthProvider>().isLogged;
    return Scaffold(
      appBar: AppBar(
        title: const Text('近期浏览'),
        actions: [
          IconButton(
            tooltip: '清空近期浏览',
            onPressed: _confirmAndClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: isLogged
          ? MovieGridView(controller: _controller)
          : const LoginGuideCard(
              message: '登录后查看近期浏览',
              loginPath: '/profile/recent',
            ),
    );
  }
}
```

- [ ] **步骤 4：在 index.dart 导出新文件**

修改 `lib/features/profile/index.dart`，在末尾追加：

```dart
export 'screens/profile_recent_viewed_page.dart';
export 'services/recent_viewed_service.dart';
```

- [ ] **步骤 5：运行测试确认通过**

运行：`flutter test test/features/profile/profile_recent_viewed_page_test.dart`
预期：PASS（3 个测试全过）。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/profile/screens/profile_recent_viewed_page.dart lib/features/profile/index.dart test/features/profile/profile_recent_viewed_page_test.dart
git commit -m "feat(profile): add recent viewed page with clear action"
```

---

### 任务 3：路由接入

**文件：**
- 修改：`lib/core/router/app_router.dart:317-323`

- [ ] **步骤 1：修改路由指向新页面**

在 `lib/core/router/app_router.dart` 中，将 `/profile/recent` 路由的 `child` 从：

```dart
child: const ProfileMovieCollectionPage(title: '近期浏览'),
```

改为：

```dart
child: const ProfileRecentViewedPage(),
```

- [ ] **步骤 2：补充路由正向断言**

在 `test/core/router/app_router_requirements_test.dart` 的 `main()` 末尾追加一个测试：

```dart
testWidgets('近期浏览路由渲染真实近期浏览页', (tester) async {
  await tester.pumpWidget(
    await _buildApp(initialLocation: '/profile/recent'),
  );
  await tester.pump();

  expect(find.byType(ProfileRecentViewedPage), findsOneWidget);
  expect(find.text('近期浏览'), findsOneWidget);
  expect(find.byIcon(Icons.delete_outline), findsOneWidget);
});
```

> 该测试通过 `AppRouter.buildForTest`（无 redirect）渲染路由；未登录时页面由 `AuthProvider` watch 显示 `LoginGuideCard`，但 AppBar 标题与删除按钮仍存在，断言成立。运行前需确认 `find.byIcon(Icons.delete_outline)` 在未登录态仍能找到（AppBar 常驻）。

- [ ] **步骤 3：运行路由测试**

运行：`flutter test test/core/router/app_router_test.dart test/core/router/app_router_auth_test.dart test/core/router/app_router_requirements_test.dart`
预期：PASS（新增断言通过，原有断言不受影响——`ProfileMovieCollectionPage` 仅用于 `/profile/want-watch` 的 findsNothing 断言，与 `/profile/recent` 无关）。

- [ ] **步骤 4：运行全部 profile 相关测试**

运行：`flutter test test/features/profile test/core/router`
预期：PASS。

- [ ] **步骤 4：静态分析**

运行：`flutter analyze`
预期：No issues found。

- [ ] **步骤 5：Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(profile): wire recent viewed route to new page"
```

---

## 自检清单

**规格覆盖度：**

- [x] 三列宫格 MovieCard → 任务 2（`MovieGridView` 默认 `crossAxisCount: 3`）
- [x] 自动分页加载 → 任务 1（`apiPageResult` 满页推断）+ 任务 2（`PaginationController.fetchMore` 由 `MovieGridView` 滚动触发）
- [x] 顶部导航栏右侧删除按钮 → 任务 2（`actions: IconButton`）
- [x] 点击弹窗确认清空 → 任务 2（`showDialog` AlertDialog）
- [x] 确认后 DELETE 调用 → 任务 1（`clearRecentViewed` 发 DELETE）
- [x] 清空后刷新列表 → 任务 2（`_controller.reloadWith` + SnackBar）
- [x] 登录守卫 → 任务 2（`AuthProvider` watch + `LoginGuideCard`；路由已有 `_AuthGuard`）
- [x] 错误处理 → `MovieGridView` 现有错误/重试 + 清空失败 SnackBar（任务 2）
- [x] 测试 → 任务 1 service 单测 + 任务 2 widget 测试

**占位符扫描：** 无 "待定/TODO/后续实现/适当错误处理" 类占位；所有代码步骤含完整代码。

**类型一致性：** `RecentViewedDataSource.getRecentViewed({int page})` / `clearRecentViewed()` 在任务 1 定义、任务 2 页面与测试中签名一致；`ProfileRecentViewedPage(dataSource: ...)` 构造参数与页面一致；`UnavailableRecentViewedDataSource` 在任务 2 步骤 3 使用、需在任务 1 的 service 文件中定义（见下方补充）。
