# 首页看短评功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现首页「看短评」入口对应的短评页面（6 个周期 Tab + 分页热评列表），并把影片详情页的私有短评卡片提取为共享 `ReviewTile`，在其评价内容上方增加影片信息区。

**Architecture:** 新建 `lib/features/reviews/` feature（Feature-First），复用 `PaginationController` 与 `FakeAdapter` 测试基建；`Review` 模型扩展可选 `movie`（`ReviewMovie`）；`_ReviewTile` 从详情页提取为 `lib/core/widgets/review_tile.dart`，详情页改用它且行为不变（其评论无 `movie` 字段，不渲染头部、不可点击）。

**Tech Stack:** Flutter / Dart, go_router, provider, json_serializable + build_runner, dio, flutter_test。

## Global Constraints

- 全部文案中文硬编码，不引入 l10n。
- Material 3；新组件遵循 `lib/core/widgets` 现有样式约定（`MovieCoverImage`、`StarRating`、`EmptyState`、`ErrorRetryWidget`）。
- 接口：`GET /api/v1/reviews/hotly`，`period` 必填，可选 `latest|weekly|monthly|quarterly|yearly|all`，分页 `page`（从 1 开始）+ `limit`（本项目用 20）。
- 响应不含 `total_pages`/`current_page`，分页用「返回条数不足 `limit` 即到底」推断 `totalPages`。
- 影片详情页短评接口不返回 `movie`，`ReviewTile` 影片信息区数据驱动（`review.movie` 非空才渲染）。
- 提交粒度：每个 Task 独立 commit，先写失败测试再实现（TDD）。

---

### Task 1: Review 模型扩展（ReviewMovie + normalizeReviewJson）

**Files:**
- Modify: `lib/core/models/review.dart`
- Modify: `lib/core/network/api_data.dart:200-208`（`normalizeReviewJson`）
- Generate: `lib/core/models/review.g.dart`（build_runner 自动生成）
- Test: `test/core/models/review_model_test.dart`（新建）

**Interfaces:**
- Consumes: `apiString`、`apiMap`（`lib/core/network/api_data.dart` 已存在）。
- Produces: `ReviewMovie`（字段 `id` String、`number`/`title`/`originTitle`/`score`/`thumbUrl`/`releaseDate` String?，`fromJson` 构造）；`Review.movie` 为 `ReviewMovie?`；`normalizeReviewJson` 返回含 `movie` 键（snake_case 原样透传，`id`/`score` 归一化）的 Map。

- [ ] **Step 1: 写失败测试**

新建 `test/core/models/review_model_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_data.dart';

void main() {
  test('ReviewMovie 解析 snake_case 字段', () {
    final review = Review.fromJson(
      normalizeReviewJson({
        'id': 242751665,
        'username': 'zy520_jj',
        'watched_count': 65,
        'content': '好看',
        'score': 5,
        'likes_count': 400,
        'created_at': '2026-07-31T13:17:35.000Z',
        'movie': {
          'id': 'GZQMqq',
          'number': 'CAWB-012',
          'title': '测试标题',
          'origin_title': 'テストタイトル',
          'score': '4.56',
          'thumb_url': 'https://tp.spfcas.com/x.jpg',
          'release_date': '2026-08-05',
        },
      }),
    );

    final movie = review.movie;
    expect(movie, isNotNull);
    expect(movie!.id, 'GZQMqq');
    expect(movie.number, 'CAWB-012');
    expect(movie.title, '测试标题');
    expect(movie.originTitle, 'テストタイトル');
    expect(movie.score, '4.56');
    expect(movie.thumbUrl, 'https://tp.spfcas.com/x.jpg');
    expect(movie.releaseDate, '2026-08-05');
    expect(review.id, '242751665');
    expect(review.author?.name, 'zy520_jj');
    expect(review.likedCount, 400);
    expect(review.watchedCount, 65);
  });

  test('movie id 为整数时归一化为字符串', () {
    final review = Review.fromJson(
      normalizeReviewJson({
        'id': 1,
        'movie': {'id': 123, 'number': 'ABC-001'},
      }),
    );
    expect(review.movie?.id, '123');
  });

  test('无 movie 字段时 movie 为 null', () {
    final review = Review.fromJson(normalizeReviewJson({'id': '1', 'username': 'u'}));
    expect(review.movie, isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/models/review_model_test.dart`
