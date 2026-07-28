# Home Sections and Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按参考图统一首页入口、全局分区标题和换组控件，并让首页两个影片分区通过精确的 `/api/v1/movies/latest` 参数独立请求下一页。

**Architecture:** `HomeService` 负责精确的接口查询参数，`HomeProvider` 负责两个分区各自的页码和刷新状态，`HomePage` 只编排异步交互与错误反馈。共享 `SectionHeader` 在 core 层全局更新，首页专用的入口卡片和换组按钮留在 home feature。

**Tech Stack:** Flutter, Dart, Material 3, Dio, Provider/ChangeNotifier, GoRouter, flutter_test

## Global Constraints

- 首个分区标题固定为“最新上架”。
- 最新上架请求固定使用 `type=all&filter_by=can_play&sort_by=update&order_by=desc&limit=9`。
- 近期磁链更新请求固定使用 `type=all&filter_by=magnets&sort_by=update&order_by=desc&limit=9`。
- 初始页码均为 1；点击对应“换一组”后仅该分区请求下一页。
- 不硬编码 curl 中的临时 `jdsignature`，继续由现有网络拦截器生成。
- 全局修改 `SectionHeader`，允许首页和演员页等全部现有调用同步变化。
- 不新增依赖，不修改路由目标，不修改影片卡片内容。
- 不修改已由提交 `ff236e3` 更新的 `docs/main/api/jdb_api_openapi.json`。
- 所有行为变更先写失败测试并确认 RED，再写最小实现并确认 GREEN。

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/features/home/services/home_service.dart` | Modify | 发送两个首页分区的精确 latest 请求 |
| `test/api_integration_test.dart` | Modify | 验证两个请求的完整查询参数与解析结果 |
| `lib/features/home/providers/home_provider.dart` | Modify | 管理独立页码、换组加载状态和失败回滚 |
| `test/features/home/home_provider_test.dart` | Create | 验证分页递增、互不影响和失败重试 |
| `lib/core/widgets/section_header.dart` | Modify | 全局实现加粗标题与“尾部 + 右箭头” |
| `test/core/widgets/section_header_test.dart` | Create | 验证全局标题视觉和尾部交互 |
| `lib/features/home/widgets/tofu_scroll.dart` | Modify | 实现横向彩色入口卡片 |
| `test/features/home/tofu_scroll_test.dart` | Create | 验证卡片结构、尺寸和点击路由 |
| `lib/features/home/screens/home_screen.dart` | Modify | 实现整行换组按钮、加载态和错误提示 |
| `test/features/home/home_screen_test.dart` | Modify | 验证换组控件与真实请求页码 |

## Task 1: Correct the Two Home Feed Requests

**Files:**

- Modify: `test/api_integration_test.dart`
- Modify: `lib/features/home/services/home_service.dart`

**Interfaces:**

- Produces: `HomeService.getLatest({int page = 1, int limit = 9})`
- Produces: `HomeService.getMagnetUpdates({int page = 1, int limit = 9})`
- Both return `Future<List<MovieSummary>>`

- [ ] **Step 1: Replace the loose HomeService tests with exact contract tests**

Replace the current latest and magnet-update tests in the `HomeService` group:

```dart
test('首页最新上架使用 can_play 的 latest 完整参数', () async {
  ok(adapter, Endpoints.moviesLatest, {
    'movies': [
      {'id': 'm2', 'number': 'N2', 'title': 'T2', 'cover_url': 'c2.jpg'},
    ],
  });

  final list = await svc.getLatest(page: 2);

  final request = adapter.requests.last;
  expect(request.path, Endpoints.moviesLatest);
  expect(request.uri.queryParameters, {
    'type': 'all',
    'filter_by': 'can_play',
    'sort_by': 'update',
    'order_by': 'desc',
    'limit': '9',
    'page': '2',
  });
  expect(list.single.id, 'm2');
});

test('首页近期磁链更新使用 magnets 的 latest 完整参数', () async {
  ok(adapter, Endpoints.moviesLatest, {
    'movies': [
      {'id': 'm3', 'number': 'N3', 'title': 'T3', 'cover_url': 'c3.jpg'},
    ],
  });

  final list = await svc.getMagnetUpdates(page: 3);

  final request = adapter.requests.last;
  expect(request.path, Endpoints.moviesLatest);
  expect(request.uri.queryParameters, {
    'type': 'all',
    'filter_by': 'magnets',
    'sort_by': 'update',
    'order_by': 'desc',
    'limit': '9',
    'page': '3',
  });
  expect(list.single.id, 'm3');
});
```

- [ ] **Step 2: Run both tests and confirm RED**

Run:

```bash
flutter test test/api_integration_test.dart \
  --plain-name "首页最新上架使用 can_play 的 latest 完整参数"
