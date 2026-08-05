# AV资讯功能实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现首页豆腐块「AV资讯」：全宽卡片资讯列表页（无限滚动分页）+ 资讯详情页（flutter_html 渲染正文）。

**架构：** 新增 feature `lib/features/articles/`（models/services/screens/widgets/index），数据层参考 `TagMoviesService`（limit 48、无 total_pages 推断），列表页参考 `MovieGridView`/`ActorGridView` 的 `PaginationController` + `NotificationListener` + `RefreshIndicator` 状态机；`/articles` 路由由占位页替换为真实列表页，新增 `/articles/:id` 详情路由。

**技术栈：** Flutter、Dio（ApiClient）、go_router、json_serializable、cached_network_image（CachedImage）、flutter_html（正文 HTML 渲染，核心内置 img 标签支持）。

**规格：** `docs/superpowers/specs/2026-08-05-articles-feature-design.md`

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 修改 | `pubspec.yaml` | 新增 `flutter_html` |
| 创建 | `lib/features/articles/models/article.dart` | `ArticleSummary`（列表项）+ `ArticleDetail`（详情） |
| 生成 | `lib/features/articles/models/article.g.dart` | build_runner 生成 |
| 修改 | `lib/core/network/api_data.dart` | `normalizeArticleSummaryJson` / `normalizeArticleDetailJson` / `_articleAuthor` |
| 删除 | `lib/core/models/article.dart`、`article.g.dart` | 旧模型（无引用，迁移至 feature） |
| 创建 | `lib/features/articles/services/article_service.dart` | `ArticleService`：列表（page/limit=48）+ 详情 |
| 创建 | `lib/features/articles/widgets/article_card.dart` | 全宽资讯卡片（16:9 封面/2 行标题/作者·分类胶囊·时间） |
| 创建 | `lib/features/articles/screens/articles_screen.dart` | `ArticlesPage` 列表页（无限滚动分页） |
| 创建 | `lib/features/articles/screens/article_detail_screen.dart` | `ArticleDetailPage` 详情页（flutter_html 正文） |
| 创建 | `lib/features/articles/index.dart` | feature 入口，export 页面与模型 |
| 修改 | `lib/core/router/routes.dart` | 新增 `articleDetail = '/articles/:id'` |
| 修改 | `lib/core/router/app_router.dart` | `/articles` → `ArticlesPage`；`/articles/:id` → `ArticleDetailPage` |
| 测试 | `test/core/network/api_data_test.dart` | 追加 normalize 断言 |
| 测试 | `test/features/articles/article_service_test.dart` | 服务请求参数与解析 |
| 测试 | `test/features/articles/article_card_test.dart` | 卡片渲染与标签条件 |
| 测试 | `test/features/articles/articles_screen_test.dart` | 列表页状态机与分页 |
| 测试 | `test/features/articles/article_detail_screen_test.dart` | 详情页展示与图片 URL 解析 |

---

## 任务 1：添加 flutter_html 依赖

**文件：**
- 修改：`pubspec.yaml`

- [ ] **步骤 1：添加依赖**

运行：`flutter pub add flutter_html`
预期：`pub get` 成功，`pubspec.yaml` 出现 `flutter_html: ^3.0.0`。若版本解析冲突，按 pub 提示使用兼容约束后重试。

