# Movie Detail Review Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在影片详情操作区实现真实的“想看”“看过”和删除状态，并通过可交互 `StarRating` 收集 1–5 分及必填评论。

**Architecture:** 详情模型负责承载 `movie.review`，`MovieDetailService` 独占影评请求契约；共享 `StarRating` 以可选回调扩展交互模式，影片详情 feature 内的表单和按钮组件分别负责输入校验与状态矩阵。页面协调 mutation、即时状态更新和详情校准，不把公开短评列表与当前用户影评混用。

**Tech Stack:** Flutter、Dart、Material 3、Dio/`ApiClient`、`json_serializable`、`flutter_test`、项目 `FakeAdapter`

## Global Constraints

- 接口契约以用户提供的 OpenAPI 附件为准。
- “想看”POST JSON 只能是 `{"status":"want_watch"}`。
- “看过”POST JSON 必须包含整数 `score`（1–5）、裁剪后的非空 `content`、`status=watched`。
- 删除路径固定为 `/api/v1/movies/{movie_id}/reviews/{review_id}`，review ID 来自详情或最近一次 POST 响应。
- 未标记按钮顺序固定为“想看、看过、存入清单”。
- 已想看按钮顺序固定为“删除想看、看过、存入清单”。
- 已看过只显示“删除看过、存入清单”。
- “看过”使用可滚动、键盘安全的 Material 3 bottom sheet；评分和评论均有效前不可提交。
- 表单必须使用共享 `StarRating`，五颗星分别回调整数 1–5。
- `StarRating` 现有只读、半星和 10 分制折算行为不得改变。
- “存入清单”、公开短评列表、点赞和举报行为不得改变。
- 认证错误继续交给现有全局认证处理；不重复显示普通失败提示。
- 不新增依赖，不推送远端，不触发版本发布。

---

### Task 1: 解析详情中的当前用户影评

**Files:**

- Modify: `lib/core/models/movie.dart`
- Modify (generated): `lib/core/models/movie.g.dart`
- Modify: `lib/core/network/api_data.dart`
- Test: `test/core/network/api_data_test.dart`

**Interfaces:**

- Consumes: `Review`、`normalizeReviewJson`、`MovieDetail.fromJson`
- Produces: `MovieDetail.review`，类型为 `Review?`，JSON key 为 `review` 且不参与 `toJson`

- [ ] **Step 1: 写入当前用户影评归一化失败测试**

在 `test/core/network/api_data_test.dart` 增加：

```dart
test('normalizeMovieDetailJson 解析当前用户影评并统一数字 ID', () {
  final movie = MovieDetail.fromJson(
    normalizeMovieDetailJson({
      'movie': {
        'id': 'm1',
        'number': 'ABC-001',
        'title': 'Title',
        'cover_url': '',
        'review': {
          'id': 245236128,
          'status': 'watched',
          'score': 3,
          'content': '评论内容',
        },
      },
    }),
  );

  expect(movie.review?.id, '245236128');
  expect(movie.review?.status, 'watched');
  expect(movie.review?.score, 3);
  expect(movie.review?.content, '评论内容');
});

test('normalizeMovieDetailJson 将缺失或 null review 解析为 null', () {
  for (final review in <Object?>[null, const _AbsentReview()]) {
    final json = <String, dynamic>{
      'id': 'm1',
      'number': 'ABC-001',
      'title': 'Title',
      'cover_url': '',
    };
    if (review is! _AbsentReview) json['review'] = review;

    final movie = MovieDetail.fromJson(normalizeMovieDetailJson(json));

    expect(movie.review, isNull);
  }
});
```

在测试文件末尾增加：

```dart
class _AbsentReview {
  const _AbsentReview();
}
```

- [ ] **Step 2: 运行测试确认 RED**

Run:

```bash
flutter test test/core/network/api_data_test.dart --plain-name 'normalizeMovieDetailJson 解析当前用户影评并统一数字 ID'
```

Expected: FAIL，因为 `MovieDetail` 尚无 `review` getter。

- [ ] **Step 3: 为 MovieDetail 增加只读影评字段**

在 `lib/core/models/movie.dart` 引入 `review.dart`，给构造函数增加 `this.review`，并在字段区增加：

```dart
@JsonKey(includeToJson: false)
final Review? review;
```

在 `normalizeMovieDetailJson` 读取详情内的 review：

```dart
final review = movie['review'];
```

返回 Map 时加入：

```dart
'review': review is Map
    ? normalizeReviewJson(Map<String, dynamic>.from(review))
    : null,
```

- [ ] **Step 4: 更新 json_serializable 产物**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

检查 `lib/core/models/movie.g.dart` 只新增 `Review.fromJson` 的 `review` 解析，没有无关生成文件变化。

- [ ] **Step 5: 运行模型测试确认 GREEN**