flutter test test/api_integration_test.dart \
  --plain-name "首页近期磁链更新使用 magnets 的 latest 完整参数"
```

Expected:

- latest test fails because the request only contains `page` and `limit`;
- magnet test fails because it requests `/api/v1/movies/tags` with legacy parameters.

- [ ] **Step 3: Implement the exact request builders**

Update the two service methods:

```dart
Future<List<MovieSummary>> getLatest({int page = 1, int limit = 9}) async {
  final resp = await _api.get(
    Endpoints.moviesLatest,
    queryParameters: {
      'type': 'all',
      'filter_by': 'can_play',
      'sort_by': 'update',
      'order_by': 'desc',
      'limit': limit,
      'page': page,
    },
  );
  return apiList(resp.data, const [
    'movies',
    'items',
  ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
}

Future<List<MovieSummary>> getMagnetUpdates({
  int page = 1,
  int limit = 9,
}) async {
  final resp = await _api.get(
    Endpoints.moviesLatest,
    queryParameters: {
      'type': 'all',
      'filter_by': 'magnets',
      'sort_by': 'update',
      'order_by': 'desc',
      'limit': limit,
      'page': page,
    },
  );
  return apiList(resp.data, const [
    'movies',
    'items',
  ]).map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j))).toList();
}
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/features/home/services/home_service.dart \
  test/api_integration_test.dart
flutter test test/api_integration_test.dart --plain-name HomeService
```

Expected: all `HomeService` tests pass.

- [ ] **Step 5: Commit the service contract**

Run:

```bash
git add lib/features/home/services/home_service.dart \
  test/api_integration_test.dart
git commit -m "fix: align home feeds with latest API"
```

## Task 2: Add Independent Page State and Failure Rollback

**Files:**

- Create: `test/features/home/home_provider_test.dart`
- Modify: `lib/features/home/providers/home_provider.dart`

**Interfaces:**

- Produces: `int get latestPage`
- Produces: `int get magnetPage`
- Produces: `bool get isLatestRefreshing`
- Produces: `bool get isMagnetRefreshing`
- Changes: `reshuffleLatest()` and `reshuffleMagnets()` return `Future<void>`

- [ ] **Step 1: Create a deterministic HomeService fake**

Create the test file with a fake that records page arguments:

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

MovieSummary _movie(String id) => MovieSummary(
  id: id,
  number: id,
  title: id,
  coverUrl: '$id.jpg',
);

class _FakeHomeService implements HomeService {
  final latestPages = <int>[];
  final magnetPages = <int>[];
  Object? latestError;
  Object? magnetError;
  Completer<void>? latestGate;

  @override
  Future<List<MovieSummary>> getRecommends({String? period}) async {
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
```

- [ ] **Step 2: Add failing pagination and loading tests**

Add:

```dart
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
    expect(provider.latest.single.id, 'latest-3');
    expect(provider.magnetUpdates.single.id, 'magnet-2');
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
    expect(provider.latest.single.id, 'latest-1');
    service.latestError = null;
    await provider.reshuffleLatest();
    expect(service.latestPages, [1, 2, 2]);
    expect(provider.latestPage, 2);
  });
}
```

- [ ] **Step 3: Run the provider tests and confirm RED**

Run:

```bash
flutter test test/features/home/home_provider_test.dart
```

Expected: compile failures because page/loading getters do not exist and reshuffle methods still return `void`.

- [ ] **Step 4: Implement independent asynchronous pagination**

Add state and getters:

```dart
int _latestPage = 1;
int _magnetPage = 1;
bool _isLatestRefreshing = false;
bool _isMagnetRefreshing = false;

int get latestPage => _latestPage;
int get magnetPage => _magnetPage;
bool get isLatestRefreshing => _isLatestRefreshing;
bool get isMagnetRefreshing => _isMagnetRefreshing;
```

Make initial loading explicit:

```dart
final results = await Future.wait([
  _service.getRecommends(),
  _service.getLatest(page: 1),
  _service.getMagnetUpdates(page: 1),
]);
_recommends = results[0];
_latest = results[1];
_magnetUpdates = results[2];
_latestPage = 1;
_magnetPage = 1;
```

Replace both local shuffle methods:

```dart
Future<void> reshuffleLatest() async {
  if (_isLatestRefreshing) return;
  _isLatestRefreshing = true;
  notifyListeners();
  final nextPage = _latestPage + 1;
  try {
    final movies = await _service.getLatest(page: nextPage);
    _latest = movies;
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
    _magnetUpdates = movies;
    _magnetPage = nextPage;
  } finally {
    _isMagnetRefreshing = false;
    notifyListeners();
  }
}
```