- [ ] **步骤 2：Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add flutter_html for article detail rendering"
```

---

## 任务 2：Article 模型 + normalize 函数

**文件：**
- 测试：`test/core/network/api_data_test.dart`（末尾追加 group）
- 创建：`lib/features/articles/models/article.dart`
- 生成：`lib/features/articles/models/article.g.dart`
- 修改：`lib/core/network/api_data.dart`
- 删除：`lib/core/models/article.dart`、`lib/core/models/article.g.dart`

- [ ] **步骤 1：编写失败的 normalize 测试**

在 `test/core/network/api_data_test.dart` 末尾追加（若文件已有 group 结构，追加为独立 `group`）：

```dart
group('normalizeArticleSummaryJson', () {
  test('author 支持字符串/对象/缺失三种形态', () {
    expect(
      normalizeArticleSummaryJson({'id': 1, 'title': 't', 'author': '作者'})['author'],
      '作者',
    );
    expect(
      normalizeArticleSummaryJson(
        {'id': 1, 'title': 't', 'author': {'name': '作者'}},
      )['author'],
      '作者',
    );
    expect(
      normalizeArticleSummaryJson({'id': 1, 'title': 't'})['author'],
      isNull,
    );
  });

  test('id 归一化为字符串，空 category 归一化为 null', () {
    final json = normalizeArticleSummaryJson({
      'id': 123,
      'title': '标题',
      'category': '  ',
    });
    expect(json['id'], '123');
    expect(json['category'], isNull);
    expect(json['cover_url'], isNull);
  });
});
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/core/network/api_data_test.dart`
预期：FAIL，编译错误 `normalizeArticleSummaryJson is not defined`。

- [ ] **步骤 3：创建模型文件**

`lib/features/articles/models/article.dart`：

```dart
import 'package:json_annotation/json_annotation.dart';
part 'article.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.title,
    this.coverUrl,
    this.author,
    this.category,
    this.releasedAt,
  });
  final String id;
  final String title;
  final String? coverUrl;
  final String? author;
  final String? category;
  final String? releasedAt;
  factory ArticleSummary.fromJson(Map<String, dynamic> json) =>
      _$ArticleSummaryFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ArticleDetail {
  const ArticleDetail({
    required this.id,
    required this.title,
    this.originName,
    this.originUrl,
    this.coverUrl,
    this.author,
    this.category,
    this.imageDomain,
    this.content,
    this.releasedAt,
  });
  final String id;
  final String title;
  final String? originName;
  final String? originUrl;
  final String? coverUrl;
  final String? author;
  final String? category;
  final String? imageDomain;
  final String? content;
  final String? releasedAt;
  factory ArticleDetail.fromJson(Map<String, dynamic> json) =>
      _$ArticleDetailFromJson(json);
}
```

- [ ] **步骤 4：在 api_data.dart 实现 normalize 函数**

在 `lib/core/network/api_data.dart` 的 `normalizeListModelJson` 之后追加：

```dart
String? _articleAuthor(dynamic author) {
  if (author is String) return _nonEmptyApiString(author);
  if (author is Map) {
    return _nonEmptyApiString(author['name'] ?? author['username']);
  }
  return _nonEmptyApiString(author);
}

Map<String, dynamic> normalizeArticleSummaryJson(Map<String, dynamic> json) {
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'title': apiString(json['title']) ?? '',
    'cover_url': apiString(json['cover_url']),
    'author': _articleAuthor(json['author']),
    'category': _nonEmptyApiString(json['category']),
    'released_at': apiString(json['released_at']),
  };
}