Run:

```bash
flutter test test/core/network/api_data_test.dart
```

Expected: PASS，新增影评测试与现有归一化测试全部通过。

- [ ] **Step 6: 提交 Task 1**

```bash
git add lib/core/models/movie.dart lib/core/models/movie.g.dart lib/core/network/api_data.dart test/core/network/api_data_test.dart
git commit -m "feat(movie-detail): parse current user review"
```

---

### Task 2: 为 StarRating 增加无回归的交互模式

**Files:**

- Modify: `lib/core/widgets/star_rating.dart`
- Create: `test/core/widgets/star_rating_test.dart`
- Regression: `test/core/widgets/movie_card_test.dart`
- Regression: `test/core/widgets/review_tile_test.dart`

**Interfaces:**

- Consumes: 现有 `score`、`semanticLabel`、`size`
- Produces:

```dart
const StarRating({
  super.key,
  required this.score,
  this.semanticLabel = '评分',
  this.size = 18,
  this.onChanged,
  this.enabled = true,
});

final ValueChanged<int>? onChanged;
final bool enabled;
```

- [ ] **Step 1: 写入交互模式失败测试**

创建 `test/core/widgets/star_rating_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/star_rating.dart';

void main() {
  testWidgets('交互评分五颗星分别回调 1 到 5', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRating(
            score: selected?.toDouble() ?? 0,
            size: 32,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    for (var value = 1; value <= 5; value++) {
      await tester.tap(find.byKey(Key('star-rating-$value')));
      expect(selected, value);
    }
  });

  testWidgets('交互评分按选中整数显示实心星且没有半星', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRating(score: 3, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_half_rounded), findsNothing);
  });

  testWidgets('交互评分禁用时保持选中显示且不回调', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRating(
            score: 4,
            enabled: false,
            onChanged: (_) => calls++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('star-rating-2')));
    expect(calls, 0);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
  });

  testWidgets('交互评分每颗星具有独立按钮语义', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRating(score: 0, onChanged: (_) {}),
        ),
      ),
    );

    for (var value = 1; value <= 5; value++) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '$value分' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
    }
  });
}
```

- [ ] **Step 2: 运行测试确认 RED**

Run:

```bash
flutter test test/core/widgets/star_rating_test.dart
```

Expected: 编译失败，因为 `onChanged`、`enabled` 和星级 Key 尚不存在。

- [ ] **Step 3: 保留只读路径并实现交互路径**

在 `StarRating` 中保留现有只读 `Semantics + ExcludeSemantics + Row` 分支不变。`onChanged != null` 时返回交互 Row：

```dart
Widget _buildInteractive(BuildContext context, double value, Color color) {
  return Semantics(
    label: value == 0
        ? '$semanticLabel 未评分'
        : '$semanticLabel ${value.toInt()} 分',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 1,
      children: [
        for (var index = 0; index < 5; index++)
          Semantics(
            button: true,
            enabled: enabled,
            selected: value >= index + 1,
            label: '${index + 1}分',
            child: InkResponse(
              key: Key('star-rating-${index + 1}'),
              onTap: enabled ? () => onChanged!(index + 1) : null,
              radius: 24,
              child: SizedBox.square(
                dimension: size < 48 ? 48 : size,
                child: Icon(
                  value >= index + 1
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: size,
                  color: color,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
```

`build` 中按 `onChanged` 分流，交互模式把 `_starScore` 的值限制到 0–5，但不生成半星。

- [ ] **Step 4: 运行共享组件和消费者回归测试**

Run:

```bash
flutter test test/core/widgets/star_rating_test.dart test/core/widgets/movie_card_test.dart test/core/widgets/review_tile_test.dart
```

Expected: PASS；既有 7.5 分显示 3 实星、1 半星、1 空星的断言保持通过。

- [ ] **Step 5: 提交 Task 2**

```bash
git add lib/core/widgets/star_rating.dart test/core/widgets/star_rating_test.dart
git commit -m "feat(ui): make star rating optionally interactive"
```

---

### Task 3: 实现“标记为看过”表单

**Files:**

- Create: `lib/features/movie_detail/widgets/watched_review_sheet.dart`
- Create: `test/features/movie_detail/watched_review_sheet_test.dart`

**Interfaces:**

- Consumes: 交互式 `StarRating`
- Produces:

```dart
typedef WatchedReviewSubmit =
    Future<void> Function({required int score, required String content});

class WatchedReviewSheet extends StatefulWidget {
  const WatchedReviewSheet({super.key, required this.onSubmit});
  final WatchedReviewSubmit onSubmit;
}
```

- [ ] **Step 1: 写入表单验证失败测试**

创建 `test/features/movie_detail/watched_review_sheet_test.dart`，覆盖：

