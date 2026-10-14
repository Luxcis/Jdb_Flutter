# 目标

修复资讯列表页面 `ArticleCard` 的封面图片未按 `16:9` 容器缩放裁剪的问题：图片当前按原始尺寸/宽高比显示，未应用 `BoxFit.cover`，需通过 `LayoutBuilder` 获取父容器尺寸并显式传递给底层 `CachedImage`，使图片在 `AspectRatio(16 / 9)` 容器内等比例填充并裁剪。

# 范围

## 目录结构

### 新建

- 无

### 修改

- `lib/features/articles/widgets/article_cover_image.dart`

### 删除

- 无

### 明确不建

- 不新增文件；不改 `ArticleCard` 结构。

# 非目标

- 不改宽高比、不改兜底图资源、不改卡片点击或文字样式。
- 不影响影片详情预览图逻辑。

# 验收示例

- A1：`ArticleCoverImage` 使用 `LayoutBuilder` 读取父容器尺寸并传给 `CachedImage` 的 `width`/`height`。
- A2：`ArticleCard` 中 `AspectRatio(16 / 9)` 容器内的图片按 `BoxFit.cover` 填充裁剪，不显示完整原始比例。
- A3：`flutter analyze --no-pub`（修改文件）通过。
- A4：`flutter test --no-pub test/features/articles/article_card_test.dart` 通过。

# 约束与不变量

- 保持默认 `BoxFit.cover`。
- 保持 `CachedImage` 作为底层加载组件。
- 保持空地址/加载失败的兜底图行为。

# 决策

- 根因：`ArticleCoverImage` 未向 `CachedImage` 提供明确的 `width`/`height`，导致网络图片在没有 tight constraints 时按固有尺寸渲染，`BoxFit.cover` 未生效。
- 修复：在 `ArticleCoverImage` 内部使用 `LayoutBuilder`，将父容器 `maxWidth`/`maxHeight` 作为 `CachedImage` 与兜底 `Image.asset` 的宽高，确保图片填满 `AspectRatio` 容器。

# 待解决问题

- 无

# 验证预期

- 修改文件 analyze 零告警。
- `article_card_test.dart` 通过。
