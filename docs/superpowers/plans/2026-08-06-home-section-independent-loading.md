# 首页分区独立加载实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 取消首页整页 loading/error，让“佳片推荐”“最新上架”“近期磁链更新”三个分区各自独立加载、独立 loading 占位、独立失败重试。

**Architecture:** `HomeProvider` 用 `HomeSection`（items/isLoading/error）分别跟踪三个分区，`loadAll` 并发发起三个分区请求但互不等待；`HomePage` 始终渲染搜索栏/豆腐块/分区标题，按分区状态渲染占位、错误重试或内容。`HomeService` 接口不变。

**Tech Stack:** Flutter / Dart 3 pattern matching / ChangeNotifier / Flutter widget tests

## Global Constraints

- 不新增依赖；不修改路由目标；不调整 `TofuScroll`、`SectionHeader`、`MovieCard` 视觉。
- 换一组请求参数保持不变：`/api/v1/movies/latest`，`type=all`，`sort_by=update`，`order_by=desc`，`limit=9`；最新上架 `filter_by=can_play`，磁链更新 `filter_by=magnets`；page 独立递增。
- 换一组失败语义不变：保留当前页码与影片，SnackBar 提示“换一组失败，请重试”，不写入分区 error。
- 文案直接中文硬编码（佳片推荐/最新上架/近期磁链更新/换一组/重试/暂无数据）。
- 空列表是成功响应，显示现有 `EmptyState`。
- 改完运行 `dart format` 格式化相关文件。

---

### Task 1: HomeProvider 分区独立状态

**Files:**
- Modify: `lib/features/home/providers/home_provider.dart`（整文件替换）
- Modify: `test/features/home/home_provider_test.dart`（整文件替换）

**Interfaces:**
- Consumes: `HomeService.getRecommends({String? period})`、`getLatest({int page, int limit})`、`getMagnetUpdates({int page, int limit})`，均返回 `Future<List<MovieSummary>>`。
- Produces（Task 2 依赖的精确签名）:
  - `enum HomeSectionKind { recommends, latest, magnets }`
  - `class HomeSection { final List<MovieSummary> items; final bool isLoading; final String? error; bool get isEmpty; HomeSection startLoading(); HomeSection fail(Object error); }`
  - `HomeProvider.recommends / latest / magnetUpdates` → `HomeSection`
  - `HomeProvider.loadAll()` → `Future<void>`
  - `HomeProvider.retrySection(HomeSectionKind)` → `Future<void>`
  - `HomeProvider.loadSection(HomeSectionKind)` → `Future<void>`
  - `isLatestRefreshing / isMagnetRefreshing / latestPage / magnetPage / reshuffleLatest() / reshuffleMagnets()` 保持原签名

- [ ] **Step 1: 重写测试，先验证新行为（含失败用例）**

将 `test/features/home/home_provider_test.dart` 整文件替换为：

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/providers/home_provider.dart';
import 'package:jade/features/home/services/home_service.dart';

const _recommend = MovieSummary(
  id: 'recommend',
  number: 'R-1',
  title: 'Recommend',
  coverUrl: 'recommend.jpg',
);

MovieSummary _movie(String id) =>
    MovieSummary(id: id, number: id, title: id, coverUrl: '$id.jpg');

class _FakeHomeService implements HomeService {
  final latestPages = <int>[];
  final magnetPages = <int>[];
  int recommendCalls = 0;
  Object? recommendError;
  Object? latestError;
  Object? magnetError;
  Completer<void>? latestGate;

  @override
  Future<List<MovieSummary>> getRecommends({String? period}) async {
    recommendCalls++;
    if (recommendError case final error?) throw error;
    return const [_recommend];
  }

  @override
  Future<List<String>> getRecommendPeriods() async => const [];

  @override
  Future<List<MovieSummary>> getLatest({int page = 1, int limit = 9}) async {
    latestPages.add(page);
    if (latestGate case final gate?) await gate.future;
    if (latestError case final error?) throw error;
    return [_movie('latest-$page')];
  }

  @override
  Future<List<MovieSummary>> getMagnetUpdates({
    int page = 1,
    int limit = 9,
  }) async {
    magnetPages.add(page);
    if (magnetError case final error?) throw error;
    return [_movie('magnet-$page')];
  }
}

