# Home Recommend Carousel（首页佳片推荐轮播）

## 概述

首页"佳片推荐"轮播（`RecommendCarousel`，位于 `lib/features/home/widgets/recommend_carousel.dart`），以 `CarouselSlider.builder` 承载推荐影片卡片，卡片为全幅封面图叠加底部黑色半透明遮罩内的标题。本能力为标题单行省略后的完整行为规格。

## 组成与数据

- 输入为 `List<MovieSummary> movies` 与 `onMovieTap` 回调；轮播键为 `Key('home-recommend-carousel')`，每张卡片键为 `Key('home-recommend-card-<movie.id>')`。
- 轮播高度 220，`viewportFraction: 1`；卡片为 `StackFit.expand` 的 `Stack`：底层 `MovieCoverImage`（`MovieImageVariant.cover`，语义标签为影片标题），底部 `Positioned` 遮罩容器（`Colors.black54`，内边距 8）内放标题 `Text`。

## 标题排版（本次变更的核心行为）

底部遮罩内的标题 `Text` 必须限定单行：`maxLines: 1`、`overflow: TextOverflow.ellipsis`，白色文字样式不变。遮罩高度由单行文本加内边距决定，不随标题长度变化。

### Scenario: 长标题单行省略

Given 首页佳片推荐轮播展示的影片标题长度超过卡片宽度
When 卡片渲染完成
Then 标题仅渲染一行，行尾以省略号截断，不换行，底部遮罩高度保持单行文本的高度

### Scenario: 短标题完整显示

Given 首页佳片推荐轮播展示的影片标题未超出一行宽度
When 卡片渲染完成
Then 标题完整显示且行尾无省略号

## 轮播行为（保持不变）

- 多于一张时自动播放：每 5 秒切换，切换动画 400ms `Curves.easeInOut`，无限循环；单张时不自动切换、不无限循环。
- 应用进入后台或 `TickerMode` 关闭时暂停自动播放，恢复后重新计时；手动滑动后重新等待完整周期；轮播销毁后无异步异常。
- 点击卡片回调 `onMovieTap` 打开对应影片。
