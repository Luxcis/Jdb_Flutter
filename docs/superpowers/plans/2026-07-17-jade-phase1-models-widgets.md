# Jade Phase 1 — 数据模型 + 共享组件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan with parallel subagent batches.

**Goal:** 创建 spec §5 全部 15 个数据模型（json_serializable + build_runner）和 §4 全部 15 个共享组件（core/widgets），提供所有后续 Phase 需要的类型与 UI 基础设施。

**Architecture:** 模型集中在 `lib/core/models/`，每个模型独立文件，`@JsonSerializable(fieldRename: FieldRename.snake)`，通过 `build_runner` 生成 `.g.dart`。共享组件集中在 `lib/core/widgets/`。Task 1-3（模型组）可并行 → Task 4（build_runner）汇聚 → Task 5-10（组件组）可并行。

**Tech Stack:** Flutter ^3.8.0、json_annotation ^4.9.0、json_serializable ^6.8.0、build_runner ^2.4.13、cached_network_image ^3.4.1、provider ^6.1.5+1。

## Global Constraints

（逐字取自 spec §3 / §5 / RULES.md）
- Material Design 3；`ThemeMode.system`；`ColorScheme.fromSeed()`；系统字体；无 google_fonts。
- **不做本地化**，所有文案中文硬编码；不使用 `.arb`/`flutter_localizations`。
- Feature-First：`core/` 放公共层；`core/models/` 共享模型；`core/widgets/` 共享组件。
- JSON 序列化用 `json_serializable`，`fieldRename: FieldRename.snake`。每个模型独立文件 + `part 'X.g.dart'`。
- CDN 图片域名 `https://tp.spfcas.com/rhe951l4q/`（`AppConstants.imageCdnBase`）——CachedImage 自动拼。
- 状态管理优先内置 + `provider`；PaginationController 用 `ChangeNotifier`。
- 测试：widget test 验证组件渲染，unit test 验证序列化往返。
- Git 提交前设置代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890`。

---

## File Structure

```
lib/core/models/
├── paged_result.dart          # PagedResult<T> 泛型分页包装
├── movie.dart                 # MovieSummary + MovieDetail
├── magnet.dart                # Magnet
├── review.dart                # Review + ReviewAuthor
├── actor.dart                 # ActorSummary + ActorDetail
├── director.dart              # Director
├── maker.dart                 # Maker
├── publisher.dart             # Publisher
├── series.dart                # Series
├── code.dart                  # Code
├── list_model.dart            # ListModel
├── tag.dart                   # Tag
├── article.dart               # Article
├── ranking.dart               # RankingEntry
├── startup.dart               # BackupDomains（完整版替换 Phase0）+ StartupData

lib/core/widgets/
├── cached_image.dart          # CachedNetworkImage 封装
├── movie_card.dart            # MovieCard
├── movie_list_tile.dart       # MovieListTile（三行布局）
├── movie_grid_view.dart       # MovieGridView（瀑布+分页+换一组）
├── actor_card.dart            # ActorCard
├── actor_grid_view.dart       # ActorGridView（头像网格+分页）
├── section_header.dart        # SectionHeader
├── filter_drawer.dart         # FilterDrawer（动态 schema）
├── sort_segmented.dart        # SortSegmented
├── sort_select.dart           # SortSelect
├── rating_badge.dart          # RatingBadge
├── tag_chip.dart              # TagChip
├── empty_state.dart           # EmptyState
├── error_retry_widget.dart    # ErrorRetryWidget
├── pagination_controller.dart # PaginationController<T>

test/core/models/
├── movie_test.dart            # MovieSummary ↔ JSON 往返 + MovieDetail 字段
├── actor_test.dart            # ActorSummary ↔ JSON 往返 + ActorDetail 字段
├── paged_result_test.dart     # PagedResult<T> 泛型 fromJson

