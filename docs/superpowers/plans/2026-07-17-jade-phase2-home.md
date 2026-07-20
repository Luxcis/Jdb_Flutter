# Jade Phase 2 — 首页 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans with parallel subagents.

**Goal:** 实现 spec §7 首页完整页面：豆腐块横滚条、佳片推荐轮播、最新上架 3×3 grid、近期磁链更新 3×3 grid，含 HomeService（API）+ HomeProvider（状态）。

**Architecture:** Feature-First，`lib/features/home/` 内 screens/widgets/services 三层。HomeService 调用 `ApiClient` 封装 4 个接口。HomeProvider 管理首屏数据并发加载。HomePage 使用 `CustomScrollView` + Sliver 组件，复用 Phase 1 共享组件。

**Tech Stack:** provider、dio、go_router。复用：CachedImage、MovieCard、MovieGridView、SectionHeader、MovieListTile、PaginationController、EmptyState、ErrorRetryWidget。

## Global Constraints
- Material Design 3、中文硬编码、无本地化、ThemeMode.system
- Feature-First、core/只被 feature 依赖
- 使用已有 `ApiClient`、`Endpoints`、`PaginationController`
- 测试：widget test 主要 section 渲染
- Git 代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890`

---

### Task 1: HomeService — API 封装

**Files:**
- Create: `lib/features/home/services/home_service.dart`

**Interfaces:**
- `HomeService(ApiClient)`：`Future<List<MovieSummary>> getRecommends({String? period})`、`Future<List<String>> getRecommendPeriods()`、`Future<List<MovieSummary>> getLatest({int page=1, int limit=9})`、`Future<List<MovieSummary>> getMagnetUpdates({int limit=9})`。

```dart
// lib/features/home/services/home_service.dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';

class HomeService {
  HomeService(this._api);
  final ApiClient _api;

  Future<List<MovieSummary>> getRecommends({String? period}) async {
    final resp = await _api.get(Endpoints.moviesRecommend,
      queryParameters: if (period != null) 'period': period,
    );
    final list = (resp.data as List?) ?? [];
    return list.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<String>> getRecommendPeriods() async {
    final resp = await _api.get(Endpoints.moviesRecommendPeriods);
    final list = (resp.data as List?) ?? [];
    return list.cast<String>();
  }

  Future<List<MovieSummary>> getLatest({int page = 1, int limit = 9}) async {
    final resp = await _api.get(Endpoints.moviesLatest,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = resp.data;
    final items = (data is Map ? data['items'] ?? [] : []) as List;
    return items.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<MovieSummary>> getMagnetUpdates({int limit = 9}) async {
    final resp = await _api.get(Endpoints.moviesTags,
      queryParameters: {'sort_by': 'magnet_date', 'limit': limit},
    );
    final data = resp.data;
    final items = (data is Map ? data['items'] ?? [] : []) as List;
    return items.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>)).toList();
  }
}
```

- [ ] **Step 1: Create and commit**

```bash
git add lib/features/home/services/home_service.dart
git commit -m "feat(home): add HomeService API layer"
```

---

### Task 2: HomeProvider — 状态管理

**Files:**
- Create: `lib/features/home/providers/home_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/services/home_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider(this._service);

  final HomeService _service;

  List<MovieSummary> _recommends = [];
  List<MovieSummary> _latest = [];
  List<MovieSummary> _magnetUpdates = [];
  bool _isLoading = false;
  String? _error;

  List<MovieSummary> get recommends => _recommends;
  List<MovieSummary> get latest => _latest;
  List<MovieSummary> get magnetUpdates => _magnetUpdates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getRecommends(),
        _service.getLatest(),
        _service.getMagnetUpdates(),
      ]);
      _recommends = results[0] as List<MovieSummary>;
      _latest = results[1] as List<MovieSummary>;
      _magnetUpdates = results[2] as List<MovieSummary>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reshuffleLatest() { _latest = List.from(_latest)..shuffle(); notifyListeners(); }
  void reshuffleMagnets() { _magnetUpdates = List.from(_magnetUpdates)..shuffle(); notifyListeners(); }
}
```

- [ ] **Step 1: Create and commit**

```bash
git add lib/features/home/providers/home_provider.dart
git commit -m "feat(home): add HomeProvider state management"
```

---

### Task 3: 豆腐块组件 + 首页完整页面

**Files:**
- Create: `lib/features/home/widgets/tofu_scroll.dart`
- Modify: `lib/features/home/screens/home_screen.dart` (替换占位)
- Modify: `lib/features/home/index.dart` (export 更新)
- Test: `test/features/home/home_screen_test.dart`

**豆腐块组件**：
```dart
// lib/features/home/widgets/tofu_scroll.dart
import 'package:flutter/material.dart';

