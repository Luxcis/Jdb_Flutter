# 资讯详情渲染迁移 flutter_widget_from_html 与图片预览 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 `flutter_widget_from_html_core` + 增强扩展包替换 `flutter_html` 渲染资讯详情，正文图片跟随全局模糊开关，点击打开支持缩放与切换的大图预览。

**Architecture:** 自定义 `ArticleWidgetFactory` 覆写 `buildImageWidget` 让网络图片走 `CachedImage`（模糊 + 解密缓存复用）；从电影详情页抽取公共 `ImageGalleryViewer`（photo_view 图库），两处共用；`extractImageUrls` 提取正文图片供预览定位。

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2；`flutter_widget_from_html_core ^0.17.2`、`fwfh_cached_network_image ^0.16.1`、`photo_view ^0.15.0`（已有）、`cached_network_image ^3.4.1`（已有）。

## Global Constraints

- 依赖只新增 `flutter_widget_from_html_core: ^0.17.2` 与 `fwfh_cached_network_image: ^0.16.1`；不引入全量 `flutter_widget_from_html`（避免 chewie/just_audio/webview/svg/url_launcher）。
- 模糊统一走 `CachedImage`（`SettingsProvider.blurMovieImages`，默认 true，`ImageFilter.blur(12)` + `JdbImageCacheManager`），不新增第二套模糊逻辑。
- svg（含带查询参数，如 `a.svg?v=1`）、`data:`、`asset:` 图片不进入 `CachedImage` 与预览列表。
- 公共预览组件 `ImageGalleryViewer` 供电影详情与资讯详情共用，交互保持一致（黑底、contained~4x 缩放、PageView 切换、计数标题、关闭按钮）。
- 保留 `resolveArticleImageUrls` 与 `imageDomain` 处理，不引入 `baseUrl` 替代。
- 在 `codex/article-html-renderer` 分支上分步提交；只暂存/提交本计划涉及的文件，保留工作区其它改动。
- 中文文案（标题"资讯详情"、tooltip"关闭"），Material 3，feature-first，共享能力放 `lib/core`。
- 沙箱对 `.git` 只读：`git add`/`commit`/`switch` 需提权执行；`flutter pub get` 若网络受限需提权。

---

### Task 1: 替换依赖并解析

**Files:**
- Modify: `pubspec.yaml`（dependencies 段）
- Verify: `pubspec.lock`

**Interfaces:**
- Produces: `flutter_widget_from_html_core`（导出 `HtmlWidget`/`WidgetFactory`/`BuildTree`/`ImageSource`/`ImageMetadata`）与 `fwfh_cached_network_image`（导出 `CachedNetworkImageFactory`）可被 import。

- [ ] **Step 1: 修改 pubspec.yaml**

```yaml
  flutter_secure_storage: ^10.3.1
  flutter_widget_from_html_core: ^0.17.2
  fwfh_cached_network_image: ^0.16.1
  photo_view: ^0.15.0
  path_provider: ^2.1.6
-  flutter_html: ^3.0.0
```

- [ ] **Step 2: 解析依赖**

Run: `flutter pub get`
Expected: 成功；如沙箱网络受限（DNS/registry 失败），以 `require_escalated` 重试。

- [ ] **Step 3: 验证依赖替换**

Run:
```bash
flutter pub deps | rg 'flutter_widget_from_html_core|fwfh_cached_network_image|flutter_html'
rg -n 'flutter_html' pubspec.lock
```
Expected: 第一条输出两个新包且无 `flutter_html`；第二条无输出。

- [ ] **Step 4: 提交**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: swap flutter_html for flutter_widget_from_html_core"
```

---

### Task 2: 公共大图预览组件 ImageGalleryViewer + 电影详情切换

**Files:**
- Create: `lib/core/widgets/image_gallery_viewer.dart`
- Create: `test/core/widgets/image_gallery_viewer_test.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`（import、调用点、删除 `_ScreenshotViewer`/`_ScreenshotViewerState`、移除 photo_view 两行 import）
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`（两处 key 断言）

**Interfaces:**
- Consumes: `CachedImage`（`lib/core/widgets/cached_image.dart`）、`photo_view ^0.15.0`。
- Produces: `class ImageGalleryViewer extends StatefulWidget`，构造 `ImageGalleryViewer({super.key, required this.urls, required this.initialIndex, this.itemBuilder})`；字段 `List<String> urls`、`int initialIndex`、`Widget Function(BuildContext, String url, int index)? itemBuilder`；内部 key：`image-gallery-viewer`、`image-gallery-pages`、`image-gallery-page-$index`。

- [ ] **Step 1: 写失败的组件测试**