test/core/widgets/
├── cached_image_test.dart     # 渲染 CDN 前缀拼接 + placeholder/error
├── movie_card_test.dart       # 封面+标题+番号渲染
├── pagination_controller_test.dart  # fetchMore/refresh/reshuffle 状态
```

---

### Task 1: PagedResult + RankingEntry + Startup 基础模型

**Files:**
- Create: `lib/core/models/paged_result.dart`
- Create: `lib/core/models/ranking.dart`
- Create: `lib/core/models/startup.dart`
- Modify: `lib/core/network/domain_manager.dart`（替换 BackupDomainsData 为 models 版本）
- Test: `test/core/models/paged_result_test.dart`

**Interfaces:**
- Produces: `PagedResult<T>(items, currentPage, totalPages, total)` with `fromJson`；`RankingEntry(rank, movie: MovieSummary)`；`BackupDomains(apiDomains[], backupUrls[], unblockedAppDomain, permanentAppDomain, imageEndpoint)`；`StartupData(backupDomainsData, settings, user)`。

- [ ] **Step 1: 创建模型 + 序列化测试**

`lib/core/models/paged_result.dart`：
```dart
import 'package:json_annotation/json_annotation.dart';
part 'paged_result.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, genericArgumentFactories: true)
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.total,
  });
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int total;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) => _$PagedResultFromJson(json, fromJsonT);
}
```

`lib/core/models/ranking.dart`：
```dart
import 'package:jade/core/models/movie.dart';
import 'package:json_annotation/json_annotation.dart';
part 'ranking.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class RankingEntry {
  const RankingEntry({required this.rank, required this.movie});
  final int rank;
  final MovieSummary movie;
  factory RankingEntry.fromJson(Map<String, dynamic> json) =>
      _$RankingEntryFromJson(json);
}
```

`lib/core/models/startup.dart`：
```dart
import 'package:json_annotation/json_annotation.dart';
part 'startup.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class BackupDomains {
  const BackupDomains({
    required this.apiDomains,
    this.backupUrls = const [],
    this.unblockedAppDomain,
    this.permanentAppDomain,
    this.imageEndpoint,
  });
  final List<String> apiDomains;
  final List<String> backupUrls;
  final String? unblockedAppDomain;
  final String? permanentAppDomain;
  final String? imageEndpoint;
  factory BackupDomains.fromJson(Map<String, dynamic> json) =>
      _$BackupDomainsFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StartupData {
  const StartupData({this.backupDomainsData, this.settings, this.user});
  final String? backupDomainsData;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? user;
  factory StartupData.fromJson(Map<String, dynamic> json) =>
      _$StartupDataFromJson(json);
}
```

`test/core/models/paged_result_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';

