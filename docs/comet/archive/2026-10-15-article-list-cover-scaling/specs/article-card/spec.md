# Capability: article-card（资讯卡片封面图片）

本能力描述资讯列表中 `ArticleCard` 封面图片的完整渲染行为：封面按图片真实宽高比等比例完整显示，宽度撑满卡片、高度自适应，超高封面限高并取图顶部等比裁剪；空地址或加载失败时显示统一兜底图。

## 自适应等比缩放

### Scenario: 封面宽度撑满并在加载完成前占位
- GIVEN 资讯列表中任意 `ArticleCard`
- WHEN 卡片渲染封面区域且封面 URL 非空
- THEN 封面宽度撑满卡片内容宽度
- AND 图片真实尺寸未解码显示前，封面区域使用 `AspectRatio(16 / 9)` 占位，封面无塌陷、无按原始尺寸溢出
- AND 封面高度由容器宽度按图片真实宽高比推导，不使用固定 `16 / 9` 容器裁剪图片

### Scenario: 封面始终等比例缩放不变形
- GIVEN 封面图片为任意宽高比（宽幅、竖版或正方形）
- WHEN 封面渲染完成
- THEN 图片按等比例缩放显示，宽度与容器一致时高度等于 `容器宽度 / 原始宽高比`（在限高范围内）
- AND 图片不变形、不拉伸，不使用 `BoxFit.fill` 或 `BoxFit.contain` 留白模式

### Scenario: 超高封面限高并取顶部裁剪
- GIVEN 封面图片按宽度等比缩放后的高度超过最大限高（卡片宽度的 1.0 倍）
- WHEN 封面渲染完成
- THEN 封面显示高度固定为限高，图片仍然等比例缩放并完整覆盖宽度
- AND 图片以 `Alignment.topCenter` 呈现，裁剪发生在图片底部，保留图片顶部主体

## 兜底占位

### Scenario: 空地址或加载失败时显示兜底图
- GIVEN 资讯封面 URL 为空、缺失或网络加载失败
- WHEN `ArticleCard` 渲染封面区域
- THEN 封面区域保持 `16 / 9` 占位区并显示项目统一兜底占位图（`assets/images/noimage_600x404.jpg`），填满占位区

## 既有行为保持

### Scenario: 卡片整体行为不变
- GIVEN 用户在资讯列表浏览
- WHEN 点击 `ArticleCard`
- THEN 仍跳转至资讯详情页
- AND 卡片圆角、间距、标题、作者、分类、发布时间展示与改动前一致
- AND 全局"模糊图片"设置对封面图片继续生效

## 回归保障

### Scenario: 静态分析与测试通过
- GIVEN 完成封面图片重构
- WHEN 运行 `flutter analyze --no-pub` 与 `flutter test --no-pub test/features/articles/article_card_test.dart`
- THEN analyze 零告警、widget 测试通过，既有行为无回归