void main() {
  test('两个首页分区从第 1 页开始并独立递增', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);

    await provider.loadAll();
    await provider.reshuffleLatest();
    await provider.reshuffleLatest();
    await provider.reshuffleMagnets();

    expect(service.latestPages, [1, 2, 3]);
    expect(service.magnetPages, [1, 2]);
    expect(provider.latestPage, 3);
    expect(provider.magnetPage, 2);
    expect(provider.latest.items.single.id, 'latest-3');
    expect(provider.magnetUpdates.items.single.id, 'magnet-2');
  });

  test('最新上架换组加载期间阻止重复请求', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    await provider.loadAll();
    service.latestGate = Completer<void>();

    final first = provider.reshuffleLatest();
    final duplicate = provider.reshuffleLatest();

    expect(provider.isLatestRefreshing, isTrue);
    expect(service.latestPages, [1, 2]);
    service.latestGate!.complete();
    await Future.wait([first, duplicate]);
    expect(provider.isLatestRefreshing, isFalse);
  });

  test('换组失败保留当前页和影片并允许重试同一下一页', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    await provider.loadAll();
    service.latestError = StateError('network');

    await expectLater(provider.reshuffleLatest(), throwsStateError);

    expect(provider.latestPage, 1);
    expect(provider.latest.items.single.id, 'latest-1');
    service.latestError = null;
    await provider.reshuffleLatest();
    expect(service.latestPages, [1, 2, 2]);
    expect(provider.latestPage, 2);
  });

  test('三个分区独立加载，一个挂起不影响其它分区', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.latestGate = Completer<void>();

    final load = provider.loadAll();
    await Future<void>.delayed(Duration.zero);

    expect(provider.recommends.isLoading, isFalse);
    expect(provider.recommends.items.single.id, 'recommend');
    expect(provider.latest.isLoading, isTrue);
    expect(provider.latest.error, isNull);
    expect(provider.magnetUpdates.isLoading, isFalse);
    expect(provider.magnetUpdates.items.single.id, 'magnet-1');

    service.latestGate!.complete();
    await load;
    expect(provider.latest.isLoading, isFalse);
    expect(provider.latest.items.single.id, 'latest-1');
  });

  test('单分区首次加载失败不影响其它分区', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.latestError = StateError('network');

    await provider.loadAll();

    expect(provider.latest.isLoading, isFalse);
    expect(provider.latest.error, isNotNull);
    expect(provider.latest.items, isEmpty);
    expect(provider.recommends.items.single.id, 'recommend');
    expect(provider.magnetUpdates.items.single.id, 'magnet-1');
  });

  test('retrySection 只重发失败分区并清除错误', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.latestError = StateError('network');
    await provider.loadAll();
    expect(provider.latest.error, isNotNull);

    service.latestError = null;
    await provider.retrySection(HomeSectionKind.latest);

    expect(provider.latest.error, isNull);
    expect(provider.latest.items.single.id, 'latest-1');
    expect(service.latestPages, [1, 1]);
    expect(service.magnetPages, [1]);
    expect(provider.latestPage, 1);
  });

  test('重试推荐分区只重新请求推荐接口', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.recommendError = StateError('network');
    await provider.loadAll();
    expect(provider.recommends.error, isNotNull);

    service.recommendError = null;
    await provider.retrySection(HomeSectionKind.recommends);

    expect(provider.recommends.error, isNull);
    expect(provider.recommends.items.single.id, 'recommend');
    expect(service.recommendCalls, 2);
    expect(service.latestPages, [1]);
    expect(service.magnetPages, [1]);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/home_provider_test.dart`
Expected: FAIL——`HomeSection`/`HomeSectionKind` 未定义、`provider.latest` 类型仍为 `List<MovieSummary>`（编译错误）。

- [ ] **Step 3: 实现分区独立状态**

将 `lib/features/home/providers/home_provider.dart` 整文件替换为：

```dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/services/home_service.dart';

/// 首页分区标识。
enum HomeSectionKind { recommends, latest, magnets }

/// 单个分区的数据与加载状态。
@immutable
class HomeSection {
  const HomeSection({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<MovieSummary> items;
  final bool isLoading;
  final String? error;

  /// 标记分区开始加载（保留旧数据，清除错误）。
  HomeSection startLoading() => HomeSection(items: items, isLoading: true);

  /// 标记分区加载失败（保留旧数据，记录错误信息）。
  HomeSection fail(Object error) => HomeSection(items: items, error: error.toString());

  bool get isEmpty => items.isEmpty;
}

class HomeProvider extends ChangeNotifier {
  HomeProvider(this._service);

  final HomeService _service;

  HomeSection _recommends = const HomeSection();
  HomeSection _latest = const HomeSection();
  HomeSection _magnetUpdates = const HomeSection();
  bool _isLatestRefreshing = false;
  bool _isMagnetRefreshing = false;
  int _latestPage = 1;
  int _magnetPage = 1;

  HomeSection get recommends => _recommends;
  HomeSection get latest => _latest;
  HomeSection get magnetUpdates => _magnetUpdates;
  bool get isLatestRefreshing => _isLatestRefreshing;
  bool get isMagnetRefreshing => _isMagnetRefreshing;
  int get latestPage => _latestPage;
  int get magnetPage => _magnetPage;

  /// 并发加载三个分区，各自独立成功或失败。
  Future<void> loadAll() async {
    await Future.wait([
      loadSection(HomeSectionKind.recommends),
      loadSection(HomeSectionKind.latest),
      loadSection(HomeSectionKind.magnets),
    ]);
  }

  /// 仅重试指定分区的第 1 页请求；加载中则忽略。
  Future<void> retrySection(HomeSectionKind kind) async {
    if (_sectionOf(kind).isLoading) return;
    await loadSection(kind);
  }

  Future<void> loadSection(HomeSectionKind kind) async {
    _setSection(kind, _sectionOf(kind).startLoading());
    try {
      final items = switch (kind) {
        HomeSectionKind.recommends => await _service.getRecommends(),
        HomeSectionKind.latest => await _service.getLatest(page: 1),
        HomeSectionKind.magnets => await _service.getMagnetUpdates(page: 1),
      };
      if (kind == HomeSectionKind.latest) _latestPage = 1;
      if (kind == HomeSectionKind.magnets) _magnetPage = 1;
      _setSection(kind, HomeSection(items: items));
    } catch (e) {
      _setSection(kind, _sectionOf(kind).fail(e));
    }
  }

  HomeSection _sectionOf(HomeSectionKind kind) => switch (kind) {
        HomeSectionKind.recommends => _recommends,
        HomeSectionKind.latest => _latest,
        HomeSectionKind.magnets => _magnetUpdates,
      };

  void _setSection(HomeSectionKind kind, HomeSection section) {
    switch (kind) {
      case HomeSectionKind.recommends:
        _recommends = section;
      case HomeSectionKind.latest:
        _latest = section;
      case HomeSectionKind.magnets:
        _magnetUpdates = section;
    }
    notifyListeners();
  }

  Future<void> reshuffleLatest() async {
    if (_isLatestRefreshing) return;
    _isLatestRefreshing = true;
    notifyListeners();
    final nextPage = _latestPage + 1;
    try {
      final movies = await _service.getLatest(page: nextPage);
      _latest = HomeSection(items: movies);
      _latestPage = nextPage;
    } finally {
      _isLatestRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> reshuffleMagnets() async {
    if (_isMagnetRefreshing) return;
    _isMagnetRefreshing = true;
    notifyListeners();
    final nextPage = _magnetPage + 1;
    try {
      final movies = await _service.getMagnetUpdates(page: nextPage);
      _magnetUpdates = HomeSection(items: movies);
      _magnetPage = nextPage;
    } finally {
      _isMagnetRefreshing = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/home/home_provider_test.dart`
Expected: PASS（7 个用例）

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/providers/home_provider.dart test/features/home/home_provider_test.dart
git commit -m "feat(home): track per-section home loading state"
```

---

### Task 2: HomePage 分区级渲染

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`（整文件替换）
- Modify: `test/features/home/home_screen_test.dart`（`_pumpHome` 改造 + 新增 3 个用例）

**Interfaces:**
- Consumes: Task 1 产出的 `HomeSection`/`HomeSectionKind`/`HomeProvider`（签名见 Task 1）。
- Produces: `HomePage` 行为契约——首屏搜索栏/豆腐块/三个分区标题立即可见；分区加载中显示固定高度占位转圈（推荐区 220，网格区 640）；分区失败显示分区内错误与“重试”；点击重试只重发该分区；换一组行为不变。

- [ ] **Step 1: 改造 Widget 测试，先写失败用例**

在 `test/features/home/home_screen_test.dart` 中：

1) 将 `_pumpHome` 改造为支持延迟与响应序列（替换原 `_pumpHome` 函数）：

```dart
Future<FakeAdapter> _pumpHome(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  List<Map<String, dynamic>>? latestBodies,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'key_baseurl': 'https://jdforrepam.com',
    'key_api_domains': ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: auth.logout,
  );
  final adapter = FakeAdapter()..responseDelay = responseDelay;
  api.setAdapterForTest(adapter);
  adapter.enqueue(Endpoints.moviesRecommend, {
    'success': 1,
    'data': {
      'movies': [
        {
          'id': 'recommend',
          'number': 'R-1',
          'title': 'Recommend',
          'cover_url': 'recommend.jpg',
        },
      ],
    },
  });
  if (latestBodies != null) {
    adapter.enqueueSequence(Endpoints.moviesLatest, latestBodies);
  } else {
    adapter.enqueue(Endpoints.moviesLatest, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'home-movie',
            'number': 'H-1',
            'title': 'Home Movie',
            'cover_url': 'home.jpg',
          },
        ],
      },
    });
  }

  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  return adapter;
}
```

2) 在 `main()` 末尾追加 3 个新用例：

```dart
testWidgets('首屏立即显示搜索栏、豆腐块与分区标题，不整页转圈', (tester) async {
  await _pumpHome(tester, responseDelay: const Duration(milliseconds: 300));

  expect(find.byType(HomeSearchBar), findsOneWidget);
  expect(find.byType(TofuScroll), findsOneWidget);
  expect(find.text('佳片推荐'), findsOneWidget);
  expect(find.text('最新上架'), findsOneWidget);
  expect(find.text('近期磁链更新'), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNWidgets(3));

  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsNothing);
});

testWidgets('最新上架分区失败显示分区错误与重试，其余分区正常', (tester) async {
  await _pumpHome(tester, latestBodies: [
    {'success': 0, 'message': 'network'},
    {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'home-movie',
            'number': 'H-1',
            'title': 'Home Movie',
            'cover_url': 'home.jpg',
          },
        ],
      },
    },
  ]);

  expect(find.text('最新上架'), findsOneWidget);
  expect(find.text('近期磁链更新'), findsOneWidget);
  expect(find.text('重试'), findsOneWidget);
  expect(find.text('Home Movie'), findsWidgets);
  expect(find.text('Recommend'), findsOneWidget);
});

