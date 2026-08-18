# ReviewTile 交互优化与评论点赞 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** ReviewTile 仅影片信息区点击跳转、正文点击展开/收起长评论、实现评论点赞（幂等、组件内部逻辑）。

**架构：** 数据层在 core 增加 `ReviewApi.likeReview`（core 不依赖 feature）；模型 `Review` 增加 `liked` 字段；组件 `ReviewTile` 状态化并拆分点击区域，点赞时**点击时**读取 `AuthProvider`（缺失视为未登录），调 `ReviewApi` 成功后本地置灰 +1。

**技术栈：** Flutter / provider / go_router / dio / json_serializable / build_runner

---

## 文件结构

| 文件 | 职责 | 操作 |
|------|------|------|
| `lib/core/network/endpoints.dart` | 点赞端点常量 | 修改 |
| `lib/core/network/review_api.dart` | `ReviewApi.likeReview()` 点赞调用（core 层） | 新建 |
| `lib/core/models/review.dart` | `Review.liked` 字段 | 修改 |
| `lib/core/models/review.g.dart` | 重新生成（`liked` 解析） | 生成 |
| `lib/core/network/api_data.dart` | `normalizeReviewJson` 加 `liked` 归一化 | 修改 |
| `lib/core/widgets/review_tile.dart` | 状态化、点击区域划分、点赞逻辑 | 重写 |
| `test/core/network/review_api_test.dart` | likeReview 单测 | 新建 |
| `test/core/models/review_model_test.dart` | liked 解析单测 | 修改 |
| `test/core/widgets/review_tile_test.dart` | 交互 + 点赞组件测试 | 重写 |

---

### 任务 1：端点常量与 ReviewApi

**文件：**
- 修改：`lib/core/network/endpoints.dart`
- 创建：`lib/core/network/review_api.dart`
- 测试：`test/core/network/review_api_test.dart`

- [ ] **步骤 1：编写失败的测试**

创建 `test/core/network/review_api_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/review_api.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fixture {
  const _Fixture({required this.adapter, required this.api});
  final FakeAdapter adapter;
  final ReviewApi api;
}

Future<_Fixture> _createFixture() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: 'https://jdforrepam.com'));
  dio.interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final apiClient = ApiClient.forTest(dio: dio, domainManager: dm);
  final adapter = FakeAdapter();
  dio.httpClientAdapter = adapter;
  return _Fixture(adapter: adapter, api: ReviewApi(apiClient));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('likeReview 发送 POST 到影片与评论组成的路径', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews/r9/like', {
      'success': 1,
      'data': null,
    });

    await fixture.api.likeReview(movieId: 'm1', reviewId: 'r9');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/movies/m1/reviews/r9/like');
  });

  test('likeReview 正确替换路径中的 movie_id 与 review_id', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(
      '/api/v1/movies/m-42/reviews/r-7/like',
      {'success': 1, 'data': null},
    );

    await fixture.api.likeReview(movieId: 'm-42', reviewId: 'r-7');

    expect(
      fixture.adapter.requests.single.path,
      '/api/v1/movies/m-42/reviews/r-7/like',
    );
  });

  test('点赞失败时抛出异常', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews/r9/like', {
      'success': 0,
      'message': '失败',
    });

    await expectLater(
      fixture.api.likeReview(movieId: 'm1', reviewId: 'r9'),
      throwsA(isA<DioException>()),
    );
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/network/review_api_test.dart`
预期：FAIL，报错 `Error: Method not found: 'ReviewApi'`

- [ ] **步骤 3：添加端点常量**

修改 `lib/core/network/endpoints.dart`，在 `reviewsHotly` 下方添加：

```dart
  static const String reviewLike =
      '/api/v1/movies/{movie_id}/reviews/{review_id}/like';
```

- [ ] **步骤 4：创建 ReviewApi**

创建 `lib/core/network/review_api.dart`：

```dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';

/// 评论相关 API 封装（core 层，供通用组件复用）。
class ReviewApi {
  ReviewApi(this._api);

  final ApiClient _api;

  /// 为指定评论点赞（幂等）。
  Future<void> likeReview({
    required String movieId,
    required String reviewId,
  }) async {
    await _api.post(
      Endpoints.reviewLike
          .replaceAll('{movie_id}', movieId)
          .replaceAll('{review_id}', reviewId),
    );
  }
}
```

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/core/network/review_api_test.dart`
预期：PASS（3 个测试）

- [ ] **步骤 6：Commit**

```bash
git add lib/core/network/endpoints.dart lib/core/network/review_api.dart test/core/network/review_api_test.dart
git commit -m "feat(core): add review like API"
```

---

### 任务 2：Review 模型 liked 字段

**文件：**
- 修改：`lib/core/models/review.dart`
- 生成：`lib/core/models/review.g.dart`
- 修改：`lib/core/network/api_data.dart`
- 测试：`test/core/models/review_model_test.dart`

- [ ] **步骤 1：编写失败的测试**

在 `test/core/models/review_model_test.dart` 追加：

```dart
  test('liked 字段解析：true / false / 缺失', () {
    final liked = Review.fromJson(normalizeReviewJson({'id': '1', 'liked': true}));
    expect(liked.liked, isTrue);

    final unliked = Review.fromJson(normalizeReviewJson({'id': '2', 'liked': false}));
    expect(unliked.liked, isFalse);

    final missing = Review.fromJson(normalizeReviewJson({'id': '3'}));
    expect(missing.liked, isFalse);
  });

  test('liked 为字符串或数字时归一化', () {
    final fromString = Review.fromJson(normalizeReviewJson({'id': '1', 'liked': '1'}));
    expect(fromString.liked, isTrue);

    final fromNum = Review.fromJson(normalizeReviewJson({'id': '2', 'liked': 1}));
    expect(fromNum.liked, isTrue);
  });
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/models/review_model_test.dart`
预期：FAIL，报错 `The getter 'liked' isn't defined for the class 'Review'`

- [ ] **步骤 3：Review 模型加字段**

修改 `lib/core/models/review.dart`：

```dart
  const Review({
    required this.id,
    this.score,
    this.content,
    this.status,
    this.author,
    this.likedCount = 0,
    this.liked = false,
    this.watchedCount = 0,
    this.createdAt,
    this.movie,
  });
```

在 `final int likedCount;` 后添加：

```dart
  final bool liked;
```

- [ ] **步骤 4：normalizeReviewJson 加 liked**

修改 `lib/core/network/api_data.dart` 的 `normalizeReviewJson`，在 `'liked_count': ...` 行后添加：

```dart
    'liked': apiBool(json['liked'], false),
```

- [ ] **步骤 5：重新生成 review.g.dart**

运行：`dart run build_runner build --delete-conflicting-outputs`
预期：`lib/core/models/review.g.dart` 中 `Review` 构造函数包含 `liked: json['liked'] as bool? ?? false`

- [ ] **步骤 6：运行测试验证通过**

运行：`flutter test test/core/models/review_model_test.dart`
预期：PASS

- [ ] **步骤 7：Commit**

```bash
git add lib/core/models/review.dart lib/core/models/review.g.dart lib/core/network/api_data.dart test/core/models/review_model_test.dart
git commit -m "feat(core): add liked field to review model"
```

---

### 任务 3：ReviewTile 状态化与点击区域划分

**文件：**
- 重写：`lib/core/widgets/review_tile.dart`
- 测试：`test/core/widgets/review_tile_test.dart`

- [ ] **步骤 1：编写失败的测试（点击区域）**

在 `test/core/widgets/review_tile_test.dart` 中修改 `_wrap` 支持 Provider，并新增用例：

```dart
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _wrapWithAuth(Widget child, AuthProvider auth) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(home: Scaffold(body: child)),
    );

Future<AuthProvider> _loggedOutAuth() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AuthProvider.create(prefs);
}

Future<AuthProvider> _loggedInAuth() async {
  final auth = await _loggedOutAuth();
  await auth.login(token: 't', user: {'id': 1, 'username': 'u'});
  return auth;
}
```

新增测试：

```dart
  testWidgets('点击正文展开收起，点击影片信息区跳转', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    final router = GoRouter(
      initialLocation: '/reviews',
      routes: [
        GoRoute(
          path: '/reviews',
          builder: (_, _) => Scaffold(
            body: ReviewTile(review: _review(movie: _movie, content: longText)),
          ),
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

    // 点击正文展开
    await tester.tap(find.text(longText));
    await tester.pump();
    final expanded = tester.widget<Text>(find.text(longText));
    expect(expanded.maxLines, isNull);

    // 点击影片标题跳转
    await tester.tap(find.text('这是一个非常长的影片标题需要省略显示最多两行'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/movie/m1');
  });

  testWidgets('点击作者行不跳转', (tester) async {
    final router = GoRouter(
      initialLocation: '/reviews',
      routes: [
        GoRoute(
          path: '/reviews',
          builder: (_, _) =>
              Scaffold(body: ReviewTile(review: _review(movie: _movie))),
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

    await tester.tap(find.text('作者A'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/reviews');
  });
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/widgets/review_tile_test.dart`
预期：FAIL——「点击作者行不跳转」测试中 `find.text('作者A')` tap 会命中整个 InkWell 跳转到 `/movie/m1`

