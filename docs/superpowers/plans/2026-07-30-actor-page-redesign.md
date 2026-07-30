# 演员页面改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重做演员推荐与分类页面，实现正确的推荐分区、三列圆角方形演员网格、自动分页、仅有码女可用的紧凑筛选面板，以及全局 `name_zht > name` 展示规则。

**Architecture:** 使用不可变的演员分类/筛选模型作为页面与 Service 之间的契约，五个分类 Tab 各自持有独立 `PaginationController`。推荐页通过结构化 `ActorRecommend` 保留三个响应分区；共享 `ActorAvatarImage`、`ActorCard`、`ActorGridView` 负责全局视觉和页尾状态。

**Tech Stack:** Flutter、Dart 3.8、Material 3、Dio、Provider、flutter_test、现有 `FakeAdapter`

## Global Constraints

- 以 `docs/main/api/jdb_api_openapi.json` 和用户补充的演员筛选参数表为接口契约。
- `/api/v1/actors` 始终发送 `type`、`gender`、`page`、`limit=60`。
- 六个范围参数只对“有码(女)”生效，并且只在偏离默认值时发送。
- 推荐接口不要求登录；不得继续展示登录引导。
- 所有演员名称统一按非空 `name_zht > name` 选择。
- 所有演员头像统一为约 8px 圆角方形，使用 `BoxFit.cover`，不得使用 `ClipOval`。
- 不新增依赖，不使用 ARB/l10n，不使用触觉反馈。
- 所有新增行为必须先写失败测试并确认失败原因，再写生产代码。

---

## File Map

- Create `lib/features/actors/models/actor_filter.dart`: 演员分类映射、整数范围和可选筛选参数编码。
- Create `lib/features/actors/models/actor_recommend.dart`: 推荐接口三分区模型与容错解析。
- Create `lib/features/actors/widgets/actor_filter_sheet.dart`: 仅处理筛选草稿、重置和应用的紧凑底部面板。
- Modify `lib/core/network/api_data.dart`: 全局演员名称优先级规范化。
- Modify `lib/features/actors/services/actor_service.dart`: 新接口参数契约与推荐模型返回值。
- Modify `lib/core/widgets/actor_avatar_image.dart`: 全局圆角方形裁切。
- Modify `lib/core/widgets/actor_card.dart`: 去除固定 72×72 圆形布局。
- Modify `lib/core/widgets/actor_grid_view.dart`: 三列响应式网格、自动加载、页尾加载/错误。
- Modify `lib/features/actors/screens/actors_screen.dart`: 推荐页、五个独立分类页和筛选入口。
- Modify `lib/features/actors/screens/actor_detail_screen.dart`: 移除详情页圆形裁切。
- Modify `lib/features/actors/index.dart`: 只导出路由需要的页面；新模型与私有组件不对外暴露。
- Modify `test/core/network/api_data_test.dart`: 名称优先级回归。
- Create `test/features/actors/models/actor_filter_test.dart`: 分类映射与筛选编码测试。
- Create `test/features/actors/models/actor_recommend_test.dart`: 三分区解析测试。
- Modify `test/api_integration_test.dart`: 演员 Service 请求与响应契约。
- Modify `test/core/widgets/actor_avatar_image_test.dart`: 圆角、语义与占位图测试。
- Modify `test/core/widgets/actor_card_test.dart`: 方形图片和弹性尺寸测试。
- Create `test/core/widgets/actor_grid_view_test.dart`: 自动加载、页尾错误和重试测试。
- Create `test/features/actors/actor_filter_sheet_test.dart`: 紧凑筛选面板交互测试。
- Modify `test/features/actors/actors_screen_test.dart`: 推荐分区、未登录访问、筛选可见性与应用刷新测试。
- Modify `test/core/widgets/section_header_test.dart`: 保留现有尾部回调回归，不改生产组件。
- Modify `test/core/router/app_router_requirements_test.dart`: 确认默认构造的演员页仍可由路由渲染。

---

### Task 1: 演员名称、分类、筛选与推荐模型

**Files:**
- Create: `lib/features/actors/models/actor_filter.dart`
- Create: `lib/features/actors/models/actor_recommend.dart`
- Modify: `lib/core/network/api_data.dart`
- Test: `test/core/network/api_data_test.dart`
- Test: `test/features/actors/models/actor_filter_test.dart`
- Test: `test/features/actors/models/actor_recommend_test.dart`

**Interfaces:**
- Produces: `enum ActorListCategory`
- Produces: `class ActorRange`
- Produces: `class ActorFilter`
- Produces: `class ActorRecommend`
- Produces: `Map<String, dynamic> ActorFilter.toQueryParameters()`
- Consumes: `normalizeActorSummaryJson(Map<String, dynamic>)`

- [ ] **Step 1: 写演员名称优先级失败测试**

在 `test/core/network/api_data_test.dart` 增加：

