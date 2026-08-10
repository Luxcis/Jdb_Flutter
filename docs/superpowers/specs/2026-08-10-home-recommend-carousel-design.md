# 首页佳片推荐自动循环轮播设计

## 目标

使用 `carousel_slider` 重构首页“佳片推荐”分区：

- 每 5 秒自动切换到下一张；
- 最后一张之后继续向前显示第一张；
- 用户触摸或手动滑动时暂停，交互结束后重新计时；
- 页面不可见或应用进入后台时暂停，恢复可见后重新计时；
- 只有一张推荐时不自动轮播。

现有推荐数据加载、失败重试、空态、图片展示、标题遮罩和点击进入电影详情的行为保持不变。

## 文档依据

通过 Context7 查询 `/serenader2014/flutter_carousel_slider`，确认：

- `CarouselSlider.builder` 支持按需构建；
- `CarouselOptions` 提供 `autoPlay`、`autoPlayInterval`、`autoPlayAnimationDuration`、`autoPlayCurve`、`enableInfiniteScroll` 和 `pauseAutoPlayOnTouch`；
- `CarouselSliderController` 提供 `startAutoPlay()` 与 `stopAutoPlay()`。

Context7 未返回明确的当前稳定版本，因此使用官方 pub.dev 补充确认 `carousel_slider 5.1.2` 为当前稳定版。该版本修复了内部 `PageController` 未正确释放，以及控制器尚未就绪时调用导致的崩溃。

参考：

- Context7 library：`/serenader2014/flutter_carousel_slider`
- pub.dev：`https://pub.dev/packages/carousel_slider`
- API：`https://pub.dev/documentation/carousel_slider/latest/carousel_slider/`

## 方案选择

采用 `carousel_slider: ^5.1.2`，由第三方组件负责无限循环、自动播放、动画和触摸暂停。项目代码不再持有自研 `Timer`，也不再维护虚拟页索引。

仍保留首页 feature 内的 `RecommendCarousel` 薄封装，用于：

- 把 `MovieSummary` 映射为现有封面、标题遮罩和点击区域；
- 统一固化首页轮播参数；
- 通过 `CarouselSliderController` 响应 App 生命周期和 `TickerMode` 可见性；
- 隔离第三方组件 API，避免 `HomePage` 直接承担轮播状态。

未选择以下方案：

- 直接在 `HomePage` 内联 `CarouselSlider`：文件更短，但生命周期和第三方配置会再次混入首页页面代码。
- `carousel_slider` 外再叠加自研 `Timer`：产生两套自动播放状态，容易重复翻页，不符合单一职责。

## 组件配置

`RecommendCarousel` 使用 `CarouselSlider.builder`，配置固定为：

```dart
CarouselOptions(
  height: 220,
  viewportFraction: 1,
  enableInfiniteScroll: movies.length > 1,
  autoPlay: movies.length > 1,
  autoPlayInterval: const Duration(seconds: 5),
  autoPlayAnimationDuration: const Duration(milliseconds: 400),
  autoPlayCurve: Curves.easeInOut,
  pauseAutoPlayOnTouch: true,
  enlargeCenterPage: false,
)
```

不增加页码指示器、不放大中心项、不改变页面边距。轮播项继续使用 `MovieCoverImage`、`MovieImageVariant.cover`、黑色半透明标题遮罩和现有电影详情回调。

## 可见性与生命周期

`RecommendCarousel` 为 `StatefulWidget` 并实现 `WidgetsBindingObserver`：

- 创建并持有 `CarouselSliderController`；
- App 进入非 `resumed` 状态时调用 `stopAutoPlay()`；
- App 恢复 `resumed` 时，仅在 `TickerMode` 启用且影片数量大于 1 时调用 `startAutoPlay()`；
- `TickerMode` 关闭时停止，重新启用时恢复；
- `dispose` 时移除生命周期观察者，不创建或管理额外计时器。

调用控制器前通过 post-frame 同步，避免组件尚未挂载到控制器时调用。

## 数据与边界

- 推荐为空：继续使用现有 `EmptyState`，不创建轮播组件。
- 推荐只有一条：`autoPlay` 与 `enableInfiniteScroll` 均为 `false`。
- 推荐多于一条：开启自动播放与无限循环。
- 推荐列表变化：由 `CarouselSlider.builder` 根据新的 `itemCount` 重建。
- 网络错误与重试：继续由现有 `HomeSection` 和 `HomeProvider` 处理。
- 点击影片：继续由 `HomePage` 执行 `context.push('/movie/${movie.id}')`。

## 测试设计

测试用户可见行为，不依赖 `carousel_slider` 内部 `PageController`：

1. 未满 5 秒时保持第一条，满 5 秒并完成 400 毫秒动画后显示第二条；
2. 从最后一条继续自动切换后显示第一条；
3. 用户手动滑动后重新等待完整 5 秒；
4. 只有一条推荐时经过多个间隔仍保持原页；
5. App 进入后台时不切换，恢复后重新计时；
6. `TickerMode` 关闭时不切换，重新启用后恢复；
7. 组件销毁后推进测试时钟不会产生异常；
8. 首页成功态接入新轮播，同时保留原有 loading、error、empty 和路由行为。

验证顺序：

1. `flutter test test/features/home/recommend_carousel_test.dart`
2. `flutter test test/features/home/home_screen_test.dart`
3. `flutter analyze`
4. `flutter test`
5. `git diff --check`

## 非目标

- 不增加指示器、自动播放开关或新的用户设置；
- 不改变轮播高度、图片裁剪、标题样式和点击路由；
- 不修改推荐接口、推荐顺序或首页其他分区；
- 不直接依赖 `carousel_slider` 的内部实现或私有状态。