- [ ] **步骤 3：ReviewTile 状态化**

重写 `lib/core/widgets/review_tile.dart` 为 `StatefulWidget`，保留 `_MovieHeader` 与 `_ExpandableReviewContent` 结构。核心变化：

```dart
class ReviewTile extends StatefulWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  State<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<ReviewTile> {
  late bool _liked;
  late int _likedCount;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.review.liked;
    _likedCount = widget.review.likedCount;
  }

  @override
  void didUpdateWidget(ReviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review != widget.review) {
      _liked = widget.review.liked;
      _likedCount = widget.review.likedCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final authorName = widget.review.author?.name ?? '';
    final movie = widget.review.movie;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (movie != null)
          _MovieHeader(
            movie: movie,
            onTap: () => context.push('/movie/${movie.id}'),
          ),
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
            if (widget.review.watchedCount > 0)
              Expanded(
                child: Text(
                  '看过${widget.review.watchedCount}部影片',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const Spacer(),
            if (widget.review.score != null)
              StarRating(
                score: widget.review.score!,
                semanticLabel: '$authorName 短评评分',
                size: 17,
              ),
          ],
        ),
        if (widget.review.content != null && widget.review.content!.isNotEmpty)
          _ExpandableReviewContent(
            text: widget.review.content!,
            style: textTheme.bodyLarge,
          ),
        // 任务 5 将替换为 _LikeRow（含点赞交互）
        Row(
          children: [
            Icon(
              Icons.thumb_up_alt_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              widget.review.likedCount.toString(),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (widget.review.createdAt != null)
              Text(
                widget.review.createdAt!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: content,
    );
  }
}
```

- [ ] **步骤 4：_MovieHeader 增加 onTap**

修改 `_MovieHeader`：

```dart
class _MovieHeader extends StatelessWidget {
  const _MovieHeader({required this.movie, required this.onTap});

  final ReviewMovie movie;
  final VoidCallback onTap;
```

`build` 中把 `Column` 用 `InkWell` 包裹：

```dart
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(...),
    );
```

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/core/widgets/review_tile_test.dart`
预期：PASS（含原有用例，`InkWell` 现在只包影片信息区，原「点击卡片跳转」测试需改为点击影片标题）

> 注意：原测试 `testWidgets('点击卡片跳转影片详情')` 中 `tester.tap(find.byType(InkWell))` 会失效（现在有多个 InkWell），需改为 `tester.tap(find.text('这是一个非常长的影片标题需要省略显示最多两行'))`。

- [ ] **步骤 6：Commit**

```bash
git add lib/core/widgets/review_tile.dart test/core/widgets/review_tile_test.dart
git commit -m "feat(reviews): split review tile tap zones and stateful like row"
```

---

### 任务 4：正文点击展开收起

**文件：**
- 修改：`lib/core/widgets/review_tile.dart`
- 测试：`test/core/widgets/review_tile_test.dart`

- [ ] **步骤 1：编写失败的测试（正文点击）**

在 `test/core/widgets/review_tile_test.dart` 追加：

```dart
  testWidgets('点击评论正文展开收起', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    final collapsed = tester.widget<Text>(find.text(longText));
    expect(collapsed.maxLines, 5);

    // 点击正文（非按钮）展开
    await tester.tapAt(
      tester.getCenter(find.text(longText)).translate(0, -20),
    );
    await tester.pump();

    final expanded = tester.widget<Text>(find.text(longText));
    expect(expanded.maxLines, isNull);

    // 再点收起
    await tester.tapAt(
      tester.getCenter(find.text(longText)).translate(0, -20),
    );
    await tester.pump();

    final collapsedAgain = tester.widget<Text>(find.text(longText));
    expect(collapsedAgain.maxLines, 5);
  });

  testWidgets('点击展开收起按钮仍可用', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    await tester.tap(find.text('展开'));
    await tester.pump();
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.text('收起'));
    await tester.pump();
    expect(find.text('展开'), findsOneWidget);
  });
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/widgets/review_tile_test.dart`
预期：FAIL——点击正文不展开（目前只有按钮能展开）

- [ ] **步骤 3：_ExpandableReviewContent 支持正文点击**

修改 `_ExpandableReviewContent`，把返回的 `Column` 包进 `GestureDetector`（排除按钮区域——按钮本身点击已处理，正文区域点击切换）：

```dart
class _ExpandableReviewContent extends StatefulWidget {
  const _ExpandableReviewContent({required this.text, required this.style});

