# 资讯详情图片自动模糊 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (
> recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让资讯详情页正文中的网络图片通过 flutter_html 扩展自动改用 `CachedImage`
渲染，从而跟随全局"模糊图片"开关。

**Architecture:** 新增 `CachedImageHtmlExtension extends HtmlExtension`，在 `build` 阶段接管 `img`
标签（仅网络图片），返回 `WidgetSpan(child: CssBoxWidget(child: CachedImage(...)))`。`CachedImage`
已内部自动读取 `SettingsProvider.blurMovieImages` 决定模糊。`ArticleDetailPage` 的 `Html` 组件传入
`extensions: [CachedImageHtmlExtension()]`。

**Tech Stack:** Flutter、flutter_html 3.0.0（`HtmlExtension`/`ImageElement`/`CssBoxWidget`
）、provider、cached_network_image。

参考设计文档：`docs/superpowers/specs/2026-08-05-article-image-blur-design.md`

---

## 关键 API 事实（实现前必读）

- flutter_html 3.0.0 公开导出：`HtmlExtension`、`ExtensionContext`、`CurrentStep`、`ImageElement`（含
  `src`）、`CssBoxWidget`、`Style`/`Width`/`Height`。
- 用户传入 `Html.extensions` 的优先级**高于**内置 `ImageBuiltIn`（见 `HtmlParser.buildFromExtension`
  遍历顺序）。
- `prepare` 阶段（`CurrentStep.preparing`）不拦截：让内置 `ImageBuiltIn` 生成 `ImageElement`，保留 CSS
  尺寸解析；仅在 `CurrentStep.building` 阶段接管渲染。
- 内置 `ImageBuiltIn` 不渲染 svg、不渲染无网络 scheme 的图片；扩展匹配条件必须与之一致（`http(s)` 且非
  `.svg`）。

---

### Task 1: 编写 CachedImageHtmlExtension 测试（预期失败）

**Files:**

- Create: `test/features/articles/cached_image_html_extension_test.dart`

- [ ] **Step 1: 创建测试文件**

```dart
// test/features/articles/cached_image_html_extension_test.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/features/articles/widgets/cached_image_html_extension.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Future<void> _pumpHtml(WidgetTester tester, String data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Html(
            data: data,
            extensions: const [CachedImageHtmlExtension()],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('网络图片使用 CachedImage 渲染', (tester) async {
    await _pumpHtml(tester, '<p>正文</p><img src="https://img.example.com/a.jpg">');
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('base64 图片不渲染为 CachedImage', (tester) async {
    await _pumpHtml(tester, '<img src="data:image/png;base64,$_onePixelPngBase64">');
    expect(find.byType(CachedImage), findsNothing);
  });

  testWidgets('asset 图片不渲染为 CachedImage', (tester) async {
    await _pumpHtml(tester, '<img src="asset:assets/images/noimage_147x200.jpg">');
    expect(find.byType(CachedImage), findsNothing);
  });

  testWidgets('svg 图片不渲染为 CachedImage', (tester) async {
    await _pumpHtml(tester, '<img src="https://img.example.com/a.svg">');
    expect(find.byType(CachedImage), findsNothing);
  });

  testWidgets('正文图片跟随全局模糊开关', (tester) async {
    SharedPreferences.setMockInitialValues({StorageKeys.blurMovieImages: false});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Html(
                data: '<img src="https://img.example.com/a.jpg">',
                extensions: const [CachedImageHtmlExtension()],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageBuilder, isNull);

    await settings.setBlurMovieImages(true);
    await tester.pump();
    networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.imageBuilder, isNotNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/articles/cached_image_html_extension_test.dart`
Expected: 编译失败
`Error: Target of URI doesn't exist: 'package:jade/features/articles/widgets/cached_image_html_extension.dart'`

---

### Task 2: 实现 CachedImageHtmlExtension（测试通过）

**Files:**

- Create: `lib/features/articles/widgets/cached_image_html_extension.dart`

- [ ] **Step 1: 创建扩展类**