```dart
test('normalizeActorSummaryJson 优先使用非空 name_zht', () {
  final actor = ActorSummary.fromJson(
    normalizeActorSummaryJson({
      'id': 'a1',
      'name': '日本語名',
      'name_zht': '繁體中文名',
      'avatar_url': '',
    }),
  );

  expect(actor.name, '繁體中文名');
});

test('normalizeActorSummaryJson 在 name_zht 为空时回退到 name', () {
  final actor = ActorSummary.fromJson(
    normalizeActorSummaryJson({
      'id': 'a1',
      'name': '日本語名',
      'name_zht': '   ',
      'avatar_url': '',
    }),
  );

  expect(actor.name, '日本語名');
});
```

- [ ] **Step 2: 运行名称测试并确认 RED**

Run:

```bash
flutter test test/core/network/api_data_test.dart --plain-name "normalizeActorSummaryJson"
```

Expected: `name_zht` 优先级测试失败，实际仍为 `name`。

- [ ] **Step 3: 最小实现全局名称选择**

在 `lib/core/network/api_data.dart` 增加私有清洗函数并更新演员规范化：

```dart
String? _nonEmptyApiString(dynamic value) {
  final text = apiString(value)?.trim();
  return text == null || text.isEmpty ? null : text;
}

Map<String, dynamic> normalizeActorSummaryJson(Map<String, dynamic> json) {
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'name':
        _nonEmptyApiString(json['name_zht']) ??
        _nonEmptyApiString(json['name']) ??
        _nonEmptyApiString(json['title']) ??
        '',
    'gender': apiString(json['gender']),
    'avatar_url':
        apiString(json['avatar_url'] ?? json['avatar'] ?? json['image_url']) ??
        '',
  };
}
```

- [ ] **Step 4: 写分类映射和筛选编码失败测试**

创建 `test/features/actors/models/actor_filter_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/actors/models/actor_filter.dart';

void main() {
  test('五个分类映射为接口 type 和 gender', () {
    expect(
      ActorListCategory.values
          .map((category) => (category.type, category.gender))
          .toList(),
      [('0', '0'), ('0', '1'), ('1', 'all'), ('2', '0'), ('2', '1')],
    );
  });

  test('只有有码女支持范围筛选', () {
    expect(ActorListCategory.censoredFemale.supportsFilter, isTrue);
    expect(
      ActorListCategory.values
          .where((category) => category != ActorListCategory.censoredFemale)
          .every((category) => !category.supportsFilter),
      isTrue,
    );
  });

  test('默认范围不编码为请求参数', () {
    expect(const ActorFilter().toQueryParameters(), isEmpty);
  });

  test('只编码偏离默认值的范围', () {
    final filter = const ActorFilter().copyWith(
      age: const ActorRange(20, 40),
      cup: const ActorRange(3, 8),
      hips: const ActorRange(80, 100),
    );

    expect(filter.toQueryParameters(), {
      'age': '20,40',
      'cup': '3,8',
      'hips': '80,100',
    });
  });
}
```

- [ ] **Step 5: 运行筛选模型测试并确认 RED**

Run:

```bash
flutter test test/features/actors/models/actor_filter_test.dart
```

Expected: FAIL，模型文件和类型尚不存在。

- [ ] **Step 6: 实现不可变分类与筛选模型**

创建 `lib/features/actors/models/actor_filter.dart`：

```dart
enum ActorListCategory {
  censoredFemale(type: '0', gender: '0', supportsFilter: true),
  censoredMale(type: '0', gender: '1'),
  uncensored(type: '1', gender: 'all'),
  westernFemale(type: '2', gender: '0'),
  westernMale(type: '2', gender: '1');

  const ActorListCategory({
    required this.type,
    required this.gender,
    this.supportsFilter = false,
  });

  final String type;
  final String gender;
  final bool supportsFilter;
}

class ActorRange {
  const ActorRange(this.min, this.max);

  final int min;
  final int max;

  String get queryValue => '$min,$max';

  @override
  bool operator ==(Object other) =>
      other is ActorRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

class ActorFilter {
  const ActorFilter({
    this.age = defaultAge,
    this.height = defaultHeight,
    this.cup = defaultCup,
    this.bust = defaultBust,
    this.waist = defaultWaist,
    this.hips = defaultHips,
  });

  static const defaultAge = ActorRange(19, 65);
  static const defaultHeight = ActorRange(130, 185);
  static const defaultCup = ActorRange(0, 15);
  static const defaultBust = ActorRange(70, 120);
  static const defaultWaist = ActorRange(50, 90);
  static const defaultHips = ActorRange(70, 120);

  final ActorRange age;
  final ActorRange height;
  final ActorRange cup;
  final ActorRange bust;
  final ActorRange waist;
  final ActorRange hips;

  ActorFilter copyWith({
    ActorRange? age,
    ActorRange? height,
    ActorRange? cup,
    ActorRange? bust,
    ActorRange? waist,
    ActorRange? hips,
  }) => ActorFilter(
    age: age ?? this.age,
    height: height ?? this.height,
    cup: cup ?? this.cup,
    bust: bust ?? this.bust,
    waist: waist ?? this.waist,
    hips: hips ?? this.hips,
  );

  Map<String, dynamic> toQueryParameters() => {
    if (age != defaultAge) 'age': age.queryValue,
    if (height != defaultHeight) 'height': height.queryValue,
    if (cup != defaultCup) 'cup': cup.queryValue,
    if (bust != defaultBust) 'bust': bust.queryValue,
    if (waist != defaultWaist) 'waist': waist.queryValue,
    if (hips != defaultHips) 'hips': hips.queryValue,
  };
}
```

