# 目标

重新修复资讯列表 `ArticleCard` 封面"没有正常缩放"的问题。上一轮 `fix-news-cover-fit` 已让封面按 `16:9` 容器 `BoxFit.cover` 填充裁剪，但服务端返回的封面比例并不固定（宽幅约 2.4:1，也有约 3:4 的竖版图），`16:9` + cover 把竖版封面裁剪成只剩中央特写窄条，用户反馈依旧是"没有正常缩放"。本轮将封面改为按图片真实宽高比等比例完整显示：宽度撑满卡片、高度自适应，超高封面限高并取图顶部等比裁剪。

# 范围

## 目录结构

### 新建

- 无

### 修改

- `lib/features/articles/widgets/article_card.dart`（移除固定 `AspectRatio(16 / 9)` 封面容器）
- `lib/features/articles/widgets/article_cover_image.dart`（按图片真实尺寸自适应高度与限高裁剪）
- `lib/core/widgets/cached_image.dart`（透传封面渲染所需的 `alignment`）

### 删除

- 无

### 明确不建

- 不改资讯列表分页、加载与刷新逻辑。
- 不改资讯详情页正文渲染（`ArticleWidgetFactory`、`ArticleDetailScreen`）。
- 不改影片封面组件（`MovieCoverImage` 等其他页面图片）。

# 非目标

- 不改卡片点击跳转、圆角间距、标题/作者/分类/时间样式。
- 不改服务端接口与封面 URL。
- 不处理详情页正文内图片的拉伸问题（另一话题，若用户要求再另行处理）。

# 验收示例

- A1：`ArticleCard` 封面宽度撑满卡片宽度，加载完成前以 `16 / 9` 占位（无塌陷、无按原始尺寸溢出）。
- A2：封面图片始终等比例缩放（fitWidth 自适应或限高等比裁剪），任意比例封面均不变形、不拉伸。
- A3：图片真实尺寸解锁后，封面高度按图片真实宽高比自适应：竖版封面（如约 3:4）在限高范围内完整可见。
- A4：封面高超过最大限高（取卡片宽度 1.0 倍为上限）时，封面高度固定为该上限，图片等比缩放并以顶部对齐裁剪（保留图片顶部主体）。
- A5：封面 URL 为空或加载失败时，在 `16 / 9` 占位区内显示统一兜底图（`assets/images/noimage_600x404.jpg`）并填满占位区。
- A6：卡片点击跳转、圆角间距、标题/作者/分类/时间样式与改动前一致；全局"模糊图片"设置对封面继续生效。
- A7：`flutter analyze --no-pub` 对修改文件零告警。
- A8：`flutter test --no-pub test/features/articles/article_card_test.dart`（及新增用例）通过。

# 约束与不变量

- 保持 `CachedImage` 作为底层加载组件与解密缓存路径，`memCache` 槽位不新增解码负担。
- 保持空地址/加载失败时显示统一兜底图。
- 保持图片不变形（等比例缩放，禁止 `BoxFit.fill` 式拉伸）。
- `ArticleCoverImage` 需改为 StatefulWidget 以粘住本次会话内已解码的图片尺寸，避免滚动复用时尺寸丢失。
- 高度自适应值与限高值在 build 期从容器宽度推导，不依赖 `MediaQuery.textScale` 等无关量。

# 决策

- 真机调查结论（模拟器 Medium Phone，debug 构建当前 master 代码）：
  - 服务端封面比例不固定：卡 1（吉村）为宽幅图（约 2.4:1），卡 2（SNOS-484）与卡 3 为竖版图（约 3:4），列表 `AspectRatio(16/9)` + `BoxFit.cover` 将竖图裁剪为中央特写窄条。
  - 该行为的实现自归档 change `fix-news-cover-fit`（提交 500cb9c），`ArticleCard` 使用 `AspectRatio(16/9)`，`ArticleCoverImage` 内 `LayoutBuilder` 取容器尺寸显式传给 `CachedImage`。
- D1（封面形态，Q1 用户未答复、按推荐采用）：封面按图片真实宽高比等比例完整显示（宽度撑满、高度自适应），超高封面限高并取图顶部裁剪；不采用"固定 16:9 容器等比留白"与"维持现状裁剪"。若用户在最终确认时改为其他形态，按 `--revise-requirements` 流程重新确认 Shape。
- D2（限高值）：最大显示高度取卡片宽度 1.0 倍（正方形上限）：既避免竖版封面占满整屏，又保证约 3:4 的常见竖图裁剪量可控（约 25%，顶部对齐保留主体）；具体数值在真机预览后如有明显观感问题再调整。
- D3（顶部对齐）：超高限高裁剪采用 `Alignment.topCenter`，保留图片顶部主体（人物头部通常位于上部）。

# 待解决问题

- （已无 blocking：Q1 用户线上未答复，按工具指引以最佳判断采用推荐形态 A 推进；该假设已记入 D1，最终 Shape 确认时用户可推翻。）

# 验证预期

- 修改文件 `flutter analyze --no-pub` 零告警。
- 资讯卡片相关 widget 测试通过（含新增自适应高度/限高裁剪用例）。
- 真机（adb_tool 安装 debug 构建到模拟器）截图核对：宽幅与竖版封面按 D1 形态正常缩放，无变形。