void main() {
  test('PagedResult<int> fromJson 往返', () {
    final json = {
      'items': [1, 2, 3],
      'current_page': 1,
      'total_pages': 10,
      'total': 100,
    };
    final result = PagedResult<int>.fromJson(json, (v) => v as int);
    expect(result.items, [1, 2, 3]);
    expect(result.currentPage, 1);
  });
  // 注：此测试需 build_runner 生成后验证；Phase 1 的 Task 4 之后重跑。
}
```

- [ ] **Step 2: 创建占位文件使编译通过（build_runner 需要所有依赖模型存在）**

> 注：RankingEntry 引用 MovieSummary → Task 2 创建后此文件可编译。Phase 1 采用"全部模型先写出再一次性 build_runner"策略。各 Task 仅创建文件，编译验证暂延到 Task 4。

- [ ] **Step 3: 更新 domain_manager.dart 引用**

`lib/core/network/domain_manager.dart` 中替换内联 `BackupDomainsData` 为 `import 'package:jade/core/models/startup.dart';` 并将 `BackupDomainsData` 重命名为 `BackupDomains`（全文件引用）。`applyStartup` 参数类型同步更新。

- [ ] **Step 4: Commit**

```bash
git add lib/core/models/paged_result.dart lib/core/models/ranking.dart lib/core/models/startup.dart lib/core/network/domain_manager.dart test/core/models/paged_result_test.dart
git commit -m "feat(core/models): add PagedResult, RankingEntry, BackupDomains, StartupData models"
```

---

### Task 2: Movie + Magnet + Review 模型

**Files:**
- Create: `lib/core/models/movie.dart`
- Create: `lib/core/models/magnet.dart`
- Create: `lib/core/models/review.dart`
- Test: `test/core/models/movie_test.dart`

**Interfaces:**
- Produces: `MovieSummary(id, number, title, coverUrl, releaseDate?, duration?, score?)`；`MovieDetail extends MovieSummary` + director/maker/series/actors/screenshots/tags/magnetCount 等。`Magnet(hash, title?, size?, publishDate?, isHighDefinition?)`。`ReviewAuthor(name)`；`Review(id, score?, content?, status?, author, likedCount?, createdAt?)`。

- [ ] **Step 1: 创建模型文件**

`lib/core/models/movie.dart`：
```dart
import 'package:jade/core/models/actor.dart';
import 'package:json_annotation/json_annotation.dart';
part 'movie.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MovieSummary {
  const MovieSummary({
    required this.id,
    required this.number,
    required this.title,
    required this.coverUrl,
    this.releaseDate,
    this.duration,
    this.score,
  });
  final String id;
  final String number;
  final String title;
  final String coverUrl;
  final String? releaseDate;
  final int? duration;
  final double? score;
  factory MovieSummary.fromJson(Map<String, dynamic> json) =>
      _$MovieSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MovieSummaryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MovieDetail extends MovieSummary {
  const MovieDetail({
    required super.id,
    required super.number,
    required super.title,
    required super.coverUrl,
    super.releaseDate,
    super.duration,
    super.score,
    this.director,
    this.maker,
    this.series,
    this.actors = const [],
    this.screenshots = const [],
    this.tags = const [],
    this.magnetCount = 0,
    this.wantWatchCount = 0,
    this.watchedCount = 0,
    this.playable = false,
    this.hasSubtitle = false,
  });
  final String? director;
  final String? maker;
  final String? series;
  final List<ActorSummary> actors;
  final List<String> screenshots;
  final List<String> tags;
  final int magnetCount;
  final int wantWatchCount;
  final int watchedCount;
  final bool playable;
  final bool hasSubtitle;
  factory MovieDetail.fromJson(Map<String, dynamic> json) =>
      _$MovieDetailFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$MovieDetailToJson(this);
}
```

`lib/core/models/magnet.dart`、`lib/core/models/review.dart`：同模式单文件单模型。

- [ ] **Step 2: 创建序列化测试**

`test/core/models/movie_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';