```dart
// test/core/widgets/image_gallery_viewer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/image_gallery_viewer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

Future<void> _pumpViewer(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ImageGalleryViewer(
        urls: const [
          'https://img.example.com/a.jpg',
          'https://img.example.com/b.jpg',
        ],
        initialIndex: 1,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('显示黑底图库与计数标题，初始定位到指定页', (tester) async {
    await _pumpViewer(tester);

    expect(find.byKey(const Key('image-gallery-viewer')), findsOneWidget);
    expect(find.byType(PhotoViewGallery), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('默认页内图片为 CachedImage 且 contain 适配', (tester) async {
    await _pumpViewer(tester);

    final page = find.byKey(const Key('image-gallery-page-1'));
    expect(page, findsOneWidget);
    final image = tester.widget<CachedImage>(
      find
          .descendant(of: page, matching: find.byType(CachedImage))
          .first,
    );
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('左右滑动切换并更新计数，关闭按钮可退出', (tester) async {
    await _pumpViewer(tester);

    await tester.drag(find.byType(PhotoViewGallery), const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('image-gallery-viewer')), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/widgets/image_gallery_viewer_test.dart`
Expected: FAIL（找不到 `image_gallery_viewer.dart`）。

- [ ] **Step 3: 创建公共组件**

```dart
// lib/core/widgets/image_gallery_viewer.dart
import 'package:flutter/material.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 全屏大图预览：黑底、缩放（contained~4x）、左右切换、计数标题、关闭按钮。
class ImageGalleryViewer extends StatefulWidget {
  const ImageGalleryViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
    this.itemBuilder,
  });

  final List<String> urls;
  final int initialIndex;
  final Widget Function(BuildContext context, String url, int index)?
      itemBuilder;

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late final PageController _controller;
  late final List<PhotoViewController> _photoViewControllers;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _photoViewControllers = List.generate(
      widget.urls.length,
      (_) => PhotoViewController(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _photoViewControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      key: const Key('image-gallery-viewer'),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          title: Text('${_currentIndex + 1} / ${widget.urls.length}'),
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final childSize = Size(
              constraints.maxWidth * 2,
              constraints.maxHeight * 2,
            );
            return PhotoViewGallery.builder(
              key: const Key('image-gallery-pages'),
              pageController: _controller,
              itemCount: widget.urls.length,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              customSize: constraints.biggest,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              builder: (_, index) => PhotoViewGalleryPageOptions.customChild(
                childSize: childSize,
                controller: _photoViewControllers[index],
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 4,
                child: SizedBox.expand(
                  child:
                      widget.itemBuilder?.call(context, widget.urls[index], index) ??
                          CachedImage(
                            widget.urls[index],
                            key: Key('image-gallery-page-$index'),
                            fit: BoxFit.contain,
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/widgets/image_gallery_viewer_test.dart`
Expected: PASS。

- [ ] **Step 5: 电影详情页切换到公共组件**

在 `lib/features/movie_detail/screens/movie_detail_screen.dart`：

1. 删除 import：
```dart
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
```
2. 新增 import：`import 'package:jade/core/widgets/image_gallery_viewer.dart';`
3. `_ScreenshotSection` 的 `showDialog` 调用改为：
```dart
onTap: () => showDialog<void>(
  context: context,
  useSafeArea: false,
  builder: (_) =>
      ImageGalleryViewer(urls: urls, initialIndex: index),
),
```
4. 删除 `_ScreenshotViewer` 与 `_ScreenshotViewerState` 两个类（从 `class _ScreenshotViewer extends StatefulWidget` 到 `_ScreenshotViewerState` 结束）。

- [ ] **Step 6: 更新电影详情测试的 key 断言**

在 `test/features/movie_detail/movie_detail_screen_test.dart`：
- `Key('movie-screenshot-viewer')` → `Key('image-gallery-viewer')`（两处）
- `Key('movie-screenshot-page-1')` → `Key('image-gallery-page-1')`（一处）

- [ ] **Step 7: 运行相关测试与静态分析**

Run:
```bash
flutter test test/core/widgets/image_gallery_viewer_test.dart test/features/movie_detail/movie_detail_screen_test.dart
flutter analyze
```
Expected: 全部 PASS；analyze 无新增告警。

- [ ] **Step 8: 提交**

```bash
git add lib/core/widgets/image_gallery_viewer.dart test/core/widgets/image_gallery_viewer_test.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "feat: extract shared ImageGalleryViewer and reuse in movie detail"
```

---

### Task 3: ArticleWidgetFactory 与 extractImageUrls