```dart
testWidgets('评分和非空评论都满足后才允许提交', (tester) async {
  ({int score, String content})? submitted;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WatchedReviewSheet(
          onSubmit: ({required score, required content}) async {
            submitted = (score: score, content: content);
          },
        ),
      ),
    ),
  );

  FilledButton submitButton() => tester.widget(
    find.byKey(const Key('watched-review-submit-button')),
  );

  expect(submitButton().onPressed, isNull);
  await tester.tap(find.byKey(const Key('star-rating-3')));
  await tester.pump();
  expect(submitButton().onPressed, isNull);

  await tester.enterText(
    find.byKey(const Key('watched-review-content-field')),
    '  评论内容  ',
  );
  await tester.pump();
  expect(submitButton().onPressed, isNotNull);

  await tester.tap(find.byKey(const Key('watched-review-submit-button')));
  await tester.pumpAndSettle();
  expect(submitted, (score: 3, content: '评论内容'));
});
```

使用下列异步重复提交测试：用 `Completer<void>` 阻塞 `onSubmit`，连续点击提交两次，断言 callback 只调用一次，输入框、StarRating 与两个操作按钮均禁用。

增加失败保留测试：`onSubmit` 抛出异常后，断言 sheet 未关闭、评分和评论仍在，并显示 `操作失败，请重试`。

对应测试体：

```dart
testWidgets('提交期间禁用表单且重复点击只提交一次', (tester) async {
  final completer = Completer<void>();
  var calls = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WatchedReviewSheet(
          onSubmit: ({required score, required content}) {
            calls++;
            return completer.future;
          },
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('star-rating-4')));
  await tester.enterText(
    find.byKey(const Key('watched-review-content-field')),
    '评论',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('watched-review-submit-button')));
  await tester.tap(find.byKey(const Key('watched-review-submit-button')));
  await tester.pump();

  expect(calls, 1);
  expect(
    tester
        .widget<TextField>(
          find.byKey(const Key('watched-review-content-field')),
        )
        .enabled,
    isFalse,
  );
  expect(
    tester
        .widget<StarRating>(
          find.byKey(const Key('watched-review-rating')),
        )
        .enabled,
    isFalse,
  );

  completer.complete();
  await tester.pumpAndSettle();
});

testWidgets('提交失败保留评分评论并允许重试', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WatchedReviewSheet(
          onSubmit: ({required score, required content}) async {
            throw StateError('failed');
          },
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('star-rating-2')));
  await tester.enterText(
    find.byKey(const Key('watched-review-content-field')),
    '保留的评论',
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('watched-review-submit-button')));
  await tester.pump();

  expect(find.text('操作失败，请重试'), findsOneWidget);
  expect(find.text('保留的评论'), findsOneWidget);
  expect(
    tester
        .widget<FilledButton>(
          find.byKey(const Key('watched-review-submit-button')),
        )
        .onPressed,
    isNotNull,
  );
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run:

```bash
flutter test test/features/movie_detail/watched_review_sheet_test.dart
```

Expected: 编译失败，因为 `WatchedReviewSheet` 尚不存在。

- [ ] **Step 3: 实现键盘安全 bottom-sheet 内容**

组件使用：

```dart
Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
  child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text('标记为看过', style: Theme.of(context).textTheme.titleLarge),
        const Text('评分'),
        StarRating(
          key: const Key('watched-review-rating'),
          score: _score.toDouble(),
          size: 32,
          enabled: !_submitting,
          onChanged: (value) => setState(() => _score = value),
        ),
        TextField(
          key: const Key('watched-review-content-field'),
          controller: _contentController,
          enabled: !_submitting,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: '评论内容'),
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null)
          Text(
            _error!,
            key: const Key('watched-review-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              key: const Key('watched-review-cancel-button'),
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('watched-review-submit-button'),
              onPressed: _canSubmit ? _submit : null,
              child: Text(_submitting ? '提交中' : '提交'),
            ),
          ],
        ),
      ],
    ),
  ),
)
```

`_canSubmit` 必须要求 `_score` 在 1–5、评论 trim 后非空且未提交。`_submit` 在 callback 成功后 `Navigator.pop`，失败时保留输入并设置 `_error`。`dispose` 释放 `TextEditingController`。

- [ ] **Step 4: 运行表单测试确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/watched_review_sheet_test.dart
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 3**

```bash
git add lib/features/movie_detail/widgets/watched_review_sheet.dart test/features/movie_detail/watched_review_sheet_test.dart
git commit -m "feat(movie-detail): add watched review form"
```

---

### Task 4: 实现影评创建、更新和删除接口

**Files:**

- Create: `lib/features/movie_detail/models/movie_review_status.dart`
- Modify: `lib/core/network/api_client.dart`
- Modify: `lib/features/movie_detail/services/movie_detail_service.dart`
- Create: `test/features/movie_detail/movie_detail_service_test.dart`

**Interfaces:**

- Produces:

```dart
enum MovieReviewStatus {
  wantWatch('want_watch'),
  watched('watched');

