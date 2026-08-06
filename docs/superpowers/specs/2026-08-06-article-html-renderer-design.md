# 资讯详情渲染迁移 flutter_widget_from_html 与图片预览设计

## 目标

将资讯详情正文渲染从已归档的 `flutter_html ^3.0.0` 迁移到活跃维护的
`flutter_widget_from_html ^0.17.2`，并补齐两个图片能力：正文图片跟随全局
"模糊图片"开关（`blurMovieImages`），点击图片打开支持缩放与左右切换的全屏大图预览。

## 已确认需求

- 用 `flutter_widget_from_html ^0.17.2`（增强包）替换 `flutter_html ^3.0.0` 渲染资讯详情正文。
- 正文网络图片跟随全局 `blurMovieImages` 开关（默认开启），复用 `CachedImage` 现有的
  模糊与 `JdbImageCacheManager` 解密缓存能力，不重复实现模糊逻辑。
- 点击正文图片打开全屏大图预览：黑底、缩放（1x~4x）、PageView 左右切换、计数标题、关闭按钮。
- 大图预览组件从电影详情页抽取为公共组件，电影详情与资讯详情共用，行为统一。
- 本次在 `codex/article-html-renderer` 分支上分步提交；保留脏工作区无关改动。

## 架构设计

### 依赖

`pubspec.yaml`：删除 `flutter_html: ^3.0.0`，新增 `flutter_widget_from_html: ^0.17.2`
（增强包自带 core + `fwfh_cached_network_image` + svg/url/webview/音视频等 mixin）。
环境 Flutter 3.44.8 / Dart 3.12.2 满足其 Flutter >= 3.32 / Dart >= 3.4 要求。

### 图片渲染（模糊跟随）

新增 `lib/features/articles/widgets/article_widget_factory.dart`：

- `class ArticleWidgetFactory extends WidgetFactory`，仅覆写
  `Widget? buildImageWidget(BuildTree tree, ImageSource src)`。
- 网络图片（`src.url` 为 `http`/`https` 且路径不以 `.svg` 结尾，含带查询参数的 svg）
  返回 `CachedImage(src.url, fit: BoxFit.fill)`；`CachedImage` 内部已通过
  `context.watch<SettingsProvider?>()?.blurMovieImages ?? true` 决定是否模糊。
- 其余（`asset:`/`data:`/`file:` 及 svg）返回 `super.buildImageWidget`，延续现有语义
  （对应历史提交 e17ebc9 的 svg 排除）。
- 库的 `buildImage` 在自定义 widget 之外仍自动包裹 `AspectRatio`（有 width/height 属性时）
  与 `onTapImage` 点击手势，行内小图不被改坏。

### 大图预览（公共组件）

新增 `lib/core/widgets/image_gallery_viewer.dart`：

- 从电影详情页 `_ScreenshotViewer` 抽取，参数：`urls`、`initialIndex`、可选 `itemBuilder`。
- 默认页内图片为 `CachedImage(url, fit: BoxFit.contain)`（模糊跟随依然生效）。
- 保留既有交互：黑底 `Dialog.fullscreen`、AppBar 计数标题（"当前页 / 总数"）、关闭按钮、
  `PhotoViewGallery.builder`（`PhotoViewComputedScale.contained` 起始，最大 4 倍）、
  `onPageChanged` 更新计数。

修改 `lib/features/movie_detail/screens/movie_detail_screen.dart`：`_ScreenshotViewer`
替换为公共组件，交互与视觉不变。

### 资讯详情页

修改 `lib/features/articles/screens/article_detail_screen.dart`：

- `Html` → `HtmlWidget`；正文样式从
  `Style(fontSize: FontSize(15), lineHeight: LineHeight(1.6), color: scheme.onSurface)`
  迁移为 `textStyle: TextStyle(fontSize: 15, height: 1.6, color: scheme.onSurface)`。
- `factoryBuilder: () => ArticleWidgetFactory()`。
- 新增 `onTapImage`：取 `image.sources.first.url`，在正文图片列表中的 index 定位预览。
- 保留 `resolveArticleImageUrls` 与 `imageDomain` 处理，不引入 `baseUrl` 替代（回归最小）。

新增纯函数 `extractImageUrls(String content)`：提取全部网络且非 svg 的 `img src`
（复用现有正则语义），供预览切换与 index 定位。

### 数据流

正文 HTML → `resolveArticleImageUrls`（相对地址补全）→ `HtmlWidget` 渲染；
点击图片 → `onTapImage` 得被点 URL → `extractImageUrls` 求 index →
`showDialog(Dialog.fullscreen)` 打开 `ImageGalleryViewer`，PageView 左右切换。

### 文件组织

- 新增 `lib/features/articles/widgets/article_widget_factory.dart`
- 新增 `lib/core/widgets/image_gallery_viewer.dart`
- 修改 `lib/features/articles/screens/article_detail_screen.dart`
- 修改 `lib/features/movie_detail/screens/movie_detail_screen.dart`
- 修改 `pubspec.yaml`（依赖替换）
- 删除 `lib/features/articles/widgets/cached_image_html_extension.dart`

## 异常与边界处理

- svg、data URI、asset 图片不进入 `CachedImage` 与预览列表（延续现有语义）。
- 预览列表为空或被点 URL 未命中时：仅展示被点单图（`itemCount` 为 1）。
- 图片加载失败由 `CachedImage` 内置 `errorWidget` 兜底（broken_image 图标或占位图）。
- 正文样式迁移后行高/字体色需真机目测核对；标题/链接颜色由库自带样式决定，
  如有偏差用 `customStylesBuilder` 微调。
- `onTapImage` 仅在点击到图片时触发，链接点击仍由默认行为处理。

## 测试与验收

### 自动化测试

- factory 测试（迁移 `cached_image_html_extension_test.dart`）：网络图片渲染 `CachedImage`；
  base64/asset/svg（含带查询参数 svg）不渲染；模糊开关关闭时
  `CachedNetworkImage.imageBuilder` 为 null，开启时非 null。
- 单元测试：`extractImageUrls` 的相对/绝对/协议相对 URL 提取、svg/data 排除。
- 详情页 widget 测试：正文文本渲染；点击图片后出现 `ImageGalleryViewer` 与计数标题；
  预览可切换页。
- 电影详情回归：截图预览仍工作（公共组件切换后）。
- 运行相关测试、`flutter test` 和 `flutter analyze`。

### 设备验收

1. 资讯详情正文图片在开关开启时模糊，关闭后恢复清晰。
2. 点击正文图片打开大图预览，可双指缩放、左右滑动切换、关闭返回。
3. 电影详情截图预览行为与迁移前一致。
4. 正文行高、字体色与迁移前一致。

## 成功标准

- 资讯详情正文由 `flutter_widget_from_html` 渲染，`flutter_html` 及其扩展代码全部移除。
- 正文图片统一遵守全局模糊开关，非网络图片与失败占位不被误模糊。
- 点击正文图片可打开全屏预览并缩放/切换。
- 公共预览组件被电影详情与资讯详情共用，行为一致。