**Files:**
- Create: `lib/features/articles/widgets/article_widget_factory.dart`
- Create: `test/features/articles/article_widget_factory_test.dart`（迁移自 `cached_image_html_extension_test.dart`）
- Modify: `lib/features/articles/screens/article_detail_screen.dart`（新增顶层函数 `extractImageUrls`）
- Modify: `test/features/articles/article_detail_screen_test.dart`（新增 `extractImageUrls` 单元测试）

**Interfaces:**
- Consumes: `WidgetFactory`/`BuildTree`/`ImageSource`（core）、`CachedNetworkImageFactory`（fwfh）、`CachedImage`。
- Produces: `class ArticleWidgetFactory extends WidgetFactory with CachedNetworkImageFactory`，覆写 `Widget? buildImageWidget(BuildTree tree, ImageSource src)`；顶层函数 `List<String> extractImageUrls(String content)`。

- [ ] **Step 1: 写失败的测试**

```dart
// test/features/articles/article_widget_factory_test.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/features/articles/widgets/article_widget_factory.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Future<void> _pumpHtml(WidgetTester tester, String data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HtmlWidget(
            data,
            factoryBuilder: () => ArticleWidgetFactory(),
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

  testWidgets('带查询参数的 svg 不渲染为 CachedImage', (tester) async {
    await _pumpHtml(tester, '<img src="https://img.example.com/a.svg?v=1">');
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
              child: HtmlWidget(
                '<img src="https://img.example.com/a.jpg">',
                factoryBuilder: () => ArticleWidgetFactory(),
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

在 `test/features/articles/article_detail_screen_test.dart` 的 `main` 内（`resolveArticleImageUrls` 测试之后）追加：

```dart
  test('extractImageUrls 提取网络非 svg 图片', () {
    expect(
      extractImageUrls(
        '<img src="https://img.example.com/a.jpg">'
        '<img src="https://cdn.x.com/b.webp">'
        '<img src="https://img.example.com/c.svg">'
        '<img src="https://img.example.com/d.svg?v=1">'
        '<img src="data:image/png;base64,abc">'
        '<img src="asset:assets/images/noimage_147x200.jpg">',
      ),
      ['https://img.example.com/a.jpg', 'https://cdn.x.com/b.webp'],
    );
  });

  test('extractImageUrls 无图片时返回空列表', () {
    expect(extractImageUrls('<p>纯文本</p>'), isEmpty);
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/articles/article_widget_factory_test.dart test/features/articles/article_detail_screen_test.dart`
Expected: FAIL（找不到 `ArticleWidgetFactory` / `extractImageUrls`）。

- [ ] **Step 3: 实现工厂与提取函数**

```dart
// lib/features/articles/widgets/article_widget_factory.dart
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:fwfh_cached_network_image/fwfh_cached_network_image.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// 将资讯正文中的网络图片改用 [CachedImage] 渲染，
/// 使其自动跟随全局"模糊图片"设置，并复用解密缓存。
/// 网络 svg、`data:`、`asset:` 图片交给默认实现。
class ArticleWidgetFactory extends WidgetFactory
    with CachedNetworkImageFactory {
  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    final url = src.url;
    final uri = Uri.tryParse(url);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final isSvg = uri != null && uri.path.toLowerCase().endsWith('.svg');
    if (isNetwork && !isSvg) {
      return CachedImage(url, fit: BoxFit.fill);
    }
    return super.buildImageWidget(tree, src);
  }
}
```

在 `lib/features/articles/screens/article_detail_screen.dart` 顶层（`resolveArticleImageUrls` 之后）新增：

```dart
/// 提取正文中所有网络且非 svg 的图片地址，供大图预览切换与定位。
List<String> extractImageUrls(String content) {
  final urls = <String>[];
  final pattern = RegExp(r'src="([^"]+)"');
  for (final match in pattern.allMatches(content)) {
    final src = match[1]!;
    final uri = Uri.tryParse(src);
    if (uri == null) continue;
    if (uri.scheme != 'http' && uri.scheme != 'https') continue;
    if (uri.path.toLowerCase().endsWith('.svg')) continue;
    urls.add(src);
  }
  return urls;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/articles/article_widget_factory_test.dart test/features/articles/article_detail_screen_test.dart`
Expected: PASS。

- [ ] **Step 5: 静态分析**

Run: `flutter analyze`
Expected: 无新增告警。

- [ ] **Step 6: 提交**

```bash
git add lib/features/articles/widgets/article_widget_factory.dart test/features/articles/article_widget_factory_test.dart lib/features/articles/screens/article_detail_screen.dart test/features/articles/article_detail_screen_test.dart
git commit -m "feat(articles): add ArticleWidgetFactory and extractImageUrls"
```

---

### Task 4: 资讯详情页替换 Html 为 HtmlWidget 并接入预览

**Files:**
- Modify: `lib/features/articles/screens/article_detail_screen.dart`
- Modify: `test/features/articles/article_detail_screen_test.dart`
- Delete: `lib/features/articles/widgets/cached_image_html_extension.dart`
- Delete: `test/features/articles/cached_image_html_extension_test.dart`

**Interfaces:**
- Consumes: `HtmlWidget`（core）、`ArticleWidgetFactory`、`ImageGalleryViewer`、`extractImageUrls`。
- Produces: 资讯详情页使用 `HtmlWidget` 渲染正文；点击正文图片弹出 `ImageGalleryViewer`。

- [ ] **Step 1: 更新详情页测试（含新预览测试）**

`test/features/articles/article_detail_screen_test.dart`：

1. `渲染正文 HTML` 测试中的两处断言改为：
```dart
expect(find.text('正文第一段', findRichText: true), findsOneWidget);
expect(find.text('正文第二段', findRichText: true), findsOneWidget);
```
2. 新增测试：
```dart
testWidgets('点击正文图片打开大图预览并可关闭', (tester) async {
  await _pumpDetail(
    tester,
    content: '<p>正文</p>'
        '<img src="https://img.example.com/a.jpg">'
        '<img src="https://img.example.com/b.jpg">',
  );

  await tester.tap(find.byType(CachedImage).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.byKey(const Key('image-gallery-viewer')), findsOneWidget);
  expect(find.text('1 / 2'), findsOneWidget);

  await tester.tap(find.byTooltip('关闭'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const Key('image-gallery-viewer')), findsNothing);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/articles/article_detail_screen_test.dart`
Expected: FAIL（详情页仍是 `Html`，无 `onTapImage`，且旧正文断言因 `RichText` 不匹配而失败）。

- [ ] **Step 3: 修改详情页**

`lib/features/articles/screens/article_detail_screen.dart`：

1. import 调整：
```dart
// 删除：
import 'package:flutter_html/flutter_html.dart';
import 'package:jade/features/articles/widgets/cached_image_html_extension.dart';
// 新增：
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:jade/core/widgets/image_gallery_viewer.dart';
import 'package:jade/features/articles/widgets/article_widget_factory.dart';
```
2. `_buildBody` 中，在 `final scheme = Theme.of(context).colorScheme;` 之后新增：
```dart
final content =
    resolveArticleImageUrls(detail.content ?? '', detail.imageDomain);
final imageUrls = extractImageUrls(content);
```
并将 `Html(...)` 替换为：
```dart
HtmlWidget(
  content,
  factoryBuilder: () => ArticleWidgetFactory(),
  textStyle: TextStyle(
    fontSize: 15,
    height: 1.6,
    color: scheme.onSurface,
  ),
  onTapImage: (image) {
    final url = image.sources.first.url;
    final index = imageUrls.indexOf(url);
    final urls = index < 0 ? [url] : imageUrls;
    final initialIndex = index < 0 ? 0 : index;
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) =>
          ImageGalleryViewer(urls: urls, initialIndex: initialIndex),
    );
  },
),
```

- [ ] **Step 4: 删除旧扩展及其测试**

```bash
git rm lib/features/articles/widgets/cached_image_html_extension.dart test/features/articles/cached_image_html_extension_test.dart
```

- [ ] **Step 5: 运行资讯相关测试与静态分析**

Run:
```bash
flutter test test/features/articles
flutter analyze
```
Expected: 全部 PASS；analyze 无新增告警。

- [ ] **Step 6: 提交**

```bash
git add lib/features/articles/screens/article_detail_screen.dart test/features/articles/article_detail_screen_test.dart
git commit -m "feat(articles): render detail via HtmlWidget with image preview"
```

---

### Task 5: 全量验证与真机验收

**Files:**
- Verify: 全仓

- [ ] **Step 1: 全量静态分析与测试**

Run:
```bash
flutter analyze
flutter test
```
Expected: analyze 无告警；全部测试 PASS。

- [ ] **Step 2: 真机验收**

按设计文档"设备验收"清单人工核对：
1. 资讯详情正文图片在开关开启时模糊，关闭后恢复清晰。
2. 点击正文图片打开大图预览，可双指缩放、左右滑动切换、关闭返回；计数标题正确。
3. 电影详情截图预览行为与迁移前一致。
4. 正文行高、字体色与迁移前一致；链接/标题样式无异常。

- [ ] **Step 3: 处理问题并收尾**

如验收发现问题，按问题范围做小步修复并提交；无问题则任务完成。

```bash
git log --oneline
```
Expected: 依次可见 Task 1~4 的提交。

