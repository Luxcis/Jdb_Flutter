# Photo View 剧照大图浏览设计

## 目标

引入 `photo_view: ^0.15.0`，使用 `PhotoViewGallery` 替换电影详情页现有的 `PageView + InteractiveViewer` 大图浏览实现，同时保留现有全屏界面、图片加载、XOR 解密、磁盘缓存、错误占位和模糊设置。

## 范围

本次只替换电影详情页的剧照大图浏览能力：

- 保留详情页横向剧照缩略图列表和点击入口。
- 保留全屏黑色浏览界面、关闭按钮和页码标题。
- 保留从用户点击的剧照下标开始展示。
- 使用 `photo_view` 提供双击缩放、双指缩放、拖动和图片边缘翻页。
- 接受 `photo_view` 默认双击缩放和边缘翻页手感，不保留当前精确的点击位置 2.5 倍放大与 48px 边缘翻页阈值。

以下内容不在本次范围内：

- 不替换普通封面、头像和缩略图展示。
- 不移除 `cached_network_image` 或 `flutter_cache_manager`。
- 不修改图片 CDN 地址解析、XOR 解密或缓存策略。
- 不增加图片编辑、旋转、下载、分享或 Hero 动画。

## 组件设计

### 依赖

在 `pubspec.yaml` 中添加 `photo_view: ^0.15.0`，并更新 `pubspec.lock`。该包仅用于大图浏览，不承担网络请求或缓存职责。

### 全屏浏览器

保留 `_ScreenshotViewer` 及其 `Dialog.fullscreen`、黑色 `Scaffold` 和 `AppBar`。状态只保留：

- 根据 `initialIndex` 创建的 `PageController`。
- 用于标题展示的 `_currentIndex`。

浏览器主体改为 `PhotoViewGallery.builder`：

- `pageController` 使用现有控制器，保证从点击下标开始。
- `itemCount` 使用剧照 URL 数量。
- `onPageChanged` 更新 `_currentIndex`。
- `backgroundDecoration` 使用黑色背景。
- 每页由 `PhotoViewGalleryPageOptions.customChild` 构建。
- 子组件继续使用 `MovieScreenshotImage(url, fit: BoxFit.contain)`。
- 初始和最小缩放使用 `PhotoViewComputedScale.contained`。
- 最大缩放使用 `PhotoViewComputedScale.contained * 4`。
- 不启用图片旋转和页面状态长期保留。

### 删除的旧实现

替换后删除以下仅服务于旧手势实现的代码：

- `_zoomedPages`。
- `_handleZoomChanged`。
- `_handleBoundarySwipe`。
- `_ScreenshotPageDirection`。
- `_ZoomableScreenshot` 及其 State。
- `TransformationController`。
- 自定义双击位置、缩放矩阵与 48px 边缘翻页判断。

## 图片数据流

`PhotoViewGalleryPageOptions.customChild` 不直接获取网络图片。每页继续构建 `MovieScreenshotImage`，由它读取全局模糊设置并调用 `CachedImage`。`CachedImage` 继续负责完整 URL、加载状态、错误占位和 `JdbImageCacheManager`；缓存管理器继续在下载阶段完成图片 XOR 解密。

因此本次迁移不会改变图片缓存键、缓存时效、最大缓存对象数或已缓存图片的读取方式。

## 错误与状态处理

- 图片加载中仍显示 `CachedImage` 的圆形进度指示器。
- 图片加载失败仍使用现有破损图片图标或业务占位资源。
- 全局剧照模糊设置仍由 `MovieScreenshotImage` 响应。
- 切换页面只更新页码，不触发业务状态或网络接口。
- 关闭按钮仍通过 `Navigator.pop` 关闭全屏 Dialog。

## 测试设计

在电影详情 Widget 测试中增加大图浏览回归覆盖：

1. 点击第二张剧照后打开全屏浏览器，并显示 `2 / 2`。
2. 浏览器主体使用 `PhotoViewGallery`，不再包含 `InteractiveViewer`。
3. 从第二张向前翻页后标题更新为 `1 / 2`。
4. 点击关闭按钮后全屏浏览器消失。
5. 现有 `MovieScreenshotImage` 模糊开关测试继续通过，证明图片展示链路未被替换。

依赖加入后依次运行聚焦 Widget 测试、完整 `flutter test` 和 `flutter analyze`。

## 成功标准

- 项目依赖解析成功。
- 大图浏览由 `PhotoViewGallery` 承担。
- 可以从任意剧照下标打开、缩放、拖动和左右翻页。
- 页码和关闭行为正确。
- 原有 CDN、XOR 解密、缓存、加载失败和模糊行为保持不变。
- 聚焦测试、完整测试和静态分析通过。