Expected: 编译失败（`ReviewMovie` 未定义、`movie` 参数不存在）。

- [ ] **Step 3: 实现模型扩展**

`lib/core/models/review.dart` 在 `ReviewAuthor` 之后追加：

```dart
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ReviewMovie {
  const ReviewMovie({
    required this.id,
    this.number,
    this.title,
    this.originTitle,
    this.score,
    this.thumbUrl,
    this.releaseDate,
  });

  final String id;
  final String? number;
  final String? title;
  final String? originTitle;
  final String? score;
  final String? thumbUrl;
  final String? releaseDate;

  factory ReviewMovie.fromJson(Map<String, dynamic> json) =>
      _$ReviewMovieFromJson(json);
}
```

`Review` 构造器增加 `this.movie`，类体增加 `final ReviewMovie? movie;`：

```dart
class Review {
  const Review({
    required this.id,
    this.score,
    this.content,
    this.status,
    this.author,
    this.likedCount = 0,
    this.watchedCount = 0,
    this.createdAt,
    this.movie,
  });
  // ... 现有字段不变 ...
  final ReviewMovie? movie;
  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
}
```

`lib/core/network/api_data.dart` 的 `normalizeReviewJson` 改为：

```dart
Map<String, dynamic> normalizeReviewJson(Map<String, dynamic> json) {
  final movie = json['movie'];
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'liked_count': json['liked_count'] ?? json['likes_count'],
    'watched_count': apiInt(json['watched_count'], 0),
    'author': json['author'] ?? {'name': json['username'] ?? ''},
    if (movie is Map)
      'movie': {
        ...Map<String, dynamic>.from(movie),
        'id': apiString(movie['id']) ?? '',
        'score': apiString(movie['score']),
      },
  };
}
```

- [ ] **Step 4: 重新生成序列化代码**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/core/models/review.g.dart` 新增 `_$ReviewMovieFromJson`，`_$ReviewFromJson` 增加 `movie` 读取。

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/core/models/review_model_test.dart`
Expected: 3 个测试全部 PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/core/models/review.dart lib/core/models/review.g.dart lib/core/network/api_data.dart test/core/models/review_model_test.dart
git commit -m "feat(models): add movie info to review model"
```

---

### Task 2: ReviewTile 共享组件提取与影片信息头部

**Files:**
- Create: `lib/core/widgets/review_tile.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`（删除 `_ReviewTile`，改引用共享组件）
- Test: `test/core/widgets/review_tile_test.dart`（新建）
- Regression: `test/features/movie_detail/movie_detail_screen_test.dart`（现有测试须保持通过）

**Interfaces:**
- Consumes: `Review`/`ReviewMovie`（Task 1）、`MovieCoverImage`（`lib/core/widgets/movie_cover_image.dart`）、`StarRating`（`lib/core/widgets/star_rating.dart`）。
- Produces: `ReviewTile({required Review review})`。有 `review.movie` 时顶部渲染影片信息区且整体可点击 `context.push('/movie/${movie.id}')`；无 `movie` 时仅渲染原评价内容、不可点击。

- [ ] **Step 1: 写失败测试**

新建 `test/core/widgets/review_tile_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/widgets/review_tile.dart';

Review _review({ReviewMovie? movie}) => Review(
  id: '1',
  author: const ReviewAuthor(name: '作者A'),
  watchedCount: 3,
  score: 4.5,
  content: '评论内容',
  likedCount: 17,
  createdAt: '2016-09-24',
  movie: movie,
);

