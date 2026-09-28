# 目标

首页"佳片推荐"轮播卡片（`RecommendCarousel`）底部遮罩内的标题文本固定单行显示：标题超出卡片宽度时在行尾以省略号截断，不再换行；遮罩与轮播布局不因长标题变化。

# 范围

- 修改 `lib/features/home/widgets/recommend_carousel.dart` 中底部遮罩内标题 `Text` 的排版约束（`maxLines: 1`、`overflow: TextOverflow.ellipsis`）。
- 在 `test/features/home/recommend_carousel_test.dart` 为单行省略行为补充组件级测试。

# 非目标

- 不调整轮播高度、图片加载、模糊逻辑、自动播放与其他视觉样式。
- 不处理首页其他组件（豆腐块、历史推荐、最新影片等）的文本溢出。
- 不改变标题字体、字号、颜色与遮罩配色。

# 验收示例

- A1: 首页佳片推荐轮播卡片标题超出卡片宽度时，标题仅渲染一行并在行尾显示省略号，不换行，底部遮罩高度保持单行文本的高度。
- A2: 首页佳片推荐轮播卡片标题未超出一行宽度时完整显示，行尾无省略号。
- A3: 轮播既有行为保持不变：多张时每 5 秒自动切换、手动滑动、单张不自动切换、后台暂停恢复、TickerMode 暂停。

# 约束与不变量

- 不引入新依赖；仅使用 Flutter 标准文本排版能力。
- 既有测试锚点不变（`home-recommend-carousel`、`home-recommend-card-<id>`）。
- 组件其他逻辑（自动播放同步、生命周期监听）不做行为性修改。

# 决策

- D1: 采用 `Text(maxLines: 1, overflow: TextOverflow.ellipsis)` 的标准实现，而非自定义裁剪或固定行高；这是 Flutter 单行溢出省略的惯用方式，直接满足"超出一行省略表示"。
- D2: 验收以组件级 widget 测试验证（断言标题 `Text` 的 `maxLines`/`overflow` 属性及长标题下的渲染表现），不依赖真机截图。

# 待解决问题

无。

# 验证预期

- `flutter test test/features/home/recommend_carousel_test.dart` 全部通过（含新增单行省略用例）。
- `flutter analyze` 无新增告警。
