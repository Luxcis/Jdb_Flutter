# Capability: article-card（资讯卡片封面图片）

本能力描述资讯列表中 `ArticleCard` 封面图片的完整渲染行为，确保其在 `16:9` 容器内按 `BoxFit.cover` 等比例填充并裁剪。

## 等比例缩放

Scenario: 封面图片按 16:9 容器等比例填充裁剪
- GIVEN 资讯列表中任意 `ArticleCard`
- WHEN 卡片渲染封面区域
- THEN 封面容器使用 `AspectRatio(aspectRatio: 16 / 9)` 固定宽高比
- AND `ArticleCoverImage` 通过 `LayoutBuilder` 读取父容器尺寸
- AND 将容器宽高显式传给底层 `CachedImage` 与兜底 `Image.asset`
- AND 图片使用 `BoxFit.cover` 等比例填充并裁剪，不变形、不拉伸、不显示完整原始比例

## 兜底占位

Scenario: 空地址或加载失败时显示兜底图
- GIVEN 资讯封面 URL 为空、缺失或网络加载失败
- WHEN `ArticleCard` 渲染封面区域
- THEN 显示项目统一的兜底占位图（`assets/images/noimage_600x404.jpg`）
- AND 兜底图同样按 `BoxFit.cover` 填充 `16 / 9` 容器

## 既有行为保持

Scenario: 卡片整体行为不变
- GIVEN 用户在资讯列表浏览
- WHEN 点击 `ArticleCard`
- THEN 仍跳转至资讯详情页
- AND 卡片圆角、间距、标题、作者、分类、发布时间展示与改动前一致

## 回归保障

Scenario: 静态分析与测试通过
- GIVEN 完成封面图片修复
- WHEN 运行 `flutter analyze --no-pub` 与 `flutter test --no-pub test/features/articles/article_card_test.dart`
- THEN analyze 零告警、widget 测试通过，既有行为无回归