testWidgets('点击分区重试仅重发失败分区并恢复', (tester) async {
  final adapter = await _pumpHome(tester, latestBodies: [
    {'success': 0, 'message': 'network'},
    {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'home-movie',
            'number': 'H-1',
            'title': 'Home Movie',
            'cover_url': 'home.jpg',
          },
        ],
      },
    },
    {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'home-movie',
            'number': 'H-1',
            'title': 'Home Movie',
            'cover_url': 'home.jpg',
          },
        ],
      },
    },
  ]);
  expect(find.text('重试'), findsOneWidget);

  await tester.tap(find.text('重试'));
  await _pumpRequest(tester);

  expect(find.text('重试'), findsNothing);
  expect(find.text('Home Movie'), findsWidgets);
  final recommendRequests = adapter.requests
      .where((r) => r.path == Endpoints.moviesRecommend)
      .length;
  expect(recommendRequests, 1);
});
```

说明：`enqueueSequence(Endpoints.moviesLatest, ...)` 按请求发起顺序弹出——`loadAll` 中最新上架先于磁链更新发起，因此序列第 1 项对应最新上架。若该用例因顺序不稳定失败，改用 `adapter.responseDelay = Duration(milliseconds: 1)` 隔离请求后重跑（实施时验证）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/home_screen_test.dart`
Expected: FAIL——旧页面整页转圈/整页错误，新用例断言（3 个占位、分区错误与 Home Movie 并存）不满足。

