# Outcome

优化资讯列表页面（`ArticlesScreen`）中每条资讯卡片的封面图片展示，使其等比例缩放逻辑与影片详情页预告片/剧照区的预览图保持一致，提升视觉一致性和错误/空图时的兜底体验。

# Scope

- 修改 `lib/features/articles/widgets/article_card.dart` 中的封面图片区域。
- 参考 `lib/features/movie_detail/widgets/basic_info_sections.dart` 中 `MovieScreenshotSection` 的预览图实现。
- 统一使用 `AspectRatio(16 / 9)` + `BoxFit.cover` 的等比例缩放逻辑。
- 为资讯封面引入与 `MovieCoverImage` 一致的图片兜底（fallback）机制。

# Non-goals

- 不改变资讯列表的整体布局、卡片点击行为或文字样式。
- 不修改影片详情页预览图现有逻辑。
- 不新增外部图片资源（复用项目已有兜底图，或沿用图标占位）。
- 不调整资讯详情页（article detail）内的图片展示。

# Acceptance examples

- A1：资讯列表的 `ArticleCard` 封面区域仍保持 `16 / 9` 宽高比。
- A2：封面图片使用 `BoxFit.cover` 等比例填充并裁剪，与影片详情预览图一致。
- A3：封面 URL 为空或加载失败时，显示统一的兜底占位，不再只显示空白或图标。
- A4：资讯列表项的视觉回归测试或 widget 测试通过，确认无溢出、无变形。

# Constraints and invariants

- 保持现有 `ArticleCard` 的 `Card` + `InkWell` 结构和外边缘圆角。
- 不引入新的第三方依赖。
- 保持 `CachedImage` 作为底层图片加载组件。

# Decisions

- 调查发现 `ArticleCard` 当前已使用 `AspectRatio(16 / 9)` + `CachedImage(fit: BoxFit.cover)`，核心等比例缩放逻辑与影片详情预览图一致。
- 差异仅在于影片详情预览图通过 `MovieCoverImage` 提供了 `fallbackAsset` 兜底图；资讯列表当前仅使用图标占位。
- 采用语义更合适的 `ArticleCoverImage` 组件封装 `CachedImage` 并配置 fallback，与 `MovieCoverImage` 结构保持一致，避免在资讯列表直接引用影片专用组件。

# Open questions

- 无

# Verification expectations

- `dart analyze` 无新增错误/警告。
- 相关 widget 测试通过；如缺少测试则补充覆盖等比例与兜底图场景。