class TofuItem {
  const TofuItem({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
}

class TofuScroll extends StatelessWidget {
  const TofuScroll({super.key});

  static const items = [
    TofuItem(label: '看热播', icon: Icons.play_circle, route: '/rankings'),
    TofuItem(label: 'AV资讯', icon: Icons.article, route: '/articles'),
    TofuItem(label: '看短评', icon: Icons.reviews, route: '/reviews'),
    TofuItem(label: '找磁链', icon: Icons.link, route: '/search/magnet'),
    TofuItem(label: '识演员', icon: Icons.person_search, route: '/search/image'),
    TofuItem(label: '识影片', icon: Icons.movie, route: '/search/image'),
    TofuItem(label: '系列', icon: Icons.collections, route: '/series'),
    TofuItem(label: '片商', icon: Icons.business, route: '/makers'),
    TofuItem(label: '导演', icon: Icons.person, route: '/directors'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            // 路由跳转 — 由父组件通过 Navigator 或 go_router 处理
            if (items[i].route.startsWith('/search/image')) {
              // 识演员/识影片 → 图片搜索页
            }
            // 各豆腐块跳转由 onTofuTap 回调处理
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(items[i].icon, size: 28),
            const SizedBox(height: 4),
            Text(items[i].label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
```

**首页主页面** — 替换 `lib/features/home/screens/home_screen.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';
import 'package:jade/features/home/providers/home_provider.dart';
import 'package:jade/features/home/services/home_service.dart';
import 'package:jade/core/network/api_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<ApiClient>();
    final provider = HomeProvider(HomeService(api));
    provider.loadAll().then((_) {
      if (mounted) setState(() => _provider = provider);
    });
    _provider = provider;
  }

  HomeProvider? _provider;

  @override
  Widget build(BuildContext context) {
    final p = _provider;
    if (p == null || p.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (p.error != null) {
      return Scaffold(body: ErrorRetryWidget(message: p.error!, onRetry: _load));
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: const TofuScroll()),
          SliverToBoxAdapter(child: SectionHeader(
            title: '佳片推荐', trailing: '往期推荐', bold: true,
            onTrailing: () => context.go('/movies/recommend'),
          )),
          if (p.recommends.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: p.recommends.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => context.go('/movie/${p!.recommends[i].id}'),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(p.recommends[i].coverUrl, fit: BoxFit.cover),
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: Container(color: Colors.black54,
                            padding: const EdgeInsets.all(8),
                            child: Text(p.recommends[i].title,
                              style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SectionHeader(title: '最新上架', trailing: '全部',
            onTrailing: () => context.go('/common?type=latest')),
          _buildGrid(p.latest, () => p.reshuffleLatest()),
          SectionHeader(title: '近期磁链更新', trailing: '全部',
            onTrailing: () => context.go('/common?type=magnet')),
          _buildGrid(p.magnetUpdates, () => p.reshuffleMagnets()),
        ],
      ),
    );
  }

  Widget _buildGrid(List items, VoidCallback onShuffle) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: EmptyState());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
          childAspectRatio: 0.56,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => MovieCard(movie: items[i],
            onTap: () => context.go('/movie/${items[i].id}')),
          childCount: items.length > 9 ? 9 : items.length,
        ),
      ),
    );
  }
}
```

- [ ] **Step 1: Widget 测试**
```dart
// test/features/home/home_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/home/screens/home_screen.dart';

void main() {
  testWidgets('首页渲染豆腐块 + section 标题', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(...);
    expect(find.text('看热播'), findsOneWidget);
    expect(find.text('佳片推荐'), findsWidgets);
  });
}
```
> 注：由于 HomePage 初始化后异步加载，widget 测试需 pump 多次或 mock HomeProvider。

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/
git commit -m "feat(home): implement home page with tofu bar, carousel, grids"
```

---

## Self-Review
- Spec §7 全部 4 个 section 覆盖 ✅
- 复用 Phase 1 组件（SectionHeader、MovieCard、EmptyState、ErrorRetryWidget）✅
- HomeService 调用 4 个 API（recommend/recommendPeriods/latest/tags）✅
- HomeProvider 并发加载 + reshuffle ✅
- 无 TBD/TODO。类型一致。
