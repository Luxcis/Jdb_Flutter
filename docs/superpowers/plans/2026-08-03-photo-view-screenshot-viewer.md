# Photo View 剧照大图浏览实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 引入 `photo_view`，用 `PhotoViewGallery` 替换电影详情页现有的手写大图缩放与分页实现。

**Architecture:** 全屏 Dialog、页码和关闭行为保留在 `_ScreenshotViewer`，图库主体改为 `PhotoViewGallery.builder`。每页通过 `PhotoViewGalleryPageOptions.customChild` 继续渲染 `MovieScreenshotImage`，从而完整复用现有 CDN 解析、XOR 解密、磁盘缓存、加载错误和模糊设置。

**Tech Stack:** Flutter 3.44.8、Dart 3.12.2、photo_view 0.15.0、cached_network_image、flutter_cache_manager、flutter_test

## Global Constraints

- 只替换电影详情页的剧照大图浏览能力。
- 保留详情页横向剧照缩略图列表和点击入口。
- 保留全屏黑色浏览界面、关闭按钮和页码标题。
- 保留从用户点击的剧照下标开始展示。
- 接受 `photo_view` 默认双击缩放和边缘翻页手感，不保留当前精确的点击位置 2.5 倍放大与 48px 边缘翻页阈值。
- 不替换普通封面、头像和缩略图展示。
- 不移除 `cached_network_image` 或 `flutter_cache_manager`。
- 不修改图片 CDN 地址解析、XOR 解密或缓存策略。
- 不增加图片编辑、旋转、下载、分享或 Hero 动画。

---

### Task 1: 以 PhotoViewGallery 替换剧照大图浏览

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart:952-1173`
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**
- Consumes: `MovieScreenshotImage(String url, {BoxFit fit})`
- Produces: `_ScreenshotViewer` 内部的 `PhotoViewGallery.builder`
- Preserves: `Key('movie-screenshot-viewer')`、关闭按钮 tooltip `关闭`、页码格式 `<current> / <total>`

- [ ] **Step 1: 添加 photo_view 依赖**

Run: `flutter pub add photo_view:^0.15.0`

Expected: `pubspec.yaml` 新增 `photo_view: ^0.15.0`，`pubspec.lock` 锁定 `photo_view 0.15.0`，不新增其它传递依赖。

- [ ] **Step 2: 写大图浏览失败测试**

在测试文件顶部加入：

```dart
import 'package:photo_view/photo_view_gallery.dart';
```

在 `test/features/movie_detail/movie_detail_screen_test.dart` 中增加：

```dart
testWidgets('从第二张剧照打开 PhotoView 图库并可翻页关闭', (tester) async {
  _mockPathProvider(tester);
  final adapter = await _setupApiClient();
  _enqueueCompleteMovieDetail(adapter);

  await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));

  final innerScrollable = find
      .descendant(
        of: find.byType(TabBarView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text('预告片 / 剧照'),
    300,
    scrollable: innerScrollable,
  );

  await tester.tap(find.byKey(const Key('movie-detail-screenshot-1')));
  await tester.pump();

  expect(find.byKey(const Key('movie-screenshot-viewer')), findsOneWidget);
  expect(find.text('2 / 2'), findsOneWidget);
  expect(find.byType(PhotoViewGallery), findsOneWidget);
  expect(find.byType(InteractiveViewer), findsNothing);

  await tester.drag(find.byType(PhotoViewGallery), const Offset(500, 0));
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('1 / 2'), findsOneWidget);

  await tester.tap(find.byTooltip('关闭'));
  await tester.pump();
  expect(find.byKey(const Key('movie-screenshot-viewer')), findsNothing);
});
```

该测试防止生产代码回退到手写 `InteractiveViewer`，同时覆盖用户可观察的初始页、翻页页码和关闭行为。

- [ ] **Step 3: 运行测试并确认 RED**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart --plain-name '从第二张剧照打开 PhotoView 图库并可翻页关闭'`

Expected: FAIL，原因是当前浏览器中找不到 `PhotoViewGallery`，而不是 API 请求、资源加载或测试环境错误。

- [ ] **Step 4: 编写最小 PhotoViewGallery 实现**

在 `movie_detail_screen.dart` 中加入：

```dart
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
```

保留 `_ScreenshotViewer` 和 `_ScreenshotViewerState`，将 State 简化为：

```dart
class _ScreenshotViewerState extends State<_ScreenshotViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      key: const Key('movie-screenshot-viewer'),
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
        body: PhotoViewGallery.builder(
          key: const Key('movie-screenshot-pages'),
          pageController: _controller,
          itemCount: widget.urls.length,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          onPageChanged: (index) => setState(() => _currentIndex = index),
          builder: (_, index) => PhotoViewGalleryPageOptions.customChild(
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained * 4,
            child: SizedBox.expand(
              child: MovieScreenshotImage(
                widget.urls[index],
                key: Key('movie-screenshot-page-$index'),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

删除 `_zoomedPages`、旧手势处理方法、`_ScreenshotPageDirection`、`_ZoomableScreenshot` 及其 State，不修改 `_ScreenshotSection` 或共享图片组件。

- [ ] **Step 5: 格式化并确认 GREEN**

Run: `dart format lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart`

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart --plain-name '从第二张剧照打开 PhotoView 图库并可翻页关闭'`

Expected: PASS，测试输出无异常或警告。

- [ ] **Step 6: 运行相关图片与详情回归测试**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart test/core/widgets/movie_screenshot_image_test.dart test/core/widgets/cached_image_test.dart test/core/network/image_decryptor_test.dart`

Expected: PASS，证明大图浏览替换未改变模糊、缓存或解密行为。

- [ ] **Step 7: 提交实现**

```bash
git add pubspec.yaml pubspec.lock \
  lib/features/movie_detail/screens/movie_detail_screen.dart \
  test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "feat: replace screenshot viewer with photo view"
```

### Task 2: 完整验证

**Files:**
- Verify only: entire repository

**Interfaces:**
- Consumes: Task 1 的完整实现提交
- Produces: 最新的完整测试和静态分析证据

- [ ] **Step 1: 检查变更范围与格式**

Run: `git status --short`

Run: `git diff HEAD^ --check`

Expected: 只包含本计划和实现范围内的文件，且没有空白错误。

- [ ] **Step 2: 运行完整测试**

Run: `flutter test`

Expected: 全部测试通过，0 个失败。

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`

Expected: `No issues found!`。

- [ ] **Step 4: 核对成功标准**

逐项确认：

- 大图浏览树包含 `PhotoViewGallery`，不包含 `InteractiveViewer`。
- 从第二张打开显示 `2 / 2`，向前翻页显示 `1 / 2`。
- 关闭按钮移除全屏浏览器。
- `MovieScreenshotImage`、`CachedImage` 和 `JdbImageCacheManager` 未修改。
- `cached_network_image` 与 `flutter_cache_manager` 依赖仍保留。
