# Capability: article-card（资讯卡片封面图片）

本能力描述资讯列表中 `ArticleCard` 封面图片的完整渲染行为，确保其等比例缩放、兜底占位与影片详情预览图保持一致。

## 等比例缩放

Scenario: 封面图片按 16:9 等比例展示
- GIVEN 资讯列表中任意 `ArticleCard`
- WHEN 卡片渲染封面区域
- THEN 封面容器使用 `AspectRatio(aspectRatio: 16 / 9)` 固定宽高比
- AND 图片使用 `BoxFit.cover` 等比例填充并裁剪，不变形、不拉伸
- AND 视觉行为与影片详情页 `MovieScreenshotSection` 的预览图一致

## 兜底占位

Scenario: 空地址或加载失败时显示兜底图
- GIVEN 资讯封面 URL 为空、缺失或网络加载失败
- WHEN `ArticleCard` 渲染封面区域
- THEN 显示项目统一的兜底占位图（复用 `assets/images/noimage_600x404.jpg`）
- AND 兜底图同样按 `BoxFit.cover` 填充 `16 / 9` 容器

## 组件封装

Scenario: 资讯封面使用专用组件
- GIVEN 需要渲染资讯封面
- WHEN 查看 `lib/features/articles/widgets/`
- THEN 存在 `ArticleCoverImage` 组件，内部使用 `CachedImage`
- AND `ArticleCoverImage` 结构与 `MovieCoverImage` 保持一致（url、fit、fallbackAsset、semanticLabel 等参数）
- AND `ArticleCard` 通过 `ArticleCoverImage` 渲染封面，不再直接调用 `CachedImage`

## 既有行为保持

Scenario: 卡片整体行为不变
- GIVEN 用户在资讯列表浏览
- WHEN 点击 `ArticleCard`
- THEN 仍跳转至资讯详情页
- AND 卡片圆角、间距、标题、作者、分类、发布时间展示与改动前一致

## 回归保障

Scenario: 静态分析与测试通过
- GIVEN 完成封面图片改造
- WHEN 运行 `flutter analyze --no-pub` 与 `flutter test`
- THEN analyze 零告警、相关 widget 测试通过，既有行为无回归