- [ ] **Step 7: 写推荐三分区失败测试**

创建 `test/features/actors/models/actor_recommend_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/actors/models/actor_recommend.dart';

void main() {
  test('ActorRecommend 分别解析三组演员并应用中文名优先级', () {
    final result = ActorRecommend.fromJson({
      'new_actors': [
        {'id': 'n1', 'name': '新人', 'name_zht': '新人中文', 'avatar_url': ''},
      ],
      'monthly_actors': [
        {'id': 'm1', 'name': '月榜', 'avatar_url': ''},
      ],
      'recommend_actors': [
        {'id': 'd1', 'name': 'DMM', 'avatar_url': ''},
      ],
    });

    expect(result.newActors.single.name, '新人中文');
    expect(result.monthlyActors.single.id, 'm1');
    expect(result.recommendActors.single.id, 'd1');
  });
}
```

- [ ] **Step 8: 运行推荐模型测试并确认 RED**

Run:

```bash
flutter test test/features/actors/models/actor_recommend_test.dart
```

Expected: FAIL，`ActorRecommend` 尚不存在。

- [ ] **Step 9: 实现推荐模型并跑 GREEN**

创建 `lib/features/actors/models/actor_recommend.dart`：

```dart
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/network/api_data.dart';

class ActorRecommend {
  const ActorRecommend({
    required this.newActors,
    required this.monthlyActors,
    required this.recommendActors,
  });

  final List<ActorSummary> newActors;
  final List<ActorSummary> monthlyActors;
  final List<ActorSummary> recommendActors;

  factory ActorRecommend.fromJson(Map<String, dynamic> json) {
    List<ActorSummary> parse(String key) => apiList(json, [key])
        .map(normalizeActorSummaryJson)
        .map(ActorSummary.fromJson)
        .toList(growable: false);

    return ActorRecommend(
      newActors: parse('new_actors'),
      monthlyActors: parse('monthly_actors'),
      recommendActors: parse('recommend_actors'),
    );
  }
}
```

Run:

```bash
flutter test test/core/network/api_data_test.dart test/features/actors/models
```

Expected: PASS。

- [ ] **Step 10: 格式化并提交 Task 1**

Run:

```bash
dart format lib/core/network/api_data.dart lib/features/actors/models test/core/network/api_data_test.dart test/features/actors/models
git add lib/core/network/api_data.dart lib/features/actors/models test/core/network/api_data_test.dart test/features/actors/models
git commit -m "feat(actors): add actor filters and recommend model"
```

---

### Task 2: ActorService 接口契约与分页终止规则

**Files:**
- Modify: `lib/features/actors/services/actor_service.dart`
- Modify: `test/api_integration_test.dart`

**Interfaces:**
- Consumes: `ActorListCategory`, `ActorFilter`, `ActorRecommend`
- Produces:

```dart
Future<PagedResult<ActorSummary>> getActors({
  required ActorListCategory category,
  required int page,
  ActorFilter filter = const ActorFilter(),
})

Future<ActorRecommend> getRecommends()
```

- [ ] **Step 1: 将旧演员接口测试改成新契约并确认 RED**

在 `test/api_integration_test.dart` 的 `ActorService` group 中替换演员列表和推荐测试：

```dart
test('GET /api/v1/actors 固定发送分类、性别、页码和 60 条', () async {
  ok(adapter, Endpoints.actors, {
    'actors': [
      {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
    ],
    'current_page': 2,
  });

  final result = await svc.getActors(
    category: ActorListCategory.censoredMale,
    page: 2,
  );

  final query = adapter.requests.last.uri.queryParameters;
  expect(query, containsPair('type', '0'));
  expect(query, containsPair('gender', '1'));
  expect(query, containsPair('page', '2'));
  expect(query, containsPair('limit', '60'));
  expect(result.items.single.name, 'Actor1');
  expect(result.totalPages, 2);
});

test('只有有码女发送非默认筛选范围', () async {
  ok(adapter, Endpoints.actors, {'actors': [], 'current_page': 1});
  final filter = const ActorFilter().copyWith(
    age: const ActorRange(20, 40),
    height: const ActorRange(150, 170),
  );

  await svc.getActors(
    category: ActorListCategory.censoredFemale,
    page: 1,
    filter: filter,
  );

  final query = adapter.requests.last.uri.queryParameters;
  expect(query['age'], '20,40');
  expect(query['height'], '150,170');
  expect(query.containsKey('cup'), isFalse);
});

test('非有码女忽略筛选对象', () async {
  ok(adapter, Endpoints.actors, {'actors': [], 'current_page': 1});

  await svc.getActors(
    category: ActorListCategory.westernFemale,
    page: 1,
    filter: const ActorFilter(age: ActorRange(20, 40)),
  );

  expect(
    adapter.requests.last.uri.queryParameters.containsKey('age'),
    isFalse,
  );
});

test('不足 60 条停止分页，满 60 条允许下一页', () async {
  ok(adapter, Endpoints.actors, {
    'actors': List.generate(
      60,
      (index) => {
        'id': '$index',
        'name': 'Actor $index',
        'avatar_url': '',
      },
    ),
    'current_page': 3,
  });

  final fullPage = await svc.getActors(
    category: ActorListCategory.uncensored,
    page: 3,
  );
  expect(fullPage.totalPages, 4);

  ok(adapter, Endpoints.actors, {
    'actors': [
      {'id': 'last', 'name': 'Last', 'avatar_url': ''},
    ],
    'current_page': 4,
  });
  final lastPage = await svc.getActors(
    category: ActorListCategory.uncensored,
    page: 4,
  );
  expect(lastPage.totalPages, 4);
});

test('GET /api/v1/actors/recommend 保留三个独立分区', () async {
  ok(adapter, Endpoints.actorsRecommend, {
    'new_actors': [
      {'id': 'n1', 'name': '新人', 'avatar_url': ''},
    ],
    'monthly_actors': [
      {'id': 'm1', 'name': '月榜', 'avatar_url': ''},
    ],
    'recommend_actors': [
      {'id': 'd1', 'name': 'DMM', 'avatar_url': ''},
    ],
  });

  final result = await svc.getRecommends();
  expect(result.newActors.single.id, 'n1');
  expect(result.monthlyActors.single.id, 'm1');
  expect(result.recommendActors.single.id, 'd1');
});
```

