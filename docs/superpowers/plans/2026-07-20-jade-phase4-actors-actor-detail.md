# Jade Phase 4 — 演员 + 演员详情 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善 actors feature（推荐 Tab 真实数据 + 分类 Tab 筛选）并从零创建 actor_detail feature（演员详情页：头像/信息/作品列表/收藏）。

**Architecture:** `lib/features/actors/` 已有骨架（6 Tab，推荐 Tab 用 mock 数据，分类 Tab 用 PaginationController）；需重构推荐 Tab 为三段式真实数据 + 登录引导。新建 `lib/features/actor_detail/` 完整 feature（screens/services/index.dart），复用 ActorGridView/MovieGridView/PaginationController/FilterDrawer/SortSelect/SectionHeader/CachedImage 等 core widgets。

**Tech Stack:** Flutter + Dart, provider (ChangeNotifier), go_router, Dio, json_serializable, cached_network_image.

## Global Constraints

（逐字取自 spec 与 RULES.md）
- Material Design 3；ThemeMode.system；ColorScheme.fromSeed()；系统字体；无 google_fonts。
- 不做本地化，所有文案中文硬编码；不使用 .arb/flutter_localizations。
- Feature-First：core/ 放公共层；feature 只依赖 core，feature 之间不互相依赖。
- JSON 序列化用 json_serializable，fieldRename: FieldRename.snake。
- CDN 图片域名 https://tp.spfcas.com/rhe951l4q/（AppConstants.imageCdnBase）。
- 状态管理优先内置 + provider；PaginationController 用 ChangeNotifier。
- 测试：widget test 验证组件渲染，unit test 验证 service 逻辑。
- Git 提交前设置代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890`
- 不使用触觉反馈。
- 每 Task 完成后 commit，提交信息格式：`feat(actors): <描述>` 或 `feat(actor_detail): <描述>`。
- 不 push，除非用户明确指示。

---

## Task 1: 创建 ActorRecommend 模型 + 增强 ActorService

**Files:**
- **Create:** `lib/features/actors/models/actor_recommend.dart`
- **Create:** `lib/features/actors/models/actor_recommend.g.dart`（由 build_runner 生成）
- **Modify:** `lib/features/actors/services/actor_service.dart`
- **Create:** `test/features/actors/services/actor_service_test.dart`

**Interfaces:**
- **Consumes:** `ApiClient.get(Endpoints.actorsRecommend)`, `ApiClient.get(Endpoints.rankingsActors)`, `ApiClient.post('${Endpoints.actors}/{id}/collect_actions')`
- **Produces:**
  ```dart
  // ActorRecommend — 推荐三段响应模型
  class ActorRecommend {
    final List<ActorSummary> newcomers;   // 新人
    final List<ActorSummary> monthly;     // 月排名
    final List<ActorSummary> dmm;         // Fanza(DMM)推荐
    final String? updateDate;             // 更新日期（可选）
  }

  // ActorService 新增/修改方法：
  Future<ActorRecommend> getRecommends();
  // 原返回 List<ActorSummary> → 改为返回 ActorRecommend

  Future<void> collectActor(String id);
  // 新增：POST /api/v1/actors/{id}/collect_actions
  ```

### 5-step Checklist

- [ ] Step 1: **写测试** — `test/features/actors/services/actor_service_test.dart`
- [ ] Step 2: **跑失败** — `flutter test test/features/actors/services/actor_service_test.dart`（expected FAIL）
- [ ] Step 3: **写实现** — 创建 model + 修改 service
- [ ] Step 4: **跑通过** — `flutter test test/features/actors/services/actor_service_test.dart`（expected PASS）
- [ ] Step 5: **commit** — `git add ... && git commit -m "feat(actors): add ActorRecommend model and enhance ActorService"`

### 完整代码

#### 文件 1: `lib/features/actors/models/actor_recommend.dart`

```dart
// lib/features/actors/models/actor_recommend.dart
import 'package:jade/core/models/actor.dart';
import 'package:json_annotation/json_annotation.dart';
part 'actor_recommend.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ActorRecommend {
  const ActorRecommend({
    this.newcomers = const [],
    this.monthly = const [],
    this.dmm = const [],
    this.updateDate,
  });

  final List<ActorSummary> newcomers;
  final List<ActorSummary> monthly;
  final List<ActorSummary> dmm;
  final String? updateDate;

  factory ActorRecommend.fromJson(Map<String, dynamic> json) =>
      _$ActorRecommendFromJson(json);
  Map<String, dynamic> toJson() => _$ActorRecommendToJson(this);
}
```

#### 文件 2: `lib/features/actors/services/actor_service.dart`（完整替换）

```dart
// lib/features/actors/services/actor_service.dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/actors/models/actor_recommend.dart';

class ActorService {
  ActorService(this._api);
  final ApiClient _api;