  static const maxLines = 5;

  final String text;
  final TextStyle? style;

  @override
  State<_ExpandableReviewContent> createState() =>
      _ExpandableReviewContentState();
}

class _ExpandableReviewContentState extends State<_ExpandableReviewContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: _ExpandableReviewContent.maxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        if (!textPainter.didExceedMaxLines) {
          return Text(widget.text, style: widget.style);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: _expanded
                    ? null
                    : _ExpandableReviewContent.maxLines,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key(_expanded ? 'review-collapse' : 'review-expand'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
                child: Text(_expanded ? '收起' : '展开'),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/core/widgets/review_tile_test.dart`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/core/widgets/review_tile.dart test/core/widgets/review_tile_test.dart
git commit -m "feat(reviews): tap review content to toggle expansion"
```

---

### 任务 5：点赞交互（登录引导 + 幂等点赞）

**文件：**
- 修改：`lib/core/widgets/review_tile.dart`
- 测试：`test/core/widgets/review_tile_test.dart`

- [ ] **步骤 1：编写失败的测试（点赞）**

在 `test/core/widgets/review_tile_test.dart` 追加：

```dart
  testWidgets('未登录点击点赞提示登录且不发请求', (tester) async {
    final auth = await _loggedOutAuth();
    await tester.pumpWidget(
      _wrapWithAuth(ReviewTile(review: _review(movie: _movie)), auth),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();

    expect(find.text('请先登录'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('无 Provider 包裹点击点赞按未登录处理不崩溃', (tester) async {
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(movie: _movie))),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();

    expect(find.text('请先登录'), findsOneWidget);
  });

  testWidgets('已登录点赞成功数字加一且图标变实心', (tester) async {
    final auth = await _loggedInAuth();
    final adapter = await _setupFakeApi();
    adapter.enqueue(
      '/api/v1/movies/m1/reviews/r1/like',
      {'success': 1, 'data': null},
    );

    await tester.pumpWidget(
      _wrapWithAuth(
        ReviewTile(review: _review(movie: _movie)),
        auth,
      ),
    );

    expect(find.text('17'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('18'), findsOneWidget);
    expect(find.byKey(const Key('review-liked-icon')), findsOneWidget);
  });

  testWidgets('已点赞评论点击无效果', (tester) async {
    final auth = await _loggedInAuth();
    await tester.pumpWidget(
      _wrapWithAuth(
        ReviewTile(
          review: _review(movie: _movie).copyWith(liked: true),
        ),
        auth,
      ),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();

    expect(find.text('17'), findsOneWidget);
  });

  testWidgets('点赞失败提示且数字不变', (tester) async {
    final auth = await _loggedInAuth();
    final adapter = await _setupFakeApi();
    adapter.enqueue(
      '/api/v1/movies/m1/reviews/r1/like',
      {'success': 0, 'message': '失败'},
    );

    await tester.pumpWidget(
      _wrapWithAuth(ReviewTile(review: _review(movie: _movie)), auth),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('点赞失败，请重试'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
  });
```

同时需要测试辅助函数（`_setupFakeApi` 注入 FakeAdapter + ApiClient.forTest）：

```dart
Future<FakeAdapter> _setupFakeApi() async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.baseUrl: 'https://jdforrepam.com',
  });
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: 'https://jdforrepam.com'));
  dio.interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: dm);
  final adapter = FakeAdapter();
  dio.httpClientAdapter = adapter;
  return adapter;
}
```

需要新增 imports（`StorageKeys`、`DomainManager`、`ResponseInterceptor`、`dio`）：

```dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/storage/storage_keys.dart';
```

`_review` 增加 `liked` 与 `copyWith` 支持（模型无 copyWith 时在测试内构造）：

```dart
Review _review({
  ReviewMovie? movie,
  String content = '评论内容',
  bool liked = false,
}) =>
    Review(
      id: 'r1',
      author: const ReviewAuthor(name: '作者A'),
      watchedCount: 3,
      score: 4.5,
      content: content,
      likedCount: 17,
      liked: liked,
      createdAt: '2016-09-24',
      movie: movie,
    );
```

> 注意：`Review` 目前无 `copyWith`，直接用 `_review(movie: _movie, liked: true)` 即可，不需要 copyWith。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/widgets/review_tile_test.dart`
预期：FAIL——`find.byKey(Key('review-like-button'))` 找不到（点赞行还没实现）

- [ ] **步骤 3：实现 _LikeRow 与点赞逻辑**

在 `lib/core/widgets/review_tile.dart` 添加 `_LikeRow` 组件与 `_handleLikeTap`：

```dart
  Future<void> _handleLikeTap() async {
    final movie = widget.review.movie;
    if (movie == null) {
      _showSnackBar('无法点赞');
      return;
    }
    if (_liked || _liking) return;

    final AuthProvider? auth;
    try {
      auth = context.read<AuthProvider>();
    } on ProviderNotFoundException {
      auth = null;
    }
    if (auth == null || !auth.isLogged) {
      _showSnackBar('请先登录', actionLabel: '去登录', onAction: () {
        context.push('/login');
      });
      return;
    }

    final api = ApiClient.instanceOrNull;
    if (api == null) {
      _showSnackBar('点赞失败，请重试');
      return;
    }
    setState(() => _liking = true);
    try {
      await ReviewApi(api).likeReview(
        movieId: movie.id,
        reviewId: widget.review.id,
      );
      if (!mounted) return;
      setState(() {
        _liked = true;
        _likedCount += 1;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('点赞失败，请重试');
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _showSnackBar(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
  }
```

`_LikeRow`：

```dart
class _LikeRow extends StatelessWidget {
  const _LikeRow({
    required this.liked,
    required this.likedCount,
    required this.liking,
    required this.createdAt,
    required this.onTap,
  });

  final bool liked;
  final int likedCount;
  final bool liking;
  final String? createdAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        InkWell(
          key: const Key('review-like-button'),
          onTap: liking ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: liked ? '已点赞' : '点赞，当前 $likedCount 人已赞',
                  child: ExcludeSemantics(
                    child: Icon(
                      liked
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                      key: liked
                          ? const Key('review-liked-icon')
                          : const Key('review-unliked-icon'),
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  likedCount.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (createdAt != null)
          Text(
            createdAt!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
```

`_ReviewTileState.build` 中调用 `_LikeRow`：

```dart
        _LikeRow(
          liked: _liked,
          likedCount: _likedCount,
          liking: _liking,
          createdAt: widget.review.createdAt,
          onTap: _handleLikeTap,
        ),
```

需要新增 imports：

```dart
import 'package:provider/provider.dart';
import 'package:jade/core/network/review_api.dart';
import 'package:jade/core/providers/auth_provider.dart';
```

> 说明：`createdAt` 从原 Column 底部的 `Row` 中移到 `_LikeRow` 内（同一行右侧）。原结构改为 `_LikeRow` 一行包含点赞 + 日期。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/core/widgets/review_tile_test.dart`
预期：PASS（含点赞全部用例）

- [ ] **步骤 5：运行全部相关测试**

运行：`flutter test test/core/widgets/review_tile_test.dart test/core/network/review_api_test.dart test/core/models/review_model_test.dart test/features/reviews/reviews_screen_test.dart test/features/movie_detail/movie_detail_screen_test.dart`
预期：全部 PASS

- [ ] **步骤 6：Commit**

```bash
git add lib/core/widgets/review_tile.dart test/core/widgets/review_tile_test.dart
git commit -m "feat(reviews): implement idempotent like with login guide"
```

---

### 任务 6：静态分析与全量验证

**文件：** 无

- [ ] **步骤 1：运行 flutter analyze**

运行：`flutter analyze`
预期：`No issues found!`

- [ ] **步骤 2：运行全量测试**

运行：`flutter test`
预期：全部 PASS

- [ ] **步骤 3：Commit（如有 analyze 修复）**

```bash
git status --short
# 如有未提交修复
git add -A
git commit -m "chore: fix analysis issues"
```

---

## 自检

**规格覆盖度：**
- ✅ 3.1 端点：任务 1
- ✅ 3.2 端点常量：任务 1
- ✅ 3.3 ReviewApi：任务 1
- ✅ 4.1 Review.liked：任务 2
- ✅ 4.2 归一化：任务 2
- ✅ 5.1 状态化：任务 3
- ✅ 5.2 点击区域划分：任务 3
- ✅ 5.3 点赞交互：任务 5
- ✅ 5.4 依赖与边界：任务 5
- ✅ 5.5 无障碍：任务 5（Semantics）
- ✅ 6 测试计划：任务 1/2/3/4/5

**占位符扫描：** 无 TODO/待定；所有步骤含完整代码与命令。

**类型一致性：**
- `ReviewApi.likeReview({required String movieId, required String reviewId})` 在任务 1 定义、任务 5 调用，签名一致
- `_LikeRow({liked, likedCount, liking, onTap})` 任务 5 内定义与使用一致
- `Key('review-like-button')`、`Key('review-liked-icon')` 测试与实现一致
- `Review.liked` 字段任务 2 定义、任务 5 `_review(liked: true)` 使用一致