同时增加 `actor_filter.dart` import。

- [ ] **Step 2: 运行 ActorService 测试并确认 RED**

Run:

```bash
flutter test test/api_integration_test.dart --plain-name "ActorService"
```

Expected: FAIL，旧方法仍接收字符串 `type`、不发送 `page`、返回扁平推荐列表。

- [ ] **Step 3: 最小实现新请求契约**

修改 `lib/features/actors/services/actor_service.dart`：

```dart
Future<PagedResult<ActorSummary>> getActors({
  required ActorListCategory category,
  required int page,
  ActorFilter filter = const ActorFilter(),
}) async {
  final query = <String, dynamic>{
    'type': category.type,
    'gender': category.gender,
    'page': page,
    'limit': 60,
    if (category.supportsFilter) ...filter.toQueryParameters(),
  };
  final response = await _api.get(
    Endpoints.actors,
    queryParameters: query,
  );
  final data = apiMap(response.data);
  final items = apiList(data, const ['actors'])
      .map(normalizeActorSummaryJson)
      .map(ActorSummary.fromJson)
      .toList(growable: false);
  final currentPage = apiInt(data['current_page'], page);
  return PagedResult(
    items: items,
    currentPage: currentPage,
    totalPages: currentPage + (items.length == 60 ? 1 : 0),
    total: apiInt(data['total'], 0),
  );
}

Future<ActorRecommend> getRecommends() async {
  final response = await _api.get(Endpoints.actorsRecommend);
  return ActorRecommend.fromJson(apiMap(response.data));
}
```

保留 `getRankingActors`、`getDetail` 和 `getActorMovies` 的现有公开签名与行为。

- [ ] **Step 4: 运行聚焦测试并确认 GREEN**

Run:

```bash
flutter test test/api_integration_test.dart --plain-name "ActorService"
```

Expected: PASS。

- [ ] **Step 5: 格式化并提交 Task 2**

Run:

```bash
dart format lib/features/actors/services/actor_service.dart test/api_integration_test.dart
git add lib/features/actors/services/actor_service.dart test/api_integration_test.dart
git commit -m "feat(actors): align actor list API contract"
```

---

### Task 3: 全局圆角方形演员头像、卡片与自动加载网格

**Files:**
- Modify: `lib/core/widgets/actor_avatar_image.dart`
- Modify: `lib/core/widgets/actor_card.dart`
- Modify: `lib/core/widgets/actor_grid_view.dart`
- Modify: `lib/features/actors/screens/actor_detail_screen.dart`
- Modify: `test/core/widgets/actor_avatar_image_test.dart`
- Modify: `test/core/widgets/actor_card_test.dart`
- Create: `test/core/widgets/actor_grid_view_test.dart`

**Interfaces:**
- Keeps: `ActorAvatarImage(ActorSummary, {width, height, fit})`
- Keeps: `ActorCard({required actor, onTap})`
- Keeps: `ActorGridView({required controller, onActorTap})`
- Produces: `const Key('actor-grid-tail-loading')`
- Produces: `const Key('actor-grid-tail-retry')`

- [ ] **Step 1: 写全局头像和卡片视觉失败测试**

在 `test/core/widgets/actor_avatar_image_test.dart` 增加：

```dart
testWidgets('演员头像由组件自身使用 8px 圆角裁切', (tester) async {
  const actor = ActorSummary(
    id: 'a1',
    name: '测试演员',
    avatarUrl: 'actors/test.jpg',
  );

  await tester.pumpWidget(
    const MaterialApp(home: SizedBox.square(dimension: 80, child: ActorAvatarImage(actor))),
  );

  final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
  expect(clip.borderRadius, BorderRadius.circular(8));
});
```