  const MovieReviewStatus(this.wireValue);
  final String wireValue;
}

Future<Review> createOrUpdateReview({
  required String movieId,
  required MovieReviewStatus status,
  int? score,
  String? content,
});

Future<void> deleteReview({
  required String movieId,
  required String reviewId,
});
```

- [ ] **Step 1: 写入接口契约失败测试**

使用真实测试 `ApiClient`、`ResponseInterceptor` 和 `FakeAdapter` 创建 `movie_detail_service_test.dart`。核心断言：

```dart
test('想看只发送 status JSON 并解析返回 review', () async {
  final fixture = await _buildFixture();
  fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
    'success': 1,
    'data': {
      'review': {'id': 10, 'status': 'want_watch'},
    },
  });

  final review = await fixture.service.createOrUpdateReview(
    movieId: 'm1',
    status: MovieReviewStatus.wantWatch,
  );

  final request = fixture.adapter.requests.single;
  expect(request.method, 'POST');
  expect(request.data, {'status': 'want_watch'});
  expect(review.id, '10');
  expect(review.status, 'want_watch');
});

test('看过发送 1 到 5 分 裁剪评论和 watched 状态', () async {
  final fixture = await _buildFixture();
  fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
    'success': 1,
    'data': {
      'review': {
        'id': 'r1',
        'status': 'watched',
        'score': 5,
        'content': '评论内容',
      },
    },
  });

  await fixture.service.createOrUpdateReview(
    movieId: 'm1',
    status: MovieReviewStatus.watched,
    score: 5,
    content: '  评论内容  ',
  );

  expect(fixture.adapter.requests.single.data, {
    'score': 5,
    'content': '评论内容',
    'status': 'watched',
  });
});