  Future<PagedResult<ActorSummary>> getActors({
    int? type,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null) params['type'] = type;
    final resp = await _api.get(Endpoints.actors, queryParameters: params);
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: (m['items'] as List?)
              ?.map((j) => ActorSummary.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [],
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<ActorRecommend> getRecommends() async {
    final resp = await _api.get(Endpoints.actorsRecommend);
    final m = resp.data as Map<String, dynamic>;
    return ActorRecommend.fromJson(m);
  }

  Future<PagedResult<ActorSummary>> getRankingActors({
    String period = 'monthly',
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      Endpoints.rankingsActors,
      queryParameters: {'period': period, 'page': page, 'limit': limit},
    );
    final m = resp.data as Map<String, dynamic>;
    return PagedResult(
      items: (m['items'] as List?)
              ?.map((j) => ActorSummary.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [],
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<ActorDetail> getDetail(
    String id, {
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      '${Endpoints.actors}/$id',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ActorDetail.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<PagedResult<MovieSummary>> getActorMovies(
    String id, {
    int page = 1,
    int limit = 20,
    String? sortBy,
    String? orderBy,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (sortBy != null) params['sort_by'] = sortBy;
    if (orderBy != null) params['order_by'] = orderBy;
    final resp = await _api.get(
      '${Endpoints.actors}/$id',
      queryParameters: params,
    );
    final m = resp.data as Map<String, dynamic>;
    final movies = (m['movies'] as List?)
            ?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>))
            .toList() ??
        (m['items'] as List?)
            ?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
    return PagedResult(
      items: movies,
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<void> collectActor(String id) async {
    await _api.post('${Endpoints.actors}/$id/collect_actions');
  }
}
```

#### 文件 3: `test/features/actors/services/actor_service_test.dart`

```dart
// test/features/actors/services/actor_service_test.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/features/actors/models/actor_recommend.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

void main() {
  late ApiClient api;
  late ActorService svc;

  setUp(() {
    api = ApiClient.instanceOrNull ??
        (ApiClient._(
          dio: Dio(BaseOptions(baseUrl: 'https://test.local')),
          domainManager: (throw UnimplementedError()),
        ));
    svc = ActorService(api);
  });

  group('getRecommends', () {
    test('returns ActorRecommend with three sections', () async {
      api.setAdapterForTest(FakeAdapter((req) {
        return ResponseBody.fromString(
          jsonEncode({
            'newcomers': [
              {'id': '1', 'name': '新人A', 'avatar_url': 'a.jpg'},
              {'id': '2', 'name': '新人B', 'avatar_url': 'b.jpg'},
            ],
            'monthly': [
              {'id': '3', 'name': '月排A', 'avatar_url': 'c.jpg'},
            ],
            'dmm': [
              {'id': '4', 'name': 'DMM推荐A', 'avatar_url': 'd.jpg'},
            ],
            'update_date': '2026-07-20',
          }),
          200,
        );
      }, 'GET'));

      final result = await svc.getRecommends();
      expect(result, isA<ActorRecommend>());
      expect(result.newcomers.length, 2);
      expect(result.newcomers[0].name, '新人A');
      expect(result.monthly.length, 1);
      expect(result.dmm.length, 1);
      expect(result.updateDate, '2026-07-20');
    });

    test('handles empty sections', () async {
      api.setAdapterForTest(FakeAdapter((req) {
        return ResponseBody.fromString(
          jsonEncode({'newcomers': [], 'monthly': [], 'dmm': []}),
          200,
        );
      }, 'GET'));

      final result = await svc.getRecommends();
      expect(result.newcomers, isEmpty);
      expect(result.monthly, isEmpty);
      expect(result.dmm, isEmpty);
      expect(result.updateDate, isNull);
    });
  });

  group('getActors', () {
    test('returns PagedResult with type filter', () async {
      api.setAdapterForTest(FakeAdapter((req) {
        return ResponseBody.fromString(
          jsonEncode({
            'items': [
              {'id': '1', 'name': '演员1', 'avatar_url': 'x.jpg'},
            ],
            'current_page': 1,
            'total_pages': 3,
            'total': 30,
          }),
          200,
        );
      }, 'GET'));

      final result = await svc.getActors(type: 1, page: 2, limit: 10);
      expect(result.items.length, 1);
      expect(result.currentPage, 1);
      expect(result.totalPages, 3);
      expect(result.total, 30);
    });
  });

  group('collectActor', () {
    test('calls POST collect_actions', () async {
      var called = false;
      api.setAdapterForTest(FakeAdapter((req) {
        called = true;
        return ResponseBody.fromString('{}', 200);
      }, 'POST'));

      await svc.collectActor('act_123');
      expect(called, isTrue);
    });
  });
}
```

### 终端命令

```bash
# Step 2: 跑测试（预期失败——model 和 service 未实现）
flutter test test/features/actors/services/actor_service_test.dart

# Step 3: 创建 model 后运行 build_runner 生成 .g.dart
dart run build_runner build --delete-conflicting-outputs

# Step 4: 跑测试（预期通过）
flutter test test/features/actors/services/actor_service_test.dart

# Step 5: commit
git add lib/features/actors/models/actor_recommend.dart \
        lib/features/actors/models/actor_recommend.g.dart \
        lib/features/actors/services/actor_service.dart \
        test/features/actors/services/actor_service_test.dart
git commit -m "$(cat <<'EOF'
feat(actors): add ActorRecommend model and enhance ActorService

- Add ActorRecommend model (newcomers/monthly/dmm sections)
- Update getRecommends to return ActorRecommend instead of flat list
- Add collectActor method for POST collect_actions
- Add sort_by/order_by params to getActorMovies
- Add unit tests for ActorService
EOF
)"
```

**预期输出（Step 4）：**
```
00:00 +3: All tests passed!
```

---

## Task 2: 重构 ActorsPage 推荐 Tab（三段数据 + 登录引导卡）

**Files:**
- **Modify:** `lib/features/actors/screens/actors_screen.dart`
- **Create:** `lib/features/actors/widgets/login_guide_card.dart`
- **Create:** `test/features/actors/screens/actors_screen_test.dart`

**Interfaces:**
- **Consumes:** `Provider.of<AuthProvider>(context)` — 获取认证状态
- **Produces:** `_RecommendTab` 内部重构（三段 SectionHeader + ActorGridView），显示更新日期

### 5-step Checklist

- [ ] Step 1: **写测试** — `test/features/actors/screens/actors_screen_test.dart`
- [ ] Step 2: **跑失败** — `flutter test test/features/actors/screens/actors_screen_test.dart`（expected FAIL）
- [ ] Step 3: **写实现** — 创建 LoginGuideCard + 重构 actors_screen.dart
- [ ] Step 4: **跑通过** — `flutter test test/features/actors/screens/actors_screen_test.dart`（expected PASS）
- [ ] Step 5: **commit** — `git add ... && git commit -m "feat(actors): refactor recommend tab with real data and login guide"`

### 完整代码

#### 文件 1: `lib/features/actors/widgets/login_guide_card.dart`

```dart
// lib/features/actors/widgets/login_guide_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/routes.dart';

class LoginGuideCard extends StatelessWidget {
  const LoginGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              '登录后可查看推荐演员',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '登录后获取个性化演员推荐',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 文件 2: `lib/features/actors/screens/actors_screen.dart`（完整替换）

```dart
// lib/features/actors/screens/actors_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/features/actors/models/actor_recommend.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:jade/features/actors/widgets/login_guide_card.dart';

class ActorsPage extends StatefulWidget {
  const ActorsPage({super.key});
  @override
  State<ActorsPage> createState() => _ActorsPageState();
}

class _ActorsPageState extends State<ActorsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  static const tabs = [
    '推荐',
    '有码(女)',
    '有码(男)',
    '无码',
    '欧美(女)',
    '欧美(男)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('演员'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RecommendTab(),
          _ActorListTab(type: 1),
          _ActorListTab(type: 4),
          _ActorListTab(type: 2),
          _ActorListTab(type: 3),
          _ActorListTab(type: 5),
        ],
      ),
    );
  }
}

// ============================================================
// 推荐 Tab
// ============================================================
class _RecommendTab extends StatefulWidget {
  const _RecommendTab();
  @override
  State<_RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<_RecommendTab> {
  ActorRecommend? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiClient.instanceOrNull;
      if (api == null) return;
      final svc = ActorService(api);
      final data = await svc.getRecommends();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const Center(child: LoginGuideCard());
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final d = _data;
    return CustomScrollView(
      slivers: [
        if (d?.updateDate != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: Text(
                '更新日期：${d!.updateDate}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        SectionHeader(title: '新人', bold: true).sliver,
        _actorSliverGrid(d?.newcomers ?? []),
        SectionHeader(
          title: '月排名',
          trailing: '全部',
          onTrailing: () =>
              context.go('/actors?type=ranking&period=monthly'),
        ).sliver,
        _actorSliverGrid(d?.monthly.take(9).toList() ?? []),
        SectionHeader(title: 'Fanza(DMM)推荐', bold: true).sliver,
        _actorSliverGrid(d?.dmm ?? []),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _actorSliverGrid(List<ActorSummary> actors) {
    if (actors.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, i) => GestureDetector(
          onTap: () => context.go('/actor/${actors[i].id}'),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: actors[i].avatarUrl.startsWith('http')
                    ? NetworkImage(actors[i].avatarUrl) as ImageProvider
                    : NetworkImage(
                        'https://tp.spfcas.com/rhe951l4q/${actors[i].avatarUrl}'),
              ),
              const SizedBox(height: 4),
              Text(
                actors[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        childCount: actors.length,
      ),
    );
  }
}

// ============================================================
// 分类列表 Tab（有码女/有码男/无码/欧美女/欧美男）
// ============================================================
class _ActorListTab extends StatefulWidget {
  final int type;
  const _ActorListTab({required this.type});
  @override
  State<_ActorListTab> createState() => _ActorListTabState();
}

class _ActorListTabState extends State<_ActorListTab> {
  Map<String, String> _filters = {};
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final _ctrl = PaginationController<ActorSummary>(
    fetch: (page) async {
      final api = ApiClient.instanceOrNull;
      if (api == null) {
        return const PagedResult(
          items: [],
          currentPage: 1,
          totalPages: 1,
          total: 0,
        );
      }
      return ActorService(api).getActors(type: widget.type, page: page);
    },
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  FilterSchema get _filterSchema {
    final genderItems = <({String label, String value})>[];
    if (widget.type == 1) {
      // 有码(女)：性别固定为女
    } else if (widget.type == 4) {
      genderItems.addAll([
        (label: '女', value: 'female'),
        (label: '男', value: 'male'),
      ]);
    } else if (widget.type == 2 || widget.type == 3 || widget.type == 5) {
      genderItems.addAll([
        (label: '女', value: 'female'),
        (label: '男', value: 'male'),
      ]);
    }

    final letterItems = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        .split('')
        .map((l) => (label: l, value: l))
        .toList();

    final groups = <FilterGroup>[];
    if (genderItems.isNotEmpty) {
      groups.add(FilterGroup(label: '性别', items: genderItems));
    }
    groups.add(FilterGroup(label: '首字母', items: letterItems));

    return FilterSchema(groups: groups);
  }

  void _openFilter() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: FilterDrawer(
        schema: _filterSchema,
        initialValues: _filters,
        onChanged: (values) {
          _filters = values;
          _ctrl.refresh();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _openFilter,
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('筛选'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ActorGridView(
              controller: _ctrl,
              onActorTap: (a) => context.go('/actor/${a.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 文件 3: `test/features/actors/screens/actors_screen_test.dart`

```dart
// test/features/actors/screens/actors_screen_test.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/actors/screens/actors_screen.dart';

class _FakeAuth extends ChangeNotifier implements TokenProvider {
  _FakeAuth({required this.logged});
  final bool logged;
  @override
  String? get token => logged ? 'tok' : null;
  bool get isLogged => logged;
  Map<String, dynamic>? get user => null;
  Future<void> login({
    required String token,
    required Map<String, dynamic> user,
  }) async {}
  Future<void> logout() async {}

  static _FakeAuth create({required bool logged}) => _FakeAuth(logged: logged);
}

Widget _buildApp({required bool logged}) {
  return ChangeNotifierProvider<_FakeAuth>(
    create: (_) => _FakeAuth.create(logged: logged),
    child: const MaterialApp(home: ActorsPage()),
  );
}

void main() {
  setUp(() {
    // 确保 ApiClient 实例可用于测试
  });

  testWidgets('ActorsPage renders 6 tabs', (tester) async {
    await tester.pumpWidget(_buildApp(logged: true));
    await tester.pump();
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('有码(女)'), findsOneWidget);
    expect(find.text('有码(男)'), findsOneWidget);
    expect(find.text('无码'), findsOneWidget);
    expect(find.text('欧美(女)'), findsOneWidget);
    expect(find.text('欧美(男)'), findsOneWidget);
  });

  testWidgets('Recommend tab shows login guide when not logged in',
      (tester) async {
    await tester.pumpWidget(_buildApp(logged: false));
    await tester.pump();
    expect(find.text('登录后可查看推荐演员'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('Recommend tab shows loading when logged in', (tester) async {
    await tester.pumpWidget(_buildApp(logged: true));
    await tester.pump();
    // 加载中状态——CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

### 终端命令

```bash
# Step 2: 跑测试（预期失败——重构尚未完成）
flutter test test/features/actors/screens/actors_screen_test.dart

# Step 4: 跑测试（预期通过）
flutter test test/features/actors/screens/actors_screen_test.dart

# Step 5: commit
git add lib/features/actors/screens/actors_screen.dart \
        lib/features/actors/widgets/login_guide_card.dart \
        test/features/actors/screens/actors_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(actors): refactor recommend tab with real data and login guide

- Recommend tab now fetches ActorRecommend (newcomers/monthly/dmm) from API
- Show login guide card when user is not authenticated
- Show update date above newcomer section
- Monthly ranking section links to full ranking page
- Category tabs unchanged (PaginationController-based)
EOF
)"
```

**预期输出（Step 4）：**
```
00:00 +3: All tests passed!
```

---

## Task 3: 为分类 Tab 添加 FilterDrawer 筛选功能

> **注意:** 此 Task 的代码已在 Task 2 的 `actors_screen.dart` 中实现。本 Task 专注于补充筛选逻辑和 widget test。

**Files:**
- **Modify:** `lib/features/actors/screens/actors_screen.dart`（已在 Task 2 完成）
- **Create:** `test/features/actors/screens/actors_filter_test.dart`

**Interfaces:**
- **Consumes:** `FilterDrawer(schema:, initialValues:, onChanged:)` + `FilterSchema` + `FilterGroup`
- **Produces:** `_ActorListTabState._filters` → `_ctrl.refresh()` 触发重新请求

### 5-step Checklist

- [ ] Step 1: **写测试** — `test/features/actors/screens/actors_filter_test.dart`
- [ ] Step 2: **跑失败** — `flutter test test/features/actors/screens/actors_filter_test.dart`
- [ ] Step 3: **写实现** — 确认 Task 2 代码中筛选按钮 + FilterDrawer 逻辑正确（review + 微调）
- [ ] Step 4: **跑通过** — `flutter test test/features/actors/screens/actors_filter_test.dart`
- [ ] Step 5: **commit** — 如有修改则 `git commit -m "feat(actors): add FilterDrawer filter to category tabs"`，无修改则跳过

### 完整代码

#### 文件 1: `test/features/actors/screens/actors_filter_test.dart`

```dart
// test/features/actors/screens/actors_filter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/filter_drawer.dart';

void main() {
  group('FilterSchema 构建', () {
    test('有码(女) type=1 不含性别筛选组', () {
      // 有码(女)已隐含性别，不需要性别筛选组
      final schema = _buildSchemaForType(1);
      final genderGroup =
          schema.groups.where((g) => g.label == '性别').toList();
      expect(genderGroup, isEmpty);
      expect(schema.groups.any((g) => g.label == '首字母'), isTrue);
    });

    test('有码(男) type=4 包含性别和首字母筛选', () {
      final schema = _buildSchemaForType(4);
      expect(schema.groups.any((g) => g.label == '性别'), isTrue);
      expect(schema.groups.any((g) => g.label == '首字母'), isTrue);
    });

    test('无码 type=2 包含性别和首字母筛选', () {
      final schema = _buildSchemaForType(2);
      expect(schema.groups.any((g) => g.label == '性别'), isTrue);
    });
  });

  testWidgets('FilterDrawer 渲染筛选组和确认按钮', (tester) async {
    final schema = FilterSchema(groups: [
      FilterGroup(label: '性别', items: [
        (label: '女', value: 'female'),
        (label: '男', value: 'male'),
      ]),
      FilterGroup(label: '首字母', items: [
        (label: 'A', value: 'A'),
        (label: 'B', value: 'B'),
      ]),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        endDrawer: FilterDrawer(
          schema: schema,
          onChanged: (_) {},
        ),
        body: const Center(child: Text('test')),
      ),
    ));
    // 打开 drawer
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openEndDrawer();
    await tester.pumpAndSettle();

    expect(find.text('性别'), findsOneWidget);
    expect(find.text('首字母'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
  });
}

FilterSchema _buildSchemaForType(int type) {
  final genderItems = <({String label, String value})>[];
  if (type == 4 || type == 2 || type == 3 || type == 5) {
    genderItems.addAll([
      (label: '女', value: 'female'),
      (label: '男', value: 'male'),
    ]);
  }
  final letterItems = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      .split('')
      .map((l) => (label: l, value: l))
      .toList();

  final groups = <FilterGroup>[];
  if (genderItems.isNotEmpty) {
    groups.add(FilterGroup(label: '性别', items: genderItems));
  }
  groups.add(FilterGroup(label: '首字母', items: letterItems));

  return FilterSchema(groups: groups);
}
```

### 终端命令

```bash
# Step 2: 跑测试
flutter test test/features/actors/screens/actors_filter_test.dart

# Step 4: 跑通过
flutter test test/features/actors/screens/actors_filter_test.dart

# Step 5: commit（仅当有代码修改时）
git add test/features/actors/screens/actors_filter_test.dart
git commit -m "feat(actors): add filter tests for category tabs"
```

**预期输出（Step 4）：**
```
00:00 +4: All tests passed!
```

---

## Task 4: 创建 actor_detail feature 骨架（service + index.dart）

**Files:**
- **Create:** `lib/features/actor_detail/services/actor_detail_service.dart`
- **Create:** `lib/features/actor_detail/index.dart`
- **Create:** `test/features/actor_detail/services/actor_detail_service_test.dart`

**Interfaces:**
- **Consumes:** `ApiClient.get()`, `ApiClient.post()`
- **Produces:**
  ```dart
  class ActorDetailService {
    Future<ActorDetail> getDetail(String id, {int page, int limit});
    Future<PagedResult<MovieSummary>> getActorMovies(String id, {int page, int limit, String? sortBy, String? orderBy});
    Future<void> collectActor(String id);
  }
  ```

### 5-step Checklist

- [ ] Step 1: **写测试** — `test/features/actor_detail/services/actor_detail_service_test.dart`
- [ ] Step 2: **跑失败** — `flutter test test/features/actor_detail/services/actor_detail_service_test.dart`（expected FAIL）
- [ ] Step 3: **写实现** — 创建 service + index.dart
- [ ] Step 4: **跑通过** — `flutter test test/features/actor_detail/services/actor_detail_service_test.dart`（expected PASS）
- [ ] Step 5: **commit** — `git commit -m "feat(actor_detail): create ActorDetailService and feature skeleton"`

### 完整代码

#### 文件 1: `lib/features/actor_detail/services/actor_detail_service.dart`

```dart
// lib/features/actor_detail/services/actor_detail_service.dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';

class ActorDetailService {
  ActorDetailService(this._api);
  final ApiClient _api;

  Future<ActorDetail> getDetail(
    String id, {
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _api.get(
      '${Endpoints.actors}/$id',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ActorDetail.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<PagedResult<MovieSummary>> getActorMovies(
    String id, {
    int page = 1,
    int limit = 20,
    String? sortBy,
    String? orderBy,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (sortBy != null) params['sort_by'] = sortBy;
    if (orderBy != null) params['order_by'] = orderBy;
    final resp = await _api.get(
      '${Endpoints.actors}/$id',
      queryParameters: params,
    );
    final m = resp.data as Map<String, dynamic>;
    final movies = (m['movies'] as List?)
            ?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>))
            .toList() ??
        (m['items'] as List?)
            ?.map((j) => MovieSummary.fromJson(j as Map<String, dynamic>))
            .toList() ??
        [];
    return PagedResult(
      items: movies,
      currentPage: m['current_page'] ?? 1,
      totalPages: m['total_pages'] ?? 1,
      total: m['total'] ?? 0,
    );
  }

  Future<void> collectActor(String id) async {
    await _api.post('${Endpoints.actors}/$id/collect_actions');
  }
}
```

#### 文件 2: `lib/features/actor_detail/index.dart`

```dart
// lib/features/actor_detail/index.dart
export 'screens/actor_detail_screen.dart';
```

#### 文件 3: `test/features/actor_detail/services/actor_detail_service_test.dart`

```dart
// test/features/actor_detail/services/actor_detail_service_test.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/features/actor_detail/services/actor_detail_service.dart';

void main() {
  late ApiClient api;
  late ActorDetailService svc;

  setUp(() {
    api = ApiClient.instanceOrNull ??
        (ApiClient._(
          dio: Dio(BaseOptions(baseUrl: 'https://test.local')),
          domainManager: (throw UnimplementedError()),
        ));
    svc = ActorDetailService(api);
  });

  group('getDetail', () {
    test('returns ActorDetail with all fields', () async {
      api.setAdapterForTest(FakeAdapter((req) {
        return ResponseBody.fromString(
          jsonEncode({
            'id': 'a1',
            'name': '测试演员',
            'avatar_url': 'avatar.jpg',
            'birthday': '1998-05-20',
            'age': 26,
            'height': '165cm',
            'cup': 'D',
            'bust': '88cm',
            'waist': '58cm',
            'hip': '86cm',
            'birthplace': '东京',
            'movie_count': 42,
          }),
          200,
        );
      }, 'GET'));

      final result = await svc.getDetail('a1');
      expect(result, isA<ActorDetail>());
      expect(result.id, 'a1');
      expect(result.name, '测试演员');
      expect(result.birthday, '1998-05-20');
      expect(result.age, 26);
      expect(result.height, '165cm');
      expect(result.cup, 'D');
      expect(result.bust, '88cm');
      expect(result.waist, '58cm');
      expect(result.hip, '86cm');
      expect(result.birthplace, '东京');
      expect(result.movieCount, 42);
    });
  });

  group('getActorMovies', () {
    test('returns PagedResult with movies from items field', () async {
      api.setAdapterForTest(FakeAdapter((req) {
        return ResponseBody.fromString(
          jsonEncode({
            'items': [
              {
                'id': 'm1',
                'number': 'SSIS-001',
                'title': '测试影片',
                'cover_url': 'cover.jpg',
              },
            ],
            'current_page': 1,
            'total_pages': 5,
            'total': 50,
          }),
          200,
        );
      }, 'GET'));

      final result = await svc.getActorMovies('a1',
          page: 1, sortBy: 'release_date', orderBy: 'desc');
      expect(result.items.length, 1);
      expect(result.items[0].number, 'SSIS-001');
      expect(result.total, 50);
    });

    test('returns PagedResult from movies field', () async {
      api.setAdapterForTest(FakeAdapter((req) {
        return ResponseBody.fromString(
          jsonEncode({
            'movies': [
              {
                'id': 'm2',
                'number': 'IPX-002',
                'title': '影片2',
                'cover_url': 'c2.jpg',
              },
            ],
            'current_page': 1,
            'total_pages': 1,
            'total': 1,
          }),
          200,
        );
      }, 'GET'));

      final result = await svc.getActorMovies('a1');
      expect(result.items.length, 1);
      expect(result.items[0].number, 'IPX-002');
    });
  });

  group('collectActor', () {
    test('calls POST collect_actions', () async {
      var called = false;
      api.setAdapterForTest(FakeAdapter((req) {
        called = true;
        return ResponseBody.fromString('{}', 200);
      }, 'POST'));

      await svc.collectActor('a1');
      expect(called, isTrue);
    });
  });
}
```

### 终端命令

```bash
# Step 1: 先创建目录结构
mkdir -p lib/features/actor_detail/screens lib/features/actor_detail/services

# Step 2: 跑测试（预期失败——service 尚未创建）
flutter test test/features/actor_detail/services/actor_detail_service_test.dart

# Step 4: 跑测试（预期通过）
flutter test test/features/actor_detail/services/actor_detail_service_test.dart

# Step 5: commit
git add lib/features/actor_detail/services/actor_detail_service.dart \
        lib/features/actor_detail/index.dart \
        test/features/actor_detail/services/actor_detail_service_test.dart
git commit -m "$(cat <<'EOF'
feat(actor_detail): create ActorDetailService and feature skeleton

- ActorDetailService with getDetail/getActorMovies/collectActor methods
- index.dart exports ActorDetailPage (placeholder for Task 5)
- Unit tests for all service methods
EOF
)"
```

**预期输出（Step 4）：**
```
00:00 +4: All tests passed!
```

---

## Task 5: 创建 ActorDetailPage（演员详情页）

**Files:**
- **Create:** `lib/features/actor_detail/screens/actor_detail_screen.dart`
- **Create:** `test/features/actor_detail/screens/actor_detail_screen_test.dart`

**Interfaces:**
- **Consumes:** `ActorDetailService`, `PaginationController<MovieSummary>`, `MovieGridView`, `CachedImage`, `SortSelect`, `FilterDrawer` (used as BottomSheet)
- **Produces:** `ActorDetailPage({required String id})` — 路由目标页面

### 5-step Checklist

- [ ] Step 1: **写测试** — `test/features/actor_detail/screens/actor_detail_screen_test.dart`
- [ ] Step 2: **跑失败** — `flutter test test/features/actor_detail/screens/actor_detail_screen_test.dart`（expected FAIL）
- [ ] Step 3: **写实现** — 创建 ActorDetailPage
- [ ] Step 4: **跑通过** — `flutter test test/features/actor_detail/screens/actor_detail_screen_test.dart`（expected PASS）
- [ ] Step 5: **commit** — `git commit -m "feat(actor_detail): create ActorDetailPage with info/movies/collect"`

### 完整代码

#### 文件 1: `lib/features/actor_detail/screens/actor_detail_screen.dart`

```dart
// lib/features/actor_detail/screens/actor_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/actor_detail/services/actor_detail_service.dart';

class ActorDetailPage extends StatefulWidget {
  final String id;
  const ActorDetailPage({super.key, required this.id});

  @override
  State<ActorDetailPage> createState() => _ActorDetailPageState();
}

class _ActorDetailPageState extends State<ActorDetailPage> {
  ActorDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _collected = false;
  bool _collecting = false;

  String _sortBy = 'release_date';
  String _orderBy = 'desc';

  late final _moviesCtrl = PaginationController<MovieSummary>(
    fetch: _fetchMovies,
  );

  @override
  void initState() {
    super.initState();
    _load();
    _moviesCtrl.fetchMore();
  }

  @override
  void dispose() {
    _moviesCtrl.dispose();
    super.dispose();
  }

  void _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiClient.instanceOrNull;
      if (api == null) return;
      final svc = ActorDetailService(api);
      final detail = await svc.getDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<PagedResult<MovieSummary>> _fetchMovies(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return const PagedResult(
          items: [], currentPage: 1, totalPages: 1, total: 0);
    }
    return ActorDetailService(api).getActorMovies(
      widget.id,
      page: page,
      sortBy: _sortBy,
      orderBy: _orderBy,
    );
  }

  void _onSortChanged() {
    _moviesCtrl.refresh();
  }

  void _collect() async {
    setState(() => _collecting = true);
    try {
      final api = ApiClient.instanceOrNull;
      if (api == null) return;
      await ActorDetailService(api).collectActor(widget.id);
      if (!mounted) return;
      setState(() {
        _collected = !_collected;
        _collecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _collecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败')),
      );
    }
  }

  void _showInfoSheet() {
    final d = _detail;
    if (d == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.name,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('出演过 ${d.movieCount} 部影片'),
              if (d.birthday != null) Text('生日：${d.birthday}'),
              if (d.age != null) Text('年龄：${d.age}岁'),
              if (d.height != null) Text('身高：${d.height}'),
              if (d.cup != null) Text('罩杯：${d.cup}'),
              if (d.bust != null) Text('胸围：${d.bust}'),
              if (d.waist != null) Text('腰围：${d.waist}'),
              if (d.hip != null) Text('臀围：${d.hip}'),
              if (d.birthplace != null) Text('出生地：${d.birthplace}'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
          body: ErrorRetryWidget(message: _error!, onRetry: _load));
    }
    final d = _detail!;
    final theme = Theme.of(context);
    final avatarUrl = d.avatarUrl.startsWith('http')
        ? d.avatarUrl
        : '${AppConstants.imageCdnBase}${d.avatarUrl}';

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: _collecting ? null : _collect,
            icon: Icon(
              _collected ? Icons.favorite : Icons.favorite_border,
              color: _collected ? Colors.red : null,
            ),
            tooltip: '收藏',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 头像 + 基本信息
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: CachedImage(avatarUrl),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text('出演过 ${d.movieCount} 部影片',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _showInfoSheet,
                          child: const Text('更多信息'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 排序选择器
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('出演作品',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  SortSelect<String>(
                    options: const [
                      (label: '最新', value: 'release_date_desc'),
                      (label: '最旧', value: 'release_date_asc'),
                      (label: '评分', value: 'score_desc'),
                    ],
                    value: '${_sortBy}_$_orderBy',
                    onChanged: (v) {
                      if (v == null) return;
                      final parts = v.split('_');
                      setState(() {
                        _sortBy = parts[0];
                        _orderBy = parts.length > 1 ? parts[1] : 'desc';
                      });
                      _onSortChanged();
                    },
                  ),
                ],
              ),
            ),
          ),
          // 作品列表 — 使用 SliverFillRemaining 让 MovieGridView 在 CustomScrollView 内可滚动
          SliverFillRemaining(
            hasScrollBody: true,
            child: MovieGridView(
              controller: _moviesCtrl,
              onMovieTap: (m) => context.go('/movie/${m.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 文件 2: `test/features/actor_detail/screens/actor_detail_screen_test.dart`

```dart
// test/features/actor_detail/screens/actor_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/features/actor_detail/screens/actor_detail_screen.dart';

void main() {
  testWidgets('ActorDetailPage renders loading state initially',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ActorDetailPage(id: 'test_1'),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ActorDetailPage has collect button in AppBar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ActorDetailPage(id: 'test_1'),
    ));
    await tester.pump();
    // 在加载状态时 AppBar 中应有收藏按钮
    expect(
        find.byIcon(Icons.favorite_border), findsOneWidget);
  });
}
```

### 终端命令

```bash
# Step 2: 跑测试（预期失败——页面尚未创建）
flutter test test/features/actor_detail/screens/actor_detail_screen_test.dart

# Step 4: 跑测试（预期通过）
flutter test test/features/actor_detail/screens/actor_detail_screen_test.dart

# Step 5: commit
git add lib/features/actor_detail/screens/actor_detail_screen.dart \
        lib/features/actor_detail/index.dart \
        test/features/actor_detail/screens/actor_detail_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(actor_detail): create ActorDetailPage with info/movies/collect

- Actor avatar (100x100 rounded rect) with name and movie count
- "更多信息" button opens showModalBottomSheet with full details
- MovieGridView with SortSelect (release_date/score)
- Favorite collect button in AppBar via POST collect_actions
- Loading/error state handling
EOF
)"
```

**预期输出（Step 4）：**
```
00:00 +2: All tests passed!
```

---

## Task 6: 路由注册（/actor/:id）

**Files:**
- **Modify:** `lib/core/router/app_router.dart`
- **Modify:** `lib/core/router/routes.dart`（可选——如果需要在 AppRoutes 中添加常量）

**Interfaces:**
- **Consumes:** `GoRoute(path: '/actor/:id', builder:)` → `ActorDetailPage(id:)`
- **Produces:** `/actor/:id` 路由可用

### 5-step Checklist

- [ ] Step 1: **写测试** — 修改 `test/app_router_test.dart` 增加 actor 路由测试
- [ ] Step 2: **跑失败** — `flutter test test/app_router_test.dart`（expected FAIL——路由未注册）
- [ ] Step 3: **写实现** — 修改 app_router.dart
- [ ] Step 4: **跑通过** — `flutter test test/app_router_test.dart`（expected PASS）
- [ ] Step 5: **commit** — `git commit -m "feat(actor_detail): register /actor/:id route"`

### 完整代码

#### 文件 1: `lib/core/router/app_router.dart`（仅修改部分——末尾追加路由）

在 `app_router.dart` 的 `import` 部分添加：

```dart
// lib/core/router/app_router.dart（文件顶部 import 区域追加）
import 'package:jade/features/actor_detail/index.dart';
```

在 `buildForTest()` 方法中，`GoRoute(path: '/search', ...)` 之后、`];` 之前添加：

```dart
// lib/core/router/app_router.dart（buildForTest() 方法内）
// ... existing routes ...
          GoRoute(
            path: '/search',
            builder: (c, s) => const SearchPage(),
          ),
          // ↓ 新增 ↓
          GoRoute(
            path: '/actor/:id',
            builder: (c, s) =>
                ActorDetailPage(id: s.pathParameters['id']!),
          ),
        ],
      );
}
```

完整修改后的 `app_router.dart` 如下（仅列出变更部分，其余保持不变）：

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
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
import 'package:jade/features/actor_detail/index.dart';  // ← 新增

class AppRouter {
  const AppRouter._();

  static GoRouter buildForTest() => GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (c, s) => const LoginPage(),
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
          // ↓ 新增 ↓
          GoRoute(
            path: '/actor/:id',
            builder: (c, s) =>
                ActorDetailPage(id: s.pathParameters['id']!),
          ),
        ],
      );
}
```

#### 文件 2: `test/app_router_test.dart`（追加测试用例）

在现有 `test/app_router_test.dart` 文件末尾的 `main()` 函数内追加以下测试：

```dart
  testWidgets('导航到 /actor/:id 渲染 ActorDetailPage', (tester) async {
    final router = AppRouter.buildForTest();
    await tester.pumpWidget(MaterialApp.router(
        routerConfig: router));
    await tester.pump();
    router.go('/actor/test_actor_123');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // ActorDetailPage 在加载时应显示 CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('/actor/:id 路由包含收藏按钮', (tester) async {
    final router = AppRouter.buildForTest();
    await tester.pumpWidget(MaterialApp.router(
        routerConfig: router));
    await tester.pump();
    router.go('/actor/test_actor_123');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
```

### 终端命令

```bash
# Step 2: 跑测试（预期失败——路由未注册）
flutter test test/app_router_test.dart

# Step 3: 修改 app_router.dart + app_router_test.dart

# Step 4: 跑测试（预期通过）
flutter test test/app_router_test.dart

# Step 5: commit
git add lib/core/router/app_router.dart test/app_router_test.dart
git commit -m "$(cat <<'EOF'
feat(actor_detail): register /actor/:id route in go_router

- Add GoRoute('/actor/:id') → ActorDetailPage
- Add router tests for actor detail navigation
EOF
)"
```

**预期输出（Step 4）：**
```
00:00 +4: All tests passed!  (原 2 个 + 新增 2 个)
```

---

## Task 7（最终验证）: 全量测试 + 构建验证

**Files:**
- 无新增文件

### 5-step Checklist

- [ ] Step 1: **全量测试** — `flutter test`（预期全部通过）
- [ ] Step 2: **静态分析** — `dart analyze lib/features/actors/ lib/features/actor_detail/`（预期 0 errors）
- [ ] Step 3: **构建验证** — `flutter build apk --debug`（预期 BUILD SUCCESSFUL）
- [ ] Step 4: **最终 commit**（如有 lint fix）—
- [ ] Step 5: **总结报告** — 列出所有变更文件 + 测试覆盖情况

### 终端命令

```bash
# Step 0: 设置代理
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

# Step 1: 全量测试
flutter test

# Step 2: 静态分析
dart analyze lib/features/actors/
dart analyze lib/features/actor_detail/

# Step 3: 构建验证
flutter build apk --debug

# Step 4: final commit（仅当有 lint fix 时）
git add -A
git commit -m "chore: final lint and build verification for phase4"
```

**预期输出：**
```
# Step 1:
00:00 +XX: All tests passed!

# Step 2:
No issues found!
No issues found!

# Step 3:
Running Gradle task 'assembleDebug'...                              Done
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

---

## 变更文件汇总

| 操作 | 文件路径 |
|------|---------|
| Create | `lib/features/actors/models/actor_recommend.dart` |
| Create (gen) | `lib/features/actors/models/actor_recommend.g.dart` |
| Create | `lib/features/actors/widgets/login_guide_card.dart` |
| Modify | `lib/features/actors/services/actor_service.dart` |
| Modify | `lib/features/actors/screens/actors_screen.dart` |
| Create | `lib/features/actor_detail/services/actor_detail_service.dart` |
| Create | `lib/features/actor_detail/screens/actor_detail_screen.dart` |
| Create | `lib/features/actor_detail/index.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/actors/services/actor_service_test.dart` |
| Create | `test/features/actors/screens/actors_screen_test.dart` |
| Create | `test/features/actors/screens/actors_filter_test.dart` |
| Create | `test/features/actor_detail/services/actor_detail_service_test.dart` |
| Create | `test/features/actor_detail/screens/actor_detail_screen_test.dart` |
| Modify | `test/app_router_test.dart` |

**测试覆盖：**
- ActorService: getRecommends (2 用例), getActors (1), collectActor (1) = 4 用例
- ActorsPage: 6 tabs 渲染 (1), 登录引导 (1), 加载状态 (1) = 3 用例
- FilterSchema: type-based 构建 (3 用例)
- FilterDrawer 渲染 (1 用例)
- ActorDetailService: getDetail (1), getActorMovies (2), collectActor (1) = 4 用例
- ActorDetailPage: 加载状态 (1), 收藏按钮 (1) = 2 用例
- AppRouter: actor 路由导航 (2 新增用例)

**总计：约 20 个测试用例**