Map<String, dynamic> normalizeArticleDetailJson(dynamic data) {
  final root = apiMap(data);
  final article = apiMap(root['article']).isNotEmpty
      ? apiMap(root['article'])
      : root;
  return {
    ...normalizeArticleSummaryJson(article),
    'origin_name': apiString(article['origin_name']),
    'origin_url': apiString(article['origin_url']),
    'image_domain': apiString(article['image_domain']),
    'content': apiString(article['content']),
  };
}
```

- [ ] **步骤 5：生成 g.dart**

运行：`dart run build_runner build --delete-conflicting-outputs`
预期：生成 `lib/features/articles/models/article.g.dart`，无冲突报错。

- [ ] **步骤 6：删除旧模型**

用 DeleteFile 删除 `lib/core/models/article.dart` 与 `lib/core/models/article.g.dart`。

- [ ] **步骤 7：运行测试确认通过**

运行：`flutter test test/core/network/api_data_test.dart`
预期：PASS，新增 group 全部通过。

- [ ] **步骤 8：Commit**

```bash
git add lib/features/articles/models/ lib/core/network/api_data.dart test/core/network/api_data_test.dart
git rm lib/core/models/article.dart lib/core/models/article.g.dart
git commit -m "feat(articles): add article models and normalize helpers"
```

---

## 任务 3：ArticleService

**文件：**
- 测试：`test/features/articles/article_service_test.dart`
- 创建：`lib/features/articles/services/article_service.dart`

- [ ] **步骤 1：编写失败的测试**

`test/features/articles/article_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/articles/services/article_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getArticles 携带 page/limit 参数并解析列表', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueue(Endpoints.articles, {
      'success': 1,
      'data': {
        'articles': [
          {
            'id': 123,
            'title': '测试资讯',
            'cover_url': '/cover/1.jpg',
            'author': {'name': '作者A'},
            'category': '业界',
            'released_at': '2026-08-05',
          },
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getArticles(page: 1);

    expect(fixture.adapter.requests.single.queryParameters, {
      'page': 1,
      'limit': 48,
    });
    final item = result.items.single;
    expect(item.id, '123');
    expect(item.title, '测试资讯');
    expect(item.author, '作者A');
    expect(item.category, '业界');
    expect(item.releasedAt, '2026-08-05');
  });

  test('author 为字符串时直接使用', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueue(Endpoints.articles, {
      'success': 1,
      'data': {
        'articles': [
          {'id': 1, 'title': 't', 'author': '作者B'},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getArticles();

    expect(result.items.single.author, '作者B');
  });

  test('无 total_pages 时按 48 条阈值推断下一页', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueueSequence(Endpoints.articles, [
      {
        'success': 1,
        'data': {
          'articles': [
            for (var i = 0; i < 48; i++)
              {'id': i, 'title': 't$i'},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'articles': [
            {'id': 48, 'title': 't48'},
          ],
          'current_page': 2,
        },
      },
    ]);

    final full = await fixture.service.getArticles();
    final partial = await fixture.service.getArticles(page: 2);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 2);
  });

  test('getArticleDetail 请求 path 参数并解析详情', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueue('${Endpoints.articles}/456', {
      'success': 1,
      'data': {
        'id': 456,
        'title': '详情标题',
        'author': {'name': '作者C'},
        'category': '新作',
        'image_domain': 'https://img.example.com',
        'content': '<p>正文内容</p>',
        'released_at': '2026-08-05',
      },
    });

    final detail = await fixture.service.getArticleDetail('456');

    expect(fixture.adapter.requests.single.path, '${Endpoints.articles}/456');
    expect(detail.id, '456');
    expect(detail.title, '详情标题');
    expect(detail.author, '作者C');
    expect(detail.imageDomain, 'https://img.example.com');
    expect(detail.content, '<p>正文内容</p>');
  });
}

Future<({FakeAdapter adapter, ArticleService service})>
buildArticleFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: ArticleService(api));
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/features/articles/article_service_test.dart`
预期：FAIL，编译错误 `ArticleService is not defined`。

- [ ] **步骤 3：创建 ArticleService**

`lib/features/articles/services/article_service.dart`：

```dart
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/articles/models/article.dart';

class ArticleService {
  ArticleService(this._api);

  static const _pageSize = 48;
  final ApiClient _api;

  Future<PagedResult<ArticleSummary>> getArticles({int page = 1}) async {
    final response = await _api.get(
      Endpoints.articles,
      queryParameters: {'page': page, 'limit': _pageSize},
    );
    final data = apiMap(response.data);
    final items = apiList(data, const ['articles'])
        .map(normalizeArticleSummaryJson)
        .map(ArticleSummary.fromJson)
        .toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: currentPage + (items.length >= _pageSize ? 1 : 0),
      total: apiInt(data['total'], items.length),
    );
  }

  Future<ArticleDetail> getArticleDetail(String id) async {
    final response = await _api.get('${Endpoints.articles}/$id');
    return ArticleDetail.fromJson(normalizeArticleDetailJson(response.data));
  }
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/features/articles/article_service_test.dart`
预期：PASS，4 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/articles/services/ test/features/articles/article_service_test.dart
git commit -m "feat(articles): add article service with pagination"
```