test('看过接受 1 分边界值', () async {
  final fixture = await _buildFixture();
  fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
    'success': 1,
    'data': {
      'review': {
        'id': 'r-min',
        'status': 'watched',
        'score': 1,
        'content': '最低分评论',
      },
    },
  });

  await fixture.service.createOrUpdateReview(
    movieId: 'm1',
    status: MovieReviewStatus.watched,
    score: 1,
    content: '最低分评论',
  );

  expect(fixture.adapter.requests.single.data['score'], 1);
});
```

使用下列表驱动校验测试覆盖 `score` 为 0、6 或 null，以及 `content` 为 null、空串、纯空白的情况：

```dart
test('看过在评分或评论无效时不发送请求', () async {
  for (final input in <({int? score, String? content})>[
    (score: null, content: '评论'),
    (score: 0, content: '评论'),
    (score: 6, content: '评论'),
    (score: 3, content: null),
    (score: 3, content: ''),
    (score: 3, content: '   '),
  ]) {
    final fixture = await _buildFixture();

    await expectLater(
      fixture.service.createOrUpdateReview(
        movieId: 'm1',
        status: MovieReviewStatus.watched,
        score: input.score,
        content: input.content,
      ),
      throwsArgumentError,
    );
    expect(fixture.adapter.requests, isEmpty);
  }
});
```

增加删除测试：

```dart
test('删除影评使用 movie ID 与 review ID 组成路径', () async {
  final fixture = await _buildFixture();
  fixture.adapter.enqueue('/api/v1/movies/m1/reviews/r9', {
    'success': 1,
    'data': {'review': null},
  });

  await fixture.service.deleteReview(movieId: 'm1', reviewId: 'r9');

  expect(fixture.adapter.requests.single.method, 'DELETE');
  expect(
    fixture.adapter.requests.single.path,
    '/api/v1/movies/m1/reviews/r9',
  );
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_service_test.dart
```

Expected: 编译失败，因为 enum、service 方法与 `ApiClient.delete` 尚不存在。

- [ ] **Step 3: 实现类型、DELETE 转发和服务校验**

在 `ApiClient` 增加：

```dart
Future<Response> delete(String path, {dynamic data}) {
  return dio.delete(path, data: data);
}
```

在 enum 声明前增加 Dartdoc：`/// 影片详情影评操作使用的服务端状态。`

在 service 中：

```dart
Future<Review> createOrUpdateReview({
  required String movieId,
  required MovieReviewStatus status,
  int? score,
  String? content,
}) async {
  final data = switch (status) {
    MovieReviewStatus.wantWatch => <String, dynamic>{
      'status': status.wireValue,
    },
    MovieReviewStatus.watched => _watchedReviewData(
      status: status,
      score: score,
      content: content,
    ),
  };
  final response = await _api.post(
    '/api/v1/movies/$movieId/reviews',
    data: data,
  );
  final review = apiMap(response.data)['review'];
  if (review is! Map) {
    throw const FormatException('影评响应缺少 review');
  }
  return Review.fromJson(
    normalizeReviewJson(Map<String, dynamic>.from(review)),
  );
}

Future<void> deleteReview({
  required String movieId,
  required String reviewId,
}) async {
  await _api.delete('/api/v1/movies/$movieId/reviews/$reviewId');
}
```

`_watchedReviewData` 对 score 和 trim 后 content 做精确校验并返回三个字段的 Map。

- [ ] **Step 4: 运行接口测试确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_service_test.dart
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 4**

```bash
git add lib/features/movie_detail/models/movie_review_status.dart lib/core/network/api_client.dart lib/features/movie_detail/services/movie_detail_service.dart test/features/movie_detail/movie_detail_service_test.dart
git commit -m "feat(movie-detail): add review mutation service"
```

---

### Task 5: 封装详情操作按钮状态矩阵

**Files:**

- Create: `lib/features/movie_detail/widgets/movie_review_actions.dart`
- Create: `test/features/movie_detail/movie_review_actions_test.dart`

**Interfaces:**

- Consumes: `Review? review`、`bool loading`
- Produces:

```dart
class MovieReviewActions extends StatelessWidget {
  const MovieReviewActions({
    super.key,
    required this.review,
    required this.loading,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDelete,
    required this.onSaveToList,
  });
}
```

- [ ] **Step 1: 写入三态渲染失败测试**

创建下列测试 helper，并分别泵入 `null`、`Review(id: 'r1', status: 'want_watch')`、`Review(id: 'r2', status: 'watched')`：

```dart
Future<void> pumpActions(
  WidgetTester tester, {
  Review? review,
  bool loading = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MovieReviewActions(
          review: review,
          loading: loading,
          onWantWatch: () {},
          onWatched: () {},
          onDelete: () {},
          onSaveToList: () {},
        ),
      ),
    ),
  );
}

List<String> buttonLabels(WidgetTester tester) {
  return tester
      .widgetList<FilledButton>(find.byType(FilledButton))
      .map((button) => (button.child as Text).data!)
      .toList();
}

testWidgets('未标记时按想看看过存入清单排序', (tester) async {
  await pumpActions(tester);
  expect(buttonLabels(tester), ['想看', '看过', '存入清单']);
  expect(
    tester.getTopLeft(find.text('想看')).dx,
    lessThan(tester.getTopLeft(find.text('存入清单')).dx),
  );
  expect(
    tester.getTopLeft(find.text('看过')).dx,
    lessThan(tester.getTopLeft(find.text('存入清单')).dx),
  );
});
```

补充想看、看过与 loading 三态测试：

```dart
testWidgets('想看状态显示删除想看看过存入清单', (tester) async {
  await pumpActions(
    tester,
    review: const Review(id: 'r1', status: 'want_watch'),
  );
  expect(buttonLabels(tester), ['删除想看', '看过', '存入清单']);
});

testWidgets('看过状态只显示删除看过和存入清单', (tester) async {
  await pumpActions(
    tester,
    review: const Review(id: 'r2', status: 'watched'),
  );
  expect(buttonLabels(tester), ['删除看过', '存入清单']);
});

testWidgets('未知影评状态回退为未标记操作', (tester) async {
  await pumpActions(
    tester,
    review: const Review(id: 'r3', status: 'unknown'),
  );
  expect(buttonLabels(tester), ['想看', '看过', '存入清单']);
});

testWidgets('加载时只禁用影评操作而保留存入清单', (tester) async {
  await pumpActions(tester, loading: true);
  expect(
    tester
        .widget<FilledButton>(
          find.byKey(const Key('movie-want-watch-button')),
        )
        .onPressed,
    isNull,
  );
  expect(
    tester
        .widget<FilledButton>(
          find.byKey(const Key('movie-watched-button')),
        )
        .onPressed,
    isNull,
  );
  expect(
    tester
        .widget<FilledButton>(
          find.byKey(const Key('movie-save-to-list-button')),
        )
        .onPressed,
    isNotNull,
  );
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_review_actions_test.dart
```

Expected: 编译失败，因为 `MovieReviewActions` 尚不存在。

- [ ] **Step 3: 实现稳定 Key、顺序和紧凑样式**

组件内部复用当前详情页的 `FilledButton.styleFrom`：

```dart
minimumSize: const Size(0, 32),
padding: const EdgeInsets.symmetric(horizontal: 12),
visualDensity: VisualDensity.compact,
textStyle: Theme.of(context).textTheme.labelMedium,
```

使用 `Wrap(spacing: 8, runSpacing: 6)`。Key 固定为：

- `movie-want-watch-button`
- `movie-watched-button`
- `movie-delete-want-watch-button`
- `movie-delete-watched-button`
- `movie-save-to-list-button`

只有 `want_watch` 与 `watched` 进入删除状态；null 或未知 status 渲染未标记状态。

- [ ] **Step 4: 运行按钮组件测试确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_review_actions_test.dart
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 5**

```bash
git add lib/features/movie_detail/widgets/movie_review_actions.dart test/features/movie_detail/movie_review_actions_test.dart
git commit -m "feat(movie-detail): add review action states"
```

---

### Task 6: 接入影片详情状态机与服务端校准

**Files:**

- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`
- Reuse: `lib/features/movie_detail/widgets/watched_review_sheet.dart`
- Reuse: `lib/features/movie_detail/widgets/movie_review_actions.dart`

**Interfaces:**

- Consumes: Tasks 1–5 的 `MovieDetail.review`、`MovieReviewStatus`、service mutation、`WatchedReviewSheet`、`MovieReviewActions`
- Produces: 详情页完整想看/看过交互

- [ ] **Step 1: 扩展详情测试 fixture**

给 `_enqueueCompleteMovieDetail` 增加：

```dart
Map<String, dynamic>? userReview,
```

在 movie fixture 中加入：

```dart
'review': userReview,
```

需要校准详情的测试使用同一路径的两个 `_detailResponse`：第一个明确传入操作前 review/count，第二个明确传入操作后 review/count。

增加精简详情响应 helper，避免每个 mutation 测试复制完整 fixture：

```dart
Map<String, dynamic> _detailResponse({
  Map<String, dynamic>? review,
  int wantWatchCount = 12,
  int watchedCount = 8,
}) {
  return {
    'success': 1,
    'data': {
      'movie': {
        'id': 'm1',
        'number': 'SSIS-001',
        'title': '测试影片',
        'cover_url': 'covers/test.jpg',
        'want_watch_count': wantWatchCount,
        'watched_count': watchedCount,
        'review': review,
        'actors': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      },
    },
  };
}
```

- [ ] **Step 2: 写入页面状态和请求失败测试**

在 `movie_detail_screen_test.dart` 增加以下可独立运行的测试：

1. `详情无 review 时想看按钮发送单字段 JSON 并变为删除想看`
2. `已想看点击看过填写 3 分与评论后直接 POST watched 且不 DELETE`
3. `已看过只显示删除看过并用详情 review ID 删除`
4. `已想看删除时使用详情 review ID`
5. `影评 mutation 延迟期间重复点击只发送一个请求`
6. `影评 mutation 非认证失败保持原按钮状态`
7. `影评认证失败触发现有全局认证处理且无普通失败提示`
8. `mutation 成功但详情校准失败保留新按钮状态并提示刷新失败`

“看过”请求测试必须执行真实表单交互：

```dart
await tester.tap(find.byKey(const Key('movie-watched-button')));
await tester.pumpAndSettle();
await tester.tap(find.byKey(const Key('star-rating-3')));
await tester.enterText(
  find.byKey(const Key('watched-review-content-field')),
  '评论内容',
);
await tester.pump();
await tester.tap(find.byKey(const Key('watched-review-submit-button')));
```

然后断言最后一个 POST：

```dart
expect(request.data, {
  'score': 3,
  'content': '评论内容',
  'status': 'watched',
});
expect(
  adapter.requests.where((request) => request.method == 'DELETE'),
  isEmpty,
);
```

无 review 创建想看的完整测试骨架：

```dart
testWidgets('详情无 review 时想看按钮发送单字段 JSON并变为删除想看', (tester) async {
  _mockPathProvider(tester);
  final adapter = await _setupApiClient();
  _enqueueCompleteMovieDetail(adapter);
  adapter.enqueueSequence('/api/v4/movies/m1', [
    _detailResponse(),
    _detailResponse(
      review: {'id': 'r1', 'status': 'want_watch'},
      wantWatchCount: 13,
    ),
  ]);
  adapter.enqueue('/api/v1/movies/m1/reviews', {
    'success': 1,
    'data': {
      'review': {'id': 'r1', 'status': 'want_watch'},
    },
  });

  await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(const Key('movie-want-watch-button')));
  await _pumpUntilRequest(
    tester,
    adapter,
    '/api/v1/movies/m1/reviews',
  );
  await _pumpUntilText(tester, '删除想看');

  final request = adapter.requests.lastWhere(
    (request) =>
        request.path == '/api/v1/movies/m1/reviews' &&
        request.method == 'POST',
  );
  expect(request.data, {'status': 'want_watch'});
  expect(find.text('13人想看，8人看过'), findsOneWidget);
});
```

已想看更新为看过的测试在上述真实表单交互后断言：

```dart
final post = adapter.requests.lastWhere(
  (request) =>
      request.path == '/api/v1/movies/m1/reviews' &&
      request.method == 'POST',
);
expect(post.data, {
  'score': 3,
  'content': '评论内容',
  'status': 'watched',
});
expect(
  adapter.requests.where((request) => request.method == 'DELETE'),
  isEmpty,
);
await _pumpUntilText(tester, '删除看过');
expect(find.byKey(const Key('movie-want-watch-button')), findsNothing);
```

删除看过测试使用初始 `review={'id':'r9','status':'watched'}`，为 `/api/v1/movies/m1/reviews/r9` 入队成功响应并断言：

```dart
await tester.tap(find.byKey(const Key('movie-delete-watched-button')));
await _pumpUntilRequest(
  tester,
  adapter,
  '/api/v1/movies/m1/reviews/r9',
);
expect(
  adapter.requests.lastWhere((request) => request.method == 'DELETE').path,
  '/api/v1/movies/m1/reviews/r9',
);
await _pumpUntilText(tester, '想看');
expect(find.byKey(const Key('movie-watched-button')), findsOneWidget);
```

删除想看测试使用初始 `review={'id':'r-want','status':'want_watch'}`，为 `/api/v1/movies/m1/reviews/r-want` 入队成功响应并断言：

```dart
await tester.tap(
  find.byKey(const Key('movie-delete-want-watch-button')),
);
await _pumpUntilRequest(
  tester,
  adapter,
  '/api/v1/movies/m1/reviews/r-want',
);
expect(
  adapter.requests.lastWhere((request) => request.method == 'DELETE').path,
  '/api/v1/movies/m1/reviews/r-want',
);
await _pumpUntilText(tester, '想看');
expect(
  find.byKey(const Key('movie-delete-want-watch-button')),
  findsNothing,
);
```

重复提交测试在 POST 前设置 `adapter.responseDelay = const Duration(milliseconds: 200)`，无 pump 连续调用两次想看按钮的 `onPressed`，随后断言：

```dart
expect(
  adapter.requests.where(
    (request) =>
        request.path == '/api/v1/movies/m1/reviews' &&
        request.method == 'POST',
  ),
  hasLength(1),
);
```

非认证失败测试使用：

```dart
adapter.enqueue('/api/v1/movies/m1/reviews', {
  'success': 0,
  'message': 'server failed',
}, statusCode: 500);
await tester.tap(find.byKey(const Key('movie-want-watch-button')));
await _pumpUntilRequest(
  tester,
  adapter,
  '/api/v1/movies/m1/reviews',
);
await tester.pump();

expect(find.byKey(const Key('movie-want-watch-button')), findsOneWidget);
expect(find.byKey(const Key('movie-watched-button')), findsOneWidget);
expect(
  find.byKey(const Key('movie-delete-want-watch-button')),
  findsNothing,
);
expect(find.text('操作失败，请重试'), findsOneWidget);
```

认证失败测试使用：

```dart
var authCalled = false;
final adapter = await _setupApiClient(
  onAuthError: () => authCalled = true,
);
adapter.enqueue('/api/v1/movies/m1/reviews', {
  'success': 0,
  'action': 'JWTVerificationError',
  'message': '请登录',
}, statusCode: 401);
```

点击“想看”并等待请求后断言：

```dart
expect(authCalled, isTrue);
expect(find.text('操作失败，请重试'), findsNothing);
expect(find.byKey(const Key('movie-want-watch-button')), findsOneWidget);
```

校准失败测试让 POST 成功返回 want-watch review，并将详情响应配置为：

```dart
adapter.enqueueSequence(
  '/api/v4/movies/m1',
  [
    _detailResponse(),
    {'success': 0, 'message': 'refresh failed'},
  ],
  codes: [200, 500],
);
```

点击“想看”后断言：

```dart
await _pumpUntilText(tester, '删除想看');
expect(
  find.byKey(const Key('movie-delete-want-watch-button')),
  findsOneWidget,
);
expect(find.text('状态已更新，详情刷新失败'), findsOneWidget);
```

- [ ] **Step 3: 运行新增页面测试确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_screen_test.dart --plain-name '详情无 review 时想看按钮发送单字段 JSON 并变为删除想看'
```

Expected: FAIL，因为详情页尚未渲染想看按钮。

- [ ] **Step 4: 增加页面状态和 mutation 方法**

在 `_MovieDetailPageState` 增加：

```dart
Review? _currentReview;
bool _reviewMutationLoading = false;
```

首次详情加载成功时同时设置：

```dart
_detail = detail;
_currentReview = detail.review;
```

增加：

```dart
Future<void> _createOrUpdateReview(
  MovieReviewStatus status, {
  int? score,
  String? content,
}) async
```

```dart
Future<void> _deleteCurrentReview() async
```

```dart
Future<void> _refreshDetailAfterReview() async
```

三个方法按以下边界实现：

- 进入时若 `_reviewMutationLoading` 为 true 立即返回。
- POST 成功先设置 `_currentReview = review`。
- DELETE 成功先设置 `_currentReview = null`。
- `_refreshDetailAfterReview` 自己捕获校准错误；成功时同时更新 `_detail`、`_currentReview`，失败时只提示 `状态已更新，详情刷新失败`，不向 mutation 调用者抛出。
- POST/DELETE 本身失败时不改状态；认证错误直接返回，其他错误向调用者重抛。
- finally 恢复 `_reviewMutationLoading=false`。

为直接按钮与表单建立不同的错误呈现 wrapper：

```dart
Future<void> _markWantWatch() async {
  try {
    await _createOrUpdateReview(MovieReviewStatus.wantWatch);
  } catch (_) {
    if (mounted) _showSnackBar('操作失败，请重试');
  }
}

Future<void> _submitWatchedReview({
  required int score,
  required String content,
}) {
  return _createOrUpdateReview(
    MovieReviewStatus.watched,
    score: score,
    content: content,
  );
}

Future<void> _removeCurrentReview() async {
  try {
    await _deleteCurrentReview();
  } catch (_) {
    if (mounted) _showSnackBar('操作失败，请重试');
  }
}
```

`_createOrUpdateReview` 与 `_deleteCurrentReview` 在捕获到 `_isAuthError(error)` 时正常返回，避免 wrapper 或 sheet 再显示普通失败提示；非认证错误才 rethrow。

- [ ] **Step 5: 接入看过表单和操作按钮**

增加：

```dart
Future<void> _openWatchedReviewSheet() {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => WatchedReviewSheet(
      onSubmit: ({required score, required content}) =>
          _submitWatchedReview(
        score: score,
        content: content,
      ),
    ),
  );
}
```

为 `_MovieDetailTabs`、`_BasicInfoTab`、`_MovieInfoCard` 传入：

```dart
review: _currentReview,
reviewMutationLoading: _reviewMutationLoading,
onWantWatch: () => unawaited(_markWantWatch()),
onWatched: () => unawaited(_openWatchedReviewSheet()),
onDeleteReview: () => unawaited(_removeCurrentReview()),
```

`_MovieInfoCard` 用 `MovieReviewActions` 替换原有只含“存入清单”的 Wrap；divider 与人数文案位置不变。

直接“想看”和删除操作由 wrapper 显示失败 SnackBar。表单提交的非认证错误由 `WatchedReviewSheet` 保留并展示。

- [ ] **Step 6: 运行详情页面和相关回归测试**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_screen_test.dart test/features/movie_detail/watched_review_sheet_test.dart test/features/movie_detail/movie_review_actions_test.dart
```

Expected: PASS。

再运行存入清单与路由相关回归：

```bash
flutter test test/core/router/app_router_requirements_test.dart test/core/widgets/star_rating_test.dart test/core/widgets/movie_card_test.dart test/core/widgets/review_tile_test.dart
```

Expected: PASS。

- [ ] **Step 7: 提交 Task 6**

```bash
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "feat(movie-detail): add want and watched actions"
```

---

### Task 7: 最终验证

**Files:**

- Verify only; no planned production changes

**Interfaces:**

- Consumes: Tasks 1–6 complete branch
- Produces: merge-ready verification evidence

- [ ] **Step 1: 格式化所有改动 Dart 文件**

Run:

```bash
dart format lib/core/models/movie.dart lib/core/network/api_data.dart lib/core/network/api_client.dart lib/core/widgets/star_rating.dart lib/features/movie_detail/models/movie_review_status.dart lib/features/movie_detail/services/movie_detail_service.dart lib/features/movie_detail/widgets/watched_review_sheet.dart lib/features/movie_detail/widgets/movie_review_actions.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/network/api_data_test.dart test/core/widgets/star_rating_test.dart test/features/movie_detail/movie_detail_service_test.dart test/features/movie_detail/watched_review_sheet_test.dart test/features/movie_detail/movie_review_actions_test.dart test/features/movie_detail/movie_detail_screen_test.dart
```

- [ ] **Step 2: 运行完整测试**

Run:

```bash
flutter test --reporter compact
```

Expected: 所有测试通过，0 failures。

- [ ] **Step 3: 运行完整静态分析**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: 检查差异与范围**

Run:

```bash
git diff --check
git status --short
git log --oneline --decorate -10
git diff --stat "$(git merge-base master HEAD)"..HEAD
```

确认：

- 无空白错误。
- 只有本计划列出的源码、测试和生成文件发生变化。
- 无依赖、版本号、短评列表、点赞、举报或存入清单业务改动。

- [ ] **Step 5: 请求整分支代码审查**

使用 `superpowers:requesting-code-review` 对设计规格、计划和完整分支差异进行规格与代码质量审查。所有 Critical/Important finding 修复并复审后，才可进入本地合并或保留分支选择。