```dart
// lib/features/articles/widgets/cached_image_html_extension.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// 将资讯正文中的网络图片改用 [CachedImage] 渲染，
/// 使其自动跟随全局"模糊图片"设置。
class CachedImageHtmlExtension extends HtmlExtension {
  const CachedImageHtmlExtension();

  @override
  Set<String> get supportedTags => {'img'};

  @override
  bool matches(ExtensionContext context) {
    if (context.currentStep != CurrentStep.building) return false;
    final element = context.styledElement;
    if (element is! ImageElement) return false;
    final uri = Uri.tryParse(element.src);
    final isNetwork = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    return isNetwork && !element.src.endsWith('.svg');
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final element = context.styledElement as ImageElement;
    final imageStyle = Style(
      width: element.width,
      height: element.height,
    ).merge(context.styledElement!.style);
    return WidgetSpan(
      alignment: context.style!.verticalAlign
          .toPlaceholderAlignment(context.style!.display),
      baseline: TextBaseline.alphabetic,
      child: CssBoxWidget(
        style: imageStyle,
        childIsReplaced: true,
        child: CachedImage(
          element.src,
          width: imageStyle.width?.value,
          height: imageStyle.height?.value,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行测试确认通过**

Run: `flutter test test/features/articles/cached_image_html_extension_test.dart`
Expected: 5 个用例全部 PASS

- [ ] **Step 3: 提交**

```bash
git add test/features/articles/cached_image_html_extension_test.dart lib/features/articles/widgets/cached_image_html_extension.dart
git commit -m "feat(articles): render detail images via CachedImage extension"
```

---

### Task 3: 接入 ArticleDetailPage

**Files:**

- Modify: `lib/features/articles/screens/article_detail_screen.dart`

- [ ] **Step 1: 添加 import**

在现有 import 块（`article_card` 相关 import 之后）加入：

```dart
import 'package:jade/features/articles/widgets/cached_image_html_extension.dart';
```

- [ ] **Step 2: 给 Html 组件传入 extensions**

将 `_buildBody` 中的 `Html(...)`（位于第 137 行附近）修改为：

```dart
          Html
(
data: resolveArticleImageUrls(
detail.content ?? '',
detail.imageDomain,
),
extensions: const [CachedImageHtmlExtension()],
style: {
'body': Style(
fontSize: FontSize(15),
lineHeight: LineHeight(1.6),
color: scheme.onSurface,
),
},
)
,
```

- [ ] **Step 3: 运行现有详情页测试确认不回归**

Run: `flutter test test/features/articles/article_detail_screen_test.dart`
Expected: 现有用例全部 PASS

---

### Task 4: 详情页测试验证正文图片

**Files:**

- Modify: `test/features/articles/article_detail_screen_test.dart`

- [ ] **Step 1: 让 _pumpDetail 支持自定义 content**

将 `_pumpDetail` 签名与 `adapter.enqueue` 中的 `'content': ...` 改为：

```dart
Future<FakeAdapter> _pumpDetail(WidgetTester tester, {
  String content = '<p>正文第一段</p><p>正文第二段</p>',
}) async {
  // ...原有 setup 保持不变...
  adapter.enqueue('${Endpoints.articles}/1', {
    'success': 1,
    'data': {
      'id': 1,
      'title': '详情标题',
      'author': {'name': '作者D'},
      'category': '新作',
      'image_domain': 'https://img.example.com',
      'content': content,
      'released_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2))
          .toIso8601String(),
    },
  });
  // ...其余不变...
}
```

- [ ] **Step 2: 添加正文图片测试用例**

在 `main()` 中新增用例（需补充 `import 'package:jade/core/widgets/cached_image.dart';`）：

```dart
  testWidgets
('正文网络图片使用 CachedImage 渲染
'
, (tester) async {
await _pumpDetail(
tester,
content: '<p>正文</p><img src="https://img.example.com/a.jpg">',
);

expect(find.byType(CachedImage), findsOneWidget);
});
```

- [ ] **Step 3: 运行测试确认通过**

Run: `flutter test test/features/articles/article_detail_screen_test.dart`
Expected: 全部 PASS（含新增用例）

- [ ] **Step 4: 提交**

```bash
git add lib/features/articles/screens/article_detail_screen.dart test/features/articles/article_detail_screen_test.dart
git commit -m "feat(articles): blur detail images per global setting"
```

---

### Task 5: 全量验证

**Files:**

- 无改动

- [ ] **Step 1: 运行全部相关测试**

Run:
`flutter test test/features/articles/ test/core/widgets/cached_image_test.dart test/core/widgets/movie_cover_image_test.dart test/core/widgets/movie_screenshot_image_test.dart`
Expected: 全部 PASS

- [ ] **Step 2: 静态分析**

Run: `dart analyze lib/features/articles test/features/articles`
Expected: `No issues found!`

- [ ] **Step 3: 确认工作树干净**

Run: `git status`
Expected: `nothing to commit, working tree clean`

---

## Self-Review

**Spec 覆盖检查：**

- 正文网络图片跟随 `blurMovieImages` → Task 1 开关测试 + Task 3 接入 ✓
- 仅网络图片（http/https），base64/asset/svg 保持内置行为 → Task 1 三个负向用例 ✓
- 不做点击放大、不加强度调节 → 计划无相关改动 ✓
- 不引入新依赖 → 仅复用现有依赖 ✓

**占位符扫描：** 无 TBD/TODO，所有代码步骤含完整实现。

**类型一致性：** `CachedImageHtmlExtension` 名称、构造签名、`matches`/`build` 签名在所有任务中一致；
`_pumpDetail` 的 `content` 命名参数在 Task 4 定义与使用一致；`imageBuilder` 断言方式与现有
`cached_image_test.dart` 一致。