---

## 任务 4：ArticleCard

**文件：**
- 测试：`test/features/articles/article_card_test.dart`
- 创建：`lib/features/articles/widgets/article_card.dart`

- [ ] **步骤 1：编写失败的测试**

`test/features/articles/article_card_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/widgets/article_card.dart';

void main() {
  ArticleSummary article({
    String id = '1',
    String title = '标题',
    String? author = '作者',
    String? category = '业界',
    String? releasedAt = '2026-08-05',
    String? coverUrl = 'cover.jpg',
  }) => ArticleSummary(
    id: id,
    title: title,
    author: author,
    category: category,
    releasedAt: releasedAt,
    coverUrl: coverUrl,
  );

  Future<void> pumpCard(WidgetTester tester, ArticleSummary item) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ArticleCard(article: item))),
    );
  }

  testWidgets('渲染标题与作者时间', (tester) async {
    await pumpCard(tester, article());

    expect(find.text('标题'), findsOneWidget);
    expect(find.text('作者'), findsOneWidget);
    expect(find.text('2026-08-05'), findsOneWidget);
  });

  testWidgets('渲染分类胶囊标签', (tester) async {
    await pumpCard(tester, article(category: '业界'));

    expect(find.text('业界'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(of: find.text('业界'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.red);
  });

  testWidgets('category 为空时不渲染标签', (tester) async {
    await pumpCard(tester, article(category: null));

    expect(find.textContaining('业界'), findsNothing);
  });

  testWidgets('封面 16:9 比例', (tester) async {
    await pumpCard(tester, article());

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 16 / 9);
  });

  testWidgets('无封面时显示占位而非崩溃', (tester) async {
    await pumpCard(tester, article(coverUrl: null));

    expect(find.byType(AspectRatio), findsOneWidget);
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/features/articles/article_card_test.dart`
预期：FAIL，编译错误 `ArticleCard is not defined`。

- [ ] **步骤 3：创建 ArticleCard**

`lib/features/articles/widgets/article_card.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/features/articles/models/article.dart';

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article});

  final ArticleSummary article;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = article.coverUrl;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/articles/${article.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: coverUrl == null || coverUrl.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 40,
                        ),
                      )
                    : CachedImage(
                        coverUrl,
                        fit: BoxFit.cover,
                        semanticLabel: article.title,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          article.author ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if (article.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            article.category!,
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        article.releasedAt ?? '',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/features/articles/article_card_test.dart`
预期：PASS，5 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/articles/widgets/article_card.dart test/features/articles/article_card_test.dart
git commit -m "feat(articles): add article card widget"
```

---

## 任务 5：ArticlesPage 列表页

**文件：**
- 测试：`test/features/articles/articles_screen_test.dart`
- 创建：`lib/features/articles/screens/articles_screen.dart`

- [ ] **步骤 1：编写失败的测试**

`test/features/articles/articles_screen_test.dart`（注入模式参考 `home_screen_test.dart`）：

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/articles/screens/articles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FakeAdapter> _pumpArticles(WidgetTester tester) async {
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
  final adapter = FakeAdapter();
  api.setAdapterForTest(adapter);
  adapter.enqueue(Endpoints.articles, {
    'success': 1,
    'data': {
      'articles': [
        {
          'id': 1,
          'title': '资讯一',
          'author': {'name': '作者A'},
          'category': '业界',
          'released_at': '2026-08-05',
          'cover_url': 'cover1.jpg',
        },
      ],
      'current_page': 1,
    },
  });

  await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('渲染 AppBar 标题与资讯卡片', (tester) async {
    await _pumpArticles(tester);

    expect(find.text('AV资讯'), findsOneWidget);
    expect(find.text('资讯一'), findsOneWidget);
    expect(find.text('作者A'), findsOneWidget);
    expect(find.text('业界'), findsOneWidget);
  });

  testWidgets('首屏加载失败显示重试并可恢复', (tester) async {
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
    final adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    adapter.enqueueSequence(Endpoints.articles, [
      {'success': 0, 'message': 'boom'},
      {
        'success': 1,
        'data': {
          'articles': [
            {'id': 1, 'title': '恢复成功'},
          ],
          'current_page': 1,
        },
      },
    ]);

    await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('恢复成功'), findsOneWidget);
  });

  testWidgets('滚动到底部触发分页加载下一页', (tester) async {
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
    final adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    adapter.enqueueSequence(Endpoints.articles, [
      {
        'success': 1,
        'data': {
          'articles': [
            for (var i = 0; i < 48; i++)
              {'id': i, 'title': '第1页-$i'},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'articles': [
            {'id': 48, 'title': '第2页-0'},
          ],
          'current_page': 2,
        },
      },
    ]);

    await tester.pumpWidget(const MaterialApp(home: ArticlesPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // 循环滚动到接近底部，直到第二页请求发出
    for (var i = 0; i < 12 && adapter.requests.length < 2; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -1600),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('第2页-0'), findsOneWidget);
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/features/articles/articles_screen_test.dart`
预期：FAIL，编译错误 `ArticlesPage is not defined`。