在 `test/core/widgets/actor_card_test.dart` 增加：

```dart
testWidgets('ActorCard 使用父级宽度渲染方形头像且名称单行省略', (tester) async {
  const actor = ActorSummary(
    id: 'a1',
    name: '很长很长很长很长的演员名称',
    avatarUrl: 'actors/test.jpg',
  );

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: SizedBox(width: 120, child: ActorCard(actor: actor))),
    ),
  );

  expect(find.byType(AspectRatio), findsOneWidget);
  expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 1);
  final name = tester.widget<Text>(find.text(actor.name));
  expect(name.maxLines, 1);
  expect(name.overflow, TextOverflow.ellipsis);
});
```

- [ ] **Step 2: 运行头像和卡片测试并确认 RED**

Run:

```bash
flutter test test/core/widgets/actor_avatar_image_test.dart test/core/widgets/actor_card_test.dart
```

Expected: FAIL，头像组件没有 `ClipRRect`，卡片仍固定 72×72 并由 `ClipOval` 裁切。

- [ ] **Step 3: 最小实现全局头像与弹性卡片**

将 `ActorAvatarImage.build` 的返回值改为：

```dart
return ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: CachedImage(
    actor.avatarUrl,
    width: width,
    height: height,
    fit: fit,
    fallbackAsset: fallbackAsset,
    semanticLabel: actor.name,
  ),
);
```

将 `ActorCard` 主体改为：

```dart
return Semantics(
  button: onTap != null,
  label: actor.name,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ActorAvatarImage(actor, width: double.infinity, height: double.infinity),
        ),
        const SizedBox(height: 4),
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
);
```

从 `actor_detail_screen.dart` 删除外层 `ClipOval`，保留 84×84 `SizedBox`。

- [ ] **Step 4: 写网格自动加载与页尾重试失败测试**

创建 `test/core/widgets/actor_grid_view_test.dart`，使用真实 `PaginationController<ActorSummary>`：

```dart
testWidgets('滚动接近底部自动加载下一页', (tester) async {
  final requestedPages = <int>[];
  final controller = PaginationController<ActorSummary>(
    fetch: (page) async {
      requestedPages.add(page);
      return PagedResult(
        items: List.generate(
          60,
          (index) => ActorSummary(
            id: '$page-$index',
            name: '演员 $page-$index',
            avatarUrl: '',
          ),
        ),
        currentPage: page,
        totalPages: page + 1,
        total: 120,
      );
    },
  );
  await controller.fetchMore();

  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: ActorGridView(controller: controller))),
  );
  await tester.drag(find.byType(GridView), const Offset(0, -4000));
  await tester.pumpAndSettle();

  expect(requestedPages, [1, 2]);
});

testWidgets('下一页失败时保留演员并显示可重试页尾', (tester) async {
  var attempts = 0;
  final controller = PaginationController<ActorSummary>(
    fetch: (page) async {
      if (page == 2 && attempts++ == 0) throw StateError('下一页失败');
      return PagedResult(
        items: List.generate(
          page == 1 ? 60 : 1,
          (index) => ActorSummary(
            id: '$page-$index',
            name: '演员 $page-$index',
            avatarUrl: '',
          ),
        ),
        currentPage: page,
        totalPages: page == 1 ? 2 : 2,
        total: 61,
      );
    },
  );
  await controller.fetchMore();
  await controller.fetchMore();

  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: ActorGridView(controller: controller))),
  );

  expect(find.text('演员 1-0'), findsOneWidget);
  expect(find.byKey(const Key('actor-grid-tail-retry')), findsOneWidget);
  await tester.tap(find.byKey(const Key('actor-grid-tail-retry')));
  await tester.pumpAndSettle();
  expect(controller.items.length, 61);
});
```

- [ ] **Step 5: 运行网格测试并确认 RED**

Run:

```bash
flutter test test/core/widgets/actor_grid_view_test.dart
```

Expected: FAIL，当前网格没有页尾加载/错误元素，自动加载仅在特定 `ScrollEndNotification` 下工作。

- [ ] **Step 6: 实现响应式三列网格和页尾状态**

修改 `ActorGridView`：

- 用 `LayoutBuilder` 计算列数：

```dart
final crossAxisCount = (constraints.maxWidth / 120).floor().clamp(3, 6);
```

- 使用 `GridView.builder`，间距为 12，水平 padding 为 16，纵向 padding 为 12。
- `itemCount` 为演员数量加一个可选页尾单元。
- `controller.isLoading && controller.items.isNotEmpty` 时显示 key 为 `actor-grid-tail-loading` 的紧凑 `CircularProgressIndicator`。
- `controller.error != null && controller.items.isNotEmpty` 时显示 key 为 `actor-grid-tail-retry` 的 `TextButton`，点击 `controller.fetchMore`。
- `ScrollUpdateNotification` 或 `ScrollEndNotification` 的 `extentAfter < 200` 时调用 `controller.fetchMore()`；控制器自身阻止并发和无更多数据请求。
- 首屏错误继续使用 `ErrorRetryWidget`，空列表保持可下拉刷新的可滚动区域。

- [ ] **Step 7: 运行视觉与网格测试并确认 GREEN**