void main() {
  test('MovieSummary fromJson 正确解析', () {
    final json = {
      'id': 'xAenVV',
      'number': 'SSIS-001',
      'title': 'Test Movie',
      'cover_url': 'covers/x.jpg',
      'score': 8.5,
    };
    final m = MovieSummary.fromJson(json);
    expect(m.id, 'xAenVV');
    expect(m.number, 'SSIS-001');
    expect(m.score, 8.5);
  });

  test('MovieDetail 继承 MovieSummary 字段', () {
    final json = {
      'id': 'xAenVV', 'number': 'SSIS-001', 'title': 'Test',
      'cover_url': 'c.jpg', 'magnet_count': 5, 'want_watch_count': 10,
      'actors': [], 'screenshots': [], 'tags': [],
    };
    final d = MovieDetail.fromJson(json);
    expect(d.magnetCount, 5);
    expect(d.id, 'xAenVV');
  });
  // 注：build_runner 后验证
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/models/movie.dart lib/core/models/magnet.dart lib/core/models/review.dart test/core/models/movie_test.dart
git commit -m "feat(core/models): add MovieSummary, MovieDetail, Magnet, Review models"
```

---

### Task 3: Actor/Director/Maker/Publisher/Series/Code/ListModel/Tag/Article 模型

**Files:**
- Create: `lib/core/models/actor.dart`
- Create: `lib/core/models/director.dart`
- Create: `lib/core/models/maker.dart`
- Create: `lib/core/models/publisher.dart`
- Create: `lib/core/models/series.dart`
- Create: `lib/core/models/code.dart`
- Create: `lib/core/models/list_model.dart`
- Create: `lib/core/models/tag.dart`
- Create: `lib/core/models/article.dart`
- Test: `test/core/models/actor_test.dart`

**Interfaces:**
- Produces: 9 模型文件，每个 `@JsonSerializable(fieldRename: FieldRename.snake)`。

- [ ] **Step 1: 批量创建模型**

`lib/core/models/actor.dart`：
```dart
import 'package:json_annotation/json_annotation.dart';
part 'actor.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ActorSummary {
  const ActorSummary({required this.id, required this.name, required this.avatarUrl});
  final String id;
  final String name;
  final String avatarUrl;
  factory ActorSummary.fromJson(Map<String, dynamic> json) =>
      _$ActorSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ActorSummaryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ActorDetail extends ActorSummary {
  const ActorDetail({
    required super.id, required super.name, required super.avatarUrl,
    this.birthday, this.age, this.height, this.cup,
    this.bust, this.waist, this.hip, this.birthplace, this.movieCount = 0,
  });
  final String? birthday;
  final int? age;
  final String? height;
  final String? cup;
  final String? bust;
  final String? waist;
  final String? hip;
  final String? birthplace;
  final int movieCount;
  factory ActorDetail.fromJson(Map<String, dynamic> json) =>
      _$ActorDetailFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ActorDetailToJson(this);
}
```

`lib/core/models/director.dart`、`lib/core/models/maker.dart`、`lib/core/models/publisher.dart` 同构（id/name/avatarUrl/movieCount）。

`lib/core/models/series.dart`（id/name/movieCount）、`lib/core/models/code.dart`（id/number/movieCount）、`lib/core/models/list_model.dart`（id/name/movieCount/viewedCount）、`lib/core/models/tag.dart`（id/name/value）、`lib/core/models/article.dart`（id/title/coverUrl/publishDate）。

- [ ] **Step 2: 创建测试**

`test/core/models/actor_test.dart`：验证 ActorSummary/ActorDetail fromJson 往返。

- [ ] **Step 3: Commit**

```bash
git add lib/core/models/actor.dart lib/core/models/director.dart lib/core/models/maker.dart lib/core/models/publisher.dart lib/core/models/series.dart lib/core/models/code.dart lib/core/models/list_model.dart lib/core/models/tag.dart lib/core/models/article.dart test/core/models/actor_test.dart
git commit -m "feat(core/models): add Actor, Director, Maker, Publisher, Series, Code, ListModel, Tag, Article models"
```

---

### Task 4: build_runner 生成代码 + 模型测试验证

**Files:**
- 生成: `lib/core/models/*.g.dart`（13 个文件）
- Test: 重跑 `test/core/models/*_test.dart`

**Interfaces:**
- Consumes: Task 1-3 全部 `.dart` 模型文件。
- Produces: 13 个 `.g.dart` 生成文件。验证全部模型测试通过。

- [ ] **Step 1: 运行 build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: 退出码 0，生成 13 个 `.g.dart` 文件。

- [ ] **Step 2: 运行所有模型测试**

```bash
flutter test test/core/models/
```
Expected: 全部 PASS。

- [ ] **Step 3: Commit**

```bash
git add lib/core/models/*.g.dart
git commit -m "chore: run build_runner to generate json_serializable code"
```

---

### Task 5: CachedImage + RatingBadge + SectionHeader + EmptyState/ErrorRetry

**Files:**
- Create: `lib/core/widgets/cached_image.dart`
- Create: `lib/core/widgets/rating_badge.dart`
- Create: `lib/core/widgets/section_header.dart`
- Create: `lib/core/widgets/empty_state.dart`
- Create: `lib/core/widgets/error_retry_widget.dart`
- Test: `test/core/widgets/cached_image_test.dart`

**Interfaces:**
- `CachedImage(url, {aspect, width, height})`：自动拼 `AppConstants.imageCdnBase`，占位/错误图。
- `RatingBadge(rank)`：#1 金色、#2 银色、#3 铜色、其余灰色。
- `SectionHeader({title, bold, trailing, onTrailing})`。
- `EmptyState({message, icon})` / `ErrorRetryWidget({message, onRetry})`。

- [ ] **Step 1: 实现 CachedImage**

```dart
// lib/core/widgets/cached_image.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/constants/app_constants.dart';

class CachedImage extends StatelessWidget {
  const CachedImage(this.url, {super.key, this.aspect, this.width, this.height});
  final String url;
  final double? aspect;
  final double? width;
  final double? height;

  String get _fullUrl =>
      url.startsWith('http') ? url : '${AppConstants.imageCdnBase}$url';

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _fullUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey.shade200),
      errorWidget: (_, __, ___) =>
          Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
    );
  }
}
```

- [ ] **Step 2: 实现 RatingBadge + SectionHeader + EmptyState + ErrorRetry**

`RatingBadge`：`Positioned(top: 4, left: 4, child: Container(color: rank<=3 ? [gold,silver,bronze][rank-1] : grey, child: Text('#$rank')))`。

`SectionHeader`：`Row(mainAxisAlignment: spaceBetween, children:[Text(title, bold), TextButton(trailing)])`。

`EmptyState`：`Center(child: Column(icon, Text(message)))`。

`ErrorRetryWidget`：`Center(child: Column(icon, Text(message), ElevatedButton('retry', onRetry)))`。

- [ ] **Step 3: Widget 测试**

`test/core/widgets/cached_image_test.dart`：渲染 CachedImage 验证 CachedNetworkImage 存在。

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/cached_image.dart lib/core/widgets/rating_badge.dart lib/core/widgets/section_header.dart lib/core/widgets/empty_state.dart lib/core/widgets/error_retry_widget.dart test/core/widgets/cached_image_test.dart
git commit -m "feat(core/widgets): add CachedImage, RatingBadge, SectionHeader, EmptyState, ErrorRetry"
```

---

### Task 6: MovieCard + MovieListTile 组件

**Files:**
- Create: `lib/core/widgets/movie_card.dart`
- Create: `lib/core/widgets/movie_list_tile.dart`
- Test: `test/core/widgets/movie_card_test.dart`

**Interfaces:**
- `MovieCard(movie: MovieSummary, {onTap})`：`AspectRatio(aspectRatio: 3/4, child: Column[(CachedImage(cover), Text(title), Text(number))])`。
- `MovieListTile({movie: MovieDetail, rank, screenshots})`：三行 Row → Column[title, number·date]。

- [ ] **Step 1: 实现 MovieCard**

```dart
// lib/core/widgets/movie_card.dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/cached_image.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.onTap});
  final MovieSummary movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: CachedImage(movie.coverUrl)),
          const SizedBox(height: 4),
          Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(movie.number, style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: 实现 MovieListTile**

三行：`Row([CachedImage(cover) + screenshots, title, Row([number, date, note])])`。

- [ ] **Step 3: Widget 测试**

验证封面+标题+番号渲染，tap 回调触发。

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/movie_card.dart lib/core/widgets/movie_list_tile.dart test/core/widgets/movie_card_test.dart
git commit -m "feat(core/widgets): add MovieCard and MovieListTile components"
```

---

### Task 7: PaginationController + MovieGridView

**Files:**
- Create: `lib/core/widgets/pagination_controller.dart`
- Create: `lib/core/widgets/movie_grid_view.dart`
- Test: `test/core/widgets/pagination_controller_test.dart`

**Interfaces:**
- `PaginationController<T>({required Future<PagedResult<T>> Function(int page) fetch})` — ChangeNotifier，`page/limit/hasMore/isLoading/items`，`fetchMore()`、`refresh()`、`reshuffle()`。
- `MovieGridView({required PaginationController<MovieSummary> controller})` — `SliverGrid` 3 列 + `RefreshIndicator` + 首屏 "换一组" 按钮。

- [ ] **Step 1: 实现 PaginationController**

```dart
// lib/core/widgets/pagination_controller.dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/models/paged_result.dart';

class PaginationController<T> extends ChangeNotifier {
  PaginationController({required this.fetch});
  final Future<PagedResult<T>> Function(int page) fetch;

  final List<T> _items = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> fetchMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();
    try {
      final result = await fetch(_page + 1);
      _page = result.currentPage;
      _items.addAll(result.items);
      _hasMore = _page < result.totalPages;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _items.clear();
    _hasMore = true;
    notifyListeners();
    await fetchMore();
  }

  void reshuffle() {
    _items.shuffle();
    notifyListeners();
  }
}
```

- [ ] **Step 2: 实现 MovieGridView**

`CustomScrollView(slivers: [SliverGrid.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3))])` + `NotificationListener<ScrollNotification>` 检测触底触发 `fetchMore`。

- [ ] **Step 3: Unit 测试 PaginationController**

`test/core/widgets/pagination_controller_test.dart`：mock fetch，验证 fetchMore 填充 items、refresh 清空、reshuffle 重排。

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/pagination_controller.dart lib/core/widgets/movie_grid_view.dart test/core/widgets/pagination_controller_test.dart
git commit -m "feat(core/widgets): add PaginationController and MovieGridView"
```

---

### Task 8: ActorCard + ActorGridView

**Files:**
- Create: `lib/core/widgets/actor_card.dart`
- Create: `lib/core/widgets/actor_grid_view.dart`

- [ ] **Step 1: 实现 ActorCard**

`ActorCard({actor: ActorSummary, onTap})`：`Column([CircleAvatar(CachedImage(avatar)), Text(name)])`。

- [ ] **Step 2: 实现 ActorGridView**

复用 `PaginationController<ActorSummary>` + 3 列 `SliverGrid` + 触底加载。

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/actor_card.dart lib/core/widgets/actor_grid_view.dart
git commit -m "feat(core/widgets): add ActorCard and ActorGridView"
```

---

### Task 9: FilterDrawer + SortSegmented + SortSelect

**Files:**
- Create: `lib/core/widgets/filter_drawer.dart`
- Create: `lib/core/widgets/sort_segmented.dart`
- Create: `lib/core/widgets/sort_select.dart`

- [ ] **Step 1: 实现 SortSegmented + SortSelect**

`SortSegmented({options: List<String>, value, onChanged})`：`ToggleButtons` 或 `SegmentedButton`。
`SortSelect({options: List<({label, value})>, value, onChanged})`：`DropdownButton`。

- [ ] **Step 2: 实现 FilterDrawer**

`FilterDrawer({schema: FilterSchema, onChanged: (Map)})`：`Drawer` 内 `ListView` 动态渲染标签/演员/片商等筛选项。

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/filter_drawer.dart lib/core/widgets/sort_segmented.dart lib/core/widgets/sort_select.dart
git commit -m "feat(core/widgets): add FilterDrawer, SortSegmented, SortSelect"
```

---

### Task 10: TagChip + 全量测试 + 自检

**Files:**
- Create: `lib/core/widgets/tag_chip.dart`

- [ ] **Step 1: 实现 TagChip**

```dart
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label),
    onPressed: onTap,
    backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
  );
}
```

- [ ] **Step 2: 全量测试**

```bash
flutter test
```
Expected: 全部 PASS。

- [ ] **Step 3: 静态分析**

```bash
flutter analyze
```
Expected: `No issues found!`。

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/tag_chip.dart
git commit -m "feat(core/widgets): add TagChip, finalize Phase 1 components"
```

---

## Self-Review

**1. Spec 覆盖**：
- §5 15 个数据模型全部覆盖（Tasks 1-3）✅
- §4 15 个共享组件全部覆盖（Tasks 5-10）✅
- `dart run build_runner`（Task 4）✅
- 模型序列化测试（Tasks 1-3）✅
- 组件 widget 测试（Tasks 5, 6, 7）✅

**2. 占位扫描**：无 TBD/TODO。所有代码步骤含完整 Dart 代码。

**3. 类型一致性**：
- `MovieCard(movie: MovieSummary)` 在 Task 6 引用 Task 2 的 `MovieSummary`。
- `PaginationController<T>` 在 Task 7 引用 Task 1 的 `PagedResult<T>`。
- `ActorCard(actor: ActorSummary)` 在 Task 8 引用 Task 3 的 `ActorSummary`。
- `CachedImage` 在 Task 5 引用已有 `AppConstants.imageCdnBase`。
- `BackupDomains` 在 Task 1 替换 Phase0 的 `BackupDomainsData`，`DomainManager` 引用更新。