- [ ] **Step 3: 实现分区级渲染**

将 `lib/features/home/screens/home_screen.dart` 整文件替换为：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/features/home/providers/home_provider.dart';
import 'package:jade/features/home/services/home_service.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    final provider = HomeProvider(HomeService(api));
    setState(() => _provider = provider);
    for (final kind in HomeSectionKind.values) {
      provider.loadSection(kind).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _retrySection(HomeSectionKind kind) async {
    final provider = _provider;
    if (provider == null) return;
    setState(() {});
    await provider.retrySection(kind);
    if (mounted) setState(() {});
  }

  Future<void> _refreshLatest() async {
    final provider = _provider;
    if (provider == null || provider.isLatestRefreshing) return;
    final refresh = provider.reshuffleLatest();
    setState(() {});
    try {
      await refresh;
    } catch (_) {
      if (mounted) _showRefreshError();
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshMagnets() async {
    final provider = _provider;
    if (provider == null || provider.isMagnetRefreshing) return;
    final refresh = provider.reshuffleMagnets();
    setState(() {});
    try {
      await refresh;
    } catch (_) {
      if (mounted) _showRefreshError();
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _showRefreshError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('换一组失败，请重试')));
  }

  @override
  Widget build(BuildContext context) {
    final p = _provider;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HomeSearchBar()),
            const SliverToBoxAdapter(child: TofuScroll()),
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: '佳片推荐',
                trailing: '往期推荐',
                bold: true,
              ),
            ),
            _recommendSection(p?.recommends),
            SliverToBoxAdapter(
              child: SectionHeader(title: '最新上架', trailing: '全部'),
            ),
            _gridSection(p?.latest, kind: HomeSectionKind.latest),
            _shuffleButton(
              key: const Key('home-latest-shuffle'),
              isLoading: p?.isLatestRefreshing ?? false,
              onPressed: _refreshLatest,
            ),
            SliverToBoxAdapter(
              child: SectionHeader(title: '近期磁链更新', trailing: '全部'),
            ),
            _gridSection(p?.magnetUpdates, kind: HomeSectionKind.magnets),
            _shuffleButton(
              key: const Key('home-magnets-shuffle'),
              isLoading: p?.isMagnetRefreshing ?? false,
              onPressed: _refreshMagnets,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendSection(HomeSection? section) {
    if (section == null || section.isLoading) {
      return _sectionLoading(height: 220);
    }
    if (section.error != null) {
      return _sectionError(
        height: 220,
        message: section.error!,
        onRetry: () => _retrySection(HomeSectionKind.recommends),
      );
    }
    if (section.isEmpty) return const SliverToBoxAdapter(child: EmptyState());
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: PageView.builder(
          itemCount: section.items.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => context.push('/movie/${section.items[i].id}'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MovieCoverImage(
                  section.items[i].coverUrl,
                  variant: MovieImageVariant.cover,
                  semanticLabel: section.items[i].title,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      section.items[i].title,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridSection(HomeSection? section, {required HomeSectionKind kind}) {
    if (section == null || section.isLoading) {
      return _sectionLoading(height: 640);
    }
    if (section.error != null) {
      return _sectionError(
        height: 640,
        message: section.error!,
        onRetry: () => _retrySection(kind),
      );
    }
    return _buildGrid(section.items);
  }

  Widget _sectionLoading({required double height}) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _sectionError({
    required double height,
    required String message,
    required VoidCallback onRetry,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: height,
        child: ErrorRetryWidget(message: message, onRetry: onRetry),
      ),
    );
  }

  Widget _buildGrid(List items) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: EmptyState());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.56,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, index) => MovieCard(movie: items[index]),
          childCount: items.length > 9 ? 9 : items.length,
        ),
      ),
    );
  }

  Widget _shuffleButton({
    required Key key,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 72,
        child: Center(
          child: TextButton(
            key: key,
            onPressed: isLoading ? null : onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                const Text('换一组'),
                if (isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.refresh),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `dart format lib/features/home/screens/home_screen.dart test/features/home/home_screen_test.dart`，然后 `flutter test test/features/home/home_screen_test.dart`
Expected: PASS（原有 6 个用例 + 新增 3 个用例）

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/screens/home_screen.dart test/features/home/home_screen_test.dart
git commit -m "feat(home): render home sections with independent loading and retry"
```

---

### Task 3: 全量验证

**Files:**
- 无新改动；仅运行验证命令。

- [ ] **Step 1: 全量单测**

Run: `flutter test test/features/home`，再 `flutter test`
Expected: 全量 PASS（原 198 个用例 + 首页新增用例）

- [ ] **Step 2: 静态分析**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: 变更检查**

Run: `git diff --check` 与 `git status --short --branch`
Expected: 无 whitespace 错误；仅本次相关文件有未提交变更（如有则仅提交相关文件）。