Run:

```bash
flutter test test/core/widgets/actor_avatar_image_test.dart test/core/widgets/actor_card_test.dart test/core/widgets/actor_grid_view_test.dart
```

Expected: PASS。

- [ ] **Step 8: 格式化并提交 Task 3**

Run:

```bash
dart format lib/core/widgets/actor_avatar_image.dart lib/core/widgets/actor_card.dart lib/core/widgets/actor_grid_view.dart lib/features/actors/screens/actor_detail_screen.dart test/core/widgets/actor_avatar_image_test.dart test/core/widgets/actor_card_test.dart test/core/widgets/actor_grid_view_test.dart
git add lib/core/widgets/actor_avatar_image.dart lib/core/widgets/actor_card.dart lib/core/widgets/actor_grid_view.dart lib/features/actors/screens/actor_detail_screen.dart test/core/widgets/actor_avatar_image_test.dart test/core/widgets/actor_card_test.dart test/core/widgets/actor_grid_view_test.dart
git commit -m "feat(actors): use rounded square actor cards"
```

---

### Task 4: 紧凑演员筛选底部面板

**Files:**
- Create: `lib/features/actors/widgets/actor_filter_sheet.dart`
- Create: `test/features/actors/actor_filter_sheet_test.dart`

**Interfaces:**
- Produces:

```dart
class ActorFilterSheet extends StatefulWidget {
  const ActorFilterSheet({
    super.key,
    required this.initialValue,
  });

  final ActorFilter initialValue;
}
```

- Returns: `Navigator.pop<ActorFilter>(context, draft)` on apply.
- Returns: `null` when dismissed without apply.

- [ ] **Step 1: 写筛选面板交互失败测试**

创建 `test/features/actors/actor_filter_sheet_test.dart`：

```dart
testWidgets('筛选面板紧凑展示六个范围并可重置', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: ActorFilterSheet(
          initialValue: ActorFilter(age: ActorRange(20, 40)),
        ),
      ),
    ),
  );

  for (final label in ['年龄', '身高', '罩杯', '胸围', '腰围', '臀围']) {
    expect(find.text(label), findsOneWidget);
  }
  expect(find.text('20–40'), findsOneWidget);
  await tester.tap(find.text('重置'));
  await tester.pump();
  expect(find.text('19–65'), findsOneWidget);
  expect(find.text('A–P'), findsOneWidget);
});

testWidgets('应用返回草稿筛选，系统返回不应用', (tester) async {
  ActorFilter? applied;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            applied = await showModalBottomSheet<ActorFilter>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const ActorFilterSheet(
                initialValue: ActorFilter(),
              ),
            );
          },
          child: const Text('打开'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('应用筛选'));
  await tester.pumpAndSettle();
  expect(applied, const ActorFilter());
});
```

为 `ActorFilter` 增加值相等测试所需的 `==` 与 `hashCode`，覆盖六个范围。

- [ ] **Step 2: 运行面板测试并确认 RED**

Run:

```bash
flutter test test/features/actors/actor_filter_sheet_test.dart
```

Expected: FAIL，组件尚不存在。

- [ ] **Step 3: 实现筛选草稿、重置和应用**

实现 `ActorFilterSheet`：

- State 初始化 `_draft = widget.initialValue`。
- 使用 `DraggableScrollableSheet(expand: false, initialChildSize: 0.72, minChildSize: 0.45, maxChildSize: 0.94)`。
- 顶部 `Row` 显示标题“筛选”和 `TextButton`“重置”。
- 内容使用 `ListView.separated`，六行统一由私有 `_ActorRangeRow` 渲染。
- `_ActorRangeRow` 使用 `RangeSlider(divisions: max - min)`，`onChanged` 将 double 端点 round 为 int。
- 范围文本使用 `Text('19–65')` 形式；罩杯通过：

```dart
String cupLabel(ActorRange range) =>
    '${String.fromCharCode(65 + range.min)}–${String.fromCharCode(65 + range.max)}';
```

- 底部 `FilledButton` 文案“应用筛选”，点击：

```dart
Navigator.of(context).pop(_draft);
```

- 为六个滑杆设置 `Semantics(label: '年龄筛选')` 等明确标签。
- 使用 8–12px 的行间距和紧凑垂直 padding，不引入额外 Card 或 ExpansionTile。

- [ ] **Step 4: 运行面板和模型测试并确认 GREEN**

Run:

```bash
flutter test test/features/actors/actor_filter_sheet_test.dart test/features/actors/models/actor_filter_test.dart
```

Expected: PASS。

- [ ] **Step 5: 格式化并提交 Task 4**

Run:

```bash
dart format lib/features/actors/models/actor_filter.dart lib/features/actors/widgets/actor_filter_sheet.dart test/features/actors/actor_filter_sheet_test.dart
git add lib/features/actors/models/actor_filter.dart lib/features/actors/widgets/actor_filter_sheet.dart test/features/actors/actor_filter_sheet_test.dart
git commit -m "feat(actors): add compact actor filter sheet"
```

---

### Task 5: 推荐页与五个独立分类 Tab