- [ ] **Step 5: Format and verify GREEN**

Run:

```bash
dart format lib/features/home/providers/home_provider.dart \
  test/features/home/home_provider_test.dart
flutter test test/features/home/home_provider_test.dart
```

Expected: all provider tests pass.

- [ ] **Step 6: Commit provider pagination**

Run:

```bash
git add lib/features/home/providers/home_provider.dart \
  test/features/home/home_provider_test.dart
git commit -m "feat: paginate home feed groups"
```

## Task 3: Apply the Global Header and Home Entry Card Styles

**Files:**

- Create: `test/core/widgets/section_header_test.dart`
- Modify: `lib/core/widgets/section_header.dart`
- Create: `test/features/home/tofu_scroll_test.dart`
- Modify: `lib/features/home/widgets/tofu_scroll.dart`

**Interfaces:**

- Preserves: `SectionHeader({title, trailing, onTrailing, bold})`
- Extends: `TofuItem` with a required `Color color`
- Preserves all existing tofu labels and routes

- [ ] **Step 1: Write the failing global SectionHeader tests**

Create:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/section_header.dart';

void main() {
  testWidgets('全局分区标题使用强调层级并在尾部显示右箭头', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader(title: '最新上架', trailing: '全部'),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('最新上架'));
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('尾部区域整体触发 onTrailing', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            title: '月排名',
            trailing: '全部',
            onTrailing: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('全部'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Write the failing TofuScroll card test**

Create:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';

void main() {
  testWidgets('首页入口使用横向圆角卡片并保留路由', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TofuScroll()),
        GoRoute(
          path: '/rankings',
          builder: (_, _) => const Scaffold(body: Text('排行榜')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byType(Card), findsNWidgets(TofuScroll.items.length));
    expect(find.byType(InkWell), findsNWidgets(TofuScroll.items.length));
    final firstCard = tester.widget<Card>(find.byType(Card).first);
    expect(firstCard.shape, isA<RoundedRectangleBorder>());

    await tester.tap(find.text('看热播'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rankings');
  });
}
```

- [ ] **Step 3: Run both test files and confirm RED**

Run:

```bash
flutter test test/core/widgets/section_header_test.dart
flutter test test/features/home/tofu_scroll_test.dart
```

Expected:

- header test fails because there is no chevron and the current weight is `w600`;
- tofu test fails because the entries are bare `GestureDetector` columns rather than cards with `InkWell`.

- [ ] **Step 4: Implement the global SectionHeader visual**

Use theme styles and make the entire trailing group interactive:

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final trailingContent = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        trailing ?? '',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ],
  );
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
        if (trailing != null)
          InkWell(
            onTap: onTrailing,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: trailingContent,
            ),
          ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Implement the themed tofu cards**

Add `color` to `TofuItem`, assign stable colors to all nine constants, then replace the 80-high bare list with:

```dart
return SizedBox(
  height: 116,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(width: 12),
    itemBuilder: (context, i) {
      final item = items[i];
      return SizedBox(
        width: 84,
        child: Card(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(item.route),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                Icon(item.icon, size: 30, color: item.color),
                Text(item.label, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
```

- [ ] **Step 6: Format and verify GREEN**

Run:

```bash
dart format lib/core/widgets/section_header.dart \
  lib/features/home/widgets/tofu_scroll.dart \
  test/core/widgets/section_header_test.dart \
  test/features/home/tofu_scroll_test.dart
flutter test test/core/widgets/section_header_test.dart \
  test/features/home/tofu_scroll_test.dart
flutter test test/features/actors/actors_screen_test.dart
```

Expected: new style tests and existing actor screen tests pass.

- [ ] **Step 7: Commit shared and home entry styles**

Run:

```bash
git add lib/core/widgets/section_header.dart \
  lib/features/home/widgets/tofu_scroll.dart \
  test/core/widgets/section_header_test.dart \
  test/features/home/tofu_scroll_test.dart
git commit -m "style: update section headers and home entries"
```

## Task 4: Replace Local Shuffle with the Paged Refresh Control

**Files:**

- Modify: `test/features/home/home_screen_test.dart`
- Modify: `lib/features/home/screens/home_screen.dart`

**Interfaces:**

- Consumes: `HomeProvider.reshuffleLatest(): Future<void>`
- Consumes: `HomeProvider.reshuffleMagnets(): Future<void>`
- Produces keys: `home-latest-shuffle`, `home-magnets-shuffle`
- Produces: a `SnackBar` with `换一组失败，请重试` after refresh failure

- [ ] **Step 1: Add a real API-backed home test fixture**

Extend `home_screen_test.dart` with the same `SharedPreferences`, `AuthProvider`, `ApiClient.create`, and `FakeAdapter` setup used by rankings tests. Stub:

```dart
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
```

Pump `HomePage`, then settle the initial async requests with bounded pumps:

```dart
await tester.pumpWidget(const MaterialApp(home: HomePage()));
await tester.pump();
await tester.pump(const Duration(milliseconds: 350));
await tester.pump();
```

Return the adapter so tests can inspect real requests.

- [ ] **Step 2: Add failing widget and page-request tests**

Add:

```dart
testWidgets('首页显示参考样式的两个换一组控件', (tester) async {
  await _pumpHome(tester);

  expect(find.text('最新上架'), findsOneWidget);
  expect(find.text('近期磁链更新'), findsOneWidget);
  expect(find.text('换一组'), findsNWidgets(2));
  expect(find.byIcon(Icons.refresh), findsNWidgets(2));
});

testWidgets('最新上架换一组仅请求 can_play 第 2 页', (tester) async {
  final adapter = await _pumpHome(tester);
  final before = adapter.requests.length;

  await tester.tap(find.byKey(const Key('home-latest-shuffle')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();

  final added = adapter.requests.skip(before).toList();
  expect(added, hasLength(1));
  expect(added.single.uri.queryParameters['filter_by'], 'can_play');
  expect(added.single.uri.queryParameters['page'], '2');
});

testWidgets('近期磁链换一组仅请求 magnets 第 2 页', (tester) async {
  final adapter = await _pumpHome(tester);
  final before = adapter.requests.length;

  await tester.tap(find.byKey(const Key('home-magnets-shuffle')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();

  final added = adapter.requests.skip(before).toList();
  expect(added, hasLength(1));
  expect(added.single.uri.queryParameters['filter_by'], 'magnets');
  expect(added.single.uri.queryParameters['page'], '2');
});
```

- [ ] **Step 3: Run the focused widget tests and confirm RED**

Run:

```bash
flutter test test/features/home/home_screen_test.dart \
  --plain-name "首页显示参考样式的两个换一组控件"
flutter test test/features/home/home_screen_test.dart \
  --plain-name "最新上架换一组仅请求 can_play 第 2 页"
flutter test test/features/home/home_screen_test.dart \
  --plain-name "近期磁链换一组仅请求 magnets 第 2 页"
```

Expected:

- style test fails because the old control is an icon-only shuffle button;
- request tests fail because no network request is sent after tapping.

- [ ] **Step 4: Add async refresh handlers with error feedback**

Add:

```dart
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
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('换一组失败，请重试')),
  );
}
```

Call them from the two sections with their corresponding loading getters.

- [ ] **Step 5: Replace `_shuffleButton` with a centered full-row control**

Use:

```dart
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
```

Wire:

```dart
_shuffleButton(
  key: const Key('home-latest-shuffle'),
  isLoading: p.isLatestRefreshing,
  onPressed: _refreshLatest,
),
```

and the corresponding magnet key, getter, and callback.

- [ ] **Step 6: Format and verify GREEN**

Run:

```bash
dart format lib/features/home/screens/home_screen.dart \
  test/features/home/home_screen_test.dart
flutter test test/features/home/home_screen_test.dart
flutter test test/features/home/home_provider_test.dart
flutter test test/api_integration_test.dart --plain-name HomeService
```

Expected: all focused home tests pass.

- [ ] **Step 7: Commit the paged refresh UI**

Run:

```bash
git add lib/features/home/screens/home_screen.dart \
  test/features/home/home_screen_test.dart
git commit -m "feat: refresh home sections by page"
```

## Task 5: Final Regression and Scope Verification

**Files:**

- Verify all files listed above.
- Preserve unchanged: `docs/main/api/jdb_api_openapi.json`

**Interfaces:**

- Consumes all tasks above.
- Produces a clean focused test and analysis result without staging unrelated changes.

- [ ] **Step 1: Run all focused tests together**

Run:

```bash
flutter test \
  test/api_integration_test.dart \
  test/features/home/home_provider_test.dart \
  test/features/home/home_screen_test.dart \
  test/features/home/tofu_scroll_test.dart \
  test/core/widgets/section_header_test.dart \
  test/features/actors/actors_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Inspect diff and repository state**

Run:

```bash
git diff --check
git status --short
git diff --stat
```

Confirm:

- `docs/main/api/jdb_api_openapi.json` remains unchanged from commit `ff236e3`;
- only files in this plan were changed by this implementation;
- no temporary files or generated artifacts were added.

- [ ] **Step 4: Report verified behavior**

Report the exact focused tests and analysis results, list implementation commits, and explicitly state that the OpenAPI file was not modified.