- [ ] **步骤 3：创建 ArticlesPage**

`lib/features/articles/screens/articles_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/services/article_service.dart';
import 'package:jade/features/articles/widgets/article_card.dart';

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});
  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  late final PaginationController<ArticleSummary> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _ctrl = PaginationController<ArticleSummary>(fetch: _fetchPage)
      ..fetchMore();
  }

  Future<PagedResult<ArticleSummary>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);
    }
    return ArticleService(api).getArticles(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AV资讯')),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.error != null && _ctrl.items.isEmpty) {
            return ErrorRetryWidget(
              message: _ctrl.error.toString(),
              onRetry: _ctrl.refresh,
            );
          }
          if (_ctrl.isLoading && _ctrl.items.isEmpty) {
            return const Center(
              key: Key('articles-initial-loading'),
              child: CircularProgressIndicator(),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) {
                _ctrl.fetchMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => _ctrl.refresh(preserveItems: true),
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_ctrl.items.isEmpty)
                        const SliverFillRemaining(child: EmptyState())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          sliver: SliverList.builder(
                            itemCount: _ctrl.items.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ArticleCard(article: _ctrl.items[i]),
                            ),
                          ),
                        ),
                      if (_ctrl.error != null && _ctrl.items.isNotEmpty)
                        SliverToBoxAdapter(
                          child: TextButton.icon(
                            key: const Key('articles-load-more-retry'),
                            onPressed: _ctrl.fetchMore,
                            icon: const Icon(Icons.refresh),
                            label: const Text('加载失败，点击重试'),
                          ),
                        ),
                      if (_ctrl.isLoading)
                        const SliverToBoxAdapter(
                          child: Padding(
                            key: Key('articles-loading-more'),
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
                  if (_ctrl.isRefreshing)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        key: Key('articles-refreshing'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/features/articles/articles_screen_test.dart`