**Files:**
- Modify: `lib/features/actors/screens/actors_screen.dart`
- Modify: `test/features/actors/actors_screen_test.dart`
- Verify: `test/core/widgets/section_header_test.dart`
- Verify: `test/core/router/app_router_requirements_test.dart`

**Interfaces:**
- Changes:

```dart
class ActorsPage extends StatefulWidget {
  const ActorsPage({
    super.key,
    this.service,
  });

  final ActorService? service;
}
```

- Uses: `ActorListCategory`, `ActorFilter`, `ActorRecommend`, `ActorFilterSheet`
- Keeps: zero-argument `const ActorsPage()` for router compatibility.

- [ ] **Step 1: 建立可注入真实 Service 的测试辅助**

在 `test/features/actors/actors_screen_test.dart` 使用 `FakeAdapter`、`ApiClient.forTest` 和 `ResponseInterceptor` 创建 `ActorService`。测试不再创建 `AuthProvider`，因为推荐页不依赖登录状态。

辅助签名：

```dart
Future<({ActorService service, FakeAdapter adapter})> createActorService()
```

该辅助初始化 mock `SharedPreferences`、`DomainManager`、Dio 和响应解包拦截器。

- [ ] **Step 2: 写推荐分区和未登录访问失败测试**

```dart
testWidgets('未登录推荐页展示三个独立推荐分区', (tester) async {
  final fixture = await createActorService();
  fixture.adapter.enqueue(Endpoints.actorsRecommend, {
    'success': 1,
    'data': {
      'new_actors': [
        {'id': 'n1', 'name': '新人演员', 'avatar_url': ''},
      ],
      'monthly_actors': [
        {'id': 'm1', 'name': '月榜演员', 'avatar_url': ''},
      ],
      'recommend_actors': [
        {'id': 'd1', 'name': 'DMM演员', 'avatar_url': ''},
      ],
    },
  });

  await tester.pumpWidget(
    MaterialApp(home: ActorsPage(service: fixture.service)),
  );
  await tester.pumpAndSettle();

  expect(find.text('登录后可查看演员推荐'), findsNothing);
  expect(find.text('新人演员'), findsOneWidget);
  expect(find.text('月榜演员'), findsOneWidget);
  expect(find.text('DMM演员'), findsOneWidget);
  expect(find.text('全部'), findsOneWidget);
  expect(find.byIcon(Icons.chevron_right), findsOneWidget);
});
```

- [ ] **Step 3: 写筛选仅有码女可见和请求刷新失败测试**

```dart
testWidgets('筛选入口仅在有码女显示并应用后重载第 1 页', (tester) async {
  final fixture = await createActorService();
  fixture.adapter.enqueue(Endpoints.actorsRecommend, {
    'success': 1,
    'data': {
      'new_actors': [],
      'monthly_actors': [],
      'recommend_actors': [],
    },
  });
  fixture.adapter.enqueue(Endpoints.actors, {
    'success': 1,
    'data': {'actors': [], 'current_page': 1},
  });

  await tester.pumpWidget(
    MaterialApp(home: ActorsPage(service: fixture.service)),
  );
  await tester.tap(find.text('有码(女)'));
  await tester.pumpAndSettle();

  expect(find.byTooltip('筛选演员'), findsOneWidget);
  await tester.tap(find.byTooltip('筛选演员'));
  await tester.pumpAndSettle();
  expect(find.text('年龄'), findsOneWidget);
  await tester.tap(find.text('应用筛选'));
  await tester.pumpAndSettle();

  final actorRequests = fixture.adapter.requests
      .where((request) => request.path == Endpoints.actors)
      .toList();
  expect(actorRequests.last.uri.queryParameters['page'], '1');

  await tester.tap(find.text('有码(男)'));
  await tester.pumpAndSettle();
  expect(find.byTooltip('筛选演员'), findsNothing);
});
```

- [ ] **Step 4: 运行页面测试并确认 RED**

Run:

```bash
flutter test test/features/actors/actors_screen_test.dart
```

Expected: FAIL，页面仍依赖登录、推荐数组被展平、分类类型为旧字符串、筛选使用嵌套 Drawer。

- [ ] **Step 5: 重组 ActorsPage**

在 `actors_screen.dart` 实现：

1. `ActorsPage.service` 可选注入；未注入时从 `ApiClient.instanceOrNull` 创建 `ActorService`。
2. 推荐 Tab 接收同一个可选 Service，不读取 `AuthProvider`。
3. 推荐 Tab 用 `ActorRecommend? _data`、`bool _loading`、`Object? _error` 管理状态。
4. `SectionHeader(title: '月排名', trailing: '全部', onTrailing: () {})`。
5. 三个推荐分区分别使用：

```dart
_actorSliverGrid(data.newActors)
_actorSliverGrid(data.monthlyActors)
_actorSliverGrid(data.recommendActors)
```

6. `_actorSliverGrid` 使用 `SliverLayoutBuilder` 和共享 `ActorCard`，手机端至少三列。
7. 五个 `_ActorListTab` 分别接收一个 `ActorListCategory`。
8. 每个 `_ActorListTabState` 创建并在 `dispose` 中释放自己的 `PaginationController`。
9. 控制器 fetch 闭包调用：