const _movie = ReviewMovie(
  id: 'm1',
  number: 'ABC-001',
  title: '这是一个非常长的影片标题需要省略显示最多两行',
  releaseDate: '2026-08-05',
  thumbUrl: 'cover.jpg',
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('有影片信息时渲染影片信息区', (tester) async {
    await tester.pumpWidget(_wrap(ReviewTile(review: _review(movie: _movie))));

    expect(find.text('ABC-001 / 2026-08-05'), findsOneWidget);
    expect(find.text('评论内容'), findsOneWidget);
    final title = tester.widget<Text>(
      find.text('这是一个非常长的影片标题需要省略显示最多两行'),
    );
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('无影片信息时不渲染影片信息区且不可点击', (tester) async {
    await tester.pumpWidget(_wrap(ReviewTile(review: _review())));

    expect(find.text('ABC-001 / 2026-08-05'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('点击卡片跳转影片详情', (tester) async {
    final router = GoRouter(
      initialLocation: '/reviews',
      routes: [
        GoRoute(
          path: '/reviews',
          builder: (_, _) =>
              const Scaffold(body: ReviewTile(review: _review(movie: _movie))),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (_, state) =>
              Scaffold(body: Text('影片 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/movie/m1');
    expect(find.text('影片 m1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/widgets/review_tile_test.dart`
Expected: 编译失败（`ReviewTile` 未定义）。

- [ ] **Step 3: 创建共享 ReviewTile**

新建 `lib/core/widgets/review_tile.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/star_rating.dart';

/// 短评卡片：评价内容上方展示影片信息区（数据驱动，仅评论携带影片信息时渲染）。
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final authorName = review.author?.name ?? '';
    final movie = review.movie;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (movie != null) _MovieHeader(movie: movie),
        Row(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (authorName.isNotEmpty)
              Text(
                authorName,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            if (review.watchedCount > 0)
              Expanded(
                child: Text(
                  '看过${review.watchedCount}部影片',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const Spacer(),
            if (review.score != null)
              StarRating(
                score: review.score!,
                semanticLabel: '$authorName 短评评分',
                size: 17,
              ),
          ],
        ),
        if (review.content != null && review.content!.isNotEmpty)
          Text(review.content!, style: textTheme.bodyLarge),
        Row(
          children: [
            Icon(
              Icons.thumb_up_alt_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              review.likedCount.toString(),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (review.createdAt != null)
              Text(
                review.createdAt!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );

    final tile = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: content,
    );
    if (movie == null) return tile;
    return InkWell(onTap: () => context.push('/movie/${movie.id}'), child: tile);
  }
}

class _MovieHeader extends StatelessWidget {
  const _MovieHeader({required this.movie});

  final ReviewMovie movie;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final thumbUrl = movie.thumbUrl;
    final number = movie.number ?? '';
    final releaseDate = movie.releaseDate ?? '';
    final meta = [
      if (number.isNotEmpty) number,
      if (releaseDate.isNotEmpty) releaseDate,
    ].join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbUrl != null && thumbUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: MovieCoverImage(
                  thumbUrl,
                  variant: MovieImageVariant.thumbnail,
                  width: 72,
                  height: 96,
                ),
              )
            else
              Container(
                width: 72,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/widgets/review_tile_test.dart`
Expected: 3 个测试全部 PASS。

- [ ] **Step 5: 详情页改用共享 ReviewTile**

`lib/features/movie_detail/screens/movie_detail_screen.dart`：

1. 顶部 import 区新增 `import 'package:jade/core/widgets/review_tile.dart';`（与 `star_rating.dart` 等相邻）。
2. 删除 `_ReviewList` 之后的 `_ReviewTile` 类（原约 1208-1280 行，以「class _ReviewTile」到「}」为界，保留其后的 `_detailTabDivider`）。
3. `_ReviewList` 的 `itemBuilder` 中 `return _ReviewTile(review: reviews[index - 1]);` 改为 `return ReviewTile(review: reviews[index - 1]);`。

- [ ] **Step 6: 回归验证详情页**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`
Expected: 全部 PASS（短评断言：'看过2060部影片'、StarRating、点赞图标等保持不变）。

- [ ] **Step 7: 提交**

```bash
git add lib/core/widgets/review_tile.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/review_tile_test.dart
git commit -m "feat(widgets): extract shared ReviewTile with movie info header"
```

---

### Task 3: ReviewsService 与 ReviewPeriod

**Files:**
- Create: `lib/features/reviews/models/review_period.dart`
- Create: `lib/features/reviews/services/reviews_service.dart`
- Test: `test/features/reviews/reviews_service_test.dart`（新建）

**Interfaces:**
- Consumes: `Endpoints.reviewsHotly`（`lib/core/network/endpoints.dart` 已存在）、`PagedResult<T>`、`Review`（Task 1）、`normalizeReviewJson`/`apiMap`/`apiList`/`apiInt`（`api_data.dart`）。
- Produces: `enum ReviewPeriod { latest, weekly, monthly, quarterly, yearly, all }`（含 `String value`）；`ReviewsService({required ApiClient api})` 或构造注入，方法 `Future<PagedResult<Review>> getHotReviews({required ReviewPeriod period, int page = 1, int limit = 20})`。

- [ ] **Step 1: 写失败测试**

新建 `test/features/reviews/reviews_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/reviews/models/review_period.dart';
import 'package:jade/features/reviews/services/reviews_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fixture {
  const _Fixture({required this.adapter, required this.service});
  final FakeAdapter adapter;
  final ReviewsService service;
}

Future<_Fixture> _createFixture() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: 'https://jdforrepam.com'));
  dio.interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: dm);
  final adapter = FakeAdapter();
  dio.httpClientAdapter = adapter;
  return _Fixture(adapter: adapter, service: ReviewsService(api));
}

Map<String, dynamic> _response(int count) => {
  'success': 1,
  'data': {
    'reviews': [
      for (var index = 0; index < count; index++)
        {
          'id': index + 1,
          'username': '作者$index',
          'watched_count': 3,
          'content': '内容$index',
          'score': 5,
          'likes_count': 10,
          'created_at': '2026-08-05',
          'movie': {
            'id': 'm$index',
            'number': 'ABC-00$index',
            'title': '影片$index',
            'thumb_url': 'cover-$index.jpg',
            'release_date': '2026-08-05',
          },
        },
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('六周期取值映射', () {
    expect(ReviewPeriod.values.map((period) => period.value), [
      'latest',
      'weekly',
      'monthly',
      'quarterly',
      'yearly',
      'all',
    ]);
  });

  test('携带 period/page/limit 并解析 movie', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(1));

    final result = await fixture.service.getHotReviews(
      period: ReviewPeriod.quarterly,
      page: 2,
    );

    expect(fixture.adapter.requests.single.uri.queryParameters, {
      'period': 'quarterly',
      'page': '2',
      'limit': '20',
    });
    final review = result.items.single;
    expect(review.author?.name, '作者0');
    expect(review.movie?.number, 'ABC-000');
    expect(review.movie?.title, '影片0');
    expect(review.movie?.releaseDate, '2026-08-05');
  });

  test('满 20 条时推断存在下一页', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(20));

    final result = await fixture.service.getHotReviews(period: ReviewPeriod.all);

    expect(result.currentPage, 1);
    expect(result.totalPages, 2);
  });

  test('不足 20 条时视为最后一页', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(5));

    final result = await fixture.service.getHotReviews(period: ReviewPeriod.all);

    expect(result.currentPage, 1);
    expect(result.totalPages, 1);
  });

  test('空列表时不再分页', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(0));

    final result = await fixture.service.getHotReviews(period: ReviewPeriod.all);

    expect(result.items, isEmpty);
    expect(result.totalPages, 1);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/reviews/reviews_service_test.dart`
Expected: 编译失败（`ReviewPeriod`、`ReviewsService` 未定义）。

- [ ] **Step 3: 实现 ReviewPeriod 与 ReviewsService**

新建 `lib/features/reviews/models/review_period.dart`：

```dart
/// 热门短评周期，对应 /api/v1/reviews/hotly 的 period 参数。
enum ReviewPeriod {
  latest('latest'),
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  yearly('yearly'),
  all('all');

  const ReviewPeriod(this.value);

  final String value;
}
```

新建 `lib/features/reviews/services/reviews_service.dart`：

```dart
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/reviews/models/review_period.dart';

class ReviewsService {
  ReviewsService(this._api);

  static const pageSize = 20;

  final ApiClient _api;

  Future<PagedResult<Review>> getHotReviews({
    required ReviewPeriod period,
    int page = 1,
    int limit = pageSize,
  }) async {
    final response = await _api.get(
      Endpoints.reviewsHotly,
      queryParameters: {'period': period.value, 'page': page, 'limit': limit},
    );
    final data = apiMap(response.data);
    final items = apiList(data, const [
      'reviews',
    ]).map(normalizeReviewJson).map(Review.fromJson).toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    // 接口不返回 total_pages，用「返回条数不足 limit 即到底」推断。
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: items.length < limit ? currentPage : currentPage + 1,
      total: items.length,
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/reviews/reviews_service_test.dart`
Expected: 5 个测试全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/reviews/models/review_period.dart lib/features/reviews/services/reviews_service.dart test/features/reviews/reviews_service_test.dart
git commit -m "feat(reviews): add hot reviews service with period mapping"
```

---

### Task 4: ReviewsPage 与路由

**Files:**
- Create: `lib/features/reviews/screens/reviews_screen.dart`
- Create: `lib/features/reviews/index.dart`
- Modify: `lib/core/router/app_router.dart:163-165`（`/reviews` 占位页改为 `ReviewsPage`）
- Modify: `test/app_router_test.dart`（追加 `/reviews` 路由断言）
- Test: `test/features/reviews/reviews_screen_test.dart`（新建）

**Interfaces:**
- Consumes: `ReviewsService`/`ReviewPeriod`（Task 3）、`PaginationController<Review>`（`lib/core/widgets/pagination_controller.dart`）、`ReviewTile`（Task 2）、`ErrorRetryWidget`/`EmptyState`（core widgets）。
- Produces: `ReviewsPage`（无参构造，AppBar「看短评」+ 6 Tab + TabBarView，每 Tab 独立分页列表）；`lib/features/reviews/index.dart` 导出 `ReviewsPage`。

- [ ] **Step 1: 写失败测试**

新建 `test/features/reviews/reviews_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:jade/features/reviews/screens/reviews_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

Map<String, dynamic> _pageResponse(int count, {int start = 0}) => {
  'success': 1,
  'data': {
    'reviews': [
      for (var index = 0; index < count; index++)
        {
          'id': start + index + 1,
          'username': '作者${start + index}',
          'watched_count': 3,
          'content': '内容${start + index}',
          'score': 5,
          'likes_count': 17,
          'created_at': '2016-09-24',
          'movie': {
            'id': 'm${start + index}',
            'number': 'ABC-00${start + index}',
            'title': '影片${start + index}',
            'thumb_url': 'cover-${start + index}.jpg',
            'release_date': '2026-08-05',
          },
        },
    ],
  },
};

Future<FakeAdapter> _pumpReviews(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.baseUrl: 'https://jdforrepam.com',
    StorageKeys.apiDomains: ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TokenProvider(),
    onAuthError: () {},
  );
  final adapter = FakeAdapter();
  api.setAdapterForTest(adapter);
  await tester.pumpWidget(const MaterialApp(home: ReviewsPage()));
  return adapter;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var i = 0; i < 20; i++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('默认 Tab 请求 latest 并渲染评论卡片', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(1));

    await _pumpUntil(tester, () => adapter.requests.isNotEmpty);

    expect(find.text('看短评'), findsOneWidget);
    for (final tab in ['最新', '上周热评', '月度热评', '季度热评', '年度热评', '全部']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(adapter.requests.single.uri.queryParameters['period'], 'latest');
    expect(find.byType(ReviewTile), findsOneWidget);
    expect(find.text('内容0'), findsOneWidget);
  });

  testWidgets('切换 Tab 请求对应周期', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(1));
    await _pumpUntil(tester, () => adapter.requests.isNotEmpty);

    await tester.tap(find.text('年度热评'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _pumpUntil(
      tester,
      () =>
          adapter.requests.any(
            (request) =>
                request.uri.queryParameters['period'] == 'yearly',
          ),
    );

    expect(
      adapter.requests
          .where((request) => request.path == Endpoints.reviewsHotly)
          .last
          .uri
          .queryParameters['period'],
      'yearly',
    );
  });

  testWidgets('滚动到底部请求下一页', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(20));
    await _pumpUntil(tester, () => adapter.requests.isNotEmpty);
    await _pumpUntil(tester, () => find.byType(ReviewTile).evaluate().isNotEmpty);

    await tester.drag(
      find.byType(ListView),
      const Offset(0, -10000),
    );
    await tester.pump();
    await _pumpUntil(
      tester,
      () =>
          adapter.requests.any(
            (request) => request.uri.queryParameters['page'] == '2',
          ),
    );

    expect(
      adapter.requests
          .where((request) => request.path == Endpoints.reviewsHotly)
          .last
          .uri
          .queryParameters['page'],
      '2',
    );
  });

  testWidgets('请求失败显示错误并可重试', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueueSequence(
      Endpoints.reviewsHotly,
      [
        {'success': 0, 'message': '失败'},
        _pageResponse(1),
      ],
    );
    await _pumpUntil(tester, () => find.byType(ErrorRetryWidget).evaluate().isNotEmpty);

    await tester.tap(find.text('重试'));
    await _pumpUntil(tester, () => find.byType(ReviewTile).evaluate().isNotEmpty);

    expect(find.byType(ReviewTile), findsOneWidget);
  });

  testWidgets('空列表显示暂无短评', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(0));
    await _pumpUntil(tester, () => find.text('暂无短评').evaluate().isNotEmpty);

    expect(find.text('暂无短评'), findsOneWidget);
  });
}
```

`test/app_router_test.dart` 追加（import 区加 `package:jade/features/reviews/index.dart` 与 `package:jade/core/network/testing/fake_adapter.dart` 不需要——沿用现有 import）：

```dart
testWidgets('/reviews 渲染短评页面', (tester) async {
  await tester.pumpWidget(_buildApp(initialLocation: AppRoutes.reviews));
  await tester.pump();

  expect(find.text('看短评'), findsOneWidget);
  expect(find.text('最新'), findsOneWidget);
  expect(find.text('全部'), findsOneWidget);
}, timeout: const Timeout(Duration(seconds: 10)));
```

说明：该测试环境未初始化 `ApiClient`，页面会进入错误态，但 AppBar 标题与 Tab 文案仍可断言。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/reviews/reviews_screen_test.dart`
Expected: 编译失败（`ReviewsPage` 未定义）。

- [ ] **Step 3: 实现 ReviewsPage**

新建 `lib/features/reviews/screens/reviews_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:jade/features/reviews/models/review_period.dart';
import 'package:jade/features/reviews/services/reviews_service.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage>
    with TickerProviderStateMixin {
  static const tabs = ['最新', '上周热评', '月度热评', '季度热评', '年度热评', '全部'];
  static const periods = [
    ReviewPeriod.latest,
    ReviewPeriod.weekly,
    ReviewPeriod.monthly,
    ReviewPeriod.quarterly,
    ReviewPeriod.yearly,
    ReviewPeriod.all,
  ];

  late final TabController _tabController;

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
        title: const Text('看短评'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [for (final period in periods) _HotReviewList(period: period)],
      ),
    );
  }
}

class _HotReviewList extends StatefulWidget {
  const _HotReviewList({required this.period});

  final ReviewPeriod period;

  @override
  State<_HotReviewList> createState() => _HotReviewListState();
}

class _HotReviewListState extends State<_HotReviewList>
    with AutomaticKeepAliveClientMixin {
  late final PaginationController<Review> _controller =
      PaginationController(fetch: _fetchPage);

  Future<PagedResult<Review>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      throw StateError('网络客户端未初始化');
    }
    return ReviewsService(api).getHotReviews(period: widget.period, page: page);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.error != null && _controller.items.isEmpty) {
          return ErrorRetryWidget(
            message: _controller.error.toString(),
            onRetry: _controller.refresh,
          );
        }
        if (_controller.isLoading && _controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.items.isEmpty) {
          return const EmptyState(message: '暂无短评');
        }
        final showFooter = _controller.isLoading || _controller.error != null;
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 200 &&
                  _controller.error == null) {
                _controller.fetchMore();
              }
              return false;
            },
            child: ListView.separated(
              key: Key('hot-reviews-${widget.period.value}'),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _controller.items.length + (showFooter ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                if (index == _controller.items.length) {
                  if (_controller.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Center(
                    child: TextButton.icon(
                      onPressed: _controller.fetchMore,
                      icon: const Icon(Icons.refresh),
                      label: const Text('加载失败，点击重试'),
                    ),
                  );
                }
                return ReviewTile(review: _controller.items[index]);
              },
            ),
          ),
        );
      },
    );
  }
}
```

新建 `lib/features/reviews/index.dart`：

```dart
export 'screens/reviews_screen.dart';
```

- [ ] **Step 4: 更新路由**

`lib/core/router/app_router.dart`：

1. import 区（feature index 组）新增 `import 'package:jade/features/reviews/index.dart';`。
2. `/reviews` 路由：

```dart
GoRoute(
  path: AppRoutes.reviews,
  builder: (c, s) => const ReviewsPage(),
),
```

（替换原 `builder: (c, s) => const _SimpleListPage(title: '看短评'),`，`_SimpleListPage` 若无其他引用可一并删除。）

- [ ] **Step 5: 运行新测试确认通过**

Run: `flutter test test/features/reviews/reviews_screen_test.dart test/app_router_test.dart`
Expected: 全部 PASS。

- [ ] **Step 6: 全量验证**

Run: `flutter analyze`
Expected: 无新增 warning/error。

Run: `flutter test`
Expected: 全量测试 PASS（含 movie_detail 回归）。

- [ ] **Step 7: 提交**

```bash
git add lib/features/reviews lib/core/router/app_router.dart test/features/reviews test/app_router_test.dart
git commit -m "feat(reviews): add hot reviews page with six period tabs"
```

---

## 自审记录

- **Spec 覆盖**：6 Tab 与周期映射 → Task 3/4；ReviewTile 影片信息区 → Task 2；分页启发式 → Task 3；路由替换 → Task 4；测试验收 → 各 Task 测试步骤。
- **占位符扫描**：无 TBD/TODO，所有步骤含可执行代码。
- **类型一致性**：`ReviewMovie` 字段名、`Review.movie`、`ReviewPeriod.value`、`getHotReviews` 签名、`ReviewTile({required Review review})` 在相关 Task 间保持一致；`PaginationController.fetch` 类型为 `PageFetcher<Review>`。