预期：PASS，3 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/articles/screens/articles_screen.dart test/features/articles/articles_screen_test.dart
git commit -m "feat(articles): add articles list screen"
```

---

## 任务 6：ArticleDetailPage 详情页

**文件：**
- 测试：`test/features/articles/article_detail_screen_test.dart`
- 创建：`lib/features/articles/screens/article_detail_screen.dart`

- [ ] **步骤 1：编写失败的测试**

`test/features/articles/article_detail_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/articles/screens/article_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FakeAdapter> _pumpDetail(WidgetTester tester) async {
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
  final adapter = FakeAdapter();
  api.setAdapterForTest(adapter);
  adapter.enqueue('${Endpoints.articles}/1', {
    'success': 1,
    'data': {
      'id': 1,
      'title': '详情标题',
      'author': {'name': '作者D'},
      'category': '新作',
      'image_domain': 'https://img.example.com',
      'content': '<p>正文第一段</p><p>正文第二段</p>',
      'released_at': '2026-08-05',
    },
  });

  await tester.pumpWidget(const MaterialApp(home: ArticleDetailPage(id: '1')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('渲染标题、作者、分类、发布日期', (tester) async {
    await _pumpDetail(tester);

    expect(find.text('详情标题'), findsOneWidget);
    expect(find.text('作者D'), findsOneWidget);
    expect(find.text('新作'), findsOneWidget);
    expect(find.text('2026-08-05'), findsOneWidget);
  });

  testWidgets('渲染正文 HTML', (tester) async {
    await _pumpDetail(tester);

    expect(find.text('正文第一段'), findsOneWidget);
    expect(find.text('正文第二段'), findsOneWidget);
  });

  testWidgets('加载失败显示重试并可恢复', (tester) async {
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
    final adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    adapter.enqueueSequence('${Endpoints.articles}/1', [
      {'success': 0, 'message': 'boom'},
      {
        'success': 1,
        'data': {
          'id': 1,
          'title': '恢复标题',
          'content': '<p>恢复正文</p>',
        },
      },
    ]);

    await tester.pumpWidget(const MaterialApp(home: ArticleDetailPage(id: '1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('恢复标题'), findsOneWidget);
    expect(find.text('恢复正文'), findsOneWidget);
  });

  test('resolveArticleImageUrls 拼接相对图片地址', () {
    expect(
      resolveArticleImageUrls(
        '<img src="https://img.example.com/a.jpg">',
        'https://img.example.com',
      ),
      '<img src="https://img.example.com/a.jpg">',
    );
    expect(
      resolveArticleImageUrls(
        '<img src="/images/a.jpg">',
        'https://img.example.com',
      ),
      '<img src="https://img.example.com/images/a.jpg">',
    );
    expect(
      resolveArticleImageUrls(
        '<img src="a.jpg">',
        '//img.example.com',
      ),
      '<img src="https://img.example.com/a.jpg">',
    );
    expect(
      resolveArticleImageUrls('<img src="/a.jpg">', null),
      '<img src="/a.jpg">',
    );
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`flutter test test/features/articles/article_detail_screen_test.dart`
预期：FAIL，编译错误 `ArticleDetailPage` / `resolveArticleImageUrls` 未定义。

- [ ] **步骤 3：创建 ArticleDetailPage**

`lib/features/articles/screens/article_detail_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/services/article_service.dart';

/// 将正文中相对路径的图片地址拼接为完整 URL。
///
/// 跳过已有 scheme（如 https:、data:）的 src；`imageDomain` 为空时不处理。
String resolveArticleImageUrls(String content, String? imageDomain) {
  final domain = imageDomain?.trim();
  if (domain == null || domain.isEmpty) return content;
  final base = domain.startsWith('//') ? 'https:$domain' : domain;
  final pattern = RegExp(r'src="(?![a-z]+:)([^"]+)"');
  return content.replaceAllMapped(pattern, (m) {
    final src = m[1]!;
    final url = src.startsWith('/') ? '$base$src' : '$base/$src';
    return 'src="$url"';
  });
}

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({super.key, required this.id});
  final String id;
  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  ArticleDetail? _detail;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      setState(() {
        _loading = false;
        _error = '网络未就绪';
      });
      return;
    }
    try {
      final detail = await ArticleService(api).getArticleDetail(widget.id);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资讯详情')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return ErrorRetryWidget(message: error.toString(), onRetry: _load);
    }
    final detail = _detail!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.title,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (detail.author != null && detail.author!.isNotEmpty) ...[
                Text(
                  detail.author!,
                  style: textTheme.labelMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(width: 12),
              ],
              if (detail.category != null && detail.category!.isNotEmpty) ...[
                Text(
                  detail.category!,
                  style: textTheme.labelMedium?.copyWith(color: Colors.red),
                ),
                const SizedBox(width: 12),
              ],
              if (detail.releasedAt != null && detail.releasedAt!.isNotEmpty)
                Text(
                  detail.releasedAt!,
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          Html(
            data: resolveArticleImageUrls(
              detail.content ?? '',
              detail.imageDomain,
            ),
            style: {
              'body': Style(
                fontSize: FontSize(15),
                lineHeight: LineHeight(1.6),
                color: scheme.onSurface,
              ),
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/features/articles/article_detail_screen_test.dart`
预期：PASS，4 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/articles/screens/article_detail_screen.dart test/features/articles/article_detail_screen_test.dart
git commit -m "feat(articles): add article detail screen"
```

---

## 任务 7：feature 入口 + 路由接入 + 全量验证

**文件：**
- 创建：`lib/features/articles/index.dart`
- 修改：`lib/core/router/routes.dart`
- 修改：`lib/core/router/app_router.dart`

- [ ] **步骤 1：创建 feature 入口**

`lib/features/articles/index.dart`：

```dart
export 'models/article.dart';
export 'screens/article_detail_screen.dart';
export 'screens/articles_screen.dart';
```

- [ ] **步骤 2：新增路由常量**

在 `lib/core/router/routes.dart` 的 `articles` 常量后新增：

```dart
static const String articleDetail = '/articles/:id';
```

- [ ] **步骤 3：替换列表页并新增详情路由**

在 `lib/core/router/app_router.dart` 中：

1. 顶部 import 区新增：

```dart
import 'package:jade/features/articles/screens/article_detail_screen.dart';
import 'package:jade/features/articles/screens/articles_screen.dart';
```

2. 将现有 `GoRoute(path: AppRoutes.articles, ...)` 替换为：

```dart
GoRoute(
  path: AppRoutes.articles,
  builder: (c, s) => const ArticlesPage(),
  routes: [
    GoRoute(
      path: ':id',
      builder: (c, s) => ArticleDetailPage(id: s.pathParameters['id']!),
    ),
  ],
),
```

   注意：`routes.dart` 的 `articleDetail = '/articles/:id'` 常量是**完整路径**（供 `context.push` 使用），而 `GoRoute.path` 子路由使用**相对段** `':id'`，二者用途不同，不要混淆。

- [ ] **步骤 4：静态分析**

运行：`flutter analyze`
预期：无 error / warning 新增（`_SimpleListPage` 仍被 reviews、imageSearch 引用，保留）。

- [ ] **步骤 5：全量测试**

运行：`flutter test`
预期：全部通过（含既有测试与新增 4 个测试文件；`tofu_scroll_test` 的 `tofu-AV资讯` 断言不受影响）。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/articles/index.dart lib/core/router/routes.dart lib/core/router/app_router.dart
git commit -m "feat(articles): wire routes and feature index"
```

---

## 自检对照

- 规格「数据模型」→ 任务 2 ✅
- 规格「服务层」→ 任务 3 ✅
- 规格「资讯卡片」→ 任务 4 ✅（16:9 封面、2 行标题、作者/分类胶囊/时间、全出血 `Card(margin: EdgeInsets.zero)`、整卡可点）
- 规格「列表页」→ 任务 5 ✅（PaginationController、NotificationListener、RefreshIndicator、尾部加载/重试、EmptyState）
- 规格「详情页」→ 任务 6 ✅（信息区 + flutter_html + 相对图片 URL 预处理 + 深色适配）
- 规格「路由」→ 任务 7 ✅（`/articles` 替换占位、`/articles/:id` 新增）
- 规格「依赖」→ 任务 1 ✅
- 规格「测试」→ 任务 2-6 内联 ✅