```dart
service.getActors(
  category: widget.category,
  page: page,
  filter: _filter,
)
```

10. 只有 `category.supportsFilter` 时，在网格上方用右对齐 `IconButton` 显示 tooltip“筛选演员”。
11. 打开筛选：

```dart
final next = await showModalBottomSheet<ActorFilter>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ActorFilterSheet(initialValue: _filter),
);
if (!mounted || next == null || next == _filter) return;
setState(() => _filter = next);
await _controller.reloadWith(_fetchPage, preserveItems: true);
```

12. `TabBarView` 中所有分类 Tab 都使用 `AutomaticKeepAliveClientMixin`，并在 `build` 中调用 `super.build(context)`。
13. 推荐加载完成与失败分支在 `setState` 前检查 `mounted`。
14. Service 不可用时返回清晰错误状态，不在 build 中抛出空指针。

- [ ] **Step 6: 运行页面、SectionHeader 和路由测试并确认 GREEN**

Run:

```bash
flutter test test/features/actors/actors_screen_test.dart test/core/widgets/section_header_test.dart test/core/router/app_router_requirements_test.dart
```

Expected: PASS。

- [ ] **Step 7: 格式化并提交 Task 5**

Run:

```bash
dart format lib/features/actors/screens/actors_screen.dart test/features/actors/actors_screen_test.dart
git add lib/features/actors/screens/actors_screen.dart test/features/actors/actors_screen_test.dart
git commit -m "feat(actors): redesign actor browsing page"
```

---

### Task 6: 消费者回归、静态分析与完整验证

**Files:**
- Verify: `lib/features/search/screens/search_screen.dart`
- Verify: `lib/features/profile/screens/profile_sub_pages.dart`
- Verify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Verify: `test/features/movie_detail/movie_detail_screen_test.dart`
- Verify: `test/features/profile/profile_sub_pages_test.dart`
- Verify: all modified files

**Interfaces:**
- No new public API.
- Confirms all existing `ActorCard` and `ActorGridView` consumers compile and render with flexible square cards.

- [ ] **Step 1: 运行所有演员相关聚焦测试**

Run:

```bash
flutter test test/core/network/api_data_test.dart test/core/widgets/actor_avatar_image_test.dart test/core/widgets/actor_card_test.dart test/core/widgets/actor_grid_view_test.dart test/core/widgets/section_header_test.dart test/features/actors test/api_integration_test.dart
```

Expected: PASS，输出无异常和测试框架错误。

- [ ] **Step 2: 运行受全局演员组件影响的消费者测试**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_screen_test.dart test/features/profile/profile_sub_pages_test.dart test/core/router/app_router_requirements_test.dart
```

Expected: PASS。若现有固定高度因方形卡片产生 overflow，只调整对应消费者容器高度，使其容纳“方形头像 + 4px + 单行名称”，不得恢复圆形或固定 72×72 头像。

- [ ] **Step 3: 运行完整测试**

Run:

```bash
flutter test
```

Expected: 全部 PASS。

- [ ] **Step 4: 运行静态分析**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`。若 Flutter SDK 缓存目录写入被沙箱拒绝，使用已批准的 Flutter 命令权限重跑，不修改项目代码规避环境问题。

- [ ] **Step 5: 格式与差异检查**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
git diff --check
git status --short
```

Expected:

- Dart 格式检查退出码 0。
- `git diff --check` 无输出。
- `git status --short` 只包含本计划相关文件。

- [ ] **Step 6: 最终范围审计**

逐项核对：

- 推荐页无登录限制。
- 三个推荐数组没有混用。
- 五个分类请求映射准确。
- `limit=60`、`page` 和默认筛选省略规则准确。
- 仅有码女显示筛选入口。
- 月排名显示 `SectionHeader` 的“全部 >”且不跳转。
- 所有演员名称使用 `name_zht > name`。
- 演员详情、搜索、收藏、影片详情均使用圆角方形全局头像。
- 不存在 `ClipOval(child: ActorAvatarImage(...))`。

Run:

```bash
rg -n "ClipOval.*ActorAvatarImage|ActorAvatarImage.*ClipOval" lib
```

Expected: 无匹配。

- [ ] **Step 7: 提交验证中产生的必要消费者调整**

仅当 Step 2 或静态分析要求修改消费者布局时执行：

```bash
git add lib/features/search/screens/search_screen.dart lib/features/profile/screens/profile_sub_pages.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "fix(actors): align actor card consumers"
```

若没有额外修改，跳过本提交。

---

## Plan Self-Review

- Spec coverage: 推荐分区、未登录访问、分类映射、自动分页、筛选参数、紧凑面板、全局头像、`name_zht` 优先级、`SectionHeader` 尾部入口和验证均有对应任务。
- Placeholder scan: 无占位标记、延后实现语句或未定义类型；“月排名”跳转明确排除在本次范围外。
- Type consistency: `ActorListCategory`、`ActorRange`、`ActorFilter`、`ActorRecommend`、`ActorService.getActors` 与页面调用签名一致。
- Scope: 不新增依赖，不修改 `SectionHeader` 公开 API，不扩展到演员搜索功能。
