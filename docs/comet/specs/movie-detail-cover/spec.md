# 影片详情页顶部封面大图

## 概述

影片详情页顶部封面大图（`MovieDetailHero`）在页面头部全宽展示影片封面。本规格定义其显示行为与点击放大能力：点击封面打开与剧照一致的全屏大图查看器（`ImageGalleryViewer`）。

## 显示

- 布局不变：宽度全宽，高度 `(maxWidth / 1.45).clamp(220.0, 360.0)`；底色 `surfaceContainerHighest`；封面按 `BoxFit.cover` 填充。
- 图片通过 `MovieCoverImage`（cover variant）加载，沿用现有缓存、解密与 fallback 资产逻辑；模糊开关（`blurMovieImages`）开启时同样模糊，由 `CachedImage` 统一处理，无特判。

## 点击放大

- 封面区域整体可点击（InkWell 水波反馈），点击打开 `ImageGalleryViewer`。
- 查看器仅包含封面一张：`urls = [detail.coverUrl]`，`initialIndex = 0`，计数显示「1 / 1」。
- 打开方式与剧照一致：`showDialog(useSafeArea: false)`。
- `coverUrl` 为空（trim 后空串）时不提供点击入口，封面保持纯展示。
- 入口语义：`Semantics(button: true)`，label「查看《影片标题》封面大图」；Key `movie-detail-cover`。
- 查看器内部行为（黑底全屏、缩放初始 `contained`、最小 `contained`、最大 4x、拖动平移、计数标题、关闭按钮、Key `image-gallery-viewer` / `image-gallery-pages`）与剧照查看器一致，无特判。

### Scenario: 点击封面打开查看器

Given 影片详情页已加载且封面 URL 非空
When 点击顶部封面大图
Then 打开全屏大图查看器并显示封面，计数 1 / 1，可关闭返回详情页

### Scenario: 放大交互与剧照一致

Given 封面查看器已打开
When 进行双指缩放或拖动
Then 缩放范围与剧照查看器一致（初始 contained、最小 contained、最大 4x），可拖动平移，黑底全屏

### Scenario: 模糊跟随设置

Given blurMovieImages 开启
When 点击封面放大查看
Then 放大后的封面同样模糊；关闭开关后放大查看时清晰，与剧照查看器行为一致

### Scenario: 入口语义与 Key

Given 使用无障碍服务或测试按 Key 查找
When 聚焦或点击顶部封面
Then 播报按钮语义「查看《影片标题》封面大图」，Key 为 movie-detail-cover；查看器沿用 image-gallery-viewer 等现有 Key

## 与剧照区的关系

- 剧照区（`MovieScreenshotSection`）行为完全不变：缩略图点击打开查看器并定位对应剧照、预告片封面为播放入口、语义与 Key 不变。
- 封面入口与剧照区各自打开独立的查看器实例，互不影响。

### Scenario: 剧照区行为保持不变

Given 详情页含剧照与预告片
When 点击剧照缩略图或预告片封面
Then 剧照缩略图仍打开查看器并定位对应剧照，预告片封面仍触发播放；两者行为与语义同修改前一致
